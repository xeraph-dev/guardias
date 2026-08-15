snit::widget WorkersActions {
    hulltype ttk::frame

    component up
    component down
    component delete
    component cancel

    option -selected_worker_id -configuremethod ConfigureSelectedWorkerIdOption
    option -revisions

    delegate option * to hull
    delegate method * to hull

    variable delete_text {}

    constructor {args} {
        install up using ttk::button $win.up -text "^" -command [mymethod Up] -state disabled
        install down using ttk::button $win.down -text "v" -command [mymethod Down] -state disabled
        install delete using ttk::button $win.delete -textvariable [myvar delete_text]  -command [mymethod Delete] -state disabled
        install cancel using ttk::button $win.cancel -text "cancelar" -command [mymethod Cancel] -state disabled

        pack $cancel $delete $down $up -side right -fill y -padx 4

        $self configurelist $args
    }

    destructor {
        try {trace remove variable $options(-selected_worker_id) write [mymethod Refresh]}
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

        set delete_text "dar baja"
        set upper_weight 0
        set lower_weight 0
        set worker_weight 0
        set worker_active 0

        if {$selected_worker_id == -1} {return}

        db eval {SELECT weight, active FROM workers WHERE id = :selected_worker_id} {
            set worker_weight $weight
            set worker_active $active
        }
        db eval {SELECT weight FROM workers WHERE active = :worker_active ORDER BY weight ASC LIMIT 1} {
            set lower_weight $weight
        }
        db eval {SELECT weight FROM workers WHERE active = :worker_active ORDER BY weight DESC LIMIT 1} {
            set upper_weight $weight
        }

        puts "$selected_worker_id | $worker_weight"

        if {!$worker_active} { set delete_text "eliminar" }

        $delete configure -state normal
        $cancel configure -state normal
        if {$worker_weight > $lower_weight} {$up configure -state normal}
        if {$worker_weight < $upper_weight} {$down configure -state normal}
    }

    method Up {args} {
        upvar $options(-selected_worker_id) selected_worker_id

        db eval {SELECT id, weight, active FROM workers WHERE id = :selected_worker_id} {
            db transaction {
                db eval {
                    UPDATE workers
                    SET weight = :weight
                    WHERE weight = :weight - 1
                      and active = :active
                }
                db eval {
                    UPDATE workers
                    SET weight = :weight - 1
                    WHERE id = :id
                      AND active = :active
                }
            }
        }

        $self Refresh
        incr $options(-revisions)(workers)
    }

    method Down {args} {
        upvar $options(-selected_worker_id) selected_worker_id

        db eval {SELECT id, weight, active FROM workers WHERE id = :selected_worker_id} {
            db transaction {
                db eval {
                    UPDATE workers
                    SET weight = :weight
                    WHERE weight = :weight + 1
                      AND active = :active
                }
                db eval {
                    UPDATE workers
                    SET weight = :weight + 1
                    WHERE id = :id
                      AND active = :active
                }
            }
        }

        $self Refresh
        incr $options(-revisions)(workers)
    }

    method Delete {args} {
        upvar $options(-selected_worker_id) selected_worker_id

        db eval {SELECT id, name, active FROM workers WHERE id = :selected_worker_id} {
            if {$active} {
                $self SoftDelete $id $name
            } else {
                $self HardDelete $id $name
            }
        }

        incr $options(-revisions)(workers)
    }

    method SoftDelete {id name} {
        if {[tk_messageBox -type yesno -icon question -title "Dar de baja" -message "¿Seguro que desea dar de baja a $name?"] == yes} {
            db transaction {
                set weight 0
                db eval {SELECT weight FROM workers WHERE NOT active ORDER BY weight DESC LIMIT 1} values {
                    set weight [expr {$values(weight) + 1}]
                }

                db eval {
                    UPDATE workers
                    SET active = FALSE,
                        weight = :weight
                    WHERE id = :id
                }

                set weight 0
                db eval {SELECT id FROM workers WHERE active ORDER BY weight ASC} {
                    db eval {
                        UPDATE workers
                        SET weight = :weight
                        WHERE id = :id
                    }
                    incr weight
                }
            }
            $self Cancel
            incr $options(-revisions)(workers)
        }
    }

    method HardDelete {id name} {
        if {[tk_messageBox -type yesno -icon question -title "Borrar" -message "¿Seguro que desea borrar a $name? Esto también borrará todo su registro histórico"] == yes} {

            db transaction {
                db eval {DELETE FROM workers WHERE id = :id}

                set weight 0
                db eval {SELECT id FROM workers WHERE NOT active ORDER BY weight ASC} {
                    db eval {
                        UPDATE workers
                        SET weight = :weight
                        WHERE id = :id
                    }
                    incr weight
                }
            }
            $self Cancel
            incr $options(-revisions)(workers)
        }
    }

    method Cancel {args} {
        upvar $options(-selected_worker_id) selected_worker_id
        if {$selected_worker_id != -1} { set selected_worker_id -1 }
    }
}
