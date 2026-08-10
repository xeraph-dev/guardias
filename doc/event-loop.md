# Event loop, coroutines y concurrencia en Tcl

Tcl es de un solo hilo por intérprete, pero tiene un modelo de concurrencia cooperativa muy potente basado en el event loop — el mismo mecanismo que hace funcionar Tk. Entender esto a fondo es lo que te permite escribir servidores, GUIs responsivas, y código asíncrono sin bloquear, todo sin threads reales (aunque Tcl también soporta threads reales si los necesitas, ver §6).

---

## 1. El event loop: qué es realmente

Cuando corres `wish` o llamas `vwait`, Tcl entra en un bucle que:
1. Revisa si hay eventos pendientes (I/O de sockets/archivos, timers `after`, eventos de ventana Tk, eventos idle).
2. Ejecuta el/los callback(s) asociados al primer evento listo.
3. Vuelve al paso 1.

**Nada corre en paralelo real** — cada callback corre hasta completarse antes de que el siguiente empiece (como el event loop de Node.js/JS en el navegador). Por eso un callback que tarda mucho (ej. un cálculo pesado en un `for`) congela toda tu GUI: no hay quien más procese eventos mientras ese callback no termine.

```tcl
button .b -text "Congelar 3 segundos" -command {
    after 3000    ;# BLOQUEA todo el event loop, la ventana se congela
    puts "listo"
}
```
Esto es el error #1 de rendimiento percibido en apps Tk: cualquier operación larga (I/O de red sin async, cálculo pesado, `exec` sincrónico) bloquea la interfaz completa.

---

## 2. `vwait`: entrar al event loop manualmente

Fuera de Tk (en un script Tcl puro, ej. un servidor), no hay loop automático — tú decides cuándo entrar:

```tcl
set corriendo 1
proc detener {} {
    set ::corriendo 0
}
vwait corriendo    ;# bloquea aquí, procesando eventos, hasta que $corriendo cambie
puts "servidor detenido"
```
`vwait variable` es el mecanismo estándar para "mantener vivo" un script que solo reacciona a eventos (sockets, timers) — es tu equivalente a `select{}` en Go para bloquear el main goroutine, o a un `app.listen()` sin nada después en Node.

Patrón típico de servidor:
```tcl
socket -server aceptarConexion 8080
proc aceptarConexion {canal addr puerto} {
    fconfigure $canal -buffering line
    fileevent $canal readable [list procesarLinea $canal]
}
proc procesarLinea {canal} {
    if {[eof $canal]} {
        close $canal
        return
    }
    gets $canal linea
    puts $canal "eco: $linea"
    flush $canal
}
vwait forever    ;# "forever" nunca se define, así que espera indefinidamente
```

---

## 3. `after`: timers, sin bloquear

```tcl
after 1000 {puts "1 segundo después"}                 ;# ejecuta una vez, no bloquea
set id [after 5000 miProc]                              ;# guarda el ID para poder cancelarlo
after cancel $id                                          ;# lo cancela antes de que dispare

# Timer repetitivo (patrón: la proc se re-agenda a sí misma)
proc tick {} {
    puts "tick [clock seconds]"
    after 1000 tick
}
tick
```
`after ms script` **no bloquea**: agenda el script para el futuro y retorna inmediatamente, dejando el event loop libre. Es el `setTimeout` de Tcl. La versión bloqueante (`after ms` sin script) sí detiene todo — solo úsala para pausas cortas fuera de contexto de GUI, o para simular delays en tests.

`after idle script` agenda para cuando el event loop esté libre (sin eventos pendientes) — útil para diferir actualizaciones de UI costosas hasta que el usuario deje de teclear, por ejemplo.

---

## 4. `fileevent`: I/O asíncrono real

Esto es la base de todo el networking no bloqueante en Tcl. En vez de `read`/`gets` bloqueante, registras un callback que se dispara cuando el canal tiene datos listos:

```tcl
set sock [socket -async servidor.example.com 80]
fconfigure $sock -blocking 0 -buffering line

fileevent $sock writable {
    fileevent $sock writable {}   ;# se dispara una vez al conectar, la desactivamos
    puts $sock "GET / HTTP/1.0\r\n\r\n"
    flush $sock
    fileevent $sock readable {leerRespuesta $sock}
}

proc leerRespuesta {sock} {
    if {[eof $sock]} {
        close $sock
        return
    }
    gets $sock linea
    puts "recibido: $linea"
}

vwait forever
```
`-async` en `socket` hace que la conexión misma no bloquee (se completa en background, notificada vía `fileevent writable`). Esto es exactamente el patrón que usarías con callbacks en Node antes de que existieran promises — Tcl no tiene `async/await` nativo salvo que uses coroutines (§5), que le dan justo esa cara.

---

## 5. Coroutines: async/await sin sintaxis especial

Desde Tcl 8.6, `coroutine` te permite escribir código que **parece secuencial y bloqueante**, pero que en realidad cede el control al event loop en los puntos que tú marques con `yield`. Es el mecanismo más elegante de Tcl para evitar el "callback hell" del §4.

```tcl
proc esperarDatos {canal} {
    # yield hasta que el canal tenga datos, sin bloquear el event loop
    fileevent $canal readable [info coroutine]
    yield
    fileevent $canal readable {}
    gets $canal linea
    return $linea
}

proc manejarCliente {canal} {
    fconfigure $canal -blocking 0 -buffering line
    while {![eof $canal]} {
        set linea [esperarDatos $canal]
        puts $canal "eco: $linea"
        flush $canal
    }
    close $canal
}

socket -server {apply {{canal addr puerto} {
    coroutine cliente_$canal manejarCliente $canal
}}} 8080

vwait forever
```

Cómo funciona `[info coroutine]` + `yield`:
- `[info coroutine]` devuelve el nombre del comando de la coroutine actual — se lo pasas a `fileevent` como callback.
- `yield` suspende la ejecución de la coroutine ahí mismo, devolviendo el control al event loop.
- Cuando el evento (dato disponible en el canal) ocurre, Tcl **reanuda la coroutine exactamente donde quedó** — como si `yield` hubiera retornado.

El resultado: `manejarCliente` está escrito como un loop secuencial normal (`while {![eof $canal]} {...}`), pero nunca bloquea el proceso — cada `esperarDatos` cede el control mientras espera. Esto es **async/await implementado a mano con primitivas de más bajo nivel**, y una vez que interiorizas el patrón, puedes envolverlo en un helper reutilizable:

```tcl
proc await {canal} {
    fileevent $canal readable [info coroutine]
    yield
    fileevent $canal readable {}
}
```

### Coroutines como generadores (fuera del contexto de I/O)
```tcl
proc contador {max} {
    for {set i 1} {$i <= $max} {incr i} {
        yield $i
    }
    return "fin"
}

coroutine c1 contador 5
puts [c1]   ;# 1
puts [c1]   ;# 2
puts [c1]   ;# 3
```
Cada llamada a `c1` reanuda la coroutine desde el último `yield`, exactamente como un generador de Python (`yield` allí) o un iterador de Go implementado con goroutines+channels.

---

## 6. Threads reales (`Thread` package)

Cuando necesitas paralelismo genuino (uso real de múltiples cores, no solo I/O no bloqueante), Tcl soporta threads del sistema operativo vía el paquete `Thread` — cada thread tiene su **propio intérprete Tcl completo**, sin memoria compartida por defecto (a diferencia de threads en C/Go). La comunicación es por paso de mensajes, similar a channels de Go o actors.

```tcl
package require Thread

set tid [thread::create {
    proc procesarPesado {n} {
        set total 0
        for {set i 0} {$i < $n} {incr i} { incr total $i }
        return $total
    }
    thread::wait    ;# mantiene el thread vivo esperando comandos
}]

# Enviar trabajo al thread y esperar resultado (bloqueante)
set resultado [thread::send $tid {procesarPesado 10000000}]
puts $resultado

# Enviar trabajo sin esperar respuesta (fire and forget)
thread::send -async $tid {puts "trabajo en background"}

thread::release $tid
```
`thread::send` es sincrónico por defecto (bloquea tu hilo llamador hasta que el otro termine y devuelve el resultado); `-async` lo hace fire-and-forget. Cada thread NO comparte variables Tcl con el principal — debes pasar datos explícitamente como argumentos del comando enviado, o usar `tsv` (thread shared variables) del mismo paquete para estado compartido controlado:

```tcl
package require Thread
tsv::set contador valor 0
tsv::incr contador valor
puts [tsv::get contador valor]
```

**Cuándo usar threads reales vs coroutines:** coroutines resuelven "no bloquear mientras espero I/O" (la mayoría de tus casos: sockets, timers, UI). Threads resuelven "necesito usar más de un core de CPU para un cálculo pesado" — mucho menos común en una app típica de escritorio/POS, pero relevante si algún día procesas reportes grandes o haces cálculos batch pesados en Tcl.

---

## 7. Integrando el event loop con Tk (GUI responsiva)

El patrón más común en apps reales: una operación potencialmente lenta (llamada a tu backend Go, consulta SQLite grande) NO debe correr sincrónicamente dentro de un `-command` de botón, porque congela la ventana. Usa coroutine + `after`/`fileevent` para cederle tiempo al event loop:

```tcl
package require Tk

proc procesarVentaAsync {} {
    .btn configure -state disabled -text "Procesando..."
    coroutine procesarCoro procesarVentaImpl
}

proc procesarVentaImpl {} {
    # simula trabajo por partes, cediendo control entre cada parte
    for {set i 0} {$i < 5} {incr i} {
        after 200 [info coroutine]
        yield
        .lblProgreso configure -text "Paso $i de 5"
        update idletasks    ;# fuerza repintado inmediato de la UI
    }
    .btn configure -state normal -text "Vender"
    .lblProgreso configure -text "¡Listo!"
}

button .btn -text "Vender" -command procesarVentaAsync
label .lblProgreso -text ""
pack .btn .lblProgreso

vwait forever
```
`update idletasks` fuerza que Tk repinte inmediatamente los widgets pendientes de actualizar, sin procesar eventos de usuario adicionales (a diferencia de `update` a secas, que procesa todo, incluyendo más clicks — generalmente evita `update` completo dentro de callbacks porque puede causar reentrancia rara).

---

## 8. `update` vs `update idletasks`: la trampa clásica

```tcl
update            ;# procesa TODOS los eventos pendientes, incluyendo clicks nuevos
update idletasks  ;# solo repinta la UI, no procesa eventos de input nuevos
```
`update` sin argumentos es tentador para "forzar que la UI se refresque ya" dentro de un loop largo, pero tiene un problema serio: si el usuario hace click en un botón mientras tu loop sigue corriendo, ese click se procesa **inmediatamente**, en medio de tu loop — puede causar reentrancia (el mismo handler corriendo dos veces superpuesto) y bugs muy difíciles de reproducir. Prefiere `update idletasks` para solo repintar, o mejor aún, usa coroutines (§5/§7) para ceder el control de forma controlada.

---

## 9. Patrón: debounce (típico en buscadores tipo el `buscadorProducto` de la guía de Snit)

```tcl
variable debounceId ""

proc onTecla {} {
    variable debounceId
    if {$debounceId ne ""} {
        after cancel $debounceId
    }
    set debounceId [after 300 ejecutarBusqueda]
}

proc ejecutarBusqueda {} {
    puts "buscando: [.entry get]"
}

entry .entry
bind .entry <KeyRelease> onTecla
pack .entry
```
Cancela el timer anterior cada vez que el usuario teclea de nuevo, y solo dispara la búsqueda real 300ms después del último carácter — evita golpear tu backend/SQLite en cada tecla. Este patrón es idéntico al debounce que ya conoces de React (`useDebounce` / `lodash.debounce`), implementado aquí con `after`/`after cancel`.

---

## 10. Errores dentro de callbacks asíncronos

Un detalle importante: si un callback de `after`, `fileevent`, o `-command` lanza un error, **no se propaga a donde lo llamaste** (porque no hay "donde lo llamaste" — lo disparó el event loop). Por defecto, Tcl imprime el error a stderr vía `bgerror` y sigue corriendo. Puedes capturarlo globalmente:

```tcl
proc bgerror {mensaje} {
    puts stderr "ERROR NO CAPTURADO: $mensaje"
    # aquí podrías loggear a archivo, mostrar un tk_messageBox, etc.
}
```
Redefinir `bgerror` es el equivalente a un handler global de "uncaught exception" — muy recomendable en producción para que errores en callbacks async no desaparezcan silenciosamente ni tumben tu app sin dejar rastro.

---

## 11. Resumen: qué mecanismo usar según el problema

| Necesitas... | Usa |
|---|---|
| Ejecutar algo una vez, en el futuro, sin bloquear | `after ms script` |
| Ejecutar algo repetidamente | `after ms script` que se re-agenda a sí mismo |
| Esperar a que I/O esté listo sin bloquear | `fileevent canal readable/writable callback` |
| Código async que se lee como código secuencial | `coroutine` + `yield` |
| Mantener el proceso vivo esperando eventos | `vwait variable` (o `vwait forever`) |
| Repintar la UI durante un loop largo | `update idletasks` (evita `update` a secas) |
| Paralelismo real multi-core | `package require Thread` |
| Evitar disparar una acción en cada tecla/evento | debounce con `after` + `after cancel` |
| Capturar errores de callbacks async | redefinir `bgerror` |

---

## 12. Dónde esto te sirve directamente

Si construyes cualquier herramienta Tcl/Tk que hable con tu backend Go (vía socket local o HTTP), **nunca** hagas esa llamada de forma sincrónica dentro de un `-command` — usa el patrón del §7 (coroutine + `after`/`fileevent`) para que la ventana no se congele mientras esperas respuesta. Y si construyes algún daemon/utilidad de servidor en Tcl puro (poco probable dado tu stack, pero posible para scripts de diagnóstico), el patrón del §2+§4 (socket server + fileevent, o coroutines para simplificar el código) es exactamente cómo Tcl maneja miles de conexiones concurrentes sin threads, con el mismo modelo mental que ya conoces de Node.js.
