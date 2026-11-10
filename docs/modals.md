# Ventanas modales

Una ventana modal combina tres cosas:

1. **`toplevel` + `wm transient`:** se muestra encima de la ventana padre y no aparece como ventana independiente en la barra de tareas.
2. **`grab`:** el ratón y el teclado solo llegan a esa ventana; el resto de la app queda bloqueada.
3. **`vwait`:** detiene el código que llamó al diálogo hasta que una variable cambie. Así el diálogo puede devolver un resultado como si fuera una función.

## Helper de centrado

```tcl
proc center_over {win parent} {
    update idletasks
    set w [winfo reqwidth $win]
    set h [winfo reqheight $win]
    set x [expr {[winfo rootx $parent] + ([winfo width $parent] - $w) / 2}]
    set y [expr {[winfo rooty $parent] + ([winfo height $parent] - $h) / 2}]
    wm geometry $win +$x+$y
}
```

## Diálogo de trabajador (agregar y editar)

Un solo diálogo para los dos casos: si pasas `-name`, es edición.

```tcl
snit::widget WorkerDialog {
    hulltype toplevel

    component entry
    component accept

    option -parent -default . -readonly yes
    option -name -default {}

    variable name {}
    variable result {}
    variable done 0

    constructor {args} {
        wm withdraw $win
        $self configurelist $args

        wm title $win Trabajador
        wm transient $win $options(-parent)
        wm resizable $win 0 0
        wm protocol $win WM_DELETE_WINDOW [mymethod Cancel]

        set body [ttk::frame $win.body -padding 12]
        install entry using ttk::entry $body.entry -textvariable [myvar name] -width 30
        install accept using ttk::button $body.accept -text Guardar -command [mymethod Accept] -state disabled
        ttk::button $body.cancel -text Cancelar -command [mymethod Cancel]

        grid $entry -row 0 -column 0 -columnspan 2 -sticky ew -pady {0 12}
        grid $body.cancel -row 1 -column 0 -sticky e -padx 4
        grid $accept -row 1 -column 1 -sticky e
        grid columnconfigure $body 0 -weight 1
        pack $body -fill both -expand yes

        bind $win <Return> [mymethod Accept]
        bind $win <Escape> [mymethod Cancel]

        set name $options(-name)
        trace add variable [myvar name] write [mymethod NameChanged]
        $self NameChanged
    }

    method NameChanged {args} {
        set state normal
        if {[string trim $name] eq {}} { set state disabled }
        $accept configure -state $state
    }

    method Accept {} {
        set trimmed [string trim $name]
        if {$trimmed eq {}} return
        set result $trimmed
        set done 1
    }

    method Cancel {} {
        set result {}
        set done 1
    }

    method show {} {
        center_over $win $options(-parent)
        wm deiconify $win
        tkwait visibility $win
        grab $win
        focus $entry
        $entry selection range 0 end

        vwait [myvar done]

        grab release $win
        set value $result
        destroy $win
        return $value
    }
}
```

Cómo usarlo desde un widget:

```tcl
method AddWorker {} {
    set dlg [WorkerDialog .worker_dlg -parent [winfo toplevel $win]]
    set new_name [$dlg show]
    if {$new_name eq {}} return
    # guardar en la base de datos y notificar el cambio
}

method EditWorker {current_name} {
    set dlg [WorkerDialog .worker_dlg -parent [winfo toplevel $win] -name $current_name]
    set new_name [$dlg show]
    if {$new_name eq {}} return
    # actualizar en la base de datos y notificar el cambio
}
```

Si el usuario cancela (botón, `Esc` o la X de la ventana), `show` devuelve vacío.

## Diálogo de ausencia (vacaciones y licencia)

Misma estructura que `WorkerDialog`, con más campos: trabajador (combobox `readonly`), tipo, fecha de inicio y fecha de fin. El botón `+ Vacaciones` lo abre con `-kind vac` y `+ Licencia` con `-kind lic`. La validación va dentro de `Accept`, y el resultado se devuelve como un diccionario:

```tcl
method Accept {} {
    try {
        set start [clock scan $start_text -format %d/%m/%Y]
        set end [clock scan $end_text -format %d/%m/%Y]
    } on error {} {
        tk_messageBox -parent $win -icon warning -title Aviso -message {Fecha inválida. Usa dd/mm/aaaa}
        return
    }
    if {$end < $start} {
        tk_messageBox -parent $win -icon warning -title Aviso -message {La fecha final es anterior a la inicial}
        return
    }
    set result [dict create worker_id $worker_id kind $kind start $start end $end]
    set done 1
}
```

Si la ausencia choca con guardias ya asignadas, pregunta ahí mismo con otro `tk_messageBox -type yesno -parent $win` antes de cerrar.

## Diálogos nativos

`tk_messageBox`, `tk_getOpenFile`, `tk_chooseColor` y similares ya son modales. Pásales siempre `-parent` con la ventana que los abre.

## 3. Errores comunes

- **`grab failed: window not viewable`:** hiciste `grab` antes de que la ventana fuera visible. Pon `tkwait visibility $win` antes del `grab`.
- **La ventana parpadea o aparece en una esquina:** crea el `toplevel` oculto con `wm withdraw`, centra y luego `wm deiconify`.
- **El fondo del diálogo se ve de otro gris:** un `toplevel` no usa el tema ttk. Pon un `ttk::frame` que lo llene, como en el ejemplo.
- **Un `tk_messageBox` queda detrás del diálogo:** falta `-parent $win`.
- **Cerrar con la X deja el programa colgado:** el `vwait` sigue esperando. Captura `wm protocol $win WM_DELETE_WINDOW` y llama a `Cancel`.
- **`Enter` guarda con el campo vacío:** el binding no respeta el estado del botón. Valida dentro de `Accept`.
- **Comportamiento distinto entre macOS y Windows:** el foco y `transient` se tratan algo distinto en cada sistema. Como el destino es Windows, pruébalo allí.
