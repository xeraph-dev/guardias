# Enviar y recibir eventos en Tk

Tk tiene un sistema de eventos completo — no solo para clicks y teclas, sino como mecanismo genérico de comunicación entre widgets. Esto complementa (no reemplaza) lo que ya viste con `trace`: `trace` es para "este dato cambió", los eventos son para "esto ocurrió" — una acción puntual, no un cambio de estado persistente. Todo el código de esta guía fue verificado en un `wish` real.

---

## 1. `bind`: escuchar un evento

```tcl
button .b -text "click"
pack .b
bind .b <Button-1> {puts "click en boton, x=%x y=%y widget=%W"}
```
`bind widget secuencia script` registra un script que corre cuando ese evento ocurre sobre ese widget específico. Los `%` dentro del script son **sustituciones automáticas** de Tk con datos del evento — no variables tuyas.

### Sustituciones `%` más usadas
| Sustitución | Da |
|---|---|
| `%x` `%y` | coordenadas del mouse relativas al widget |
| `%X` `%Y` | coordenadas absolutas de pantalla |
| `%W` | el path del widget que recibió el evento |
| `%K` | nombre de la tecla presionada (eventos de teclado) |
| `%k` | keycode numérico |
| `%d` | dato custom pasado con `-data` (solo en eventos virtuales, ver §3) |

---

## 2. Eventos físicos: sintaxis de patrones

```tcl
bind .b <Button-1>              {...}    ;# click izquierdo
bind .b <Double-Button-1>       {...}    ;# doble click
bind .b <ButtonRelease-1>       {...}    ;# soltar el botón del mouse
bind .b <B1-Motion>             {...}    ;# arrastrar con botón presionado (visto en la guía de Tk avanzado)
bind .b <KeyPress-a>            {...}    ;# tecla 'a'
bind .b <Return>                {...}    ;# Enter
bind .b <Control-s>             {...}    ;# Ctrl+S
bind .b <Control-Shift-Key-A>   {...}    ;# combinación con modificadores
bind .b <Enter>                 {...}    ;# el mouse ENTRA al widget (no confundir con tecla Enter)
bind .b <Leave>                 {...}    ;# el mouse sale del widget
bind .b <FocusIn>               {...}    ;# el widget gana foco
bind .b <Configure>             {...}    ;# el widget cambia de tamaño/posición
```
Para requerir foco antes de que los eventos de teclado disparen sobre un widget, necesitas `focus -force $widget` (o que el usuario haga click primero) — confirmado en las pruebas: sin foco, `<KeyPress-a>` simplemente no dispara.

---

## 3. Eventos virtuales: tu propio vocabulario de eventos

Ya viste uno (`<<ThemeChanged>>`) en la guía de temas ttk. Puedes definir los tuyos — esto es lo más útil para comunicación entre widgets de tu app:

```tcl
event add <<GuardiaAsignada>> <Control-g>
;# ahora <<GuardiaAsignada>> se dispara TANTO con Ctrl+G como programáticamente

bind .b <<GuardiaAsignada>> {puts "evento virtual recibido"}
```

`event add <<Nombre>> <secuencia-fisica>` asocia un evento virtual con nombre a una secuencia física real (opcional) — pero lo más común en comunicación entre widgets es dispararlo **solo** programáticamente, sin ninguna tecla asociada:

```tcl
bind .b <<DiaSeleccionado>> {puts "dia seleccionado, data=%d"}
event generate .b <<DiaSeleccionado>> -data "2024-08-15" -when now
;# -> dia seleccionado, data=2024-08-15
```

### El detalle que hay que saber: `-when now`
Por defecto, `event generate` **encola** el evento para procesarse en el próximo ciclo del event loop, no lo ejecuta sincrónicamente. En la práctica esto casi siempre "funciona igual" porque el event loop lo procesa enseguida, pero si generas un evento justo antes de salir del programa, o quieres garantía de orden estricto, usa `-when now` para forzar procesamiento **inmediato**, sincrónico — confirmado en las pruebas: sin `-when now`, el evento podía perderse si el programa terminaba antes de que el event loop llegara a procesarlo.

```tcl
event generate .b <<DiaSeleccionado>> -data $fecha -when now
```

---

## 4. Pasar datos con el evento: `-data` y `%d`

Los eventos de Tk no tienen un payload arbitrario nativo (a diferencia de eventos de JS con `detail`), pero `-data` + `%d` cumplen ese rol para un solo valor:

```tcl
bind .grid <<DiaSeleccionado>> {procesarSeleccion %d}

proc procesarSeleccion {fecha} {
    puts "usuario seleccionó: $fecha"
}

event generate .grid <<DiaSeleccionado>> -data $fechaSeleccionada -when now
```
Si necesitas pasar **más de un dato**, la convención es serializar en una lista o dict como string y parsearlo del lado receptor:
```tcl
event generate .grid <<GuardiaAsignada>> -data [list $workerId $fecha] -when now
bind .grid <<GuardiaAsignada>> {lassign %d workerId fecha; procesarAsignacion $workerId $fecha}
```

---

## 5. `bindtags`: cómo se propagan los eventos hacia arriba

Cada widget tiene una lista de "bindtags" — el orden en que Tk busca bindings para ese evento. Por defecto:

```tcl
puts [bindtags .b]
;# .b Button . all
```
Esto significa: primero busca un `bind` específico sobre `.b`, luego sobre la **clase** del widget (`Button`, compartido por todos los botones), luego sobre la ventana raíz (`.`), y finalmente sobre `all` (todos los widgets de la app). Confirmado con las pruebas: un `bind Button <<EventoDeClase>> {...}` capturó el evento generado sobre `.b` sin que `.b` tuviera su propio binding — y lo mismo con `bind all`.

### Por qué esto es útil para tu app
Puedes registrar un handler **una sola vez a nivel de clase o global**, en vez de repetirlo en cada instancia de un widget. Por ejemplo, si quieres loggear cada vez que se asigna una guardia, sin importar desde qué `CalendarDay` se disparó:
```tcl
bind all <<GuardiaAsignada>> {puts "LOG: guardia asignada, data=%d"}
```

---

## 6. Eventos como comunicación entre widgets Snit (alternativa a `trace`)

Ahora la parte que más te sirve: cuándo usar eventos en vez de `trace` para que tus widgets Snit se comuniquen.

```tcl
snit::widget CalendarDay {
    hulltype ttk::frame
    option -fecha -readonly 1
    component lbl

    constructor {args} {
        $self configurelist $args
        install lbl using ttk::label $win.l -text $options(-fecha)
        pack $lbl
        bind $win <Button-1> [mymethod Clickeado]
    }

    method Clickeado {} {
        ;# no decide qué hacer, solo AVISA que ocurrió algo
        event generate $win <<DiaClickeado>> -data $options(-fecha) -when now
    }
}
```

Y quien construye `CalendarDay` decide qué hacer con el click, sin que `CalendarDay` necesite conocerlo:
```tcl
set dia [CalendarDay $win.d15 -fecha "2024-08-15"]
bind $dia <<DiaClickeado>> {abrirModalAsignacion %d}
```

### `trace` vs eventos: cuándo cada uno
| Situación | Usa |
|---|---|
| Un dato cambia y varios widgets deben reflejarlo (el mes actual) | `trace` sobre una variable |
| Algo puntual ocurrió y quien lo maneja depende del contexto (un click, "se guardó exitosamente") | Evento virtual con `event generate` |
| El widget hijo no debería saber qué hace el padre con la acción | Evento — el hijo solo `event generate`, no llama métodos del padre directamente |
| Necesitas que la reacción persista/sincronice estado a través del tiempo | `trace` — los eventos no tienen "historia", solo se disparan y se van |

La diferencia de fondo: `trace` acopla al **dato** (cualquiera que lea la variable ve el estado actual). Un evento acopla al **momento** (si nadie estaba escuchando cuando se disparó, se pierde — no hay forma de "consultar" después si el evento ya ocurrió). Para el mes del calendario, `trace` es correcto (es un estado persistente). Para "el usuario hizo click en este día", un evento es más apropiado porque es una acción discreta, no un dato que alguien consulta después.

---

## 7. Resumen de referencia rápida

| Necesitas... | Usa |
|---|---|
| Reaccionar a un click/tecla/mouse | `bind $widget <Secuencia> {script}` |
| Coordenadas del evento | `%x %y` (relativas) / `%X %Y` (absolutas) |
| Qué widget disparó el evento | `%W` |
| Definir tu propio vocabulario de eventos | `event add <<Nombre>> <secuencia-opcional>` |
| Disparar un evento programáticamente | `event generate $widget <<Nombre>> -data $valor -when now` |
| Leer el dato pasado con `-data` | `%d` dentro del script del `bind` |
| Pasar más de un dato | Serializa como lista: `-data [list $a $b]`, luego `lassign %d a b` |
| Capturar un evento sin importar el widget exacto | `bind NombreDeClase <<Evento>>` o `bind all <<Evento>>` |
| Ver el orden de propagación de un widget | `bindtags $widget` |
| Comunicar un widget hijo con su contenedor sin acoplarlos | `event generate` desde el hijo, `bind` desde quien lo usa |

---

## 8. Aplicado a tu app de guardias

Combinando con la arquitectura ya establecida: `trace` sigue siendo el mecanismo para `mesActual` (estado persistente que varios widgets leen). Pero para acciones puntuales como "usuario hizo click en un día para asignar guardia", un evento virtual es más limpio que forzar a `CalendarDay` a conocer el Controlador:

```tcl
;# CalendarDay solo avisa
method Clickeado {} {
    event generate $win <<DiaClickeado>> -data $options(-fecha) -when now
}

;# App (o quien arme la ventana) decide qué significa ese click
bind $gridWidget <<DiaClickeado>> {::App::Controller::abrirAsignacion %d}
```
Esto mantiene a `CalendarDay` completamente reutilizable — no sabe nada de "asignar guardias", solo informa que fue clickeado. El significado de esa acción vive afuera, donde corresponde.
