Aquí tienes el resumen definitivo y estructurado de todas las **librerías, comandos y widgets** que hemos recopilado para construir tu aplicación con **Tcl/Tk 9.1**, organizados según su rol en el proyecto:

---

### 1. Librerías y Módulos de Tcl

* **`Tk` / `ttk` (Nativo):** El motor principal de la interfaz gráfica y los temas nativos del sistema operativo (*Vista/Aqua/Linux*).
* **`Tcllib` (Lógica y utilidades de backend):**
* `cmdline`: Para procesar argumentos y flags si ejecutas la app desde la consola.
* `json` o `inifile`: Para parsear archivos de configuración locales.
* Módulos de fecha/hora (`clock` nativo) y estructuras de datos (`struct::matrix` para la matriz del calendario).


* **`Tklib` (Widgets y extensiones gráficas):**
* `widget::dialog`: Para la gestión de ventanas modales y formularios estándar.
* `msgcat`: Para internacionalizar y traducir los botones de los diálogos (ej. cambiar "ok" por "Guardar").



---

### 2. Comandos Clave de Tcl/Tk y `ttk`

* **Geometría y Contenedores:**
* `ttk::panedwindow`: Para crear la división ajustable de dos paneles (izquierdo y derecho) con el método `$pw add` y el control del divisor mediante `$pw sashpos`.
* `ttk::notebook`: Para las pestañas superiores del panel derecho.
* `grid` y `pack`: Para la distribución y alineación milimétrica de elementos.


* **Ciclo de Vida y Persistencia:**
* `wm protocol . WM_DELETE_WINDOW`: Para interceptar el cierre de la app y guardar estados (como la posición del divisor o la configuración).
* `after idle`: Truco esencial en Tk para asegurar que los elementos se han renderizado antes de modificar sus posiciones por código (ej. restaurar el tamaño del `panedwindow`).



---

### 3. Widgets por Componente de la App

* **Panel Izquierdo (Calendario interactivo):**
* **`canvas` (Tk base):** Imprescindible para dibujar la cuadrícula del calendario, celdas seleccionadas (bordes rojos) y los indicadores de estado personalizados (rayitas de colores).


* **Panel Derecho (Listas, pestañas y formularios):**
* **`ttk::treeview`:** Para mostrar tablas de registros o listas detalladas de eventos.
* **`ttk::labelframe`:** Para agrupar visualmente los bloques de formularios.
* **`ttk::entry`, `ttk::combobox`, `ttk::button`:** Entradas de texto, selectores desplegables y botones de acción.


* **Componentes Auxiliares (Tooltips propios con Snit):**
* **`toplevel` (con `wm overrideredirect 1`) + `ttk::frame` + `ttk::label`:** Combinados en una clase propia con **Snit** para crear tooltips flotantes modernos que heredan automáticamente el tema nativo de `ttk`.
