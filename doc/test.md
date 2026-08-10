# Testing en Tcl: tcltest de raíz a avanzado

`tcltest` es el framework de testing estándar incluido con Tcl (no necesitas instalar nada externo, viene con `tclsh`). Es el equivalente al `testing` package de Go o a Jest/Vitest en JS: assertions, setup/teardown, agrupación de tests, output configurable, y soporte para test suites grandes con constraints (skips condicionales).

```tcl
package require tcltest
namespace import ::tcltest::*
```

---

## 1. Anatomía de un test: `test`

Todo gira en torno a un solo comando: `test`.

```tcl
package require tcltest
namespace import ::tcltest::*

test suma-1.1 {suma dos enteros positivos} -body {
    expr {2 + 2}
} -result 4

cleanupTests
```

Ejecutas con `tclsh archivo.test.tcl` y obtienes algo así:
```
suma-1.1 basic funcionality

Tests Total    1
Passed         1
Skipped        0
Failed         0
```

### Anatomía completa de `test`
```tcl
test <nombre> <descripción> {
    -constraints {lista de constraints}
    -setup {código antes del test}
    -body {código bajo prueba, su resultado se compara}
    -cleanup {código después del test, incluso si falla}
    -result {valor esperado}
    -returnCodes {códigos de retorno esperados}
    -match <exact|glob|regexp>
    -output {stdout esperado}
    -errorOutput {stderr esperado}
}
```

- El **nombre** (`suma-1.1`) sigue convención `grupo-N.M` — no es obligatorio pero es el estándar en toda la librería estándar de Tcl (así identificas rápido a qué módulo pertenece un test al ver el output).
- `-body` es lo único obligatorio junto con `-result` (o `-returnCodes`/`-match` para casos especiales).
- El test **pasa** si el valor de retorno de `-body` coincide con `-result` según el modo de `-match` (por defecto, comparación exacta de string).

---

## 2. `setup` y `cleanup`: aislar cada test

Igual que `beforeEach`/`afterEach` en Jest, pero por-test (no hay un `-setup` global salvo que lo armes tú con un helper).

```tcl
test carrito-1.1 {agregar un producto incrementa el total} -setup {
    source carrito.tcl
    Carrito::reset
} -body {
    Carrito::agregar "Arroz" 2.50
    Carrito::total
} -cleanup {
    Carrito::reset
} -result 2.50
```

`-cleanup` corre **incluso si `-body` falla o lanza error**, así que es el lugar correcto para cerrar conexiones DB, borrar archivos temporales, remover traces, destruir widgets de test, etc. — exactamente como un `defer` en Go o un `finally`.

### Evitar repetir setup: usa un `proc` auxiliar
```tcl
proc prepararCarritoVacio {} {
    Carrito::reset
    return
}

test carrito-1.1 {...} -setup {prepararCarritoVacio} -body {...} -result {...}
test carrito-1.2 {...} -setup {prepararCarritoVacio} -body {...} -result {...}
```

---

## 3. Comparación de resultados: `-match`

Por defecto (`exact`), el resultado debe coincidir carácter por carácter. Para casos donde no puedes/quieres predecir el string exacto:

```tcl
test fecha-1.1 {formato de fecha actual} -body {
    clock format [clock seconds] -format "%Y-%m-%d"
} -match regexp -result {^\d{4}-\d{2}-\d{2}$}

test lista-1.1 {contiene elementos esperados} -body {
    list a b c
} -match glob -result {a b*}
```

- `exact` (default): igualdad de string.
- `glob`: patrones estilo shell (`*`, `?`, `[...]`).
- `regexp`: expresión regular completa.

---

## 4. Probar errores: `-returnCodes`

En Tcl, un `error` produce código de retorno 1 (no 0=OK). Testear que algo **falle correctamente** es tan importante como testear que funcione:

```tcl
test division-1.1 {dividir por cero lanza error} -body {
    expr {10 / 0}
} -returnCodes error -result {divide by zero}

test division-1.2 {dividir por cero, solo verificar que falla} -body {
    expr {10 / 0}
} -returnCodes error -match glob -result {*divide by zero*}
```

Si tu `proc` usa `return -code error "mensaje"` o `error "mensaje"`, `-returnCodes error` es obligatorio o el test fallará con "unexpected return code" aunque el mensaje de error coincida — es un chequeo separado del `-result`.

Otros códigos: `ok` (0, default), `error` (1), `return` (2), `break` (3), `continue` (4).

---

## 5. Verificar salida por stdout/stderr

```tcl
test log-1.1 {imprime mensaje de bienvenida} -body {
    puts "Bienvenido al sistema"
} -output "Bienvenido al sistema\n"

test log-1.2 {escribe warning a stderr} -body {
    puts stderr "advertencia: stock bajo"
} -errorOutput "advertencia: stock bajo\n"
```
Útil cuando pruebas CLIs o scripts que su "API" es literalmente lo que imprimen — común en tu contexto si construyes herramientas de línea de comandos en Tcl.

---

## 6. Constraints: skips condicionales (equivalente a `t.Skip` en Go)

```tcl
package require tcltest
namespace import ::tcltest::*

# Definir constraints propias
testConstraint tieneSqlite [expr {![catch {package require sqlite3}]}]
testConstraint linux [expr {$::tcl_platform(os) eq "Linux"}]

test db-1.1 {consulta a sqlite} -constraints tieneSqlite -body {
    sqlite3 db :memory:
    db eval {SELECT 1}
} -result 1

test path-1.1 {separador de rutas en linux} -constraints linux -body {
    file separator
} -result "/"
```
Si la constraint es falsa, el test se **salta** (no falla) — el reporte final muestra "Skipped" por separado. Esto es clave para tu entorno: puedes marcar tests que requieren red (`-constraints internet`) y saltarlos automáticamente cuando corres offline, sin comentar código a mano.

Constraints predefinidas útiles que ya vienen con tcltest: `unix`, `win`, `macosx`, `interactive`, `root` (corriendo como superusuario), `tempNotWin` (para tests de archivos temporales).

---

## 7. Organización: múltiples archivos y `all.tcl`

Convención estándar de la librería Tcl: cada módulo tiene su propio archivo `.test.tcl`, y un `all.tcl` los corre todos.

```
tests/
  all.tcl
  carrito.test.tcl
  inventario.test.tcl
  productos.test.tcl
```

**carrito.test.tcl:**
```tcl
package require tcltest
namespace import ::tcltest::*

source [file join [file dirname [info script]] .. src carrito.tcl]

test carrito-1.1 {carrito vacío al iniciar} -body {
    Carrito::reset
    Carrito::total
} -result 0

test carrito-1.2 {agregar incrementa el total} -body {
    Carrito::reset
    Carrito::agregar "Arroz" 2.50
    Carrito::total
} -result 2.50

cleanupTests
```

**all.tcl:**
```tcl
package require tcltest
set dir [file dirname [info script]]

::tcltest::runAllTests
```
Ejecutas con `tclsh all.tcl` desde `tests/` y corre automáticamente todos los archivos que matcheen el patrón `*.test.tcl` (configurable con `-file`).

---

## 8. Opciones de línea de comandos

`tcltest` acepta flags que puedes pasar al invocar el script:

```bash
tclsh carrito.test.tcl -verbose {pass fail skip}
tclsh carrito.test.tcl -match "carrito-1.*"      # correr solo un subconjunto por patrón
tclsh all.tcl -verbose body                       # muestra el cuerpo de cada test al correr
tclsh carrito.test.tcl -constraints {tieneSqlite} # fuerza constraints activas
```

Niveles de `-verbose` (combina los que quieras): `body`, `pass`, `fail`, `skip`, `start`, `error`. Por defecto solo se muestra `fail` — para debugging, `-verbose {pass fail skip body}` te da el detalle completo.

---

## 9. Testing de código con estado global / namespaces (conectando con tu guía de estado)

Como el estado en Tcl vive en namespaces/variables globales (ver la guía anterior), el patrón correcto de testing es **resetear el estado en cada `-setup`**, nunca asumir orden de ejecución entre tests:

```tcl
package require tcltest
namespace import ::tcltest::*
source ../src/store.tcl

proc resetStore {} {
    ::App::Store::dispatch RESET
}

test store-1.1 {estado inicial vacío} -setup {resetStore} -body {
    ::App::Store::obtener carrito
} -result {}

test store-1.2 {dispatch agrega producto} -setup {resetStore} -body {
    ::App::Store::dispatch AGREGAR_PRODUCTO "Arroz" 2.50
    ::App::Store::obtener total
} -result 2.50

test store-1.3 {dispatch no afecta tests anteriores} -setup {resetStore} -body {
    # si el reset falla, este test heredaría estado de store-1.2 y fallaría
    ::App::Store::obtener total
} -result 0

cleanupTests
```
Necesitas una acción `RESET` (o equivalente) expuesta específicamente para testing si tu store no la tiene ya — vale la pena agregarla aunque nunca la use la UI en producción.

---

## 10. Testing de widgets Tk (sí, se puede)

Tk permite correr en modo headless-ish si tienes un X server virtual (Linux: `Xvfb`) o, más simple, testeas la **lógica** de tus megawidgets Snit sin necesariamente verificar píxeles — separando lo testeable de lo puramente visual.

```tcl
package require tcltest
namespace import ::tcltest::*
package require Tk
package require snit
source ../src/panelCarrito.tcl

test panel-1.1 {panel muestra el total correcto} -setup {
    panelCarrito .p
} -body {
    .p configure -total 15.50
    .p cget -total
} -cleanup {
    destroy .p
} -result 15.50
```
**Regla práctica:** evita testear "el label dice exactamente este texto con este color" (frágil, cambia con cualquier retoque visual). Testea la **API pública del widget** (`cget`, métodos, el estado que expone) — el equivalente a testear el comportamiento de un componente React en vez de hacer snapshot testing del DOM renderizado.

Si necesitas correr estos tests en CI sin display (tu entorno probablemente no tiene GUI en el pipeline), usa `Xvfb`:
```bash
Xvfb :99 -screen 0 1024x768x24 &
DISPLAY=:99 tclsh tests/panel.test.tcl
```

---

## 11. Mocking / stubs manuales (Tcl no tiene mocking framework estándar)

No existe un `unittest.mock` nativo, pero como todo comando es reemplazable en runtime, el mocking es trivial: **renombras el comando real y defines uno falso temporalmente**.

```tcl
test venta-1.1 {venta llama a la API de pago correctamente} -setup {
    rename ::llamarAPIPago ::llamarAPIPago_real
    proc ::llamarAPIPago {monto} {
        set ::_ultimoMontoLlamado $monto
        return "ok"
    }
} -body {
    Venta::procesar 100.0
    set ::_ultimoMontoLlamado
} -cleanup {
    rename ::llamarAPIPago {}
    rename ::llamarAPIPago_real ::llamarAPIPago
} -result 100.0
```
Este patrón —`rename` original a un alias, definir un fake, restaurar en `-cleanup`— es el equivalente Tcl de `jest.mock()` o de las interfaces+fakes de Go, solo que manual y explícito. Para proyectos grandes vale la pena escribirte un par de procs helper (`mockComando`/`unmockComando`) que envuelvan este patrón.

---

## 12. Cobertura y CI

Tcl no tiene una herramienta de cobertura tan pulida como `go test -cover`, pero existen opciones:
- **`tclcov`** (paquete externo de tcllib/terceros): instrumenta y genera reportes de líneas cubiertas.
- Alternativa manual: correr con `-verbose body` y auditar visualmente qué procs nunca aparecen invocadas en ningún test.

Para CI (dado que probablemente uses GitHub Actions u otro pipeline), el patrón típico:
```bash
#!/bin/bash
set -e
cd tests
tclsh all.tcl -verbose {pass fail skip} 2>&1 | tee resultados.log
grep -q "Failed	0" resultados.log || exit 1
```
`tcltest` no tiene un exit code no-cero automático en todas las versiones al fallar tests — verifica el output o usa `::tcltest::numTests(Failed)` explícitamente al final del suite si necesitas un exit code confiable:

```tcl
cleanupTests
if {$::tcltest::numTests(Failed) > 0} {
    exit 1
}
```

---

## 13. Ejemplo completo: suite de test para el store del §4 de la guía anterior

```tcl
# tests/store.test.tcl
package require tcltest
namespace import ::tcltest::*

source [file join [file dirname [info script]] .. src store.tcl]

proc reset {} {
    set ::App::Store::estado [dict create carrito {} total 0]
    set ::App::Store::suscriptores {}
}

test store-1.1 {estado inicial} -setup reset -body {
    ::App::Store::obtener total
} -result 0

test store-1.2 {agregar producto suma al total} -setup reset -body {
    ::App::Store::dispatch AGREGAR_PRODUCTO "Arroz" 2.50
    ::App::Store::obtener total
} -result 2.50

test store-1.3 {agregar dos productos acumula} -setup reset -body {
    ::App::Store::dispatch AGREGAR_PRODUCTO "Arroz" 2.50
    ::App::Store::dispatch AGREGAR_PRODUCTO "Frijoles" 1.80
    ::App::Store::obtener total
} -result 4.30

test store-1.4 {vaciar carrito resetea total} -setup reset -body {
    ::App::Store::dispatch AGREGAR_PRODUCTO "Arroz" 2.50
    ::App::Store::dispatch VACIAR_CARRITO
    ::App::Store::obtener total
} -result 0

test store-1.5 {dispatch de acción desconocida lanza error} -setup reset -body {
    ::App::Store::dispatch ACCION_INVENTADA
} -returnCodes error -match glob -result {*acción desconocida*}

test store-2.1 {suscriptor es notificado tras dispatch} -setup reset -body {
    set ::_notificado 0
    ::App::Store::suscribir {set ::_notificado 1}
    ::App::Store::dispatch AGREGAR_PRODUCTO "Arroz" 2.50
    set ::_notificado
} -result 1

cleanupTests
```

Corres con `tclsh tests/store.test.tcl -verbose {pass fail skip}` y obtienes un reporte inmediato de qué parte de tu lógica de negocio (independiente de la UI) está garantizada a funcionar — exactamente el mismo valor que le sacas a `go test ./...` en tu backend.

---

## 14. Referencia rápida

| Construcción | Uso |
|---|---|
| `package require tcltest` | carga el framework |
| `namespace import ::tcltest::*` | trae `test`, `cleanupTests`, etc. sin prefijo |
| `test nombre desc {...}` | define un caso de test |
| `-body` | código a ejecutar/evaluar |
| `-result` | valor esperado (comparado según `-match`) |
| `-match exact\|glob\|regexp` | modo de comparación |
| `-setup` / `-cleanup` | antes/después de cada test (cleanup corre siempre) |
| `-returnCodes` | código de retorno esperado (`ok`, `error`, etc.) |
| `-output` / `-errorOutput` | verifica stdout/stderr esperado |
| `-constraints` | condición para correr el test (si no, se salta) |
| `testConstraint nombre bool` | define una constraint custom |
| `cleanupTests` | cierra el suite, imprime resumen (siempre al final del archivo) |
| `::tcltest::runAllTests` | corre todos los `*.test.tcl` de un directorio (en `all.tcl`) |
| `-verbose {pass fail skip body}` | flag de CLI para controlar detalle del output |
| `$::tcltest::numTests(Failed)` | contador accesible para exit codes en CI |

---

## 15. Cuándo esto realmente te sirve

Dado que tu proyecto principal es React+Go, `tcltest` solo entra en juego si terminas escribiendo lógica de negocio no trivial en Tcl puro — por ejemplo, si construyes una herramienta interna (inspector de SQLite, generador de reportes, utilidad de migración) donde quieres la misma confianza que te da `go test` en tu backend. La disciplina es idéntica a la que ya usas en Go: setup limpio por test, sin estado compartido entre tests, mockear dependencias externas (DB, red) para que el suite corra rápido y offline — coherente con tu filosofía general.
