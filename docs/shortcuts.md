# Shortcuts propuestos

**Navegar por el calendario**
- `←` `→`: día anterior o siguiente.
- `↑` `↓`: semana anterior o siguiente.
- `Re Pág` / `Av Pág`: mes anterior o siguiente.
- `Inicio`: ir a hoy.

**Asignar guardias**
- `1`–`9`: asignar al trabajador n de la plantilla en el día seleccionado. Es lo más rápido para llenar a mano.
- `Enter`: asignar el trabajador elegido en el combobox.
- `Supr`: quitar la guardia del día.
- `Ctrl+Shift+A`: autocompletar desde este día.

**Plantilla**
- `Ctrl+N`: nuevo trabajador.
- `F2`: editar el trabajador seleccionado.
- `Alt+↑` / `Alt+↓`: mover en la lista.
- `Supr` (con foco en la lista): dar de baja o eliminar, siempre con confirmación.

**Ausencias**
- `Ctrl+Shift+V`: añadir vacaciones al trabajador seleccionado.
- `Ctrl+Shift+L`: añadir licencia al trabajador seleccionado.

**General**
- `Ctrl+Tab`: cambiar entre Plantilla y Resumen. `ttk::notebook` ya lo trae con `ttk::notebook::enableTraversal`.
- `Esc`: cerrar el diálogo o quitar la selección.
- `Enter`: confirmar el diálogo.

## Notas de implementación

- **`Supr` hace dos cosas según el foco.** Con el calendario enfocado quita la guardia, y con la lista enfocada da de baja al trabajador. Es coherente, pero conviene que el foco sea visible.
- **macOS vs Windows.** Como programas en macOS y despliegas en Windows, usa `Control` y pruébalo en Windows. En macOS, Tk usa `Command` por convención, así que tendrías que añadir los bindings para las dos teclas si quieres probar ahí.
- **Idea opcional.** Tras asignar con `1`–`9`, el cursor podría avanzar solo al día siguiente. Con eso llenas un mes pulsando solo números.
- **Deshacer.** `Ctrl+Z` es muy útil, sobre todo porque el autocompletado puede escribir un mes entero. Pero implica guardar un historial de cambios, así que es una decisión de diseño aparte.
