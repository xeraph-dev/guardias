# MVC en un proyecto Snit: aplicado a tu app de guardias

MVC en Tcl/Snit no es una librería que importas — es una forma de organizar código que ya tienes casi armada con lo que hemos visto: el store con trace (Modelo), tus widgets Snit (Vista), y los métodos que reaccionan a botones (Controlador). Esta guía conecta esas piezas explícitamente y te da una regla clara de dónde va cada cosa.

---

## 1. Los tres roles, en términos de Snit concretos

| Rol | Qué es en tu proyecto | Qué NO debe hacer |
|---|---|---|
| **Modelo** | Un `namespace`/`snit::type` que posee los datos reales (trabajadores, asignaciones, mes actual) y las reglas de negocio | No debe saber nada de Tk, widgets, ni `pack`/`grid` |
| **Vista** | Tu árbol de `snit::widget` (`App → Calendar → CalendarPaginator/CalendarGrid → CalendarDay`) | No debe decidir reglas de negocio (ej. "¿puede este trabajador cubrir esta guardia?") — solo mostrar y capturar input |
| **Controlador** | La capa que traduce una acción del usuario (click, selección) en una llamada al Modelo | No debe manipular widgets directamente — solo llama métodos del Modelo |

La pregunta real no es "cómo implemento MVC" (no hay sintaxis especial), sino **"a qué archivo/namespace pertenece cada pieza de lógica que escribo"**.

---

## 2. El Modelo: retomando el store ya construido

Ya lo armamos en una respuesta anterior — el ensemble `store worker create`/`store calendar assign` **es tu Modelo**, aunque no lo hayamos llamado así en su momento:

```tcl
namespace eval ::store::worker {
    variable trabajadores {}
    variable siguienteId 1
    namespace export list create
    namespace ensemble create

    proc create {args} {
        variable trabajadores
        variable siguienteId
        set opts [parseArgs {*}$args]
        set nuevo [dict create id $siguienteId nombre [dict get $opts name] \
            peso [expr {[dict exists $opts weight] ? [dict get $opts weight] : 1}]]
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
        set asignacion [dict create worker_id [dict get $opts worker_id] date [dict get $opts date]]
        lappend asignaciones $asignacion
        return $asignacion
    }
}
```

Esto ya cumple el requisito de un Modelo correcto: **no importa `Tk`**, no sabe que existe `CalendarGrid`, y puedes probarlo con `tcltest` sin levantar ninguna ventana (como viste en la guía de testing). Si mañana agregas persistencia real, es aquí donde conectas SQLite (guía correspondiente) — la Vista nunca se entera de ese detalle.

### El mes actual también es parte del Modelo, no de la Vista
Aunque hoy `calendar_date` vive como `variable` dentro de `App` (un widget), conceptualmente es un dato del Modelo. Si quieres ser estricto con la separación:

```tcl
namespace eval ::App::Model {
    variable mesActual [clock scan "01/[clock format [clock seconds] -format %m/%Y] 00:00:00" -format "%d/%m/%Y %H:%M:%S"]

    proc avanzarMes {} {
        variable mesActual
        set mesActual [clock add $mesActual 1 month]
    }
    proc retrocederMes {} {
        variable mesActual
        set mesActual [clock add $mesActual -1 month]
    }
}
```
`App` (la Vista raíz) pasaría `-date ::App::Model::mesActual` hacia abajo, en vez de tener su propia `variable calendar_date` — el mismo mecanismo que ya usas, solo que la variable vive en un namespace de Modelo explícito en vez de dentro del widget.

---

## 3. La Vista: tu árbol de `snit::widget`, sin lógica de negocio

Esto es lo que ya tienes bien hecho en `Calendar.tcl`/`CalendarPaginator.tcl`/`CalendarGrid.tcl`: widgets que reciben datos por opción, se suscriben con `trace`, y se redibujan. La regla de oro de la Vista en MVC: **si borraras todos tus widgets y los reemplazaras por otros completamente distintos (otra librería de UI), el Modelo no debería necesitar ni un cambio**.

Para verificar que tu `CalendarDay` cumple esto: mira su método `Refrescar` — solo lee `$options(-date)` y actualiza un label. No decide nada, no valida nada, no calcula reglas de negocio (como "¿es fin de semana? ¿hay guardia asignada?"). Si necesitas mostrar si un día tiene guardia asignada, la pregunta "¿este día tiene guardia?" la responde el **Modelo** (`::store::calendar::list`, filtrado), no la Vista calculándolo por su cuenta con lógica propia.

```tcl
;# MAL: la vista decide una regla de negocio
method Refrescar {} {
    set tieneGuardia [expr {[dict get $item peso] > 0.5}]  ;# regla de negocio en la vista
    ...
}

;# BIEN: la vista solo pregunta, el modelo decide
method Refrescar {} {
    set tieneGuardia [::store::calendar::tieneAsignacion $options(-fecha)]
    ...
}
```

---

## 4. El Controlador: honestamente, en Tcl casi siempre vive DENTRO de la Vista — y está bien

Aquí viene la parte que vale la pena decirte con franqueza, en la misma línea que la corrección anterior sobre pub/sub: en la mayoría de código Tcl/Snit real, **no vas a encontrar un objeto "Controlador" separado**. Lo que hace de Controlador son los métodos del propio widget, invocados vía `-command`:

```tcl
snit::widget CalendarPaginator {
    ...
    method next_month {args} {
        ::store::calendar::avanzarMes    ;# esto ES el controlador — traduce "click" en "acción de modelo"
    }
}
```
`next_month` técnicamente mezcla Vista y Controlador en el mismo objeto — el botón (Vista) y la decisión de qué hacer al presionarlo (Controlador) están en la misma clase. **Esto es idiomático en Tcl**, no un error de diseño. Forzar una separación estricta (una clase `CalendarController` aparte que intermedia entre `CalendarPaginator` y el Modelo) agrega una capa de indirección que rara vez paga su costo en una app de escritorio de un solo usuario — es la misma lección que ya viste con el pub/sub manual: no repliques patrones de otros ecosistemas solo porque tienen nombre, si Tcl ya te da algo más simple que cumple el mismo propósito.

### Cuándo SÍ vale la pena extraer un Controlador separado
La señal correcta es: **cuando la misma acción de negocio debe poder dispararse desde más de un lugar** que no es un widget. Tu propio proyecto ya tiene este caso — el ensemble `store worker create`/`store calendar assign` es exactamente eso: una API que puede invocarse desde la GUI **o** desde una consola de comandos, sin duplicar lógica.

```tcl
;# Controlador explícito, reutilizable desde GUI y desde consola/CLI
namespace eval ::App::Controller {
    proc asignarGuardia {workerId fecha} {
        # validaciones que no son puramente de datos (ej. permisos, reglas de UI)
        if {[::store::worker exists $workerId]} {
            ::store::calendar assign -worker_id $workerId -date $fecha
        } else {
            error "trabajador $workerId no existe"
        }
    }
}
```
Ahora tanto un botón "Asignar" en `CalendarPaginator` **como** el comando `store calendar assign` de tu consola de diagnóstico llaman a `::App::Controller::asignarGuardia` — ninguno de los dos reimplementa la validación.

---

## 5. El flujo completo, de punta a punta

```
[usuario hace click en "Siguiente mes" en CalendarPaginator]
            │
            ▼
CalendarPaginator::next_month (Vista actuando como Controlador)
            │
            ▼
::App::Model::avanzarMes (Modelo: muta mesActual)
            │
            ▼
trace nativo dispara sobre ::App::Model::mesActual
            │
            ├──▶ CalendarPaginator::date_changed (Vista se refresca)
            ├──▶ CalendarGrid → cada CalendarDay::Refrescar (Vista se refresca)
            └──▶ (cualquier otro widget suscrito, sin que nadie lo coordine)
```

Nota lo que **no** aparece en este flujo: ningún objeto "Controlador" recibiendo la notificación de vuelta y decidiendo manualmente qué widget actualizar. Eso es trabajo del `trace` nativo (guía de estado idiomático) — el Controlador solo va en una dirección (usuario → Modelo), la vuelta (Modelo → Vista) la resuelve la reactividad de variables, no una llamada explícita del Controlador.

---

## 6. Resumen: dónde va cada cosa en tu proyecto actual

| Archivo/namespace | Rol | Contiene |
|---|---|---|
| `::store::worker`, `::store::calendar`, `::App::Model` | Modelo | Datos, mutaciones, reglas de negocio, cero Tk |
| `App.tcl`, `Calendar.tcl`, `CalendarGrid.tcl`, `CalendarDay.tcl` | Vista | Widgets, `trace` de lectura, cero decisiones de negocio |
| Métodos como `next_month`, `assign` dentro de `CalendarPaginator.tcl` | Vista+Controlador combinados (normal en Tcl) | Traducir clicks en llamadas al Modelo |
| `::App::Controller::*` (opcional) | Controlador explícito | Solo si la misma acción se dispara desde 2+ lugares distintos (GUI + CLI, GUI + API) |

La regla práctica: empieza con Vista+Controlador mezclados (como ya tienes) — es más simple y perfectamente idiomático. Extrae un Controlador aparte **solo** cuando notes que estás copiando la misma lógica de validación en dos lugares distintos (típicamente cuando agregas una segunda forma de interactuar con tu app, como la consola `store` que ya construiste).
