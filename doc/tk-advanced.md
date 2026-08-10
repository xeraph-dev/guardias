# Tk avanzado: canvas, temas ttk y dibujo personalizado

Con la sintaxis base y Snit ya cubiertos, esta guía va a las partes de Tk que usarías para pulir la apariencia de una app (temas ttk coherentes) y para casos donde los widgets estándar no alcanzan (gráficas simples, tickets, diagramas, elementos custom dibujados a mano en un `canvas`).

---

## 1. `canvas`: el lienzo de dibujo de Tk

`canvas` es una superficie donde dibujas primitivas (líneas, rectángulos, texto, imágenes) y cada una se convierte en un **objeto independiente con su propio ID**, que puedes mover, recolorear o borrar después — no es un bitmap estático, es más parecido a SVG que a un `<canvas>` de HTML5 (donde una vez que dibujas, pierdes la referencia al objeto).

```tcl
canvas .c -width 400 -height 300 -background white
pack .c

set id1 [.c create rectangle 10 10 100 80 -fill lightblue -outline black]
set id2 [.c create text 55 45 -text "Producto" -font {Arial 10}]
set id3 [.c create oval 150 10 220 80 -fill orange]
set id4 [.c create line 0 100 400 100 -fill gray -dash {4 2}]
```

### Modificar objetos existentes por ID
```tcl
.c itemconfigure $id1 -fill red        ;# cambia el color
.c coords $id1 20 20 120 90            ;# mueve/redimensiona
.c move $id1 10 0                       ;# desplaza 10px en x
.c delete $id1                          ;# borra ese objeto específico
.c delete all                            ;# borra todo el canvas
```

### Tags: agrupar y manipular varios objetos a la vez
```tcl
.c create rectangle 10 10 100 80 -fill lightblue -tags {producto seleccionable}
.c create text 55 45 -text "Arroz" -tags {producto texto}

.c itemconfigure producto -outline blue    ;# afecta TODOS los objetos con ese tag
.c bind producto <Button-1> {puts "click en un producto"}
.c move texto 5 5                            ;# mueve solo los que tienen tag "texto"
```
Los tags son la forma correcta de manejar grupos de objetos relacionados (ej. todos los elementos de una "tarjeta" dibujada a mano) sin llevar la cuenta manual de IDs individuales.

---

## 2. Eventos en canvas: hacer objetos interactivos

```tcl
canvas .c -width 300 -height 200
pack .c

set caja [.c create rectangle 50 50 150 120 -fill lightgreen -tags arrastrable]

.c bind arrastrable <Button-1> {
    set ::dragData(x) %x
    set ::dragData(y) %y
}
.c bind arrastrable <B1-Motion> {
    set dx [expr {%x - $::dragData(x)}]
    set dy [expr {%y - $::dragData(y)}]
    .c move arrastrable $dx $dy
    set ::dragData(x) %x
    set ::dragData(y) %y
}
```
Patrón estándar de "drag and drop" en canvas: capturas la posición al hacer click (`<Button-1>`), y en cada movimiento con el botón presionado (`<B1-Motion>`) calculas el delta y mueves el objeto, actualizando la posición de referencia. `%x %y` son sustituciones especiales de Tk que insertan las coordenadas del evento dentro del canvas.

### Detección de objeto bajo el cursor
```tcl
.c bind all <Motion> {
    set actual [.c find withtag current]
    if {$actual ne ""} {
        puts "sobre el objeto: [.c gettags current]"
    }
}
```
`current` es un tag especial mágico que Tk mantiene automáticamente apuntando al objeto bajo el cursor en cada momento.

---

## 3. Ejemplo práctico: dibujar un ticket/recibo

```tcl
proc dibujarTicket {canvas datos} {
    $canvas delete all
    set y 20
    $canvas create text 150 $y -text "TICKET DE VENTA" -font {Arial 14 bold} -anchor center
    incr y 30
    $canvas create line 10 $y 290 $y -fill gray
    incr y 15

    set total 0
    dict for {producto info} [dict get $datos items] {
        set precio [dict get $info precio]
        set cantidad [dict get $info cantidad]
        set subtotal [expr {$precio * $cantidad}]
        set total [expr {$total + $subtotal}]

        $canvas create text 10 $y -text "$producto x$cantidad" -anchor w -font {Arial 9}
        $canvas create text 290 $y -text [format "\$%.2f" $subtotal] -anchor e -font {Arial 9}
        incr y 20
    }

    incr y 10
    $canvas create line 10 $y 290 $y -fill gray
    incr y 20
    $canvas create text 290 $y -text [format "Total: \$%.2f" $total] -anchor e -font {Arial 11 bold}
}

canvas .ticket -width 300 -height 400 -background white
pack .ticket

dibujarTicket .ticket [dict create items [dict create \
    "Arroz"     [dict create precio 2.50 cantidad 3] \
    "Frijoles"  [dict create precio 1.80 cantidad 2]]]
```
Este patrón —función que recibe datos y "redibuja desde cero" (`delete all` + reconstruir)— es el equivalente en canvas al patrón declarativo de React: en vez de mutar objetos incrementalmente, describes el estado completo y lo vuelves a dibujar. Para canvas pequeños (tickets, diagramas simples) es más simple y menos propenso a bugs que llevar la cuenta de qué mover/cambiar incrementalmente.

---

## 4. Exportar canvas a imagen o PostScript

```tcl
.c postscript -file "ticket.ps" -width 300 -height 400
```
Tk soporta exportar el contenido de un canvas directamente a PostScript (útil para imprimir tickets/recibos en impresoras térmicas o convertir a PDF con `ps2pdf` externamente). No hay export nativo a PNG/JPEG sin ayuda externa — para eso normalmente se combina con el paquete `Img` (`package require Img`) que añade soporte de más formatos de imagen a Tk.

---

## 5. `ttk::style`: temas coherentes para toda la app

Los widgets `ttk::*` (a diferencia de los clásicos `button`, `entry`) soportan un sistema de temas robusto. Configurar el tema una vez al inicio de tu app te da consistencia visual sin repetir opciones de color en cada widget.

```tcl
package require Tk

ttk::style theme use clam    ;# temas disponibles varían por SO: clam, alt, default, classic, vista(win), aqua(mac)

# Personalizar un widget tipo específico
ttk::style configure TButton -padding 8 -font {Arial 10}
ttk::style configure TButton -background "#2563eb" -foreground white
ttk::style map TButton -background [list active "#1d4ed8" pressed "#1e40af"]

ttk::style configure TLabel -font {Arial 10}
ttk::style configure Titulo.TLabel -font {Arial 16 bold} -foreground "#1e293b"

ttk::button .b -text "Guardar" -style TButton
ttk::label .titulo -text "Panel de Inventario" -style Titulo.TLabel
pack .titulo .b -pady 10
```

- `ttk::style configure <estilo> <opciones>` cambia el aspecto de todos los widgets de ese estilo.
- `ttk::style map` define comportamiento **según estado** (`active` = mouse encima, `pressed` = presionado, `disabled`).
- Puedes crear **estilos derivados** con notación `Nombre.TWidget` (ej. `Titulo.TLabel`, `Peligro.TButton`) para variantes específicas sin afectar el estilo base — igual que crear una clase CSS modificadora.

### Listar temas disponibles en el sistema
```tcl
puts [ttk::style theme names]
```

### Tema custom completo (patrón recomendado para una app con identidad visual propia)
```tcl
proc aplicarTemaERP {} {
    ttk::style theme use clam

    ttk::style configure . -font {Arial 10} -background "#f8fafc"
    ttk::style configure TButton -padding {12 6} -relief flat
    ttk::style configure TButton -background "#2563eb" -foreground white
    ttk::style map TButton -background [list active "#1d4ed8"]

    ttk::style configure Peligro.TButton -background "#dc2626"
    ttk::style map Peligro.TButton -background [list active "#b91c1c"]

    ttk::style configure Treeview -rowheight 28 -font {Arial 10}
    ttk::style configure Treeview.Heading -font {Arial 10 bold} -background "#e2e8f0"

    ttk::style configure TEntry -padding 6
}
aplicarTemaERP
```
`ttk::style configure .` (el punto como nombre de "widget") aplica a nivel global — es tu reset/base similar a estilos globales de CSS.

---

## 6. Layouts custom de widgets ttk (control más fino que solo colores)

Para casos donde `configure`/`map` no alcanza (ej. quitar el borde de un widget, reorganizar sus sub-elementos internos), `ttk::style layout` te permite redefinir la estructura interna del widget:

```tcl
ttk::style layout Plano.TButton {
    Button.padding -children {
        Button.label
    }
}
;# elimina el elemento "Button.border" del layout por defecto, dando un botón sin relieve
```
Esto es avanzado y poco común en la práctica diaria — solo lo necesitas si buscas una apariencia muy específica que los estados/colores no logran (ej. un botón que parece un link de texto).

---

## 7. Iconos e imágenes

```tcl
image create photo iconoGuardar -file "guardar.png"
ttk::button .b -image iconoGuardar -command guardar

# Combinando texto e icono
ttk::button .b2 -image iconoGuardar -text "Guardar" -compound left

# Redimensionar (Tk 8.6+ soporta zoom/subsample nativos para PNG)
image create photo iconoGrande -file "logo.png"
image create photo iconoChico
iconoChico copy iconoGrande -subsample 2 2    ;# reduce a la mitad
```
`photo` es el tipo de imagen nativo de Tk. Soporta PNG, GIF, PPM/PGM nativamente desde Tk 8.6; para JPEG y formatos adicionales necesitas `package require Img`.

---

## 8. `scrolledframe` / scroll en contenedores complejos

Tk no tiene un contenedor "scrollable" genérico nativo (a diferencia de un `<div overflow: scroll>` en CSS) — para scrollear un frame con muchos widgets dentro (ej. una lista larga de productos con controles), el patrón estándar es un `canvas` + `frame` embebido + `scrollbar`:

```tcl
canvas .c -yscrollcommand {.sb set}
ttk::scrollbar .sb -orient vertical -command {.c yview}
pack .sb -side right -fill y
pack .c -side left -fill both -expand 1

set contenedor [ttk::frame .c.inner]
.c create window 0 0 -window $contenedor -anchor nw

# Llenar el contenedor con muchos widgets...
for {set i 0} {$i < 50} {incr i} {
    ttk::label $contenedor.l$i -text "Producto $i"
    pack $contenedor.l$i -fill x -pady 2
}

# Actualizar la región de scroll después de agregar contenido
update idletasks
.c configure -scrollregion [.c bbox all]
```
Este patrón —canvas como "viewport" + frame interno como contenido real, con `scrollregion` recalculado tras cambios— es el mecanismo estándar para listas largas scrolleables en Tk puro. Si esto se vuelve recurrente en tu app, vale la pena envolverlo en un `snit::widget scrolledframe` reutilizable una sola vez.

---

## 9. Redimensionamiento responsivo (`grid` weights)

Ya viste `grid columnconfigure ... -weight` en la guía básica — aquí el patrón completo para una ventana que se adapta bien al redimensionar (relevante si tu app corre en distintos tamaños de pantalla):

```tcl
grid .header -row 0 -column 0 -sticky ew
grid .contenido -row 1 -column 0 -sticky nsew
grid .footer -row 2 -column 0 -sticky ew

grid rowconfigure . 1 -weight 1        ;# la fila del contenido crece, header/footer no
grid columnconfigure . 0 -weight 1

# Dentro de .contenido, si tiene su propio grid interno:
grid columnconfigure .contenido 0 -weight 1
grid columnconfigure .contenido 1 -weight 2   ;# esta columna crece el doble que la 0
```
`-sticky nsew` hace que el widget se estire en las 4 direcciones dentro de su celda; sin `-weight` en la fila/columna correspondiente, el espacio extra al redimensionar la ventana simplemente queda vacío en vez de repartirse.

---

## 10. Resumen de referencia rápida

| Necesitas... | Usa |
|---|---|
| Dibujar formas/texto libremente | `canvas create rectangle/oval/text/line/...` |
| Modificar un objeto ya dibujado | `.c itemconfigure $id -opcion valor`, `.c coords`, `.c move` |
| Agrupar objetos relacionados | tags: `-tags {grupo}`, luego `.c itemconfigure grupo ...` |
| Drag and drop en canvas | `bind <Button-1>` + `bind <B1-Motion>` con delta de coordenadas |
| Exportar canvas a impresión | `.c postscript -file archivo.ps` |
| Tema consistente en toda la app | `ttk::style configure`/`map` sobre estilos base (`TButton`, `TLabel`...) |
| Variante de un widget (ej. botón de peligro) | estilo derivado: `Nombre.TWidget` |
| Reestructurar layout interno de un widget | `ttk::style layout` (avanzado, poco común) |
| Iconos en botones | `image create photo` + `-image`/`-compound` |
| Contenedor scrolleable con muchos widgets | `canvas` + `frame` embebido + `scrollbar`, recalculando `-scrollregion` |
| Ventana que se adapta al redimensionar | `grid rowconfigure`/`columnconfigure -weight` + `-sticky nsew` |

---

## 11. Dónde esto te sirve directamente

Para tu ERP/POS: el patrón de canvas del §3 es exactamente cómo generarías una vista previa de ticket antes de imprimir (o el diseño para exportar a impresora térmica vía PostScript/imagen). El sistema de temas del §5 es lo primero que aplicarías si construyes cualquier herramienta Tk que deba verse coherente con la identidad visual de tu marca, en vez del look gris por defecto de Tk sin configurar. Y el patrón scrolleable del §8 es necesario en cuanto tengas una lista de productos/clientes que exceda el alto de la ventana — algo casi garantizado en un catálogo real de comercio local.
