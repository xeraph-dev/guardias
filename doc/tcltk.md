# Tcl/Tk: de cero a avanzado

Guía densa, pensada para leer una vez y quedarte con el modelo mental completo. Cada sección tiene teoría mínima + código que puedes ejecutar tal cual con `tclsh` (para Tcl puro) o `wish` (para Tk).

---

## 0. El modelo mental que lo explica todo

Tcl significa **Tool Command Language**. Una sola regla gobierna todo el lenguaje:

> **Todo es un comando. Todo comando es una lista de palabras separadas por espacios. Todo valor es una cadena de texto (hasta que se interpreta como otra cosa).**

No hay sintaxis especial para "if", "for", asignación, etc. Son comandos normales que reciben strings como argumentos. Esto es radicalmente distinto a Go/JS/Python, donde el parser conoce keywords. En Tcl el parser solo sabe partir en palabras y sustituir; el significado de `if`, `while`, `proc` lo da la implementación del comando, no la gramática.

```tcl
set x 5          ;# "set" es un comando, "x" y "5" son argumentos
puts $x          ;# "puts" es un comando, "$x" se sustituye por "5" ANTES de llamar a puts
if {$x > 3} {puts "mayor"}   ;# "if" es un comando que recibe 3 argumentos: {$x>3}, "puts mayor", nada más
```

Consecuencia clave: **las llaves `{}` no son bloques de código como en C**. Son solo un mecanismo de citado que impide la sustitución de variables (`$`) y comandos (`[]`) dentro de ellas. `if` recibe el string literal `$x > 3` sin evaluar y él mismo decide evaluarlo como expresión matemática.

Esto explica por qué en Tcl los espacios importan tanto y por qué errores de "espacio faltante" son el bug #1 de principiantes.

---

## 1. Sintaxis: las reglas de sustitución (esto es TODO el parser)

Solo existen 3 tipos de sustitución, y se procesan de izquierda a derecha, **una sola pasada** (no recursivo, salvo en `[]`):

### 1.1 Sustitución de variables: `$`
```tcl
set nombre "Adrian"
puts $nombre        ;# Adrian
puts $nombre.txt    ;# Adrian.txt  (el parser para en el primer char no válido)
puts ${nombre}.txt  ;# igual, pero explícito — útil si el nombre es ambiguo
```

### 1.2 Sustitución de comandos: `[]`
```tcl
set hoy [clock format [clock seconds]]
puts "Hoy es: $hoy"
```
`[...]` ejecuta el comando interno y sustituye por su resultado (stdout, no — el **valor de retorno**).

### 1.3 Citado: `{}` vs `"" `
```tcl
set a 10
puts "valor: $a"     ;# comillas: SÍ sustituye -> valor: 10
puts {valor: $a}     ;# llaves: NO sustituye  -> valor: $a
```
- `""` permite sustitución de `$` y `[]`, pero el parser sigue separando por espacios *dentro* si no escapas.
- `{}` es sustitución cero — texto literal, tal cual. Por eso se usa para cuerpos de `proc`, condiciones de `if`, scripts de `foreach`: **quieres que el comando reciba el texto crudo y lo evalúe él mismo, cuando y cómo quiera** (esto es la base de lazy evaluation en Tcl).

### 1.4 El backslash
```tcl
puts "línea1\nlínea2"   ;# \n es newline
puts a\ b               ;# escapa el espacio -> una sola palabra "a b"
```

### Por qué esto importa tanto
```tcl
if {$x>3} {puts hola}      ;# OK
if{$x>3} {puts hola}       ;# ERROR: "if{$x>3}" es UN comando inexistente (falta espacio)
if {$x>3}{puts hola}       ;# ERROR: faltan espacios entre argumentos
```
No es "sintaxis estricta arbitraria": es que sin el espacio, el parser no puede separar palabras. Interiorizar esto elimina el 80% de la frustración inicial.

---

## 2. Tipos de datos: todo es string, algunas cosas son también otra cosa

Tcl usa **"dual-ported objects" (Tcl_Obj)**: internamente cada valor tiene una representación string y, cacheada, una representación nativa (entero, lista, dict...). Tú, como programador, nunca declaras tipos — el intérprete decide la representación interna según cómo uses el valor. Esto te da la flexibilidad de Python con bastante del rendimiento de tener tipos internos.

### 2.1 Escalares
```tcl
set n 42
set f 3.14
set s "hola mundo"
```
No hay diferencia de declaración entre int/float/string. `expr {$n + 1}` funciona porque `expr` convierte internamente.

### 2.2 Listas — la estructura de datos central
Una lista es un string con formato específico (palabras separadas por espacios, opcionalmente llaves para agrupar).

```tcl
set l {manzana pera uva}
set l [list manzana pera uva]     ;# forma segura, escapa espacios internos automáticamente

lindex $l 0            ;# manzana
llength $l              ;# 3
lappend l kiwi           ;# agrega -> manzana pera uva kiwi
lsort $l                 ;# ordena
lsearch $l pera           ;# índice de "pera" -> 1
lrange $l 0 1              ;# {manzana pera}
foreach fruta $l { puts $fruta }
set l2 [lreplace $l 1 1 mango]   ;# reemplaza índice 1
```

**Regla de oro:** usa siempre `list`/`lappend` para *construir* listas en vez de concatenar strings a mano — así los espacios y caracteres especiales dentro de los elementos se citan correctamente.

### 2.3 Diccionarios (dict) — como un `map[string]string` de Go
```tcl
set d [dict create nombre Adrian pais Cuba]
dict get $d nombre         ;# Adrian
dict set d ciudad "La Habana"
dict exists $d pais         ;# 1
dict keys $d
dict for {clave valor} $d { puts "$clave = $valor" }
```
Un `dict` internamente también es una lista plana `{clave valor clave valor ...}`, pero con representación optimizada tipo hash cuando se usa como dict.

### 2.4 Arrays asociativos (el "otro" mapa, más viejo)
```tcl
array set persona {nombre Adrian pais Cuba}
puts $persona(nombre)
set persona(edad) 30
foreach {k v} [array get persona] { puts "$k -> $v" }
```
Diferencia clave con `dict`: un array NO es un valor que puedes pasar como argumento o guardar en una variable — es una colección de variables con nombres compuestos (`persona(nombre)` es literalmente una variable llamada así). Hoy en día, prefiere `dict` salvo que necesites `trace` sobre elementos individuales (ver §7).

---

## 3. Control de flujo (son comandos, no keywords — ya lo sabes, pero mira los patrones)

```tcl
# if / elseif / else
if {$x > 10} {
    puts "grande"
} elseif {$x > 5} {
    puts "mediano"
} else {
    puts "pequeño"
}

# while
set i 0
while {$i < 5} {
    puts $i
    incr i
}

# for (estilo C)
for {set i 0} {$i < 5} {incr i} {
    puts $i
}

# foreach (multi-lista, y multi-variable)
foreach a {1 2 3} b {x y z} {
    puts "$a-$b"
}
foreach {a b} {1 x 2 y 3 z} {
    puts "$a-$b"     ;# recorre de a pares
}

# switch
switch $x {
    1       { puts "uno" }
    2 - 3   { puts "dos o tres" }
    default { puts "otro" }
}
# switch con patrones glob o regex
switch -regexp $s {
    {^[0-9]+$} { puts "es numero" }
    default    { puts "no numero" }
}
```

`break` y `continue` funcionan como esperas. Ojo: como `{...}` no evalúa hasta que el comando lo pide, **`if`, `while`, `for` reevalúan la condición cada vez desde el string** — no hay "compilación" del cuerpo salvo el bytecode cache interno de Tcl (que sí existe desde Tcl 8.0, así que el rendimiento no es un problema real).

---

## 4. Procedimientos (funciones)

```tcl
proc saludar {nombre {saludo "Hola"}} {
    return "$saludo, $nombre!"
}
puts [saludar "Adrian"]              ;# Hola, Adrian!
puts [saludar "Adrian" "Buenas"]     ;# Buenas, Adrian!

# args variádicos
proc suma {args} {
    set total 0
    foreach n $args { incr total $n }
    return $total
}
puts [suma 1 2 3 4]     ;# 10
```

### Scope: todo es local por defecto
```tcl
set contador 0
proc incrementar {} {
    global contador
    incr contador
}
incrementar
puts $contador    ;# 1
```
Sin `global`, `contador` dentro de la proc sería una variable local nueva. Esto es distinto a Go (no hay closures automáticos) — Tcl es explícito sobre qué variables externas tocas: `global`, o `upvar` para referenciar variables de un scope arbitrario (esto es como pasar por referencia):

```tcl
proc duplicar {varName} {
    upvar 1 $varName v
    set v [expr {$v * 2}]
}
set x 5
duplicar x
puts $x    ;# 10
```
`upvar` es la base de cómo Tcl simula "pasar por referencia" sin punteros — muy usado en librerías (ej. `array` args, frameworks de testing).

---

## 5. `expr`: aritmética y lógica explícitas

Como todo es string, la aritmética NO ocurre implícitamente — necesitas `expr`:

```tcl
set a 5
set b 3
puts [expr {$a + $b}]        ;# 8
puts [expr {$a > $b}]        ;# 1
set c [expr {$a ** 2}]       ;# potencia, 25
```
**Siempre** encierra la expresión en `{}` (no en `""`). Con `{}` la expresión se compila una vez a bytecode y se evalúa lazy; con `""` se hace doble sustitución (una del parser Tcl, otra de expr) — funciona pero es más lento y más propenso a bugs de inyección si hay variables con contenido raro.

Operadores: `+ - * / % **`, comparación `== != < > <= >=`, lógicos `&& || !`, ternario `?:`, bit a bit `& | ^ ~ << >>`, y funciones matemáticas: `expr {sqrt(16)}`, `expr {sin($x)}`, `abs`, `max`, `min`, `int()`, `double()`.

---

## 6. Manejo de errores

```tcl
if {[catch {
    set resultado [expr {10 / 0}]
} err]} {
    puts "Error capturado: $err"
}

# Tcl 8.6+: try/on/finally (más parecido a lo que conoces)
try {
    set f [open "noexiste.txt" r]
} on error {msg opts} {
    puts "No se pudo abrir: $msg"
} finally {
    puts "Limpieza"
}

# Lanzar tus propios errores
proc dividir {a b} {
    if {$b == 0} {
        error "división por cero" "" {ARITH DIVZERO {divide by zero}}
    }
    return [expr {$a / $b}]
}
```
`catch` es el mecanismo original (retorna código de error como entero: 0=ok, 1=error, 2=return, 3=break, 4=continue). `try` es azúcar sintáctica moderna sobre lo mismo — úsala salvo que trabajes con código legado.

---

## 7. `trace` — la característica que hace único a Tcl para tu caso de uso (ERP/POS)

Puedes ejecutar código automáticamente cuando una variable se lee, escribe o borra. Esto es el mecanismo nativo de "reactive state" de Tcl, útil para sincronizar UI con datos (piensa: `useEffect` de React, pero a nivel de variable):

```tcl
set total 0

proc actualizarUI {varName index op} {
    puts "UI actualizada: total = $::total"
}
trace add variable total write actualizarUI

incr total 100    ;# dispara automáticamente: "UI actualizada: total = 100"
```
`trace` también existe para comandos (`trace add execution`) y para renombrar/borrar. En Tk, esto es exactamente cómo funcionan las `-textvariable` de widgets: el widget hace `trace` sobre tu variable y se repinta solo.

---

## 8. Namespaces y OOP (TclOO)

### 8.1 Namespaces — como paquetes de Go
```tcl
namespace eval inventario {
    variable stock 0

    proc agregar {n} {
        variable stock
        incr stock $n
    }
    proc consultar {} {
        variable stock
        return $stock
    }
}
inventario::agregar 50
puts [inventario::consultar]   ;# 50
```

### 8.2 TclOO — orientación a objetos nativa (desde Tcl 8.6)
```tcl
oo::class create Producto {
    variable nombre precio stock

    constructor {n p {s 0}} {
        set nombre $n
        set precio $p
        set stock $s
    }

    method vender {cantidad} {
        if {$cantidad > $stock} {
            error "stock insuficiente"
        }
        incr stock -$cantidad
        return [expr {$cantidad * $precio}]
    }

    method info {} {
        return "$nombre: $stock unidades a \$$precio"
    }
}

set p [Producto new "Arroz" 2.50 100]
puts [$p info]                  ;# Arroz: 100 unidades a $2.50
puts [$p vender 30]             ;# 75.0
puts [$p info]                  ;# Arroz: 70 unidades a $2.50

# Herencia
oo::class create ProductoPerecedero {
    superclass Producto
    variable fechaVencimiento
    constructor {n p s fecha} {
        next $n $p $s
        set fechaVencimiento $fecha
    }
    method vencimiento {} { return $fechaVencimiento }
}
```
`next` llama al método/constructor de la superclase (equivalente a `super()`). TclOO es completo: mixins, clases abstractas, métodos de clase (`classmethod`-like vía `self class`), filtros (aspect-oriented). Para un ERP en Go que ya conoces bien OOP-ish con interfaces, esto te resultará familiar rápido.

---

## 9. Paquetes y organización de código

```tcl
# archivo: miutil.tcl
package provide miutil 1.0
namespace eval miutil {
    namespace export saludar
    proc saludar {n} { return "Hola $n" }
}

# main.tcl
lappend auto_path [file dirname [info script]]
package require miutil
namespace import miutil::*
puts [saludar "Adrian"]
```
Para proyectos reales usa `pkgIndex.tcl` generado con `pkg_mkIndex` o el sistema de módulos de Tcl 8.6+ (`tcl::tm::path add`). Dado tu contexto de single-binary/offline, probablemente termines empaquetando todo con **Starkit/Starpack** o `tclkit` — permite compilar un proyecto Tcl/Tk completo en un solo ejecutable, análogo a lo que buscas con Go.

---

## 10. E/S de archivos y sistema

```tcl
set f [open "datos.txt" r]
while {[gets $f linea] >= 0} {
    puts "Leído: $linea"
}
close $f

set f [open "salida.txt" w]
puts $f "primera línea"
close $f

# forma segura moderna (auto-close):
set contenido [exec cat datos.txt]     ;# ejecuta comando externo, captura stdout

file exists "datos.txt"
file mkdir "carpeta"
glob *.tcl              ;# lista archivos que hacen match
```
`exec` es directo y potente para integrarte con procesos del sistema (piensa en esto como el `os/exec` de Go).

---

## 11. Sockets y red (relevante para tu contexto offline/POS)

```tcl
# Servidor TCP mínimo
socket -server aceptarConexion 12345
proc aceptarConexion {canal direccion puerto} {
    fconfigure $canal -buffering line
    puts $canal "Conectado al servidor"
    flush $canal
}
vwait forever    ;# entra al event loop, necesario para que el servidor siga vivo

# Cliente
set s [socket localhost 12345]
fconfigure $s -buffering line
puts [gets $s]
close $s
```
Tcl tiene soporte nativo de sockets no bloqueantes integrados al event loop — útil si en algún momento quieres un daemon Tcl liviano en vez de tu backend Go, aunque para tu stack seguramente Go+SQLite sigue siendo mejor opción.

---

## 12. Tk — construir interfaces gráficas

### 12.1 El evento loop (concepto #1 de Tk)
Tk es event-driven: tu script configura widgets y handlers, luego cede control a `mainloop` (implícito al abrir con `wish`, o explícito con `vwait`). Nada corre "después" salvo que sea disparado por un evento (click, teclado, timer).

```tcl
package require Tk

label .lbl -text "Hola Tk"
pack .lbl

button .btn -text "Clic" -command {puts "¡Clic!"}
pack .btn
```
Cada widget se crea con un comando que además define su **path name** jerárquico: `.` es la ventana raíz, `.btn` es hijo directo, `.frame.btn` sería hijo de `.frame`. Este path IS el identificador — no hay "referencias de objeto" separadas del namespace de widgets.

### 12.2 Geometry managers: pack, grid, place

**`pack`** — apila widgets en un lado:
```tcl
pack .lbl -side top -fill x -padx 10 -pady 5
pack .btn -side left
```

**`grid`** — como CSS grid, el más usado para layouts de formularios/ERP:
```tcl
label .l1 -text "Nombre:"
entry .e1
label .l2 -text "Precio:"
entry .e2

grid .l1 -row 0 -column 0 -sticky e
grid .e1 -row 0 -column 1 -sticky ew
grid .l2 -row 1 -column 0 -sticky e
grid .e2 -row 1 -column 1 -sticky ew

grid columnconfigure . 1 -weight 1    ;# columna 1 se expande al redimensionar
```

**`place`** — posicionamiento absoluto (úsalo poco, rompe responsive):
```tcl
place .lbl -x 10 -y 10
```

**Regla:** nunca mezcles `pack` y `grid` dentro del mismo contenedor padre (causa deadlock del geometry manager). Sí puedes anidar: un frame con `pack` que contiene otro frame gestionado por `grid` en su interior.

### 12.3 Widgets esenciales
```tcl
entry .e -textvariable nombreVar
text .t -width 40 -height 10
checkbutton .c -text "Activo" -variable activoVar
radiobutton .r1 -text "A" -variable opcion -value a
radiobutton .r2 -text "B" -variable opcion -value b
listbox .lb
scale .s -from 0 -to 100 -orient horizontal -variable volumenVar
scrollbar .sb -command {.t yview}
.t configure -yscrollcommand {.sb set}

# Menús
menu .menubar
. configure -menu .menubar
menu .menubar.archivo -tearoff 0
.menubar add cascade -label "Archivo" -menu .menubar.archivo
.menubar.archivo add command -label "Nuevo" -command nuevoArchivo
.menubar.archivo add command -label "Salir" -command exit

# Treeview (ttk) — ideal para tablas tipo ERP
package require Tk
ttk::treeview .tv -columns {nombre precio stock} -show headings
.tv heading nombre -text "Nombre"
.tv heading precio -text "Precio"
.tv heading stock -text "Stock"
.tv insert {} end -values {Arroz 2.50 100}
.tv insert {} end -values {Frijoles 1.80 50}
pack .tv -fill both -expand 1
```

### 12.4 `ttk` — widgets con temas nativos
Desde Tk 8.5, `ttk::` es la versión "moderna" de casi todos los widgets (se ve nativo en cada SO). Para apps serias, usa siempre `ttk::button`, `ttk::entry`, `ttk::frame`, `ttk::treeview` en vez de las versiones clásicas — el look es mucho mejor y es lo que Wails/otros frameworks esperan si algún día migras.
```tcl
ttk::style theme use clam
ttk::button .b -text "Guardar" -command guardar
```

### 12.5 `-textvariable` y binding de datos (esto conecta con §7 `trace`)
```tcl
set nombreVar ""
entry .e -textvariable nombreVar
label .lbl -textvariable nombreVar   ;# se actualiza SOLO cuando cambias nombreVar

# Combínalo con trace para lógica reactiva:
trace add variable nombreVar write {apply {{args} {
    puts "Nombre cambió a: $::nombreVar"
}}}
```
Esto es Tk haciendo "data binding" nativo — el widget escucha cambios en la variable Tcl vía `trace`, exactamente como harías con `useState` + efecto en React, pero incorporado al lenguaje desde los 90s.

### 12.6 Eventos y bindings
```tcl
bind .e <Return> {puts "Enter presionado: $nombreVar"}
bind .e <KeyRelease> {puts "Tecla soltada"}
bind . <Control-s> {guardar}

# bind con acceso a datos del evento (%x %y coordenadas, %W widget, etc.)
bind .canvas <Button-1> {puts "Click en %x,%y"}
```

### 12.7 Diálogos estándar
```tcl
set archivo [tk_getOpenFile]
tk_messageBox -message "Guardado con éxito" -icon info
set color [tk_chooseColor]
```

### 12.8 Canvas — dibujo (útil para gráficas simples, recibos, tickets)
```tcl
canvas .c -width 300 -height 200
pack .c
.c create rectangle 10 10 100 100 -fill blue
.c create text 150 50 -text "Ticket #001"
.c create line 0 0 300 200 -fill red -width 2
```

---

## 13. Patrón MVC práctico en Tcl/Tk (para tu caso: ERP/POS)

```tcl
package require Tk

# --- MODELO ---
oo::class create Inventario {
    variable productos
    constructor {} { set productos [dict create] }
    method agregar {nombre precio stock} {
        dict set productos $nombre [dict create precio $precio stock $stock]
    }
    method listar {} { return $productos }
}

# --- VISTA + CONTROLADOR ---
set modelo [Inventario new]
$modelo agregar "Arroz" 2.50 100
$modelo agregar "Frijoles" 1.80 50

proc refrescarTabla {tv modelo} {
    $tv delete [$tv children {}]
    dict for {nombre datos} [$modelo listar] {
        $tv insert {} end -values [list $nombre [dict get $datos precio] [dict get $datos stock]]
    }
}

ttk::treeview .tv -columns {nombre precio stock} -show headings
foreach {col texto} {nombre Nombre precio Precio stock Stock} {
    .tv heading $col -text $texto
}
pack .tv -fill both -expand 1

refrescarTabla .tv $modelo
```
Este patrón —modelo con TclOO, vista con ttk, controlador como procs que conectan ambos vía comandos `-command`— es directamente análogo a cómo estructurarías un frontend simple, y es la base de cómo funcionaban apps Tk de escritorio antes de que existieran frameworks web embebidos.

---

## 14. Empaquetado para distribución (relevante a tu filosofía single-binary)

- **`tclkit`**: intérprete Tcl/Tk como un único ejecutable, sin instalación.
- **Starkit / Starpack**: empaqueta tu script + assets + librerías en un solo archivo `.kit` (starkit, requiere tclkit) o `.exe`/binario nativo (starpack, autocontenido, sin dependencias — esto es lo que más se parece a tu filosofía de Go).
- **`freewrap`**: alternativa más simple, envuelve script + wish en un binario.
- **`tclcompiler` / `tbcload`**: compila a bytecode para ofuscar/acelerar carga (no es compilación nativa real).

Para tu caso (offline-first, minimal-dependency), Starpack es la opción más parecida a `go build -o app`: un solo binario, cero instalación, corre en la máquina destino sin Tcl preinstalado.

---

## 15. Errores comunes de principiante (y por qué ocurren, dado el modelo mental de §0)

| Error | Causa raíz |
|---|---|
| `if {$x>3}{...}` falla | Falta espacio entre `}` y `{` — son dos argumentos, el parser necesita el espacio |
| Variable "no existe" tras `if`/`proc` | Olvidaste `global` o `variable`; Tcl es local-by-default |
| `expr $a + $b` sin llaves funciona pero es mala práctica | Sin `{}` se hace doble sustitución, vulnerable e ineficiente |
| `pack` y `grid` en el mismo padre → congela la GUI | Los dos geometry managers no pueden coexistir en un mismo contenedor |
| Cambiar una variable no actualiza el widget | Falta `-textvariable`, o la actualizaste sin pasar por `set`/`trace` correctamente vinculado |
| `array set arr $lista` falla con "list must have even number" | Los arrays son pares clave-valor; verifica que tu lista tenga longitud par |

---

## 16. Ruta de práctica sugerida (para fijar esto rápido)

1. **Día 1**: Domina §0–§6 (sintaxis, tipos, control de flujo, procs, expr) escribiendo scripts de consola puros — sin Tk todavía.
2. **Día 2**: §7–§9 (trace, namespaces, TclOO) — reescribe un mini "carrito de compras" en consola usando una clase `Carrito` con TclOO.
3. **Día 3**: §12 completo — construye una ventana con formulario (entry + button) que agregue filas a un `ttk::treeview`, todo con `-textvariable` y `trace`.
4. **Día 4**: §13 — arma el mini-ERP MVC de arriba, conéctalo a lectura/escritura de un archivo o a SQLite vía el paquete `sqlite3` para Tcl (`package require sqlite3`), ya que tu backend real usa SQLite.
5. **Día 5**: §14 — empaqueta ese mini-ERP como Starpack y pruébalo como binario standalone.

---

## 17. Referencias rápidas para profundizar
- `man n <comando>` en cualquier instalación con Tcl (ej: `man n dict`, `man n trace`) — la documentación oficial vive ahí, es excelente y completa.
- Tcl/Tk reference oficial: https://www.tcl-lang.org/man/
- TclOO reference: https://www.tcl-lang.org/man/tcl8.6/TclCmd/class.html
- Wiki con miles de recetas prácticas: https://wiki.tcl-lang.org/

---

### Nota final
Dado que ya evaluaste frameworks GUI de Go y concluiste que no tienen demanda de mercado, y que tu stack real para el ERP terminó siendo React+Vite+Wails/Capacitor sobre Go+SQLite: Tcl/Tk probablemente no reemplace nada en tu pipeline actual, pero te da una herramienta extremadamente ligera para **scripts de utilidad interna, prototipos rápidos de UI, o herramientas de administración/diagnóstico locales** donde ni React ni Wails valen la pena montar — un solo archivo `.tcl` + `wish` ya es una GUI funcionando, sin build step, sin node_modules, sin conexión a internet. Esa filosofía sí encaja con tu entorno de baja conectividad.
