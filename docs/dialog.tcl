package require Tk
package require msgcat
package require widget::dialog

# Configuración de idioma y textos personalizados para los botones
msgcat::mclocale es
msgcat::mclset es ok "Guardar"
msgcat::mclset es cancel "Cancelar"

proc abrir_formulario_configuracion {} {
    set dlg .formConfig
    catch {destroy $dlg}

    # 1. Crear el diálogo modal de Tklib
    widget::dialog $dlg \
        -title "Configuración del Sistema" \
        -parent . \
        -modal local \
        -separator yes \
        -buttons {ok cancel} \
        -command [list procesar_formulario_dialogo $dlg]

    # 2. Obtener el marco contenedor interno
    set content [$dlg getframe]

    # 3. Construir los campos del formulario usando ttk
    ttk::label $content.lbl1 -text "Nombre de usuario:"
    ttk::entry $content.ent1 -textvariable ::form_usuario -width 30

    ttk::label $content.lbl2 -text "Directorio de trabajo:"
    ttk::entry $content.ent2 -textvariable ::form_path -width 30

    # Posicionamiento con grid
    grid $content.lbl1 -row 0 -column 0 -sticky w -pady 6 -padx 6
    grid $content.ent1 -row 0 -column 1 -sticky ew -pady 6 -padx 6
    grid $content.lbl2 -row 1 -column 0 -sticky w -pady 6 -padx 6
    grid $content.ent2 -row 1 -column 1 -sticky ew -pady 6 -padx 6

    grid columnconfigure $content 1 -weight 1

    # 4. Asociar tooltips a los campos creados usando nuestra clase Snit
    myapp::Tooltip attach $content.ent1 "Introduce tu nombre de usuario único"
    myapp::Tooltip attach $content.ent2 "Ruta absoluta donde se guardarán los archivos"

    # 5. Mostrar el diálogo
    $dlg display
}

proc procesar_formulario_dialogo {dlg boton} {
    # $boton recibe el ID interno ("ok" o "cancel")
    if {$boton eq "ok"} {
        puts "Datos guardados:"
        puts "  Usuario: $::form_usuario"
        puts "  Ruta:    $::form_path"
    } else {
        puts "Operación cancelada por el usuario."
    }
}
