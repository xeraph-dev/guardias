Aquí tienes una guía completa y práctica sobre cómo utilizar **`ttk::panedwindow`** en Tcl/Tk 9.1 para construir interfaces con paneles divisores redimensionables (como el diseño de dos columnas que analizamos en tu aplicación).

---

# Guía Práctica de `ttk::panedwindow`

El widget **`ttk::panedwindow`** crea un contenedor dividido en dos o más paneles separados por una barra divisoria ajustable (*sash*). El usuario puede arrastrar esta barra para cambiar el tamaño relativo de los paneles en tiempo de ejecución.

---

## 1. Conceptos Clave y Orientación

Por defecto, los paneles se disponen de forma **horizontal** (uno al lado del otro), lo cual es ideal para dividir una aplicación en una barra lateral y un panel principal. También puedes configurarlo en orientación **vertical** (uno encima del otro).

### Sintaxis básica de creación:

```tcl
# Crear un panedwindow horizontal
set pw [ttk::panedwindow .pw -orient horizontal]
pack $pw -fill both -expand yes

```

---

## 2. Añadir y Gestionar Paneles

A diferencia de otros widgets donde usas `pack` o `grid`, en un `panedwindow` los hijos (generalmente `ttk::frame`) se añaden utilizando el método **`add`**.

```tcl
# 1. Crear los contenedores de los paneles
set panelIzquierdo [ttk::frame $pw.izq -padding 5]
set panelDerecho   [ttk::frame $pw.der -padding 5]

# 2. Añadirlos al panedwindow
$pw add $panelIzquierdo -weight 1
$pw add $panelDerecho   -weight 3

```

* **La opción `-weight**`: Controla cómo se expanden o contraen los paneles cuando se redimensiona la ventana principal. Un peso mayor (`-weight 3`) hace que ese panel absorba más espacio que uno con menor peso (`-weight 1`).

---

## 3. Ejemplo Completo y Funcional

Este ejemplo replica la estructura básica de una app con un **panel izquierdo** (para un calendario o lista) y un **panel derecho** (para los detalles o controles), permitiendo ajustar el divisor con el ratón:

```tcl
package require Tk

# Crear ventana principal
wm title . "Ejemplo de PanedWindow"
wm geometry . "800x500"

# 1. Crear el contenedor PanedWindow horizontal
set pw [ttk::panedwindow .mainPane -orient horizontal]
pack $pw -fill both -expand yes

# 2. Crear los dos marcos (paneles) que contendrán la interfaz
set frameIzq [ttk::frame $pw.izq -padding 10]
set frameDer [ttk::frame $pw.der -padding 10]

# 3. Agregar los marcos al panedwindow
# -weight 1 para el panel izquierdo (más estático o fijo)
# -weight 3 para el panel derecho (se expande más al estirar la ventana)
$pw add $frameIzq -weight 1
$pw add $frameDer -weight 3

# --- CONTENIDO DEL PANEL IZQUIERDO ---
ttk::label $frameIzq.lbl -text "Panel Izquierdo (Ej. Calendario)" -font {TkDefaultFont 10 bold}
ttk::button $frameIzq.btn -text "Acción Izquierda"
pack $frameIzq.lbl -anchor w -pady 5
pack $frameIzq.btn -anchor w -pady 5

# --- CONTENIDO DEL PANEL DERECHO ---
ttk::label $frameDer.lblTitle -text "Panel Derecho (Ej. Detalles y Pestañas)" -font {TkDefaultFont 10 bold}
ttk::separator $frameDer.sep -orient horizontal

ttk::entry $frameDer.ent -width 30

pack $frameDer.lblTitle -anchor w -pady 5
pack $frameDer.sep -fill x -pady 5
pack $frameDer.ent -anchor w -pady 5

# Opcional: Rellenar con un widget de texto o treeview para simular el mockup
set tv [ttk::treeview $frameDer.tv -columns {col1 col2} -show headings -height 6]
$tv heading col1 -text "Elemento"
$tv heading col2 -text "Estado"
pack $tv -fill both -expand yes -pady 10

```

---

## 4. Métodos y Opciones Útiles

Una vez creado tu `panedwindow`, puedes interactuar con él mediante los siguientes comandos:

* **Añadir un panel nuevo en una posición específica:**
```tcl
$pw insert 1 $nuevoFrame -weight 2

```


* **Eliminar un panel:**
```tcl
$pw forget $nombreDelFrame

```


* **Consultar la posición actual de la barra divisoria (*sash*):**
```tcl
# Devuelve las coordenadas de la barra índice 0
set coords [$pw sashpos 0]

```


* **Fijar o mover la barra divisoria mediante código:**
```tcl
# Mueve la barra divisoria 0 a la coordenada X/Y de 300 píxeles
$pw sashpos 0 300

```



---

## 5. Consejos de Diseño

1. **Uso de marcos hijos (`ttk::frame`):** Nunca coloques botones o etiquetas directamente dentro del `panedwindow`. Siempre añade `ttk::frame` como hijos directos del `panedwindow`, y dentro de esos marcos diseña tu interfaz con `pack` o `grid`.
2. **Combinación con Temas Natívos:** Al ser un widget de `ttk`, la barra divisoria (*sash*) adoptará automáticamente el aspecto visual nativo del sistema operativo (Windows, macOS o Linux) sin requerir configuración adicional de colores.
