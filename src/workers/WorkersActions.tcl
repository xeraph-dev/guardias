snit::widget WorkersActions {
    hulltype ttk::frame

    component up
    component down
    component delete
    component cancel
    component assign
    component frame1
    component frame2

    option -selected_date -configuremethod ConfigureSelectedDateOption
    option -selected_worker_id -configuremethod ConfigureSelectedWorkerIdOption
    option -revisions

    delegate option * to hull
    delegate method * to hull

    variable delete_text {}

    constructor {args} {
        install frame1 using ttk::labelframe $win.frame1 -text "Acciones trabajador"
        install frame2 using ttk::labelframe $win.frame2 -text "Acciones calendario"

        install up using ttk::button $win.frame1.up -text "^" -command [mymethod Up] -state disabled
        install down using ttk::button $win.frame1.down -text "v" -command [mymethod Down] -state disabled
        install delete using ttk::button $win.frame1.delete -textvariable [myvar delete_text]  -command [mymethod Delete] -state disabled
        install cancel using ttk::button $win.frame1.cancel -text "cancelar" -command [mymethod Cancel] -state disabled
        install assign using ttk::button $win.frame2.assign -text "asignar" -command [mymethod Assign] -state disabled

        pack $up $down $delete $cancel -side left -fill y -padx 4
        pack $assign -side left -fill y -padx 4

        pack $frame1 $frame2 -fill both -pady 4

        $self configurelist $args
    }

    destructor {
        try {trace remove variable $options(-selected_worker_id) write [mymethod Refresh]}
        try {trace remove variable $options(-selected_worker_id) write [mymethod RefreshAssignButton]}
        try {trace remove variable $options(-selected_date) write [mymethod RefreshAssignButton]}
    }

    method ConfigureSelectedWorkerIdOption {option value} {
        set options($option) $value
        $self Refresh
        trace add variable $options(-selected_worker_id) write [mymethod Refresh]
        trace add variable $options(-selected_worker_id) write [mymethod RefreshAssignButton]
    }

    method ConfigureSelectedDateOption {option value} {
        set options($option) $value
        $self RefreshAssignButton
        trace add variable $options(-selected_date) write [mymethod RefreshAssignButton]
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

        if {!$worker_active} { set delete_text "borrar" }

        $delete configure -state normal
        $cancel configure -state normal
        if {$worker_weight > $lower_weight} {$up configure -state normal}
        if {$worker_weight < $upper_weight} {$down configure -state normal}
    }

    method RefreshAssignButton {args} {
        if {$options(-selected_date) == "" || $options(-selected_worker_id) == ""} {return}

        upvar $options(-selected_date) selected_date
        upvar $options(-selected_worker_id) selected_worker_id

        set worker_active [db onecolumn {SELECT active FROM workers WHERE id = :selected_worker_id}]

        if {$selected_worker_id != -1 && $worker_active && $selected_date != 0} {
            $assign configure -state normal
        } else {
            $assign configure -state disabled
        }
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
        if {[tk_messageBox -type yesno -icon question -title "Dar de baja" -message "¿Seguro que desea dar de baja a $name? Todas sus guardias y vacaciones planificadas serán eliminadas"] == yes} {
            db transaction {
                set tomorrow [clock format now -format "%d/%m/%Y 00:00:00"]
                set tomorrow_date [clock scan $tomorrow -format "%d/%m/%Y %H:%M:%S"]
                set tomorrow_date [clock add $tomorrow_date 1 day]

                db eval {
                    DELETE FROM schedules
                    WHERE worker_id = :id
                        AND date >= :tomorrow_date
                }

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
        if {[tk_messageBox -type yesno -icon question -title "Borrar" -message "¿Seguro que desea borrar a $name? Esto borrará todo su registro histórico"] == yes} {
            db transaction {
                db eval {DELETE FROM schedules WHERE worker_id = :id}

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

    method Assign {args} {
        upvar $options(-selected_date) selected_date
        upvar $options(-selected_worker_id) selected_worker_id
        upvar $options(-revisions) revisions

        db eval {
            INSERT INTO schedules (worker_id, date)
            VALUES (:selected_worker_id, :selected_date)
            ON CONFLICT (date) DO UPDATE
            SET worker_id = :selected_worker_id
        }

        incr revisions(workers)
    }
}
