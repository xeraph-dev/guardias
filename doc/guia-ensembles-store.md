# Comandos tipo CLI con ensembles anidados: patrón `store worker create`

Esta guía documenta el patrón que armamos en la conversación anterior: un comando raíz (`store`) que se comporta como una mini-CLI con sub-comandos anidados (`store worker list`, `store calendar assign -worker_id 1 -date ...`), construido enteramente con `namespace ensemble` — la misma primitiva que usan `string`, `dict`, e `info` internamente. Incluye un mecanismo de registro seguro para nunca pisar un comando existente por accidente.

Todo el código de esta guía fue probado en un intérprete Tcl real (`tclsh`, Tcl 8.6).

---

## 1. El objetivo

Queremos que esto funcione:
```tcl
store worker list
store worker create -name Juan -weight 1
store calendar assign -worker_id 1 -date 20241231
```
Es decir, un comando `store` con sub-namespaces temáticos (`worker`, `calendar`), cada uno con sus propios sub-comandos (`list`, `create`, `assign`), y argumentos con nombre estilo `-clave valor` en vez de posicionales — la misma sensación de una CLI moderna (`git remote add`, `kubectl get pods`).

---

## 2. Pieza 1: `namespace ensemble create` — la base de todo

Ya lo viste brevemente en la guía de introspección. Un ensemble convierte un namespace en **un solo comando** que despacha internamente según su primer argumento.

```tcl
namespace eval ::worker {
    namespace export list create
    namespace ensemble create

    proc list {} {
        puts "listando trabajadores"
    }
    proc create {args} {
        puts "creando trabajador con: $args"
    }
}

worker list              ;# despacha a ::worker::list
worker create -name Juan  ;# despacha a ::worker::create con args {-name Juan}
```

### El detalle que rompe esto si lo olvidas: `namespace export`
`namespace ensemble create`, sin `-subcommands` explícito, **solo expone como sub-comandos las procs que exportaste** con `namespace export`. Si omites el `export`, obtienes este error al invocar cualquier sub-comando:
```
unknown subcommand "create": namespace ::worker does not export any commands
```
Esto pasa aunque `create` exista perfectamente como proc dentro del namespace — Tcl exige la exportación explícita porque `namespace ensemble create` puede coexistir con procs "privadas" del namespace que no quieres exponer como API pública. Regla práctica: **siempre pon `namespace export` justo antes de `namespace ensemble create`**, listando exactamente lo que quieres exponer.

---

## 3. Pieza 2: ensembles anidados con `-map`

Para que `store worker create` funcione (dos niveles), el ensemble raíz `store` necesita saber que `worker` no es una proc suya, sino **otro ensemble completo** al que debe reenviar el resto de los argumentos.

```tcl
namespace eval ::store::worker {
    namespace export list create
    namespace ensemble create
    proc list {} { puts "workers..." }
    proc create {args} { puts "creando: $args" }
}

namespace eval ::store::calendar {
    namespace export assign
    namespace ensemble create
    proc assign {args} { puts "asignando: $args" }
}

namespace eval ::store {
    namespace ensemble create -map {
        worker   ::store::worker
        calendar ::store::calendar
    }
}

store worker create -name Juan     ;# store -> ::store::worker -> create
store calendar assign -worker_id 1  ;# store -> ::store::calendar -> assign
```
`-map {worker ::store::worker calendar ::store::calendar}` es una tabla explícita de "cuando el primer argumento sea X, reenvía todo lo demás al comando Y". Como `::store::worker` es en sí mismo otro ensemble, el segundo nivel de despacho (`create` dentro de `worker`) ocurre automáticamente al invocarlo — los ensembles se componen naturalmente sin código adicional.

---

## 4. Pieza 3: parseo de argumentos con nombre (`-clave valor`)

Tcl no tiene sintaxis nativa de "flags" como getopt — la armamos con una función auxiliar reutilizable que convierte pares en un `dict`:

```tcl
proc parseArgs {args} {
    if {[llength $args] % 2 != 0} {
        error "número impar de argumentos, se esperaban pares -clave valor"
    }
    set resultado [dict create]
    foreach {clave valor} $args {
        if {[string index $clave 0] ne "-"} {
            error "se esperaba una opción con guion, se recibió: $clave"
        }
        dict set resultado [string range $clave 1 end] $valor
    }
    return $resultado
}
```
Uso dentro de cualquier proc que reciba `args`:
```tcl
proc create {args} {
    set opts [parseArgs {*}$args]
    if {![dict exists $opts name]} {
        error "falta -name"
    }
    set nombre [dict get $opts name]
    set peso [expr {[dict exists $opts weight] ? [dict get $opts weight] : 1}]
    puts "creando $nombre con peso $peso"
}
```
`{*}$args` expande la lista de argumentos recibida como argumentos individuales para `parseArgs` (viste `{*}` en la guía de strings, §5 — evita `eval`). El patrón `dict exists ... ? valor_dado : default` es cómo simulas argumentos opcionales con valor por defecto sin escribir un parser más elaborado.

---

## 5. Pieza 4: registro seguro — nunca pisar un comando existente

Este es el requisito extra: si por accidente (o por cargar un módulo dos veces, o un typo) se intenta redefinir un comando que ya existe, en vez de sobrescribirlo silenciosamente (el comportamiento por defecto de `proc`), queremos que se registre con otro nombre y avise.

```tcl
proc defineSafe {nombre argList cuerpo} {
    set final $nombre
    set i 2
    while {[llength [info commands $final]] > 0} {
        set final "${nombre}_$i"
        incr i
    }
    if {$final ne $nombre} {
        puts stderr "Aviso: '$nombre' ya existía, se definió como '$final' en su lugar"
    }
    uplevel 1 [list proc $final $argList $cuerpo]
    return $final
}
```

- `[info commands $final]` (guía de introspección, §1) verifica si ya existe un comando con ese nombre exacto.
- Si existe, prueba sufijos incrementales (`_2`, `_3`...) hasta encontrar uno libre.
- `uplevel 1 [list proc $final $argList $cuerpo]` define la proc **en el scope del llamador** (no dentro de `defineSafe` mismo) — importante para que la proc resultante quede donde el código que llamó a `defineSafe` esperaba que quedara (ej. dentro de un namespace específico), usando el mismo mecanismo de `uplevel` que viste en la guía de introspección para "control de flujo custom".

### Probado en la práctica
```tcl
defineSafe ::store::worker::list {} {
    puts "otra implementación de list"
}
```
Salida real al ejecutar esto sobre un `::store::worker::list` ya existente:
```
Aviso: '::store::worker::list' ya existía, se definió como '::store::worker::list_2' en su lugar
```
La proc original queda intacta; la nueva vive en `::store::worker::list_2`, accesible pero sin haber pisado nada.

---

## 6. El ejemplo completo, unido

```tcl
package require Tcl 8.6

proc defineSafe {nombre argList cuerpo} {
    set final $nombre
    set i 2
    while {[llength [info commands $final]] > 0} {
        set final "${nombre}_$i"
        incr i
    }
    if {$final ne $nombre} {
        puts stderr "Aviso: '$nombre' ya existía, se definió como '$final' en su lugar"
    }
    uplevel 1 [list proc $final $argList $cuerpo]
    return $final
}

proc parseArgs {args} {
    if {[llength $args] % 2 != 0} {
        error "número impar de argumentos, se esperaban pares -clave valor"
    }
    set resultado [dict create]
    foreach {clave valor} $args {
        if {[string index $clave 0] ne "-"} {
            error "se esperaba una opción con guion, se recibió: $clave"
        }
        dict set resultado [string range $clave 1 end] $valor
    }
    return $resultado
}

namespace eval ::store::worker {
    variable trabajadores {}
    variable siguienteId 1

    namespace export list create
    namespace ensemble create

    proc list {} {
        variable trabajadores
        foreach t $trabajadores {
            puts "[dict get $t id]: [dict get $t nombre] (peso: [dict get $t peso])"
        }
        return $trabajadores
    }

    proc create {args} {
        variable trabajadores
        variable siguienteId
        set opts [parseArgs {*}$args]
        if {![dict exists $opts name]} { error "falta -name" }
        set nombre [dict get $opts name]
        set peso [expr {[dict exists $opts weight] ? [dict get $opts weight] : 1}]
        set nuevo [dict create id $siguienteId nombre $nombre peso $peso]
        lappend trabajadores $nuevo
        incr siguienteId
        return $nuevo
    }
}

namespace eval ::store::calendar {
    variable asignaciones {}

    namespace export assign list
    namespace ensemble create

    proc assign {args} {
        variable asignaciones
        set opts [parseArgs {*}$args]
        foreach req {worker_id date} {
            if {![dict exists $opts $req]} { error "falta -$req" }
        }
        set asignacion [dict create \
            worker_id [dict get $opts worker_id] \
            date      [dict get $opts date]]
        lappend asignaciones $asignacion
        puts "Asignado worker_id=[dict get $opts worker_id] a fecha [dict get $opts date]"
        return $asignacion
    }

    proc list {} {
        variable asignaciones
        return $asignaciones
    }
}

namespace eval ::store {
    namespace ensemble create -map {
        worker   ::store::worker
        calendar ::store::calendar
    }
}

# Uso:
store worker create -name Juan -weight 1
store worker create -name Ana
store worker list
store calendar assign -worker_id 1 -date 20241231
```

Salida real de este script:
```
1: Juan (peso: 1)
2: Ana (peso: 1)
Asignado worker_id=1 a fecha 20241231
```

---

## 7. Cómo agregar un tercer módulo (extendiendo el patrón)

Para agregar, por ejemplo, `store inventory add -product Arroz -qty 100`:

```tcl
namespace eval ::store::inventory {
    variable items {}
    namespace export add list
    namespace ensemble create

    proc add {args} {
        variable items
        set opts [parseArgs {*}$args]
        dict set items [dict get $opts product] [dict get $opts qty]
    }
    proc list {} {
        variable items
        return $items
    }
}

# Registrar el nuevo módulo en el ensemble raíz:
namespace eval ::store {
    namespace ensemble configure store -map [dict merge \
        [namespace ensemble configure store -map] \
        {inventory ::store::inventory}]
}
```
`namespace ensemble configure <comando> -map ...` te permite **modificar el mapa de un ensemble ya creado**, en vez de tener que recrearlo desde cero — útil si módulos se registran dinámicamente (ej. plugins que se cargan condicionalmente). `dict merge` combina el mapa existente con la nueva entrada, preservando lo que ya había.

---

## 8. Por qué este patrón vale la pena (vs. procs sueltas con prefijo)

| Sin ensemble | Con ensemble |
|---|---|
| `store::worker::create -name Juan` | `store worker create -name Juan` |
| El usuario necesita saber el namespace exacto | Se siente como una CLI real, autodescubrible |
| `store::worker::list` y `store::calendar::list` no colisionan, pero tampoco se agrupan visualmente | `worker list` y `calendar list` están claramente agrupados bajo `store` |
| No hay validación de "sub-comando inválido" | Tcl automáticamente da error de "unknown subcommand" con sugerencias si escribes mal |

Prueba rápida de la validación automática (mensaje real de Tcl 8.6):
```tcl
store worker invenar
;# error: unknown or ambiguous subcommand "invenar": must be create, or list
```
Este mensaje de error (con la lista de sub-comandos válidos) lo genera Tcl solo, sin que tengas que escribir tu propio manejo de "comando no reconocido" — es una ventaja directa de `namespace ensemble` sobre simplemente prefijar procs a mano.

---

## 9. Resumen de referencia rápida

| Construcción | Uso |
|---|---|
| `namespace export cmd1 cmd2` | expone procs como sub-comandos válidos (obligatorio antes de `ensemble create`) |
| `namespace ensemble create` | convierte el namespace actual en un comando-ensemble |
| `namespace ensemble create -map {sub cmd ...}` | ensemble raíz que reenvía a otros ensembles/comandos |
| `namespace ensemble configure cmd -map ...` | modifica el mapa de un ensemble ya existente (agregar módulos dinámicamente) |
| `parseArgs {*}$args` | convierte `-clave valor -clave2 valor2` en un `dict` |
| `defineSafe nombre argList cuerpo` | define una proc solo si el nombre está libre; si no, usa un sufijo y avisa |
| `[info commands $nombre]` | verifica si un comando ya existe, base del registro seguro |
| `uplevel 1 [list proc ...]` | define la proc en el scope del llamador, no dentro del helper |

---

## 10. Dónde esto te sirve directamente

Este patrón es exactamente lo que usarías para exponer una **capa de comandos administrativos/CLI interna** en cualquier herramienta Tcl que construyas — por ejemplo, una consola de diagnóstico para tu ERP donde escribes comandos tipo `store worker list`, `store db backup`, `store cache clear` en un prompt interactivo (`tclsh` con tu script cargado), en vez de recordar nombres de procs sueltas con prefijos largos. Combínalo con el store de la guía de gestión de estado: los sub-comandos de cada módulo (`worker create`, `calendar assign`) pueden ser wrappers delgados que llaman a `::App::Store::dispatch` por debajo, dándote tanto una API programática limpia como una interfaz de comandos exploratoria para debugging.
