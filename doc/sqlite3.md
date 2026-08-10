# SQLite en Tcl: guía completa del package `sqlite3`

Este es probablemente el tema más directamente aplicable a tu stack real: tu backend ya usa Go + SQLite, así que si alguna vez escribes una herramienta satélite en Tcl/Tk (inspector de DB, utilidad de migración, panel de diagnóstico), vas a necesitar hablar con la misma base de datos desde Tcl. El binding es excelente: `sqlite3` es un wrapper directo sobre la librería C de SQLite, con una API muy idiomática a Tcl.

```tcl
package require sqlite3
```

---

## 1. Conectar y comandos básicos

```tcl
sqlite3 db "inventario.db"     ;# crea el comando "db" que representa la conexión
# sqlite3 db :memory:          ;# base de datos en memoria, útil para tests

db eval {CREATE TABLE IF NOT EXISTS productos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre TEXT NOT NULL,
    precio REAL NOT NULL,
    stock INTEGER DEFAULT 0
)}

db eval {INSERT INTO productos (nombre, precio, stock) VALUES ('Arroz', 2.50, 100)}

db close    ;# cierra la conexión cuando termines
```

Nota clave: `sqlite3 db archivo.db` crea un **nuevo comando Tcl llamado `db`** (el nombre que tú elijas) que representa la conexión — no una variable, un comando. Cada llamada `db eval {...}`, `db close`, etc. es una invocación normal de comando Tcl. Puedes tener múltiples conexiones simultáneas dando nombres distintos: `sqlite3 db1 archivo1.db`, `sqlite3 db2 archivo2.db`.

---

## 2. `db eval`: el comando que usarás el 90% del tiempo

### Consultas simples, resultado como lista plana
```tcl
set resultado [db eval {SELECT nombre, precio FROM productos}]
puts $resultado    ;# Arroz 2.50 Frijoles 1.80 ...  (todo en una sola lista plana)
```
Sin variables de captura, `db eval` retorna **una sola lista plana** con todos los valores de todas las columnas de todas las filas concatenados — rara vez es lo que quieres para más de una columna; mejor usa el modo con script (abajo).

### Con script por fila (el patrón más usado)
```tcl
db eval {SELECT nombre, precio, stock FROM productos} {
    puts "$nombre cuesta \$$precio, quedan $stock unidades"
}
```
Aquí `nombre`, `precio`, `stock` se convierten **automáticamente en variables locales** con el nombre exacto de cada columna, disponibles dentro del bloque de script — no necesitas indexar nada. Esto es más cómodo que iterar `rows.Next()` en Go, aunque menos type-safe.

### Con variables de instancia (útil dentro de una proc)
```tcl
proc listarProductosBaratos {maxPrecio} {
    db eval {SELECT nombre, precio FROM productos WHERE precio <= :maxPrecio} {
        puts "$nombre: \$$precio"
    }
}
listarProductosBaratos 3.0
```
`:maxPrecio` en la consulta SQL se resuelve automáticamente contra la **variable Tcl `maxPrecio`** del scope donde llamas a `db eval` — esto es interpolación segura de parámetros (previene SQL injection), equivalente a placeholders `?`/`$1` en Go, pero con sintaxis de variable con nombre en vez de posicional.

### Capturando todas las filas en una lista de dicts
```tcl
set productos {}
db eval {SELECT id, nombre, precio, stock FROM productos} row {
    lappend productos [array get row]
}
```
`row` aquí es un **array Tcl** (no dict) que se llena con las columnas de cada fila — `array get row` lo convierte a una lista plana clave-valor que puedes envolver en `dict create {*}[array get row]` si prefieres trabajar con dicts.

---

## 3. Prepared statements y parámetros — seguridad ante inyección SQL

**Nunca** concatenes valores externos directamente en el SQL. Usa siempre variables con `:nombre` (o `$nombre`, equivalente):

```tcl
# MAL — vulnerable a inyección SQL si $nombreProducto viene de input de usuario
db eval "SELECT * FROM productos WHERE nombre = '$nombreProducto'"

# BIEN — el valor se pasa como parámetro real, nunca se interpola en el SQL
set nombreProducto "Arroz'; DROP TABLE productos; --"
db eval {SELECT * FROM productos WHERE nombre = :nombreProducto} {
    puts "$nombre: $precio"
}
```
Con `:variable`, SQLite recibe el valor como un parámetro binario real (usando `sqlite3_bind_text` internamente), nunca como texto SQL — el intento de inyección de arriba simplemente no encuentra ningún producto con ese nombre literal, sin ejecutar nada malicioso.

---

## 4. INSERT, UPDATE, DELETE

```tcl
proc agregarProducto {nombre precio stock} {
    db eval {INSERT INTO productos (nombre, precio, stock) VALUES (:nombre, :precio, :stock)}
    return [db last_insert_rowid]     ;# id autoincremental recién insertado
}

proc actualizarStock {id cantidad} {
    db eval {UPDATE productos SET stock = stock + :cantidad WHERE id = :id}
    return [db changes]                 ;# cuántas filas fueron afectadas
}

proc eliminarProducto {id} {
    db eval {DELETE FROM productos WHERE id = :id}
}
```
`db last_insert_rowid` y `db changes` son metadatos post-operación muy usados: el primero para obtener el ID generado (equivalente a `LastInsertId()` en Go), el segundo para verificar cuántas filas cambiaron realmente (útil para detectar "no encontré nada que actualizar").

---

## 5. Transacciones

```tcl
db eval {BEGIN}
if {[catch {
    db eval {UPDATE productos SET stock = stock - 1 WHERE id = 1}
    db eval {INSERT INTO ventas (producto_id, cantidad) VALUES (1, 1)}
    db eval {COMMIT}
} err]} {
    db eval {ROLLBACK}
    puts "Error en la transacción: $err"
}
```

### Forma idiomática: `db transaction`
```tcl
proc venderProducto {id cantidad} {
    db transaction {
        db eval {UPDATE productos SET stock = stock - :cantidad WHERE id = :id}
        if {[db onecolumn {SELECT stock FROM productos WHERE id = :id}] < 0} {
            error "stock insuficiente"
        }
        db eval {INSERT INTO ventas (producto_id, cantidad) VALUES (:id, :cantidad)}
    }
    ;# si el bloque lanza error, sqlite3 hace ROLLBACK automáticamente
    ;# si termina sin error, hace COMMIT automáticamente
}
```
`db transaction {...}` es la forma recomendada — maneja `BEGIN`/`COMMIT`/`ROLLBACK` automáticamente según si el bloque completa sin error o lanza uno (equivalente a lo que harías manualmente con `defer tx.Rollback()` en Go, pero automático). **Siempre** envuelve operaciones multi-tabla relacionadas en `db transaction` para garantizar atomicidad — exactamente el mismo motivo por el que lo harías en tu backend Go.

---

## 6. `db onecolumn` y `db exists`: azúcar sintáctica muy usada

```tcl
set total [db onecolumn {SELECT COUNT(*) FROM productos}]
puts "Hay $total productos"

set precio [db onecolumn {SELECT precio FROM productos WHERE id = :id}]

if {[db exists {SELECT 1 FROM productos WHERE nombre = :nombre}]} {
    puts "el producto ya existe"
}
```
`onecolumn` extrae directamente el único valor de una consulta que retorna 1 fila x 1 columna (evita el boilerplate de `db eval {...} row {return $row(columna)}`). `exists` retorna 1/0 directo, sin necesitar `COUNT(*) > 0` a mano.

---

## 7. Manejo de errores de SQLite

```tcl
if {[catch {
    db eval {INSERT INTO productos (nombre, precio) VALUES ('Arroz', 'no es un número')}
} err opts]} {
    puts "Error: $err"
    puts "Código de error SQLite: [dict get $opts -errorcode]"
}
```
`-errorcode` en las opciones capturadas por `catch` te da el código SQLite específico (`SQLITE_CONSTRAINT`, `SQLITE_BUSY`, etc.), útil para diferenciar programáticamente entre "violación de constraint" vs "base de datos bloqueada" vs otros errores.

### `SQLITE_BUSY`: bases de datos bloqueadas (relevante en apps con GUI + escrituras concurrentes)
```tcl
db timeout 5000    ;# espera hasta 5 segundos si la DB está bloqueada por otra conexión/proceso, antes de fallar
```
Si tu herramienta Tcl y tu backend Go acceden al mismo archivo `.db` simultáneamente, configura `timeout` para que Tcl reintente automáticamente en vez de fallar inmediatamente con "database is locked" — SQLite soporta un solo escritor a la vez, así que este ajuste evita errores esporádicos bajo contención leve.

---

## 8. Funciones custom en Tcl invocables desde SQL

Puedes registrar procs Tcl como funciones SQL — útil para lógica que es más fácil expresar en Tcl que en SQL puro:

```tcl
proc calcularDescuento {precio porcentaje} {
    return [expr {$precio * (1 - $porcentaje / 100.0)}]
}
db function descuento calcularDescuento

db eval {SELECT nombre, descuento(precio, 10) AS precio_con_descuento FROM productos} {
    puts "$nombre: \$$precio_con_descuento"
}
```
Esto es equivalente a registrar una función custom en `database/sql` de Go a través de un driver que lo soporte, pero mucho más directo en Tcl — cualquier proc se registra con una línea.

---

## 9. Metadatos del esquema

```tcl
# Listar tablas
db eval {SELECT name FROM sqlite_master WHERE type='table'}

# Info de columnas de una tabla
db eval {PRAGMA table_info(productos)} {
    puts "$name ($type) — pk:$pk notnull:$notnull"
}

# Índices
db eval {PRAGMA index_list(productos)}
```
Útil si construyes una herramienta genérica de inspección de base de datos (ej. un explorador visual de tablas en Tk) que debe adaptarse al esquema sin conocerlo de antemano.

---

## 10. Configuración de rendimiento (PRAGMAs relevantes para tu contexto offline)

```tcl
db eval {PRAGMA journal_mode = WAL}       ;# Write-Ahead Log: mejor concurrencia lectura/escritura
db eval {PRAGMA synchronous = NORMAL}     ;# balance entre seguridad y velocidad (FULL es más seguro pero más lento)
db eval {PRAGMA foreign_keys = ON}        ;# SQLite NO valida FKs por defecto, hay que activarlo explícitamente
db eval {PRAGMA cache_size = -2000}       ;# 2MB de cache en RAM (negativo = KB, positivo = número de páginas)
```
`journal_mode = WAL` es particularmente relevante si tu herramienta Tcl y tu backend Go leen/escriben la misma DB: WAL permite lectores concurrentes mientras hay un escritor activo, reduciendo mucho los errores de "database is locked" frente al modo journal por defecto (`DELETE`).

`foreign_keys = ON` es fácil de olvidar — SQLite por compatibilidad histórica **no** aplica constraints de FK a menos que lo actives por conexión, cada vez que abres la base.

---

## 11. Backup y export

```tcl
# Backup completo a otro archivo, mientras la DB original sigue en uso
db backup respaldo.db

# Exportar resultados a CSV manualmente
package require csv
set f [open "productos.csv" w]
fconfigure $f -encoding utf-8
puts $f [::csv::join {id nombre precio stock}]
db eval {SELECT id, nombre, precio, stock FROM productos} {
    puts $f [::csv::join [list $id $nombre $precio $stock]]
}
close $f
```

---

## 12. Patrón: capa de acceso a datos (DAO) limpia, conectando con la guía de estado

Siguiendo el patrón de la guía de gestión de estado (§7, "SQLite como fuente de verdad"), aquí un módulo DAO completo y reutilizable:

```tcl
namespace eval ::App::DB {
    variable conexionAbierta 0

    proc conectar {ruta} {
        variable conexionAbierta
        if {!$conexionAbierta} {
            sqlite3 db $ruta
            db eval {PRAGMA foreign_keys = ON}
            db eval {PRAGMA journal_mode = WAL}
            db timeout 5000
            set conexionAbierta 1
        }
    }

    proc desconectar {} {
        variable conexionAbierta
        if {$conexionAbierta} {
            db close
            set conexionAbierta 0
        }
    }

    proc obtenerProductos {} {
        set resultado {}
        db eval {SELECT id, nombre, precio, stock FROM productos ORDER BY nombre} {
            lappend resultado [dict create id $id nombre $nombre precio $precio stock $stock]
        }
        return $resultado
    }

    proc obtenerProducto {id} {
        set fila {}
        db eval {SELECT id, nombre, precio, stock FROM productos WHERE id = :id} {
            set fila [dict create id $id nombre $nombre precio $precio stock $stock]
        }
        return $fila
    }

    proc crearProducto {nombre precio stock} {
        db eval {INSERT INTO productos (nombre, precio, stock) VALUES (:nombre, :precio, :stock)}
        return [db last_insert_rowid]
    }

    proc venderProducto {id cantidad} {
        db transaction {
            set stockActual [db onecolumn {SELECT stock FROM productos WHERE id = :id}]
            if {$stockActual < $cantidad} {
                error "stock insuficiente: hay $stockActual, se pidieron $cantidad"
            }
            db eval {UPDATE productos SET stock = stock - :cantidad WHERE id = :id}
            db eval {INSERT INTO ventas (producto_id, cantidad, fecha) VALUES (:id, :cantidad, :fecha)} \
                -- with fecha [clock seconds]
        }
    }
}

::App::DB::conectar "inventario.db"
foreach p [::App::DB::obtenerProductos] {
    puts "[dict get $p nombre]: [dict get $p stock] unidades"
}
```
Esta capa (`::App::DB::*`) es exactamente lo que conectarías al `dispatch` del store de la guía de estado — el store llama a `::App::DB::venderProducto`, actualiza el dict en memoria releyendo, y notifica a los widgets suscritos. Mantiene el SQL completamente aislado del resto de la app.

---

## 13. Testing de código con SQLite (conectando con la guía de tcltest)

Usa `:memory:` para tests rápidos, sin tocar el archivo real ni dejar residuos:

```tcl
package require tcltest
namespace import ::tcltest::*
package require sqlite3

proc prepararDBTest {} {
    if {[llength [info commands ::db]] > 0} { db close }
    sqlite3 db :memory:
    db eval {CREATE TABLE productos (id INTEGER PRIMARY KEY, nombre TEXT, precio REAL, stock INTEGER)}
}

test dao-1.1 {crear e insertar producto} -setup prepararDBTest -body {
    db eval {INSERT INTO productos (nombre, precio, stock) VALUES ('Arroz', 2.50, 100)}
    db onecolumn {SELECT COUNT(*) FROM productos}
} -cleanup {db close} -result 1

test dao-1.2 {venta reduce el stock correctamente} -setup prepararDBTest -body {
    db eval {INSERT INTO productos (id, nombre, precio, stock) VALUES (1, 'Arroz', 2.50, 100)}
    db eval {UPDATE productos SET stock = stock - 10 WHERE id = 1}
    db onecolumn {SELECT stock FROM productos WHERE id = 1}
} -cleanup {db close} -result 90

cleanupTests
```
`:memory:` crea una base de datos completamente en RAM, destruida al cerrar la conexión — perfecta para tests, corre extremadamente rápido y no deja archivos residuales que limpiar entre corridas.

---

## 14. Resumen de referencia rápida

| Comando | Uso |
|---|---|
| `sqlite3 nombreCmd archivo.db` | abre/crea conexión, expone `nombreCmd` como comando |
| `db eval {sql} {...script...}` | ejecuta SQL, variables de columna disponibles en el script |
| `db eval {sql}` | sin script: retorna todo como lista plana |
| `:variable` en el SQL | parámetro seguro contra inyección, tomado del scope Tcl |
| `db onecolumn {...}` | extrae un único valor escalar |
| `db exists {...}` | retorna 1/0 si la consulta tiene resultados |
| `db last_insert_rowid` | ID autoincremental de la última inserción |
| `db changes` | filas afectadas por el último INSERT/UPDATE/DELETE |
| `db transaction {...}` | BEGIN/COMMIT/ROLLBACK automático según éxito/error |
| `db timeout ms` | reintentos automáticos si la DB está bloqueada |
| `db function nombre proc` | registra una proc Tcl como función SQL custom |
| `db backup archivo` | respaldo en caliente |
| `PRAGMA journal_mode = WAL` | mejor concurrencia lectura/escritura |
| `PRAGMA foreign_keys = ON` | activa validación de FKs (apagado por defecto) |
| `:memory:` como ruta | base de datos en RAM, ideal para tests |

---

## 15. Nota final para tu caso

Dado que tu backend real ya es Go + SQLite con probablemente `mattn/go-sqlite3` o `modernc.org/sqlite`, el único escenario real donde usarías este binding Tcl es en herramientas satélite standalone — un inspector visual rápido de la base de datos de producción para debugging en campo (sin necesitar levantar tu app completa), o un script de migración/reparación de datos que corres una sola vez. Para eso, el combo `sqlite3` + `ttk::treeview` (de la guía de Tk) + `snit::widget` (de la guía de Snit) te da, en menos de 100 líneas, un DB browser funcional — algo genuinamente útil en tu entorno de baja conectividad donde no siempre quieres depender de herramientas gráficas pesadas o basadas en web para inspeccionar una base local.
