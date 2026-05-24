snit::widget WorkersPanelAdd {
    delegate option * to hull
    delegate method * to hull

    option -worker_id

    variable name ""

    constructor {args} {
        $self configurelist $args

        set entry [ttk::entry $win.entry -textvariable [myvar name]]
        set button [ttk::button $win.button -text "agregar" -command [mymethod save_worker] -state disabled]

        pack $entry -side left -fill both -expand yes -padx 4
        pack $button -side left -fill y -padx 4

        bind $entry <Return> [mymethod save_worker]

        trace add variable name write [mymethod name_changed]
        trace add variable $options(-worker_id) write [mymethod worker_id_updated]
    }

    destructor {
        trace remove variable name write [mymethod name_changed]
        trace remove variable $options(-worker_id) write [mymethod worker_id_updated]
    }

    method save_worker {} {
        upvar $options(-worker_id) id

        if {[db exists {SELECT id FROM workers WHERE id <> $id AND name = $name}]} {
            tk_messageBox -type ok -icon info -title "Aviso" -message "$name ya existe"
            return
        }

        if {$id != -1} {
            db eval {UPDATE workers SET name = $name WHERE id = $id}
        } else {
            set weight 0
            db eval {SELECT weight FROM workers ORDER BY weight DESC LIMIT 1} values {
                set weight [expr {$values(weight) + 1}]
            }
            db eval {INSERT INTO workers (name, weight) VALUES ($name, $weight)}
        }

        $self cancel_editing
        event generate $win <<WorkerSaved>>
    }

    method cancel_editing {} {
        $win.button configure -text "agregar"
        set name ""
    }

    method worker_id_updated {args} {
        upvar $options(-worker_id) id
        if {$id == -1} {
            $self cancel_editing
        } else {
            $win.button configure -text "editar"
            db eval {SElECT name FROM workers WHERE id = $id} values {
                set name $values(name)
            }
        }
    }

    method name_changed {args} {
        if {[string trim $name] == ""} {
            $win.button configure -state disabled
        } else {
            $win.button configure -state normal
        }
    }
}
