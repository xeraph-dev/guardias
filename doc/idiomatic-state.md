# Estado idiomático en Snit: cuando una opción se define arriba pero se usa abajo

Esta guía retoma la corrección de la conversación anterior: en Tcl, la forma nativa de "algo reacciona cuando otra cosa cambia" es `trace`, no un sistema de suscripción hecho a mano. Aquí extendemos eso al problema concreto que planteas: una opción (como `-mesvar`, el nombre de la variable con el mes actual) se define en el widget raíz de tu app, pero la necesita un componente varios niveles adentro — el equivalente a "prop drilling" en frameworks de UI basados en árboles de componentes.

La diferencia clave con React/JS: en Tcl, **una variable con nombre completamente calificado (`::App::mesActual`) es accesible desde cualquier punto del programa**, sin importar la profundidad de anidamiento — no existe el problema real de "props" que deben atravesar físicamente cada nivel del árbol para llegar a un nieto. Esto cambia por completo cuál es la solución idiomática.

---

## 1. Los dos mecanismos disponibles, y cuándo es cada uno

| Mecanismo | Qué hace | Cuándo usarlo |
|---|---|---|
| **`delegate option`** | Reenvía una opción de un widget a un componente interno, nivel por nivel | Cuando el componente interno es un widget genérico/reutilizable que no debería conocer nombres de variables específicos de tu app (ej. delegar `-font` a un `entry` interno) |
| **Variable con nombre calificado, pasada directo** | Cualquier widget, sin importar cuán anidado esté, recibe el *nombre* de una variable (`::App::mesActual`) y hace `trace`/`-textvariable` sobre ella directamente | Cuando el dato es específico del dominio de tu app (el mes actual, el usuario logueado) y varios widgets no relacionados entre sí lo necesitan |

La confusión típica viniendo de React es asumir que **siempre** necesitas la primera opción (equivalente a pasar props por cada nivel, o usar Context). En Tcl casi nunca es así — la segunda opción es más simple y es lo que verás en código Tcl real.

---

## 2. `delegate option`: cuándo SÍ tiene sentido, y su límite real

`delegate option` reenvía una opción de tu widget a un componente interno — pero **no atraviesa automáticamente varios niveles**. Si tienes `padre → hijo → nieto`, y `nieto` es quien realmente necesita la opción, tanto `padre` como `hijo` deben declarar la delegación explícitamente, uno por uno:

```tcl
snit::widget nieto {
    option -font -default {Arial 10}
    constructor {args} {
        install lbl using label $win.l
        $self configurelist $args
        $lbl configure -font $options(-font)
    }
}

snit::widget hijo {
    delegate option -font to nietoComp     ;# nivel 1: hijo -> nieto
    component nietoComp
    constructor {args} {
        install nietoComp using nieto $win.n
        $self configurelist $args
    }
}

snit::widget padre {
    delegate option -font to hijoComp       ;# nivel 2: padre -> hijo
    component hijoComp
    constructor {args} {
        install hijoComp using hijo $win.h
        $self configurelist $args
    }
}

padre .p -font {Arial 14 bold}    ;# atraviesa los 2 niveles, pero cada uno lo declaró
```
Esto es correcto y útil para opciones de **presentación genérica** (`-font`, `-width`, `-background`) que tiene sentido que cualquier widget compuesto reenvíe hacia adentro sin saber para qué se usan. Pero si tu app tiene 4-5 niveles de anidamiento y la opción es algo específico de tu dominio (como el mes del calendario), declarar la delegación en cada nivel intermedio es ceremonia que no aporta nada — esos niveles intermedios no necesitan saber que `-mesvar` existe, solo están "de paso".

---

## 3. El patrón idiomático real: pasar el nombre de la variable directamente

Como una variable Tcl con nombre calificado es alcanzable desde cualquier parte del programa, el patrón que verás en código Tcl idiomático es: **el widget más interno recibe el nombre de la variable como una opción de solo-lectura al construirse, sin que ningún nivel intermedio necesite saber que esa opción existe.**

```tcl
namespace eval ::App {
    variable mesActual 8
    variable anioActual 2026
}

snit::widget diaCelda {
    option -mesvar -readonly 1
    option -dia -readonly 1
    component lbl

    constructor {args} {
        $self configurelist $args
        install lbl using ttk::label $win.l
        pack $lbl
        trace add variable $options(-mesvar) write [mymethod Refrescar]
        $self Refrescar
    }

    destructor {
        trace remove variable $options(-mesvar) write [mymethod Refrescar]
    }

    method Refrescar {args} {
        $lbl configure -text "Día $options(-dia) del mes [set $options(-mesvar)]"
    }
}

snit::widget grillaCalendario {
    hulltype ttk::frame
    option -mesvar -readonly 1

    constructor {args} {
        $self configurelist $args
        for {set d 1} {$d <= 30} {incr d} {
            # cada celda recibe DIRECTAMENTE el nombre de la variable global,
            # sin que grillaCalendario necesite delegar nada especial
            diaCelda $win.d$d -dia $d -mesvar $options(-mesvar)
            grid $win.d$d
        }
    }
}

snit::widget appPrincipal {
    hulltype ttk::frame
    component grilla

    constructor {args} {
        install grilla using grillaCalendario $win.grilla -mesvar ::App::mesActual
        pack $grilla -fill both -expand 1
    }
}

appPrincipal .app
pack .app
```

Aquí `diaCelda` está 3 niveles adentro (`appPrincipal → grillaCalendario → diaCelda`), y necesita reaccionar al mes actual — pero **ningún nivel intermedio declaró `delegate option -mesvar`**. `grillaCalendario` simplemente reenvía el string `$options(-mesvar)` al construir cada celda, porque es un dato que ya tenía como parámetro propio (no delegación, solo pasar un valor normal a un constructor, como pasarías cualquier otro argumento).

**Diferencia clave con delegación real:** `grillaCalendario` sí necesita **su propia opción `-mesvar`** para saber qué pasar hacia abajo — eso no lo evitas. Pero no necesita `-configuremethod` especial, ni saber qué hace `diaCelda` con ese valor, ni reaccionar él mismo al cambio si no le importa — solo lo retransmite al construir. Es la diferencia entre "delegar una opción configurable después de construido" (`delegate option`, que permite `.padre configure -font ...` en cualquier momento) y "pasar un dato al momento de construir" (mucho más simple, válido cuando el valor no cambia después de creado el widget, como el *nombre* de una variable — el nombre no cambia, solo su contenido).

---

## 4. Cuándo saltarte por completo el paso de pasar la opción

Si `::App::mesActual` es un dato verdaderamente único en toda tu app (un solo calendario, no vas a tener instancias múltiples), la opción más simple de todas es que **cualquier widget interno lo referencie directamente por su nombre completo**, sin recibirlo como parámetro en absoluto:

```tcl
snit::widget diaCelda {
    option -dia -readonly 1
    component lbl

    constructor {args} {
        $self configurelist $args
        install lbl using ttk::label $win.l
        pack $lbl
        trace add variable ::App::mesActual write [mymethod Refrescar]
        $self Refrescar
    }

    destructor {
        trace remove variable ::App::mesActual write [mymethod Refrescar]
    }

    method Refrescar {args} {
        $lbl configure -text "Día $options(-dia) del mes $::App::mesActual"
    }
}
```
Esto es lo más corto posible, y es exactamente lo que harías en un script Tcl "de toda la vida" sin pretensiones de reusabilidad — cero opciones que pasar, cero parámetros que retransmitir por 3 niveles. El costo: `diaCelda` ya **no es reutilizable** fuera del contexto de tu app específica (queda acoplado al nombre `::App::mesActual` para siempre), y no puedes testearlo de forma aislada sin que exista esa variable global exacta.

---

## 5. La regla de decisión

```
¿El widget interno podría necesitar usarse en otro contexto,
con otra fuente de estado (otro store, otra app, un test)?
│
├── SÍ → recíbelo como opción -readonly al construir (§3),
│        aunque tengas que retransmitirlo por varios niveles.
│        El widget queda desacoplado y testeable.
│
└── NO, es intrínsecamente parte de esta app,
    nunca habrá dos → referencia el nombre completo
    directamente (§4). Menos código, acoplamiento aceptado
    a propósito.
```

Y por separado, para la opción que sí se reenvía como parámetro (§3, no delegación real):

```
¿La opción debe poder cambiar DESPUÉS de que el widget
ya fue construido (ej. .padre configure -font otro)?
│
├── SÍ → usa delegate option de verdad (§2), nivel por nivel
│
└── NO, se fija una sola vez al crear el widget
    (como el nombre de una variable — el nombre no cambia)
    → pásalo como argumento normal del constructor (§3),
      no necesitas la maquinaria de delegate en absoluto.
```

---

## 6. Aplicado a tu app "guardias": la recomendación concreta

Dado que es un solo calendario por app (no vas a tener dos calendarios de guardias simultáneos en la misma ventana), la combinación más idiomática y con menos código es:

1. **Un namespace `::App` con las variables de estado real** (`mesActual`, `anioActual`), no un objeto Snit "store" con métodos de suscripción custom.
2. **Métodos de mutación** (`avanzarMes`, `retrocederMes`) como procs normales dentro de `::App`, que hacen `incr`/`set` sobre esas variables — la variable sigue siendo la fuente de verdad, el trace nativo se encarga de avisar.
3. **Cada widget que lo necesita** (sin importar cuán anidado esté) hace su propio `trace add variable ::App::mesActual write [mymethod Refrescar]` en el constructor, y `trace remove` en el destructor — referenciándolo directamente (§4), porque este dato es único en tu app y no hay beneficio real en fingir que `diaCelda` podría vivir en otro contexto.

```tcl
namespace eval ::App {
    variable mesActual 8
    variable anioActual 2026

    proc avanzarMes {} {
        variable mesActual
        variable anioActual
        incr mesActual
        if {$mesActual > 12} {
            set mesActual 1
            incr anioActual
        }
    }

    proc retrocederMes {} {
        variable mesActual
        variable anioActual
        incr mesActual -1
        if {$mesActual < 1} {
            set mesActual 12
            incr anioActual -1
        }
    }
}
```
Cualquier widget en cualquier nivel de anidamiento reacciona con `trace add variable ::App::mesActual write ...` — sin `delegate option`, sin pasar `-mesvar` por 3 niveles de constructores, sin ningún objeto "store" intermedio. Es la versión más corta y más reconocible como Tcl idiomático para el caso de un dato único de toda la aplicación.

Reserva `delegate option` para lo que sí es genuinamente reutilizable en tu app (ej. si `diaCelda` tuviera un `-color` o `-font` que distintas partes de la UI quisieran personalizar) — ahí sí vale la pena la ceremonia de la delegación, porque esas opciones son legítimamente parte de la API pública y reconfigurable del widget, no un canal para pasar una referencia de estado interno.
