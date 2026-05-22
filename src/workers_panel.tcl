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

    method save_worker {} {
        upvar $options(-worker_id) id

        if {[db exists {SELECT id FROM workers WHERE id <> $id AND name = $name}]} {
            tk_messageBox -type ok -icon info -title "Aviso" -message "$name ya existe"
            return
        }

        if {$id != -1} {
            db eval {UPDATE workers SET name = $name WHERE id = $id}
        } else {
            db eval {INSERT INTO workers (name) VALUES ($name)}
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

snit::widget WorkersPanelActions {
    delegate option * to hull
    delegate option * to hull

    option -worker_id

    constructor {args} {
        $self configurelist $args

        set up [ttk::button $win.up -text "^" -state disabled]
        set down [ttk::button $win.down -text "v" -state disabled]
        set delete [ttk::button $win.delete -text "dar baja" -command [mymethod delete_worker] -state disabled]
        set cancel [ttk::button $win.cancel -text "cancelar" -command [mymethod cancel_editing] -state disabled]

        pack $cancel $delete $down $up -side right -fill y -padx 4

        trace add variable $options(-worker_id) write [mymethod worker_id_updated]
    }

    method cancel_editing {args} {
        event generate $win <<EditingCanceled>>
    }

    method delete_worker {args} {
        upvar $options(-worker_id) id

        db eval {SElECT name FROM workers WHERE id = $id} {
            if {[tk_messageBox -type yesno -icon question -title "Dar de baja" -message "¿Seguro que desa dar de baja a $name?"] == yes} {
                db eval {DELETE FROM workers WHERE id = $id}
                event generate $win <<WorkerDeleted>>
            }
        }
    }

    method worker_id_updated {args} {
        upvar $options(-worker_id) id

        if {$id == -1} {
            $win.up configure -state disabled
            $win.down configure -state disabled
            $win.delete configure -state disabled
            $win.cancel configure -state disabled
        } else {
            $win.up configure -state normal
            $win.down configure -state normal
            $win.delete configure -state normal
            $win.cancel configure -state normal
        }
    }
}

snit::widget WorkersPanelList {
    delegate option * to hull
    delegate method * to hull

    option -worker_id

    constructor {args} {
        $self configurelist $args

        set tree [ttk::treeview $win.tree -columns {id name weight} -displaycolumns {name} -show {}]
        set scroll [ttk::scrollbar $win.scroll -orient vertical -command [list $tree yview]]
        $tree configure -yscrollcommand [list $scroll set]
        $tree configure -selectmode browse

        $self update_list

        pack $tree -side left -fill both -expand yes
        pack $scroll -side right -fill y

        bind $tree <<TreeviewSelect>> [mymethod worker_selected]
    }

    method update_list {} {
        $win.tree delete [$win.tree children {}]
        db eval {SELECT id, name, weight FROM workers} {
            $win.tree insert {} end -values [list $id $name $weight]
        }
    }

    method cancel_editing {} {
        $win.tree selection remove [$win.tree selection]
    }

    method worker_selected {args} {
         set sel [$win.tree selection]
         if {$sel == ""} {
             return
         }

         set values [$win.tree item $sel -values]
         lassign $values id
         set $options(-worker_id) $id
    }
}

snit::widgetadaptor WorkersPanel {
    delegate option * to hull
    delegate method * to hull

    option -worker_id

    constructor {args} {
        installhull using ttk::labelframe -text "Plantilla"
        $self configurelist $args

        set add [WorkersPanelAdd $win.add -worker_id $options(-worker_id)]
        set actions [WorkersPanelActions $win.actions -worker_id $options(-worker_id)]
        set list [WorkersPanelList $win.list -worker_id $options(-worker_id)]

        pack $add $actions -fill x -pady 4
        pack $list -fill both -expand yes -pady 4

        bind $add <<WorkerSaved>> [mymethod workers_saved]
        bind $actions <<EditingCanceled>> [mymethod cancel_editing]
        bind $actions <<WorkerDeleted>> [mymethod workers_deleted]
    }

    method workers_saved {args} {
        $win.list update_list

        event generate $win <<WorkerSaved>>
    }

    method workers_deleted {args} {
        $win.add cancel_editing
        $win.list cancel_editing
        $win.list update_list

        event generate $win <<WorkerDeleted>>
    }

    method cancel_editing {args} {
        $win.add cancel_editing
        $win.list cancel_editing

        event generate $win <<EditingCanceled>>
    }
}
