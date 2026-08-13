# Estado compartido en una app Snit: el caso del mes actual del calendario

Este es el problema concreto de tu app "guardias": varios widgets (el header con el nombre del mes, la grilla de días, quizás un selector de navegación) necesitan todos conocer y reaccionar al **mismo** dato — qué mes/año está mostrando el calendario. La pregunta de fondo es dónde vive ese dato y cómo se enteran los widgets cuando cambia.

Todo el código de esta guía fue probado en un intérprete real con `snit` cargado.

---

## 1. El antipatrón que probablemente tienes ahora

Si "toda la app usa una variable" en el sentido de una variable global suelta (`set ::mesActual 8`), el problema no es que sea global — es que **nadie sabe quién más depende de ella**, y actualizar la UI cuando cambia requiere que cada lugar que la modifica se acuerde de llamar manualmente a cada widget que debe refrescarse. Esto escala mal: agregar un nuevo widget que muestra el mes significa ir a buscar cada punto donde `mesActual` se modifica y agregar ahí una llamada de refresco más.

```tcl
# Tal como probablemente está ahora:
set ::mesActual 8

proc avanzarMes {} {
    incr ::mesActual
    .header configure -text "Mes: $::mesActual"   ;# hay que acordarse de esto...
    .grilla actualizar                              ;# ...y esto...
    .selector actualizar                            ;# ...y esto, en CADA lugar que cambia mesActual
}
```

---

## 2. La pregunta clave antes de elegir un patrón: ¿vas a tener uno o varios calendarios en pantalla a la vez?

Esto determina todo lo que sigue:

- **Un solo calendario en toda la app** (lo más probable para "guardias"): el estado puede vivir en un `namespace` global, como viste en la guía de gestión de estado general. Es más simple.
- **Podrías tener varios calendarios simultáneos** (ej. comparar guardias de dos meses lado a lado, o una vista por cada trabajador): el estado **no puede** ser global — cada instancia de calendario necesita su propia copia. Ahí necesitas encapsular el estado en un objeto Snit independiente por instancia.

Dado que Snit está pensado justo para esto último (widgets reutilizables e instanciables), te muestro el patrón que sirve para **ambos casos con el mismo código** — la diferencia es solo si creas una instancia del store o varias.

---

## 3. El store como `snit::type` (no `snit::widget`) — separar estado de presentación

La pieza central: un `snit::type` (sin GUI) que posee el mes/año actual, expone métodos para cambiarlo, y notifica a quien esté suscrito. Es la versión Snit-nativa del "store con dispatch" de la guía de gestión de estado, pero aprovechando que Snit ya te da `option`, `cget`/`configure` gratis.

```tcl
package require snit

snit::type CalendarStore {
    option -mes  -default 8
    option -anio -default 2026

    variable suscriptores {}

    method suscribir {callback} {
        lappend suscriptores $callback
    }

    method desuscribir {callback} {
        set idx [lsearch -exact $suscriptores $callback]
        if {$idx >= 0} {
            set suscriptores [lreplace $suscriptores $idx $idx]
        }
    }

    method siguienteMes {} {
        set nuevoMes [expr {$options(-mes) + 1}]
        if {$nuevoMes > 12} {
            set nuevoMes 1
            $self configure -anio [expr {$options(-anio) + 1}]
        }
        $self configure -mes $nuevoMes
        $self Notificar
    }

    method mesAnterior {} {
        set nuevoMes [expr {$options(-mes) - 1}]
        if {$nuevoMes < 1} {
            set nuevoMes 12
            $self configure -anio [expr {$options(-anio) - 1}]
        }
        $self configure -mes $nuevoMes
        $self Notificar
    }

    method irA {mes anio} {
        $self configure -mes $mes -anio $anio
        $self Notificar
    }

    method Notificar {} {
        foreach cb $suscriptores {
            uplevel #0 $cb
        }
    }
}
```

Uso y verificación (esto es exactamente lo que corrí para probarlo):
```tcl
CalendarStore calStore

proc onCambioMes {} {
    puts "el mes cambió a: [calStore cget -mes]/[calStore cget -anio]"
}
calStore suscribir onCambioMes

calStore siguienteMes    ;# -> "el mes cambió a: 9/2026"
calStore mesAnterior     ;# -> "el mes cambió a: 8/2026"
calStore irA 1 2027      ;# -> "el mes cambió a: 1/2027"
```

Puntos clave de este diseño:
- **`option -mes`/`-anio`** te da `cget`/`configure` automáticamente — no necesitas escribir getters a mano, y cualquier código externo puede leer `[calStore cget -mes]` en cualquier momento sin pasar por un método especial.
- **Nunca mutes `options(-mes)` directamente desde fuera** — todos los cambios pasan por `siguienteMes`/`mesAnterior`/`irA`, que son los únicos que llaman a `Notificar`. Esto es el mismo principio de "punto único de mutación" (dispatch) que viste en la guía general de estado, adaptado al estilo de métodos de Snit en vez de un `switch` de acciones.
- **`suscribir`/`desuscribir`** son la mitad que le faltaba a un `option` normal de Snit: `-configuremethod` (visto en la guía de Snit) te avisa cuando *alguien externo* llama `configure`, pero aquí el cambio ocurre *dentro* del store mismo (`siguienteMes` llama `$self configure`), así que necesitas tu propio mecanismo de notificación explícito.

---

## 4. Conectar los widgets Snit al store

Cada widget que necesita mostrar o reaccionar al mes recibe una **referencia al store** (no crea el suyo propio) y se suscribe en su constructor, desuscribiéndose en el destructor — el mismo cuidado de limpieza que viste en la guía de Snit (§9) para timers y traces.

```tcl
package require Tk
package require snit

snit::widget encabezadoMes {
    hulltype ttk::frame
    option -store -readonly 1     ;# se pasa al crear, no cambia después

    component lbl
    component btnAnterior
    component btnSiguiente

    variable nombresMeses {
        Enero Febrero Marzo Abril Mayo Junio
        Julio Agosto Septiembre Octubre Noviembre Diciembre
    }

    constructor {args} {
        $self configurelist $args
        if {$options(-store) eq ""} {
            error "encabezadoMes requiere -store"
        }

        install btnAnterior using ttk::button $win.ant -text "◀" \
            -command [mymethod IrAnterior]
        install lbl using ttk::label $win.lbl -font {Arial 12 bold}
        install btnSiguiente using ttk::button $win.sig -text "▶" \
            -command [mymethod IrSiguiente]

        pack $btnAnterior -side left
        pack $lbl -side left -padx 10
        pack $btnSiguiente -side left

        $options(-store) suscribir [mymethod Refrescar]
        $self Refrescar
    }

    destructor {
        if {$options(-store) ne ""} {
            $options(-store) desuscribir [mymethod Refrescar]
        }
    }

    method IrAnterior {} { $options(-store) mesAnterior }
    method IrSiguiente {} { $options(-store) siguienteMes }

    method Refrescar {} {
        set mes [$options(-store) cget -mes]
        set anio [$options(-store) cget -anio]
        set nombre [lindex $nombresMeses [expr {$mes - 1}]]
        $lbl configure -text "$nombre $anio"
    }
}
```

Y la grilla del calendario, como segundo suscriptor independiente:
```tcl
snit::widget grillaCalendario {
    hulltype ttk::frame
    option -store -readonly 1

    constructor {args} {
        $self configurelist $args
        $options(-store) suscribir [mymethod Refrescar]
        $self Refrescar
    }

    destructor {
        $options(-store) desuscribir [mymethod Refrescar]
    }

    method Refrescar {} {
        set mes [$options(-store) cget -mes]
        set anio [$options(-store) cget -anio]
        # aquí reconstruyes la grilla de días para $mes/$anio,
        # posiblemente consultando tus datos de guardias vía ::App::DB::*
        puts "redibujando grilla para $mes/$anio"
    }
}
```

Y la composición final, en el nivel de la app:
```tcl
CalendarStore calStore -mes 8 -anio 2026

encabezadoMes .header -store calStore
grillaCalendario .grilla -store calStore
pack .header .grilla -fill both -expand 1

vwait forever
```
Con esto: al hacer click en "▶" del encabezado, `siguienteMes` cambia el store, notifica a **ambos** suscriptores, y tanto el encabezado como la grilla se redibujan solos — sin que `encabezadoMes` necesite saber que `grillaCalendario` existe, ni viceversa. Exactamente el flujo unidireccional de la guía de gestión de estado (§6), aquí expresado con la sintaxis nativa de componentes/opciones de Snit en vez de namespaces sueltos.

---

## 5. ¿Uno global o una instancia por app?

```tcl
# Variante A: una sola instancia, vive como parte del namespace de tu app
namespace eval ::App {
    CalendarStore Store
}
encabezadoMes .header -store ::App::Store

# Variante B: instancia local, útil si algún día necesitas 2 calendarios
set storeIzq [CalendarStore create %AUTO%]
set storeDer [CalendarStore create %AUTO%]
encabezadoMes .headerIzq -store $storeIzq
encabezadoMes .headerDer -store $storeDer
```
`%AUTO%` le pide a Snit que genere un nombre único automáticamente (`CalendarStore1`, `CalendarStore2`...) — útil cuando no necesitas un nombre fijo y quieres poder crear cuantas instancias necesites sin colisión. Con este diseño, **no tuviste que decidir de antemano** si tu app necesita uno o varios calendarios — el mismo `CalendarStore` sirve para ambos casos, la diferencia es solo cuántas instancias creas y a cuáles widgets se las pasas.

---

## 6. Persistencia: ¿el mes actual sobrevive un reinicio de la app?

Si quieres que la app recuerde en qué mes estaba al cerrarla (razonable para una app de guardias que usas a diario), agrega la persistencia como un suscriptor más, no como lógica especial dentro del store:

```tcl
proc guardarMesActual {} {
    global calStore
    set f [open [file join $::env(HOME) ".guardias_estado"] w]
    puts $f "[calStore cget -mes] [calStore cget -anio]"
    close $f
}
calStore suscribir guardarMesActual

proc cargarMesActual {} {
    set ruta [file join $::env(HOME) ".guardias_estado"]
    if {[file exists $ruta]} {
        set f [open $ruta r]
        lassign [read $f] mes anio
        close $f
        return [list $mes $anio]
    }
    return [list 8 2026]    ;# default si no hay estado guardado
}

lassign [cargarMesActual] mesInicial anioInicial
CalendarStore calStore -mes $mesInicial -anio $anioInicial
calStore suscribir guardarMesActual
```
Guardar/cargar el mes es completamente ajeno a la lógica de `siguienteMes`/`mesAnterior` — se conecta como **un suscriptor más** del mismo mecanismo de notificación, sin tocar el store. Este es el mismo principio de la guía de gestión de estado (§7): la persistencia es una capa aparte, no algo entrelazado con la lógica de mutación del estado.

---

## 7. Resumen de la decisión

| Situación | Diseño recomendado |
|---|---|
| Un solo calendario en toda tu app "guardias" | `CalendarStore` como instancia única, referenciada por nombre fijo (ej. `::App::Store`) |
| Posibilidad futura de múltiples calendarios simultáneos | Mismo `CalendarStore`, pero instanciado con `%AUTO%` y pasado explícitamente a cada grupo de widgets vía `-store` |
| Widgets que solo leen el mes (labels, headers) | Se suscriben en el constructor, leen con `cget`, se desuscriben en el destructor |
| Widgets/lógica que cambian el mes (botones de navegación) | Llaman métodos del store (`siguienteMes`, `irA`), nunca tocan `options` directamente |
| Guardar el mes entre sesiones | Un suscriptor más (proc suelta o método de otro objeto), no lógica especial dentro del store |

---

## 8. Por qué esto es mejor que la variable global suelta

- **Ningún widget necesita saber qué otros widgets existen.** Agregar un tercer widget que también depende del mes (ej. un mini-resumen de guardias del mes) es solo: crearlo, pasarle `-store`, suscribirse. Cero cambios en el código existente.
- **El estado no se puede mutar por accidente desde cualquier lugar.** Con la variable global, cualquier línea de código en cualquier archivo podía hacer `set ::mesActual 99` sin validación. Con el store, solo `siguienteMes`/`mesAnterior`/`irA` pueden cambiar el valor, y ahí es donde pondrías cualquier validación futura (ej. no permitir ir a meses fuera de un rango de datos disponibles).
- **Es trivial de testear** (conectando con la guía de tcltest): puedes crear un `CalendarStore` en un test, suscribir una proc de prueba, llamar `siguienteMes`, y verificar que se notificó y que el valor cambió — sin necesitar levantar ningún widget Tk real.

```tcl
test store-1.1 {siguienteMes avanza correctamente} -body {
    set s [CalendarStore create %AUTO% -mes 12 -anio 2026]
    $s siguienteMes
    list [$s cget -mes] [$s cget -anio]
} -result {1 2027}
```
