# Snit: creación de widgets (megawidgets) en Tcl/Tk

Snit es el framework de programación orientada a objetos **puro Tcl** (no requiere compilar C) creado por William Duquette, y es el estándar de facto para construir **megawidgets**: widgets compuestos que combinan varios widgets nativos de Tk detrás de una interfaz limpia. Piensa en él como el equivalente Tcl de crear un componente de React que envuelve varios elementos HTML — encapsulas la complejidad interna y expones una API propia con sus `-props` (options) y métodos.

Requiere `package require snit` (viene incluido en la mayoría de instalaciones Tcl modernas vía tcllib).

---

## 0. El problema que resuelve

Sin Snit, crear un widget compuesto en Tk puro significa manejar tú mismo con procs sueltas y arrays globales el estado, la configuración, y la limpieza. Snit te da:

- Un modelo de **clases con estado encapsulado** (variables de instancia reales, no arrays globales).
- **Opciones** (`-texto`, `-color`, etc.) con getters/setters automáticos y validación.
- **Delegación**: reenviar opciones/métodos a un widget interno sin escribir código repetitivo.
- Ciclo de vida correcto: cada instancia de widget es también un comando Tcl que puedes destruir con `.miwidget destroy`.

Snit tiene dos "sabores" principales:

| Tipo | Uso |
|---|---|
| `snit::type` | Objetos normales, sin GUI (lógica de negocio, modelos) |
| `snit::widget` | Widgets nuevos que envuelven un frame Tk (megawidgets) |
| `snit::widgetadaptor` | Modifica/extiende un widget Tk **existente** (herencia de widgets) |

Este tutorial se enfoca en `snit::widget`, con una sección final sobre `snit::widgetadaptor` y `snit::type`.

---

## 1. Tu primer megawidget

```tcl
package require Tk
package require snit

snit::widget saludo {
    constructor {args} {
        install lbl using label $win.lbl -text "¡Hola!"
        pack $lbl -padx 10 -pady 10
    }
}

saludo .s
pack .s
```

Puntos clave que ya cambian tu forma de pensar sobre Tk:

- `snit::widget saludo` define una **clase** llamada `saludo`. Cada instancia (`saludo .s`) crea un widget nuevo en el path `.s`.
- Dentro del constructor, `$win` es una variable especial: el **path del propio widget** (equivalente a `.s`). Todo lo que agregues dentro debe colgar de `$win` (ej. `$win.lbl`), porque Snit automáticamente crea un `hull` (un frame contenedor) en ese path.
- `install lbl using label $win.lbl ...` crea un widget hijo y lo registra como **componente** llamado `lbl`, accesible luego como `$lbl` dentro de cualquier método.

Al final, `.s` se comporta como cualquier widget Tk: lo empacas con `pack`, lo puedes `destroy`, etc.

---

## 2. El `hull`: qué es y por qué importa

Por defecto, `snit::widget` crea automáticamente un `ttk::frame` (o `frame` clásico) como contenedor raíz de tu widget, llamado el **hull**. Es lo que se sienta en `$win`.

```tcl
snit::widget contador {
    hulltype ttk::frame       ;# opcional: elegir frame vs ttk::frame vs toplevel
    variable valor 0

    constructor {args} {
        install lbl using ttk::label $win.lbl -textvariable [myvar valor]
        install btnMas using ttk::button $win.mas -text "+" -command [mymethod incrementar]
        pack $lbl $btnMas -side left -padx 2
    }

    method incrementar {} {
        incr valor
    }
}

contador .c
pack .c
```

- `hulltype` puede ser `frame`, `ttk::frame`, o `toplevel` (para widgets tipo ventana/diálogo, ej. un date-picker emergente).
- `[myvar valor]` obtiene el **nombre completo calificado** de la variable de instancia `valor`, necesario para pasarlo a `-textvariable` (que espera un nombre de variable, no un valor).
- `[mymethod incrementar]` genera el comando completo para invocar el método `incrementar` de **esta instancia específica** — es el equivalente de pasar `this.incrementar.bind(this)` en JS: sin esto, el `-command` no sabría a qué instancia pertenece.

---

## 3. Opciones (`-option`): la API pública de tu widget

Esto es el corazón de Snit. Defines opciones como en cualquier widget Tk nativo (`-text`, `-width`, etc.), con valor por defecto, validación y callbacks de cambio.

```tcl
snit::widget etiquetaColor {
    option -texto -default "Sin texto" -configuremethod ActualizarTexto
    option -color -default black       -configuremethod ActualizarColor

    constructor {args} {
        install lbl using label $win.lbl
        pack $lbl
        $self configurelist $args     ;# aplica las opciones pasadas al crear
    }

    method ActualizarTexto {opcion valor} {
        set options($opcion) $valor
        $lbl configure -text $valor
    }

    method ActualizarColor {opcion valor} {
        set options($opcion) $valor
        $lbl configure -foreground $valor
    }
}

etiquetaColor .e -texto "Stock: 100" -color red
pack .e

.e configure -texto "Stock: 50"    ;# cambia dinámicamente, dispara ActualizarTexto
puts [.e cget -texto]               ;# lee el valor actual: "Stock: 50"
```

Cosas importantes:

- `$self configurelist $args` en el constructor es el patrón estándar: aplica todas las opciones que el usuario pasó al crear la instancia (`-texto "..." -color red`).
- `-configuremethod` te da un hook para reaccionar cuando alguien hace `.e configure -texto "..."`. Si no lo necesitas, omítelo y Snit guarda el valor automáticamente en el array `options`.
- Sin `-configuremethod`, accedes al valor actual con `$options(-texto)` dentro de cualquier método, y Snit ya expone `cget`/`configure` gratis.

### Versión simplificada (sin configuremethod, cuando no necesitas reaccionar al cambio)
```tcl
snit::widget simple {
    option -texto -default "Hola"

    constructor {args} {
        install lbl using label $win.lbl -textvariable [myvar options(-texto)]
        pack $lbl
        $self configurelist $args
    }
}
```
Aquí ligamos directamente `-textvariable` al elemento del array de opciones — cuando cambias `-texto`, Tk se entera solo porque el array cambió (mismo mecanismo de `trace` de la guía anterior).

### Validación de opciones
```tcl
option -edad -default 0 -configuremethod ValidarEdad

method ValidarEdad {opcion valor} {
    if {![string is integer -strict $valor] || $valor < 0} {
        error "edad debe ser un entero no negativo, recibí: $valor"
    }
    set options($opcion) $valor
}
```

---

## 4. Métodos y `typemethods`

```tcl
snit::widget carrito {
    variable items {}

    method agregar {producto} {
        lappend items $producto
        $self Refrescar
    }

    method vaciar {} {
        set items {}
        $self Refrescar
    }

    # método privado (por convención, Mayúscula inicial = privado)
    method Refrescar {} {
        puts "Items actuales: $items"
    }
}

carrito .c
.c agregar "Arroz"
.c agregar "Frijoles"
```

Convención de Snit: métodos con **minúscula inicial son públicos** (parte de la API), métodos con **mayúscula inicial son privados** (solo se llaman internamente vía `$self MetodoPrivado`, aunque técnicamente igual son invocables desde fuera — es disciplina, no enforcement real).

### `typemethod`: métodos de clase (sin instancia)
```tcl
snit::type contadorGlobal {
    typevariable total 0

    typemethod incrementar {} {
        incr total
        return $total
    }
}

puts [contadorGlobal incrementar]   ;# 1
puts [contadorGlobal incrementar]   ;# 2
```
`typevariable` es compartida entre **todas** las instancias (como `static` en Go/Java). Útil para contadores globales, registries, factories.

---

## 5. Delegación: la razón #1 para usar Snit en vez de Tk puro

Cuando tu widget envuelve un widget interno (ej. un `entry` dentro de tu frame), normalmente quieres que opciones como `-width` o métodos como `insert`/`get` simplemente "pasen a través" a ese widget interno, sin que tengas que reescribir cada uno a mano. Eso es **delegación**.

### 5.1 Delegar opciones
```tcl
snit::widget campoTexto {
    delegate option -width to entry
    delegate option -font to entry
    delegate option * to entry     ;# delega TODAS las opciones no reconocidas

    component entry

    constructor {args} {
        install entry using entry $win.e
        pack $entry -fill x
        $self configurelist $args
    }
}

campoTexto .ct -width 30 -font {Arial 12}
pack .ct
```
`delegate option * to entry` es el patrón más común: cualquier opción que tu widget no defina explícitamente, se reenvía automáticamente al componente `entry`. Así tu megawidget "hereda" toda la API del widget interno sin escribir 40 líneas de `-configuremethod`.

### 5.2 Delegar métodos
```tcl
snit::widget campoTexto {
    component entry
    delegate option * to entry
    delegate method insert to entry
    delegate method get to entry
    delegate method delete to entry

    constructor {args} {
        install entry using entry $win.e
        pack $entry -fill x
        $self configurelist $args
    }
}

campoTexto .ct
pack .ct
.ct insert 0 "texto inicial"      ;# se reenvía directo a $entry insert
puts [.ct get]                     ;# se reenvía a $entry get
```

### 5.3 Delegar todo al hull (patrón común para "extender" un frame)
```tcl
delegate option * to hull
delegate method * to hull
```
Esto delega absolutamente todo lo no reconocido al frame contenedor mismo.

---

## 6. Componentes múltiples (widget compuesto real)

Ejemplo más cercano a tu caso de uso (ERP/POS): un campo de búsqueda de producto con entry + botón + listbox de sugerencias.

```tcl
snit::widget buscadorProducto {
    option -placeholder -default "Buscar producto..."
    option -oncommand -default {}

    component entry
    component boton
    component lista

    delegate option -width to entry

    constructor {args} {
        install entry using ttk::entry $win.e
        install boton using ttk::button $win.b -text "Buscar" -command [mymethod Buscar]
        install lista using listbox $win.l -height 5

        grid $entry -row 0 -column 0 -sticky ew
        grid $boton -row 0 -column 1
        grid $lista -row 1 -column 0 -columnspan 2 -sticky ew
        grid columnconfigure $win 0 -weight 1

        bind $entry <Return> [mymethod Buscar]

        $self configurelist $args
    }

    method Buscar {} {
        set termino [$entry get]
        $lista delete 0 end
        # Aquí llamarías a tu backend Go, o consultarías SQLite directo
        foreach resultado [$self BuscarEnBD $termino] {
            $lista insert end $resultado
        }
        if {$options(-oncommand) ne ""} {
            uplevel #0 [linsert $options(-oncommand) end $termino]
        }
    }

    method BuscarEnBD {termino} {
        # placeholder: aquí conectarías con sqlite3 o tu API Go
        return [list "Arroz" "Arroz integral" "Arándanos"]
    }

    # Expone el valor seleccionado como método público
    method seleccion {} {
        set idx [$lista curselection]
        if {$idx eq ""} { return "" }
        return [$lista get $idx]
    }
}

buscadorProducto .bp -oncommand {puts "Buscando:"}
pack .bp -fill x -padx 10 -pady 10
```

Este patrón —opciones de configuración + componentes internos + método público que expone solo lo necesario— es exactamente cómo diseñarías un componente reutilizable en React: la diferencia es que aquí la "prop callback" (`-oncommand`) se resuelve con `uplevel #0` en vez de simplemente invocar una función JS.

---

## 7. `snit::widgetadaptor`: extender un widget existente

Cuando no quieres envolver, sino **modificar el comportamiento de un widget Tk ya existente** (herencia real, no composición):

```tcl
snit::widgetadaptor entryNumerico {
    constructor {args} {
        installhull using entry
        $self configurelist $args
        $hull configure -validate key -validatecommand [mymethod Validar %P]
    }

    method Validar {texto} {
        return [string is double -strict $texto]
    }
}

entryNumerico .en
pack .en
.en insert 0 "123"     ;# funciona, es un entry normal...
.en insert end "abc"   ;# ...pero rechaza texto no numérico
```

`installhull using entry` en vez de crear un frame contenedor nuevo, usa el widget `entry` real como el hull — así tu nuevo tipo `entryNumerico` **es** un entry (con toda su API nativa), pero con comportamiento adicional. Esto es más parecido a herencia de clases (`class EntryNumerico extends Entry`) que a composición.

---

## 8. Variables de instancia y arrays

```tcl
snit::widget panelStock {
    variable stock 0
    variable historial {}

    constructor {args} {
        install lbl using label $win.lbl -textvariable [myvar stock]
        pack $lbl
    }

    method agregar {cantidad} {
        incr stock $cantidad
        lappend historial [clock seconds]:$cantidad
    }
}
```
`variable` declara una variable de instancia (equivalente a un campo privado de clase). Cada instancia (`panelStock .p1`, `panelStock .p2`) tiene su propia copia independiente — a diferencia de las variables globales que usarías en Tk puro.

Puedes inicializar arrays directamente:
```tcl
variable config -array {
    tema oscuro
    idioma es
}
```

---

## 9. Destrucción y limpieza (`destructor`)

```tcl
snit::widget conexionEstado {
    variable timerId ""

    constructor {args} {
        set timerId [after 1000 [mymethod Tick]]
    }

    method Tick {} {
        puts "tick..."
        set timerId [after 1000 [mymethod Tick]]
    }

    destructor {
        after cancel $timerId    ;# limpieza obligatoria: sin esto, el timer sigue disparando sobre un widget destruido
    }
}

conexionEstado .ce
# .ce destroy   -> cancela el timer automáticamente
```
Cualquier recurso que sobreviva al widget (timers con `after`, `trace`, sockets abiertos, bindings globales) **debe** limpiarse en el `destructor`, o tendrás errores de "invalid command name" cuando el timer intente llamar a un método de un widget que ya no existe. Esto es el equivalente Tcl de un memory leak / dangling reference.

---

## 10. Ejemplo completo: un widget "TarjetaProducto" para tu ERP

Juntando todo lo anterior en algo directamente reutilizable:

```tcl
package require Tk
package require snit

snit::widget tarjetaProducto {
    hulltype ttk::frame

    option -nombre    -default "" -configuremethod Redibujar
    option -precio    -default 0  -configuremethod Redibujar
    option -stock     -default 0  -configuremethod Redibujar
    option -onvender  -default {}

    component lblNombre
    component lblPrecio
    component lblStock
    component btnVender

    constructor {args} {
        install lblNombre using ttk::label $win.nombre -font {Arial 12 bold}
        install lblPrecio using ttk::label $win.precio
        install lblStock  using ttk::label $win.stock
        install btnVender using ttk::button $win.vender -text "Vender" \
            -command [mymethod Vender]

        grid $lblNombre -row 0 -column 0 -sticky w
        grid $lblPrecio -row 1 -column 0 -sticky w
        grid $lblStock  -row 2 -column 0 -sticky w
        grid $btnVender -row 0 -column 1 -rowspan 3 -padx 10

        $self configurelist $args
        $self Redibujar -nombre {}
    }

    method Redibujar {opcion valor} {
        set options($opcion) $valor
        $lblNombre configure -text $options(-nombre)
        $lblPrecio configure -text "Precio: \$$options(-precio)"
        $lblStock  configure -text "Stock: $options(-stock)"
        $btnVender configure -state [expr {$options(-stock) > 0 ? "normal" : "disabled"}]
    }

    method Vender {} {
        if {$options(-stock) <= 0} { return }
        $self configure -stock [expr {$options(-stock) - 1}]
        if {$options(-onvender) ne ""} {
            uplevel #0 [linsert $options(-onvender) end $options(-nombre)]
        }
    }
}

# Uso:
tarjetaProducto .t1 -nombre "Arroz" -precio 2.50 -stock 10 \
    -onvender {puts "Vendido:"}
pack .t1 -padx 10 -pady 10
```

Ahora tienes un componente reutilizable: instáncialo tantas veces como productos, cada uno con su propio estado independiente, opciones configurables, y un callback (`-onvender`) para conectarlo a tu lógica de negocio real (que en tu caso llamaría a tu backend Go vía socket/HTTP local o directo a SQLite).

---

## 11. Referencia rápida de sintaxis

| Construcción | Uso |
|---|---|
| `snit::widget nombre { ... }` | define un nuevo tipo de widget |
| `snit::widgetadaptor nombre { ... }` | extiende un widget Tk existente |
| `snit::type nombre { ... }` | objeto sin GUI |
| `option -x -default v` | declara una opción pública |
| `-configuremethod M` | hook al hacer `configure -x valor` |
| `-cgetmethod M` | hook al hacer `cget -x` (poco común) |
| `variable v` | variable de instancia privada |
| `typevariable v` | variable compartida por la clase |
| `component c` | declara un sub-widget interno |
| `install c using widget $win.c ...` | crea y registra un componente |
| `installhull using widget ...` | (solo widgetadaptor) usa un widget existente como hull |
| `delegate option -x to c` | reenvía una opción a un componente |
| `delegate option * to c` | reenvía todas las opciones no declaradas |
| `delegate method m to c` | reenvía un método a un componente |
| `method m {args} {...}` | método público |
| `method M {args} {...}` | método "privado" (convención: mayúscula) |
| `typemethod m {args} {...}` | método de clase, sin instancia |
| `$self metodo` | invoca un método propio desde dentro |
| `[mymethod metodo]` | genera callback ligado a esta instancia (para `-command`) |
| `[myvar variable]` | nombre completo de una variable de instancia (para `-textvariable`) |
| `$win` | path Tk de este widget (dentro del constructor/métodos) |
| `constructor {args} {...}` | inicialización, normalmente termina con `$self configurelist $args` |
| `destructor {...}` | limpieza al destruir la instancia |

---

## 12. Cuándo SÍ conviene Snit y cuándo no (para tu contexto)

Snit vale la pena cuando construyes un **widget que se reutiliza varias veces** con estado propio y una API clara (como el ejemplo de `tarjetaProducto` arriba, o `buscadorProducto`). Si solo necesitas una ventana única de tu app (ej. "el panel de configuración"), un simple `proc` que arma la UI directamente es más rápido y no necesitas el overhead de una clase.

Dado tu stack real (React+Wails para el ERP), lo más probable es que uses Snit únicamente si construyes **herramientas de soporte internas en Tcl/Tk puro** — por ejemplo, un inspector de base de datos SQLite standalone, un panel de diagnóstico de red, o un instalador/configurador gráfico liviano que corra sin depender de Node/pnpm — casos donde el "un solo archivo .tcl + wish, cero build step" pesa más que tener paridad visual con tu frontend principal.
