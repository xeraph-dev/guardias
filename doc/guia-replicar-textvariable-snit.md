# Replicar `-textvariable` en tus propios widgets Snit

`-textvariable` es el mecanismo nativo de Tk para vincular el contenido de un widget a una variable externa: la variable manda, el widget se sincroniza solo (vía `trace`, como ya viste), y en widgets editables (como `entry`) también funciona al revés — si el usuario escribe, la variable se actualiza. Replicar esto correctamente en un widget Snit propio requiere resolver 4 problemas concretos que no son obvios a la primera. Todo el código de esta guía fue probado en un `wish` real.

---

## 1. El contrato completo de `-textvariable` (lo que hay que replicar)

Antes de escribir código, hay que tener claro qué hace exactamente Tk con `-textvariable`:

1. **Si no le pasas ninguna variable**, el widget usa una variable interna privada — sigue funcionando igual.
2. **Si la variable ya tenía un valor** cuando se la vinculas, el widget **adopta ese valor** inmediatamente (no lo pisa con vacío).
3. **Cambios en la variable → el widget se actualiza** (sincronización variable→widget).
4. **Cambios desde el widget (ej. el usuario escribe) → la variable se actualiza** (sincronización widget→variable), solo en widgets editables.
5. **Puedes cambiar qué variable está vinculada después de creado el widget** (`.entry configure -textvariable otra`), y el widget deja de escuchar la anterior.
6. **Al destruir el widget**, el trace se limpia — no debe quedar un trace fantasma apuntando a un widget que ya no existe.

El problema #4 es el que introduce el riesgo real: si el widget escribe en la variable, y el widget también escucha esa variable con `trace`, tienes un loop potencial (variable cambia → widget se actualiza → widget escribe en la variable → dispara el trace de nuevo → ...). Hay que cortarlo explícitamente.

---

## 2. Versión simple: solo lectura (como un `label -textvariable`)

Si tu widget solo *muestra* el valor y nunca lo modifica desde dentro (como un `label`), no hay riesgo de loop — solo necesitas sincronización en una dirección.

```tcl
snit::widget etiquetaSync {
    hulltype ttk::frame
    option -textvariable -default "" -configuremethod ConfigurarVar

    component lbl
    variable valorPrivado ""

    constructor {args} {
        install lbl using ttk::label $win.l -textvariable [myvar valorPrivado]
        pack $lbl
        $self configurelist $args
        if {$options(-textvariable) eq ""} {
            $self configure -textvariable [myvar valorPrivado]
        }
    }

    destructor {
        if {$options(-textvariable) ne "" && $options(-textvariable) ne [myvar valorPrivado]} {
            catch {trace remove variable $options(-textvariable) write [mymethod Sincronizar]}
        }
    }

    method ConfigurarVar {opcion nuevaVar} {
        if {$options(-textvariable) ne "" && $options(-textvariable) ne [myvar valorPrivado]} {
            catch {trace remove variable $options(-textvariable) write [mymethod Sincronizar]}
        }
        set options($opcion) $nuevaVar
        if {$nuevaVar ne [myvar valorPrivado]} {
            if {[uplevel #0 [list info exists $nuevaVar]]} {
                set valorPrivado [uplevel #0 [list set $nuevaVar]]
            } else {
                uplevel #0 [list set $nuevaVar $valorPrivado]
            }
            trace add variable $nuevaVar write [mymethod Sincronizar]
        }
    }

    method Sincronizar {args} {
        set valorPrivado [uplevel #0 [list set $options(-textvariable)]]
    }
}
```

Puntos clave de esta versión:

- **`[myvar valorPrivado]`** (guía de Snit) es el nombre completo de la variable interna — se usa como "variable por defecto" cuando no te pasan `-textvariable`, replicando el punto #1 del contrato.
- **`uplevel #0 [list set $nuevaVar]`** lee/escribe la variable externa en el **scope global**, sin importar desde qué profundidad de proc se llama — necesario porque el nombre de variable puede ser relativo o global, y quieres el mismo comportamiento consistente de Tk (que siempre resuelve `-textvariable` contra el scope global/namespace calificado).
- **Adopción del valor existente** (punto #2): `if {[info exists $nuevaVar]} { adoptar } else { inicializar }` — exactamente lo que se verificó en las pruebas.

---

## 3. Versión bidireccional: el widget también escribe (como un `entry`)

Aquí se agrega el problema real: cuando el widget cambia su valor internamente (ej. el usuario hace click en un botón "+1" de un contador), ese cambio debe propagarse a la variable externa — pero sin que el trace de esa misma variable dispare una actualización redundante (o, peor, un loop si hubiera lógica adicional en el trace).

```tcl
snit::widget contadorSync {
    hulltype ttk::frame
    option -textvariable -default "" -configuremethod ConfigurarVar

    component lbl
    component btn
    variable valorPrivado 0
    variable actualizandoDesdeTrace 0   ;# bandera anti-loop

    constructor {args} {
        install lbl using ttk::label $win.l -textvariable [myvar valorPrivado]
        install btn using ttk::button $win.b -text "+1" -command [mymethod Incrementar]
        pack $lbl $btn -side left
        $self configurelist $args
        if {$options(-textvariable) eq ""} {
            $self configure -textvariable [myvar valorPrivado]
        }
    }

    destructor {
        if {$options(-textvariable) ne "" && $options(-textvariable) ne [myvar valorPrivado]} {
            catch {trace remove variable $options(-textvariable) write [mymethod SincronizarDesdeFuera]}
        }
    }

    method ConfigurarVar {opcion nuevaVar} {
        if {$options(-textvariable) ne "" && $options(-textvariable) ne [myvar valorPrivado]} {
            catch {trace remove variable $options(-textvariable) write [mymethod SincronizarDesdeFuera]}
        }
        set options($opcion) $nuevaVar
        if {$nuevaVar ne [myvar valorPrivado]} {
            if {[uplevel #0 [list info exists $nuevaVar]]} {
                set valorPrivado [uplevel #0 [list set $nuevaVar]]
            } else {
                uplevel #0 [list set $nuevaVar $valorPrivado]
            }
            trace add variable $nuevaVar write [mymethod SincronizarDesdeFuera]
        }
    }

    # variable externa cambió -> reflejarlo internamente
    method SincronizarDesdeFuera {args} {
        if {$actualizandoDesdeTrace} { return }
        set actualizandoDesdeTrace 1
        set valorPrivado [uplevel #0 [list set $options(-textvariable)]]
        set actualizandoDesdeTrace 0
    }

    # el widget cambió internamente -> propagar a la variable externa
    method Incrementar {} {
        incr valorPrivado
        if {$options(-textvariable) ne "" && $options(-textvariable) ne [myvar valorPrivado]} {
            set actualizandoDesdeTrace 1
            uplevel #0 [list set $options(-textvariable) $valorPrivado]
            set actualizandoDesdeTrace 0
        }
    }
}
```

### La bandera `actualizandoDesdeTrace`: por qué es necesaria
Sin ella, esto pasaría: `Incrementar` escribe en la variable externa → dispara `SincronizarDesdeFuera` (porque el trace está activo) → que vuelve a leer y reescribir `valorPrivado` — funcionalmente inofensivo en este caso simple, pero si `SincronizarDesdeFuera` tuviera lógica adicional (validación, side-effects), se ejecutaría dos veces por cada cambio real, una desde `Incrementar` directamente y otra desde el trace disparado por el propio `Incrementar`. La bandera asegura que cuando **el widget mismo** origina el cambio, no se reprocese como si viniera de afuera.

### Prueba real de este comportamiento
```tcl
namespace eval ::App { variable contadorExterno 100 }
contadorSync .c -textvariable ::App::contadorExterno

puts $::App::contadorExterno        ;# 100 -> adoptó el valor inicial (punto #2 del contrato)
.c Incrementar
.c Incrementar
puts $::App::contadorExterno        ;# 102 -> el widget propagó los cambios hacia afuera

set ::App::contadorExterno 999
update
puts [.c.l cget -text]               ;# 999 -> el widget se sincronizó desde afuera
```
Esta secuencia exacta se corrió y confirmó: `100` → `102` → `999`, validando adopción inicial, propagación widget→variable, y sincronización variable→widget, sin loops ni desincronización.

---

## 4. Alternativa más simple si NO necesitas bidireccionalidad

Si tu widget **nunca** modifica el valor desde dentro (solo lo muestra, como un indicador de estado), sáltate por completo la bandera anti-loop y el método `Incrementar`-equivalente — usa directamente la versión de solo lectura del §2. No agregues la maquinaria bidireccional "por si acaso"; es complejidad que no necesitas si tu widget es puramente un display.

---

## 5. Simplificación: si tu widget interno YA usa `-textvariable` nativo

Un truco que evita reescribir toda la lógica de trace a mano: si tu widget compuesto internamente ya envuelve un widget Tk nativo que soporta `-textvariable` (como `entry` o `label`), puedes **delegar directamente** a esa opción nativa en vez de reimplementar la sincronización tú mismo:

```tcl
snit::widget campoConEtiqueta {
    hulltype ttk::frame
    component entry
    delegate option -textvariable to entry

    constructor {args} {
        install entry using ttk::entry $win.e
        pack $entry
        $self configurelist $args
    }
}
```
Aquí no escribiste ningún `trace` manual — `delegate option -textvariable to entry` reenvía la configuración directamente al `entry` nativo, que ya implementa el contrato completo de `-textvariable` (bidireccional, con adopción de valor, etc.) internamente en C. **Esta es la opción preferida siempre que sea posible** — solo necesitas reimplementar el patrón de los §2-3 cuando tu widget **no** envuelve un widget nativo compatible, sino que maneja su propio estado interno de otra forma (como el contador del §3, cuyo "valor" no vive dentro de ningún `entry`/`label` nativo directamente vinculable).

---

## 6. Resumen de referencia rápida

| Situación | Solución |
|---|---|
| Tu widget envuelve un `entry`/`label` nativo y quieres pasar `-textvariable` tal cual | `delegate option -textvariable to componenteInterno` (§5) — no reimplementes nada |
| Tu widget muestra un valor propio, nunca lo modifica desde dentro | Versión de solo lectura (§2): trace variable→widget únicamente |
| Tu widget modifica su valor internamente Y debe reflejarlo en una variable externa | Versión bidireccional (§3), con bandera anti-loop |
| Necesitas adoptar el valor existente de la variable al vincularla | `info exists $var` antes de decidir si adoptar o inicializar |
| Necesitas que funcione sin pasar `-textvariable` | Usa `[myvar variablePrivada]` como valor por defecto en el constructor |
| Necesitas permitir cambiar la variable vinculada después de crear el widget | `-configuremethod` que quita el trace viejo y agrega el nuevo |
| Necesitas evitar traces fantasma tras destruir el widget | `trace remove` en el `destructor`, con `catch` por si la variable ya no existe |

---

## 7. Nota de diseño: prefiere composición sobre reimplementación

Si te encuentras reimplementando el patrón bidireccional del §3 muy seguido en distintos widgets de tu app, es señal de que probablemente puedas resolverlo envolviendo un `entry` (aunque sea oculto/sin mostrar, `wm withdraw` o simplemente sin empacar visualmente) y delegando `-textvariable` a él (§5) — dejar que Tk haga el trabajo pesado de sincronización bidireccional que ya probó durante décadas, en vez de mantener tu propia implementación con trace manual en cada widget nuevo que construyas.
