# Strings, regexp y procesamiento de texto en Tcl

Tcl nació como lenguaje de "glue" para procesar texto y controlar otras herramientas, así que su manejo de strings es excepcionalmente completo — a menudo más directo que en Go, donde necesitas `strings`, `regexp`, `strconv` como paquetes separados. Aquí todo vive en `string` y `regexp`, dos comandos con muchos subcomandos.

---

## 1. `string`: el comando central

```tcl
string length "hola"              ;# 4
string index "hola" 0             ;# h
string range "hola mundo" 0 3     ;# hola
string toupper "hola"             ;# HOLA
string tolower "HOLA"             ;# hola
string trim "  hola  "            ;# "hola"
string trimleft "  hola"          ;# "hola"
string trimright "hola  "         ;# "hola"
string reverse "hola"             ;# aloh
string repeat "ab" 3              ;# ababab
```

### Comparación y búsqueda
```tcl
string equal "abc" "abc"              ;# 1
string equal -nocase "ABC" "abc"      ;# 1
string compare "abc" "abd"            ;# -1 (menor)
string first "mundo" "hola mundo"     ;# 5 (índice), -1 si no encuentra
string last "o" "hola mundo"          ;# último índice de coincidencia
string match "h*o" "hola mundo"       ;# 0 (glob pattern, no coincide todo el string)
string match "hola*" "hola mundo"     ;# 1
```

### Clasificación (`string is`)
```tcl
string is integer -strict "123"     ;# 1
string is integer -strict "12.3"    ;# 0
string is double -strict "12.3"     ;# 1
string is alpha "hola"               ;# 1
string is alnum "hola123"            ;# 1
string is space "   "                ;# 1
string is boolean "yes"              ;# 1 (acepta: true/false/yes/no/on/off/1/0)
```
`-strict` es importante: sin él, `string is integer ""` retorna 1 (string vacío se considera válido para "podría llegar a ser"). Para validación real de formularios, **siempre usa `-strict`**.

### `string map`: reemplazo múltiple en una pasada
```tcl
string map {á a é e í i ó o ú u} "canción"    ;# cancion
string map {"" ""} $texto                       ;# no hace nada, ejemplo trivial
string map {"\n" " " "\t" " "} $texto           ;# normaliza espacios en blanco
```
Más eficiente que múltiples `string replace` encadenados porque hace todos los reemplazos en una sola pasada del string.

### `string replace` (por índice, no por patrón)
```tcl
string replace "hola mundo" 0 3 "chao"    ;# chao mundo
```

### `split` / `join` (el par que más vas a usar)
```tcl
split "a,b,c" ","           ;# {a b c} — lista
split "línea1\nlínea2" "\n" ;# {línea1 línea2}
join {a b c} "-"            ;# a-b-c
join [list "Arroz" "Frijoles"] ", "   ;# Arroz, Frijoles
```

### `format` (como `printf`/`fmt.Sprintf`)
```tcl
format "%s cuesta $%.2f" "Arroz" 2.5        ;# Arroz cuesta $2.50
format "%05d" 42                              ;# 00042
format "%-10s|" "hola"                        ;# "hola      |"
format "%x" 255                                ;# ff (hexadecimal)
```
Mismos especificadores que C/Go (`%d %s %f %x %o %e`, ancho, precisión, padding).

### `scan` (el inverso de `format`, como `fmt.Sscanf`)
```tcl
scan "Arroz:2.50" "%[^:]:%f" nombre precio
puts "$nombre cuesta $precio"    ;# Arroz cuesta 2.50
```

---

## 2. Expresiones regulares: `regexp` y `regsub`

Tcl usa regex estilo POSIX extendido con extensiones (ARE — Advanced Regular Expressions), muy similar a PCRE en la práctica cotidiana.

### `regexp`: buscar/probar coincidencia
```tcl
regexp {\d+} "precio: 250" coincidencia
puts $coincidencia     ;# 250

# Con grupos de captura
regexp {(\w+):(\d+\.\d+)} "Arroz:2.50" completo nombre precio
puts $nombre    ;# Arroz
puts $precio    ;# 2.50

# Solo probar si matchea (retorna 1/0)
if {[regexp {^\d+$} $texto]} {
    puts "es numérico"
}

# -all: todas las coincidencias, no solo la primera
regexp -all -inline {\d+} "a1 b22 c333"    ;# {1 22 333}

# -nocase
regexp -nocase {hola} "HOLA MUNDO"    ;# 1
```

### `regsub`: reemplazar con regex
```tcl
regsub {\s+} "hola    mundo" " " resultado
puts $resultado    ;# "hola mundo"

regsub -all {\d+} "a1 b22 c333" "N" resultado
puts $resultado    ;# "aN bN cN"

# Referencias a grupos capturados en el reemplazo: \1, \2...
regsub {(\w+)@(\w+)} "usuario@dominio" {\2:\1} resultado
puts $resultado    ;# dominio:usuario

# -all con función de reemplazo dinámico (Tcl 8.6+): usa [subst] o regsub -command en 9.0
```

### Sintaxis clave de regex en Tcl
| Patrón | Significado |
|---|---|
| `.` | cualquier carácter |
| `*` `+` `?` | 0+, 1+, 0-1 repeticiones |
| `{n,m}` | entre n y m repeticiones |
| `[abc]` `[^abc]` | clase de caracteres / negada |
| `\d \w \s` | dígito, palabra, espacio (y `\D \W \S` negados) |
| `^` `$` | inicio / fin de línea |
| `(...)` | grupo de captura |
| `(?:...)` | grupo sin captura |
| `\|` | alternancia |
| `\1 \2` | backreference en el patrón o en el reemplazo |

### Validación práctica (caso ERP)
```tcl
proc esCodigoProducto {codigo} {
    return [regexp {^[A-Z]{3}-\d{4}$} $codigo]
}
puts [esCodigoProducto "ARR-0001"]   ;# 1
puts [esCodigoProducto "arr-1"]      ;# 0
```

---

## 3. `subst`: sustitución controlada bajo demanda

`subst` te permite aplicar las reglas de sustitución de `$`/`[]` a un string **cuando tú quieras**, no automáticamente por el parser. Es la base de templating simple en Tcl:

```tcl
set nombre "Adrian"
set plantilla {Hola $nombre, bienvenido}
puts [subst $plantilla]    ;# Hola Adrian, bienvenido

# Desactivar selectivamente
puts [subst -nocommands $plantilla]     ;# no evalúa [comandos], sí $variables
puts [subst -novariables $plantilla]    ;# no evalúa $variables, sí [comandos]
```
Útil para generar recibos, emails, o cualquier texto con placeholders desde una plantilla guardada en archivo/DB, sin necesitar una librería de templating externa.

```tcl
proc renderTicket {plantilla datos} {
    dict with datos {
        return [subst $plantilla]
    }
}

set plantilla {
Ticket #$numero
Producto: $producto
Total: \$$total
}
puts [renderTicket $plantilla [dict create numero 1 producto "Arroz" total 2.50]]
```
`dict with` inyecta cada clave del dict como variable local temporalmente — combinado con `subst`, es un motor de templates completo en 3 líneas.

---

## 4. Codificación de caracteres y encoding

Dado que trabajas con español (acentos, ñ), esto es relevante:

```tcl
encoding system              ;# encoding actual del sistema (ej. utf-8)
encoding convertto utf-8 $texto
encoding convertfrom utf-8 $bytes

fconfigure $canal -encoding utf-8    ;# fuerza encoding al leer/escribir un archivo o socket
```
Si lees archivos con acentos y ves caracteres corruptos, casi siempre es un `fconfigure -encoding` faltante o incorrecto al abrir el canal — Tcl internamente maneja Unicode nativamente en sus strings, el problema suele estar en la frontera de I/O (archivo/socket), no en el procesamiento interno.

---

## 5. Construcción segura de strings/comandos (evitar "inyección Tcl")

Como todo comando se arma como texto, concatenar strings a mano para construir código a ejecutar es peligroso si el contenido viene de input externo (ej. un nombre de producto con caracteres especiales):

```tcl
# MAL: si $nombre contiene espacios o llaves, esto se rompe o hace algo inesperado
eval "puts Hola $nombre"

# BIEN: usa list para construir el comando de forma segura
eval [list puts "Hola $nombre"]

# MEJOR AÚN: casi nunca necesitas eval; solo llama el comando directo
puts "Hola $nombre"
```
La regla general: **evita `eval` con strings concatenados a mano**. Si necesitas construir un comando dinámicamente (ej. despachar según una acción), usa `list` para armarlo con citado correcto, y prefiere `{*}` (expansión de lista como argumentos, Tcl 8.5+) sobre `eval`:

```tcl
set comando [list Carrito::agregar $nombreProducto $precio]
{*}$comando    ;# expande la lista como argumentos posicionales, sin re-parsear texto
```
`{*}` es el equivalente al operador spread (`...args`) de JS o `*args` de Python — expande una lista Tcl como argumentos separados de un comando, sin los riesgos de `eval` sobre texto.

---

## 6. Procesamiento de líneas/CSV simple

```tcl
proc parsearCSV {linea} {
    return [split $linea ","]
}

set f [open "productos.csv" r]
fconfigure $f -encoding utf-8
gets $f encabezados
set columnas [split $encabezados ","]

while {[gets $f linea] >= 0} {
    set valores [split $linea ","]
    foreach col $columnas val $valores {
        puts "$col = $val"
    }
}
close $f
```
Para CSV con comillas/comas escapadas (RFC 4180 real), esto se queda corto — en ese caso conviene usar el paquete `csv` de tcllib (`package require csv`), que maneja comillas y escapes correctamente:
```tcl
package require csv
set fila [::csv::split $linea]
```

---

## 7. Comparación de rendimiento: cuándo `string` vs `regexp`

Para operaciones simples (contiene, empieza con, termina con), `string` es más rápido que regex porque no compila un patrón:

```tcl
# Prefiere esto...
if {[string match "ARR-*" $codigo]} { ... }

# ...sobre esto, si no necesitas la potencia de regex real
if {[regexp {^ARR-} $codigo]} { ... }
```
Regla práctica: usa `string match` (glob patterns: `* ? [...]`) para casos simples, y reserva `regexp`/`regsub` para cuando necesitas grupos de captura, cuantificadores, o alternancia — igual que preferirías `strings.HasPrefix` sobre una regex en Go para el caso simple.

---

## 8. Resumen de referencia rápida

| Tarea | Comando |
|---|---|
| Longitud, mayúsculas, trim | `string length/toupper/tolower/trim` |
| Buscar substring | `string first`, `string match` (glob) |
| Reemplazo simple múltiple | `string map` |
| Validar tipo de dato | `string is <tipo> -strict` |
| Partir/unir strings | `split` / `join` |
| Formatear como printf | `format` |
| Parsear con formato | `scan` |
| Regex: probar/capturar | `regexp` (`-all -inline` para todas las coincidencias) |
| Regex: reemplazar | `regsub` (`-all` para todas) |
| Templating simple | `subst` (+ `dict with` para variables desde un dict) |
| Expandir lista como args | `{*}$lista` (evita `eval`) |
| CSV robusto | `package require csv` (tcllib) |

---

## 9. Dónde esto te sirve directamente

Para tu ERP, esto es exactamente lo que necesitarías si en algún momento escribes en Tcl: parsers de archivos de importación (CSV de proveedores), validación de códigos de producto/SKU con regex, generación de tickets/recibos con `subst` como motor de plantillas, y limpieza de texto (acentos, espacios) en datos que vienen de fuentes externas antes de insertarlos en SQLite.
