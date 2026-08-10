# Introspección y metaprogramación en Tcl

Tcl es un lenguaje profundamente reflexivo: el comando `info` te deja inspeccionar casi cualquier cosa en runtime (variables, procs, la pila de llamadas), y comandos como `uplevel`, `upvar`, `apply` y `interp` te permiten generar y ejecutar código dinámicamente con un control muy fino sobre en qué scope corre. Esta es el área donde Tcl se siente más parecido a Lisp que a un lenguaje imperativo convencional — código como dato, y viceversa.

---

## 1. `info`: la ventana a todo

```tcl
info exists variable          ;# 1/0, existe la variable en el scope actual?
info vars                     ;# lista de variables locales visibles
info globals                  ;# lista de variables globales
info locals                   ;# solo locales (dentro de una proc)
info procs                    ;# lista de procs definidas
info commands                 ;# TODOS los comandos (built-in + procs)
info args miProc               ;# lista de parámetros de una proc
info body miProc                ;# el código fuente del cuerpo de una proc
info default miProc arg var    ;# valor por defecto de un parámetro, si tiene
info level                     ;# profundidad actual de la pila de llamadas
info level 0                    ;# el comando+args de la llamada actual
info script                     ;# el archivo .tcl que se está ejecutando
info tclversion                 ;# versión de Tcl
```

```tcl
proc saludar {nombre {saludo "Hola"}} {
    return "$saludo, $nombre"
}
puts [info args saludar]      ;# nombre saludo
puts [info body saludar]      ;# return "$saludo, $nombre"
puts [info default saludar saludo valor]; puts $valor   ;# Hola
```

### Inspeccionar la pila de llamadas (útil para debugging/logging)
```tcl
proc a {} { b }
proc b {} { c }
proc c {} {
    for {set i [info level]} {$i > 0} {incr i -1} {
        puts "nivel $i: [info level $i]"
    }
}
a
```
Esto imprime cada frame de la pila, útil para construir tu propio logger de errores con "traceback" custom, o para un helper de debugging tipo `caller()` de Python.

---

## 2. `uplevel`: ejecutar código en el scope de otro nivel

`uplevel` es una de las herramientas más poderosas y menos intuitivas de Tcl: ejecuta un comando **en el contexto de variables de un nivel distinto de la pila**, no en el nivel actual.

```tcl
proc miAssert {condicion mensaje} {
    if {![uplevel 1 [list expr $condicion]]} {
        error "Assertion falló: $mensaje"
    }
}

proc probarAlgo {} {
    set x 5
    miAssert {$x > 10} "x debería ser mayor a 10"    ;# usa $x del scope de probarAlgo, no de miAssert
}
probarAlgo
```
`uplevel 1 [list expr $condicion]` evalúa la expresión **como si estuviera escrita directamente dentro de `probarAlgo`**, así que `$x` se resuelve en ese scope, no en el de `miAssert`. Sin `uplevel`, `$x` dentro de `miAssert` sería una variable inexistente (scope local de la proc).

Esto es la base de cómo se implementan comandos de control de flujo custom en Tcl (tu propio `if`, `unless`, `assert`, `repeat`) que se sienten como parte nativa del lenguaje:

```tcl
proc repetir {veces cuerpo} {
    for {set i 0} {$i < $veces} {incr i} {
        uplevel 1 $cuerpo
    }
}

set contador 0
repetir 5 {incr contador}
puts $contador    ;# 5
```
`repetir` recibe `$cuerpo` como texto sin evaluar (gracias a las llaves), y lo ejecuta con `uplevel 1` en el scope del llamador — así `incr contador` afecta la variable real del caller, no una copia local de `repetir`.

`uplevel #0` es especial: ejecuta en el scope **global**, sin importar cuán anidada esté la llamada — lo viste ya en las guías de estado/Snit para invocar callbacks (`-oncommand`, suscriptores de un store) sin importar desde qué profundidad de proc se disparan.

---

## 3. `upvar`: alias de variables entre scopes

Ya lo viste brevemente en la guía básica — aquí el detalle completo. `upvar` crea una variable local que es un **alias** de una variable en otro nivel de la pila (o en otro namespace).

```tcl
proc intercambiar {varA varB} {
    upvar 1 $varA a
    upvar 1 $varB b
    set temp $a
    set a $b
    set b $temp
}

set x 1
set y 2
intercambiar x y
puts "$x $y"    ;# 2 1
```
Esto es Tcl simulando "pasar por referencia" — `varA`/`varB` llegan como *nombres* de variable (strings), y `upvar` los convierte en alias reales dentro de la proc. Es exactamente el mecanismo detrás de `array` como parámetro implícito en muchas librerías estándar de Tcl (ej. `parray`).

`upvar #0` referencia directamente el scope global, sin importar el nivel de anidación — útil para procs que necesitan tocar una variable global específica sin usar `global` (que solo trae el nombre, no permite renombrarla localmente).

---

## 4. `apply`: funciones anónimas (lambdas)

```tcl
set doble [apply {{x} {expr {$x * 2}}}]
puts [apply $doble 5]    ;# 10

# uso típico: pasar como callback sin nombrar una proc completa
set numeros {1 2 3 4 5}
set duplicados [lmap n $numeros {apply {{x} {expr {$x * 2}}} $x}]
```
Nota la sintaxis: `apply {{args} {cuerpo}}` — es una lista de 2 elementos (lista de args, cuerpo), la misma estructura que recibe `proc` pero sin nombre. Útil para callbacks de una sola vez donde no vale la pena definir una `proc` con nombre propio, similar a una lambda de Python o arrow function de JS.

```tcl
# Combinado con namespace para lambdas con closure sobre variables
set factor 3
set multiplicador [list apply {{x factor} {expr {$x * $factor}}} $factor]
# Nota: Tcl NO tiene closures automáticos como JS; debes pasar explícitamente
# lo que la lambda necesita capturar, como argumento extra.
```
Diferencia importante con JS/Python: **Tcl no captura variables del entorno automáticamente en un lambda**. Si tu `apply` necesita un valor externo, debes pasarlo como argumento explícito — es más parecido a Go (sin closures implícitos mágicos) que a JS.

---

## 5. `interp`: intérpretes anidados y sandboxing

Tcl te permite crear **sub-intérpretes** aislados dentro del mismo proceso — útil para ejecutar código no confiable (plugins, scripts de usuario) con permisos limitados.

```tcl
interp create sandbox
interp eval sandbox {set x 10; expr {$x * 2}}    ;# 20, en un espacio de variables totalmente aislado

# Sandbox restringido (sin acceso a archivos/red/exec)
interp create -safe sandbox2
interp eval sandbox2 {file delete /etc/passwd}    ;# ERROR: comando no disponible en modo safe

interp delete sandbox
interp delete sandbox2
```
`-safe` crea un intérprete con el conjunto de comandos peligrosos (`exec`, `file`, `socket`, `open`...) removido — la base de cómo Tcl implementa sandboxing real para correr código no confiable (ej. si algún día permitieras "scripts de usuario" configurables en tu ERP sin arriesgar el sistema completo).

```tcl
# Exponer comandos específicos y controlados al sandbox
interp create -safe sandbox
interp alias sandbox miFuncion {} miFuncionSegura
interp eval sandbox {miFuncion 5}
```
`interp alias` te permite exponer selectivamente solo las funciones que quieres que el código sandboxed pueda llamar — control de superficie de ataque explícito, comando por comando.

---

## 6. Redefinir/interceptar comandos: `rename` y `trace add execution`

Ya viste `rename` en la guía de testing para mocking. También sirve para envolver comportamiento existente (patrón decorator/aspect):

```tcl
rename ::puts ::puts_original
proc ::puts {args} {
    # log adicional antes de cada puts real
    ::puts_original stderr "LOG: llamada a puts con: $args"
    uplevel 1 [list ::puts_original {*}$args]
}

puts "hola"    ;# imprime el log a stderr Y "hola" a stdout
```
Esto es **monkey-patching** real, como reasignar `console.log` en JS. Úsalo con moderación — es poderoso pero hace el código más difícil de rastrear si se abusa.

### `trace add execution`: hook sin reemplazar el comando
Alternativa más limpia cuando solo quieres observar, no reemplazar:
```tcl
proc miProc {x} { return [expr {$x * 2}] }

trace add execution miProc enter {apply {{args} {
    puts "entrando a miProc con: $args"
}}}
trace add execution miProc leave {apply {{args} {
    puts "saliendo de miProc, resultado: [lindex $args 2]"
}}}

miProc 5
```
Esto da logging/profiling automático de entradas y salidas sin tocar el código de `miProc` — el equivalente a un decorator de Python o middleware, pero completamente desacoplado del comando original.

---

## 7. Generar código dinámicamente (metaprogramación real)

Como el código es texto, puedes generar procs completas en runtime — útil para evitar repetición cuando tienes muchos comandos con estructura similar (ej. getters/setters, o comandos CRUD por entidad).

```tcl
foreach campo {nombre precio stock} {
    proc get_$campo {} [format {
        return $%s
    } $campo]
}

set nombre "Arroz"
set precio 2.50
set stock 100
puts [get_nombre]   ;# Arroz
puts [get_precio]   ;# 2.50
```

Patrón más realista: generar métodos CRUD para varias "tablas" sin repetir código:
```tcl
proc definirCRUD {entidad tabla} {
    proc ${entidad}::obtener {id} [format {
        db eval {SELECT * FROM %s WHERE id = :id}
    } $tabla]
    proc ${entidad}::eliminar {id} [format {
        db eval {DELETE FROM %s WHERE id = :id}
    } $tabla]
}

namespace eval Producto {}
definirCRUD Producto productos
namespace eval Cliente {}
definirCRUD Cliente clientes

Producto::obtener 1
Cliente::eliminar 3
```
Esto es genuinamente lo que en otros lenguajes necesitarías generics/reflection/code-gen para lograr — en Tcl es directo porque `proc` es solo otro comando que puedes llamar con argumentos construidos dinámicamente.

**Advertencia de legibilidad:** este poder es fácil de abusar. Generar procs dinámicamente hace el código más difícil de leer, buscar ("¿dónde está definido `get_nombre`?" no aparece con grep normal) y de debuggear con herramientas estáticas. Úsalo solo cuando el patrón repetitivo es genuinamente mecánico y extenso (10+ repeticiones), no como primer recurso.

---

## 8. `ensemble`: comandos con subcomandos (como `string`, `dict`, `info` mismos)

Puedes construir tus propios comandos "con subcomandos" como los nativos de Tcl:

```tcl
namespace eval ::Carrito {
    namespace ensemble create

    proc agregar {producto precio} {
        puts "agregando $producto a \$$precio"
    }
    proc vaciar {} {
        puts "carrito vaciado"
    }
    proc total {} {
        return 0
    }
}

Carrito agregar "Arroz" 2.50    ;# se comporta como "Carrito::agregar" pero con sintaxis unificada
Carrito vaciar
```
`namespace ensemble create` convierte tu namespace en un comando único que despacha a sus procs internas según el primer argumento — exactamente el patrón de `string length`, `dict get`, `info exists`: un "namespace" de comandos que se siente como una API cohesiva en vez de N procs sueltas con prefijo.

---

## 9. Resumen de referencia rápida

| Comando | Uso |
|---|---|
| `info exists/vars/procs/commands` | inspección general del entorno |
| `info args/body/default` | inspeccionar una proc específica |
| `info level` | profundidad e info de la pila de llamadas |
| `uplevel N cmd` | ejecuta `cmd` en el scope N niveles arriba |
| `uplevel #0 cmd` | ejecuta en el scope global, sin importar la profundidad |
| `upvar N varOrigen alias` | crea un alias local de una variable de otro scope |
| `apply {{args} {cuerpo}} valores` | función anónima, sin closures automáticos |
| `interp create [-safe] nombre` | sub-intérprete aislado (sandboxing) |
| `interp alias` | expone comandos específicos a un sandbox |
| `rename cmd nuevoCmd` | renombra/envuelve un comando existente |
| `trace add execution proc enter/leave` | hook de entrada/salida sin modificar el código |
| `proc nombreDinamico [format {...} $x]` | genera procs en runtime |
| `namespace ensemble create` | comando propio con sub-comandos, como `string`/`dict` |

---

## 10. Dónde esto realmente te sirve

Para tu ERP en Tcl (si lo construyeras): `uplevel`/`upvar` son la base de cómo escribirías tus propios "controles de flujo" de dominio (ej. un `transaccion {...}` que envuelva `BEGIN`/`COMMIT`/`ROLLBACK` de SQLite ejecutando el bloque en el scope correcto); `interp -safe` sería relevante solo si algún día permites scripts configurables de usuario; y `namespace ensemble` es el patrón correcto para exponer tu store (§4 de la guía de estado) como un comando limpio (`Store dispatch ...`, `Store obtener ...`) en vez de procs sueltas con prefijo `::App::Store::`.
