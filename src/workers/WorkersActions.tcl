snit::widget WorkersActions {
    hulltype ttk::frame

    component up
    component down
    component delete
    component cancel

    option -selected_worker_id -configuremethod ConfigureSelectedWorkerIdOption

    delegate option * to hull
    delegate method * to hull

    constructor {args} {
        install up using ttk::button $win.up -text "^" -command [mymethod Up] -state disabled
        install down using ttk::button $win.down -text "v" -command [mymethod Down] -state disabled
        install delete using ttk::button $win.delete -text "dar baja" -command [mymethod Delete] -state disabled
        install cancel using ttk::button $win.cancel -text "cancelar" -command [mymethod Cancel] -state disabled

        pack $cancel $delete $down $up -side right -fill y -padx 4

        $self configurelist $args
    }

    destructor {
        try {trace add variable $options(-selected_worker_id) write [mymethod Refresh]}
    }

    method ConfigureSelectedWorkerIdOption {option value} {
        set options($option) $value
        $self Refresh
        trace add variable $options(-selected_worker_id) write [mymethod Refresh]
    }

    method Refresh {args} {
        upvar $options(-selected_worker_id) selected_worker_id

        $up configure -state disabled
        $down configure -state disabled
        $delete configure -state disabled
        $cancel configure -state disabled

        if {$selected_worker_id == -1} {return}

        set upper_weight 0
        set lower_weight 0
        set worker_weight 0

        db eval {SELECT weight FROM workers WHERE id = :selected_worker_id} {
            set worker_weight $weight
        }
        db eval {SELECT weight FROM workers ORDER BY weight ASC LIMIT 1} {
            set lower_weight $weight
        }
        db eval {SELECT weight FROM workers ORDER BY weight DESC LIMIT 1} {
            set upper_weight $weight
        }

        $delete configure -state normal
        $cancel configure -state normal
        if {$worker_weight > $lower_weight} {$up configure -state normal}
        if {$worker_weight < $upper_weight} {$down configure -state normal}
    }

    method Up {args} {
        upvar $options(-selected_worker_id) selected_worker_id

        db eval {SELECT id, weight FROM workers WHERE id = :selected_worker_id} {
            db transaction {
                db eval {
                    UPDATE workers
                    SET weight = :weight
                    WHERE weight = :weight - 1
                }
                db eval {
                    UPDATE workers
                    SET weight = :weight - 1
                    WHERE id = :id
                }
            }
        }

        $self Refresh
        event generate $win <<WorkerUp>> -data $selected_worker_id -when now
    }

    method Down {args} {
        upvar $options(-selected_worker_id) selected_worker_id

        db eval {SELECT id, weight FROM workers WHERE id = :selected_worker_id} {
            db transaction {
                db eval {
                    UPDATE workers
                    SET weight = :weight
                    WHERE weight = :weight + 1
                }
                db eval {
                    UPDATE workers
                    SET weight = :weight + 1
                    WHERE id = :id
                }
            }
        }

        $self Refresh
        event generate $win <<WorkerDown>> -data $selected_worker_id -when now
    }

    method Delete {args} {
        upvar $options(-selected_worker_id) selected_worker_id

        db eval {SELECT id, name FROM workers WHERE id = :selected_worker_id} {
            if {[tk_messageBox -type yesno -icon question -title "Dar de baja" -message "¿Seguro que desea dar de baja a $name?"] == yes} {
                db eval {DELETE FROM workers WHERE id = :selected_worker_id}
                $self Cancel
                event generate $win <<WorkerDeleted>> -data $id -when now
            }
        }
    }

    method Cancel {args} {
        event generate $win <<WorkerEditCanceled>> -when now
    }
}
