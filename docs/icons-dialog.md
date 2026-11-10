# Íconos

## Estructura de archivos

```
res/
  icons/
    arrow-up.svg
    arrow-up_disabled.svg
    plus.svg
    plus_disabled.svg
    ...
    LICENSE-lucide.txt
```

`build.tcl` ya copia `res` completo al zipfs, así que no hay que cambiarlo.

## Cargar un SVG

Tk 9 soporta SVG de forma nativa:

```tcl
image create photo icon_up_16 -file res/icons/arrow-up.svg -format {svg -scaletoheight 16}
```

`-scaletoheight` fija el alto en píxeles y conserva la proporción.

## Helper con caché

Crea `src/icons.tcl` y haz `source` en `main.tcl` antes de `App.tcl`:

```tcl
proc icon {name {size 20}} {
    set id icon_${name}_$size
    if {$id ni [image names]} {
        image create photo $id -file res/icons/$name.svg -format [list svg -scaletoheight $size]
    }
    return $id
}

# Imagen normal + imagen para el estado disabled
proc icon_states {name {size 20}} {
    return [list [icon $name $size] disabled [icon ${name}_disabled $size]]
}
```

**Ojo con un choque de nombres:** en tu `main.tcl` existe `image create photo icon -file res/icon.png`. Una imagen crea un comando con su nombre, así que chocaría con el proc `icon`. Renombra la imagen a `app_icon` y usa `wm iconphoto . app_icon`.

## Usarlos

```tcl
# solo icono, con versión gris al deshabilitar
ttk::button $win.up -image [icon_states arrow-up] -command [mymethod Up]

# icono + texto
ttk::button $win.add -text agregar -image [icon plus] -compound left

# pestaña de notebook
$panel_tabs add $workers_tab -text Plantilla -image [icon user] -compound left

# fila de treeview
$tree insert {} end -id $id -text $name -image [icon user 16]
```

Con la lista de estados, el widget cambia la imagen solo cuando haces `configure -state disabled`, así que no hay que tocar tus métodos `Refresh`.

`-compound` define dónde va el icono respecto al texto: `left`, `right`, `top`, `bottom` o `image` (solo icono).

## Detalles a tener en cuenta

- **Color:** reemplaza `currentColor` por un color fijo en los SVG (por ejemplo `#333333`), y genera las versiones `_disabled` con `#aaaaaa`.
- **Tamaño:** los iconos de Lucide están pensados para 24 px con trazo de 2 px. A 16 px el trazo se ve fino y borroso. Prueba con 20 o 24 en botones.
- **SVG sin texto:** el soporte de Tk cubre formas y trazos básicos, pero no texto.
- **Licencia:** conserva el `LICENSE` de Lucide dentro de `res/icons/`.
- **Caché:** las imágenes se referencian por nombre. El helper las deja creadas, no necesitas guardarlas en variables.
