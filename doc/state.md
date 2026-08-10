# Gestión de estado en aplicaciones Tcl/Tk

Tk no impone un patrón de estado (no hay "Redux oficial" ni `useState`), pero el lenguaje te da piezas nativas —`trace`, `namespace`, `dict`, TclOO— con las que puedes construir cualquier arquitectura que ya conozcas de React: estado local, estado global centralizado, pub/sub, incluso algo parecido a un store reactivo. Esta guía va de lo más simple a lo más escalable, con foco en qué patrón usar según el tamaño de tu app (pensando en tu ERP/POS).

---

## 0. El problema de fondo

En Tk, cada widget vive colgado de un path (`.frame.entry`), y por defecto no hay ningún mecanismo que sincronice automáticamente "estos 3 widgets deben reflejar el mismo dato". Sin una estrategia, terminas con:

- Variables globales sueltas por todos lados (`set nombreProducto`, `set stockActual`... sin ningún namespace).
- Lógica de "cuando cambia X, actualiza Y" repetida a mano en cada callback.
- Imposibilidad de saber, mirando el código, **dónde vive la fuente de verdad** de un dato.

Todo lo que sigue es, en esencia, distintas formas de resolver esos tres problemas con las herramientas nativas de Tcl.

---

## 1. Nivel 0: variable + `-textvariable` (estado trivial, un solo widget)

Ya lo viste en las guías anteriores, pero es el punto de partida obligatorio:

```tcl
set nombreVar ""
entry .e -textvariable nombreVar
label .lbl -textvariable nombreVar   ;# ambos reflejan la misma variable, sin código extra
```

Tk internamente hace un `trace` sobre `nombreVar` por ti. Esto **es** gestión de estado reactiva, solo que a nivel de una sola variable. Sirve perfecto para formularios simples, pero no escala cuando el cambio de un dato debe disparar lógica de negocio (recalcular un total, validar, llamar al backend).

---

## 2. Nivel 1: `namespace` como "store" simple

En vez de variables globales sueltas, agrupa el estado de un módulo bajo un namespace — es tu primer paso hacia algo parecido a un módulo de estado de Redux/Zustand, pero sin reactividad todavía.

```tcl
namespace eval ::App::Carrito {
    variable items {}
    variable total 0

    proc agregar {producto precio} {
        variable items
        variable total
        lappend items [dict create producto $producto precio $precio]
        set total [expr {$total + $precio}]
    }

    proc vaciar {} {
        variable items
        variable total
        set items {}
        set total 0
    }

    proc obtenerTotal {} {
        variable total
        return $total
    }
}

App::Carrito::agregar "Arroz" 2.50
puts [App::Carrito::obtenerTotal]   ;# 2.50
```

Ventaja sobre variables globales sueltas: **el namespace es la fuente de verdad, visible y nombrada**. Cualquiera que lea `App::Carrito::agregar` sabe exactamente qué módulo posee ese estado. Sigue siendo manual: si quieres que la UI se refresque cuando cambia `total`, tienes que llamarlo tú explícitamente después de cada `agregar`.

---

## 3. Nivel 2: `trace` para reactividad real

Aquí es donde Tcl empieza a comportarse como un store reactivo de verdad: cualquier variable (incluida una dentro de un namespace) puede tener observadores.

```tcl
namespace eval ::App::Carrito {
    variable items {}
    variable total 0

    proc agregar {producto precio} {
        variable items
        variable total
        lappend items [dict create producto $producto precio $precio]
        set total [expr {$total + $precio}]
        # no hace falta notificar manualmente: quien observe "total" se entera solo
    }
}

# En el módulo de UI, en vez de que Carrito conozca la UI, la UI se suscribe a Carrito:
proc ::App::UI::ActualizarTotalUI {args} {
    .lblTotal configure -text "Total: \$::App::Carrito::total"
}
trace add variable ::App::Carrito::total write ::App::UI::ActualizarTotalUI
```

Esto invierte la dependencia: **el módulo de estado (`Carrito`) no sabe nada de la UI**. Es la UI la que se suscribe a los cambios de estado que le interesan. Esto es exactamente el patrón *observer* / pub-sub que usarías con un `EventEmitter` en Node o con `subscribe()` en Redux — pero aquí es una feature nativa del lenguaje, no una librería.

### Trace sobre elementos de un array (útil para "un evento por campo")
```tcl
array set ::App::Estado {
    usuario ""
    conectado 0
}

trace add variable ::App::Estado(conectado) write {apply {{args} {
    if {$::App::Estado(conectado)} {
        puts "Sesión iniciada"
    } else {
        puts "Sesión cerrada"
    }
}}}

set ::App::Estado(conectado) 1    ;# dispara el trace automáticamente
```

### Cuidado con los traces: limpieza y loops infinitos
- Si dos variables se traceán mutuamente y cada handler modifica a la otra, generas un loop. Evita escribir en `write` traces la misma variable que disparó el trace, o usa una bandera de "actualizando" si es inevitable.
- Los traces **no se destruyen solos**. Si el widget que se suscribió se destruye, debes remover el trace en su `destructor` (ver la guía de Snit, §9) o tendrás errores "invalid command name" cuando el trace intente actualizar un widget que ya no existe.

```tcl
trace remove variable ::App::Carrito::total write ::App::UI::ActualizarTotalUI
```

---

## 4. Nivel 3: estado como `dict` inmutable-ish + función de actualización única

Cuando el estado tiene muchos campos relacionados, en vez de N variables sueltas con N traces, centraliza todo en un solo `dict` y define **un único punto de entrada** para modificarlo — el equivalente Tcl de un reducer.

```tcl
namespace eval ::App::Store {
    variable estado [dict create \
        carrito {} \
        total 0 \
        usuario "" \
        conectado 0]

    variable suscriptores {}

    # --- API pública ---
    proc suscribir {callback} {
        variable suscriptores
        lappend suscriptores $callback
    }

    proc obtener {clave} {
        variable estado
        return [dict get $estado $clave]
    }

    proc dispatch {accion args} {
        variable estado
        switch $accion {
            AGREGAR_PRODUCTO {
                lassign $args producto precio
                dict lappend estado carrito [dict create producto $producto precio $precio]
                dict set estado total [expr {[dict get $estado total] + $precio}]
            }
            VACIAR_CARRITO {
                dict set estado carrito {}
                dict set estado total 0
            }
            LOGIN {
                lassign $args usuario
                dict set estado usuario $usuario
                dict set estado conectado 1
            }
            default {
                error "acción desconocida: $accion"
            }
        }
        Notificar
    }

    proc Notificar {} {
        variable suscriptores
        foreach cb $suscriptores {
            uplevel #0 $cb
        }
    }
}
```

Uso desde la UI:
```tcl
proc RefrescarUI {} {
    .lblTotal configure -text "Total: \$[::App::Store::obtener total]"
    .lblUsuario configure -text [::App::Store::obtener usuario]
}
::App::Store::suscribir RefrescarUI

::App::Store::dispatch AGREGAR_PRODUCTO "Arroz" 2.50
::App::Store::dispatch LOGIN "Adrian"
```

Esto es literalmente el patrón **Flux/Redux** trasplantado a Tcl: `dispatch` es tu única puerta de entrada para mutar estado, `suscribir` es tu `store.subscribe()`, y `Notificar` reemplaza el mecanismo de `trace` por uno explícito y más controlable (mejor cuando tienes lógica compleja de "qué debe re-renderizarse", porque evitas N traces individuales difíciles de rastrear).

**Cuándo preferir esto sobre `trace` puro:** cuando una sola acción de usuario modifica varios campos relacionados a la vez (agregar al carrito cambia `carrito` Y `total`), quieres notificar una sola vez al final, no disparar 2 traces por separado con estados intermedios inconsistentes.

---

## 5. Nivel 4: estado encapsulado con TclOO/Snit (cuando quieres múltiples instancias)

Los niveles anteriores asumen **un solo estado global** para toda la app — razonable para la mayoría de apps de escritorio. Pero si necesitas múltiples instancias independientes de un mismo "tipo" de estado (ej. varias ventanas de venta abiertas a la vez, cada una con su propio carrito), necesitas encapsular el estado en objetos, no en namespaces globales.

```tcl
package require snit

snit::type CarritoState {
    variable items {}
    variable total 0
    variable suscriptores {}

    method suscribir {callback} {
        lappend suscriptores $callback
    }

    method agregar {producto precio} {
        lappend items [dict create producto $producto precio $precio]
        set total [expr {$total + $precio}]
        $self Notificar
    }

    method vaciar {} {
        set items {}
        set total 0
        $self Notificar
    }

    method total {} { return $total }
    method items {} { return $items }

    method Notificar {} {
        foreach cb $suscriptores {
            uplevel #0 $cb
        }
    }
}

# Cada ventana de venta tiene su propio carrito independiente:
CarritoState carrito1
CarritoState carrito2

carrito1 agregar "Arroz" 2.50
carrito2 agregar "Frijoles" 1.80

puts [carrito1 total]   ;# 2.50
puts [carrito2 total]   ;# 1.80
```

Este es el patrón correcto cuando tu app no tiene "un" estado global sino múltiples instancias de la misma clase de estado — piensa en esto como tener varios `useReducer` independientes en vez de un único store global de Redux.

---

## 6. Conectando estado con megawidgets Snit (patrón recomendado para tu ERP)

Combinando la guía anterior de Snit con el store del §4: tus megawidgets no deberían mutar el estado global directamente, sino **suscribirse** a él y **despachar acciones**. Esto mantiene tus widgets "tontos" (dumb components) y toda la lógica de negocio centralizada.

```tcl
snit::widget panelCarrito {
    hulltype ttk::frame
    component lista
    component lblTotal

    constructor {args} {
        install lista using listbox $win.lista
        install lblTotal using ttk::label $win.total
        pack $lista $lblTotal -fill x

        ::App::Store::suscribir [mymethod Refrescar]
        $self Refrescar
    }

    method Refrescar {} {
        $lista delete 0 end
        foreach item [::App::Store::obtener carrito] {
            $lista insert end "[dict get $item producto]: \$[dict get $item precio]"
        }
        $lblTotal configure -text "Total: \$[::App::Store::obtener total]"
    }

    destructor {
        # si tu store guarda referencias por widget, límpialas aquí
    }
}
```

El widget **nunca** llama `dict set` directamente sobre el estado — solo lee (`obtener`) y reacciona (`Refrescar` vía suscripción). Quien quiera agregar un producto llama `::App::Store::dispatch AGREGAR_PRODUCTO ...` desde donde sea (otro widget, un handler de socket, un timer), y el panel se actualiza solo. Exactamente el flujo unidireccional de datos que ya conoces de React + un store centralizado.

---

## 7. Persistencia: sincronizar estado con SQLite (tu backend real)

Dado tu stack (Go + SQLite), lo normal es que el **store en memoria en Tcl** (si construyes alguna herramienta en Tcl/Tk) sea solo una capa de caché/UI, y la fuente de verdad real viva en SQLite. Patrón recomendado:

```tcl
package require sqlite3
sqlite3 db "inventario.db"

namespace eval ::App::Store {
    variable estado [dict create productos {}]
    variable suscriptores {}

    proc cargarDesdeDB {} {
        variable estado
        set productos {}
        db eval {SELECT nombre, precio, stock FROM productos} row {
            lappend productos [dict create nombre $row(nombre) precio $row(precio) stock $row(stock)]
        }
        dict set estado productos $productos
        Notificar
    }

    proc dispatch {accion args} {
        variable estado
        switch $accion {
            VENDER {
                lassign $args nombre cantidad
                db eval {UPDATE productos SET stock = stock - :cantidad WHERE nombre = :nombre}
                cargarDesdeDB    ;# vuelve a leer de la fuente de verdad tras mutar
            }
        }
    }

    proc suscribir {cb} { variable suscriptores; lappend suscriptores $cb }
    proc obtener {clave} { variable estado; return [dict get $estado $clave] }
    proc Notificar {} { variable suscriptores; foreach cb $suscriptores { uplevel #0 $cb } }
}

::App::Store::cargarDesdeDB
```

El patrón **"escribe en DB, luego relee y notifica"** es más simple y robusto que intentar mantener el `dict` en memoria perfectamente sincronizado con la base de datos a mano — evita bugs sutiles de desincronización. Solo optimizas esto (actualizar el dict en memoria directamente sin releer) si el `SELECT` completo se vuelve un cuello de botella real.

---

## 8. Estado derivado/computado (evitar duplicar lógica)

Un error común: guardar `total` como variable de estado Y actualizarla a mano en cada `dispatch`. Es mejor calcular valores derivados **on-demand**, no guardarlos:

```tcl
namespace eval ::App::Store {
    variable estado [dict create carrito {}]

    proc dispatch {accion args} {
        variable estado
        switch $accion {
            AGREGAR_PRODUCTO {
                lassign $args producto precio
                dict lappend estado carrito [dict create producto $producto precio $precio]
            }
        }
        Notificar
    }

    # total NO se guarda, se calcula cada vez que se pide
    proc total {} {
        variable estado
        set t 0
        foreach item [dict get $estado carrito] {
            set t [expr {$t + [dict get $item precio]}]
        }
        return $t
    }
}
```
Menos estado que sincronizar = menos bugs. Solo cachea valores derivados si el cálculo es genuinamente costoso (ej. sobre miles de filas) — en ese caso, cachea el resultado y guarda también un flag `dirty` para invalidarlo, en vez de recalcular en cada `dispatch`.

---

## 9. Resumen: qué patrón usar según el tamaño de tu app

| Escenario | Patrón recomendado |
|---|---|
| Un formulario simple, 1-2 campos | `-textvariable` directo (§1) |
| Módulo con estado propio, sin necesidad de reactividad automática | `namespace` con procs (§2) |
| Necesitas que la UI reaccione sola a cambios de una variable puntual | `trace` sobre esa variable (§3) |
| Estado con varios campos relacionados, mutados por múltiples acciones de usuario | `dict` + `dispatch` centralizado, patrón Flux (§4) |
| Necesitas múltiples instancias independientes del mismo estado (varias ventanas/pestañas) | Objeto Snit/TclOO con su propio estado (§5) |
| App completa tipo ERP con varios paneles sincronizados | Store centralizado (§4) + widgets Snit "tontos" suscritos (§6) |
| Estado que debe sobrevivir reinicios / ser fuente de verdad real | SQLite como verdad, dict en memoria como caché sincronizada (§7) |

Para tu ERP/POS específicamente, si en algún momento construyes herramientas satélite en Tcl/Tk puro (paneles de diagnóstico, utilidades internas), el combo ganador es: **§4 (store con dispatch) + §6 (widgets Snit suscritos) + §7 (SQLite como fuente de verdad)**. Es exactamente el mismo flujo unidireccional de datos que usarías con Zustand/Redux + SQLite en tu stack React real — solo que implementado con las primitivas nativas de Tcl (`dict`, `trace`, namespaces) en vez de una librería externa.

---

## 10. Errores comunes de estado en Tcl/Tk

| Error | Causa / solución |
|---|---|
| La UI no se actualiza tras cambiar una variable | Falta `-textvariable`/`trace`, o cambiaste una copia local en vez de la variable con `global`/`variable`/`::` calificado |
| "invalid command name .widget" tras cerrar una ventana | Un `trace` o callback de `after` sigue vivo apuntando a un widget destruido — límpialo en el destructor |
| Loop infinito de traces | Dos variables traceadas se modifican mutuamente en sus propios handlers `write` |
| Estado inconsistente a medias (ej. `total` no cuadra con `carrito`) | Mutaciones dispersas en vez de un único punto de `dispatch`; centraliza con el patrón del §4 |
| Duplicar datos entre memoria y SQLite que se desincronizan | Prefiere "escribe en DB, relee, notifica" (§7) antes que mantener dos copias sincronizadas a mano |
