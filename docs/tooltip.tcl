package require snit
package require Tk

namespace eval myapp {}

snit::type myapp::Tooltip {
    typevariable timer ""
    typevariable current_win ""

    typemethod attach {w text} {
        bind $w <Enter> [list [from_namespace] _show $w $text]
        bind $w <Leave> [list [from_namespace] _hide]
        bind $w <ButtonPress> [list [from_namespace] _hide]
    }

    proc _show {w text} {
        variable timer
        after cancel $timer
        _hide
        # Retardo de 400ms antes de mostrar el tooltip
        set timer [after 400 [list [from_namespace] _create $w $text]]
    }

    proc _create {w text} {
        variable current_win
        if {![winfo exists $w]} return

        set current_win ._ttk_tooltip_popup
        catch {destroy $current_win}

        # Ventana flotante sin decoraciones del sistema
        toplevel $current_win
        wm overrideredirect $current_win 1

        # Contenedor y etiqueta integrados con ttk
        set f [ttk::frame $current_win.f -padding 1]
        pack $f -fill both -expand yes

        ttk::label $f.lbl -text $text -padding {4 2}
        pack $f.lbl -fill both -expand yes

        # Posicionamiento dinámico debajo del widget
        set x [winfo rootx $w]
        set y [expr {[winfo rooty $w] + [winfo height $w] + 3}]
        wm geometry $current_win "+$x+$y"

        raise $current_win
    }

    proc _hide {} {
        variable timer
        variable current_win
        after cancel $timer
        if {$current_win ne "" && [winfo exists $current_win]} {
            destroy $current_win
            set current_win ""
        }
    }
}
