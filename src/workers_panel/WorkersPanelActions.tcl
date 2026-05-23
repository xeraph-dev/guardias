
snit::widget WorkersPanelActions {
    delegate option * to hull
    delegate option * to hull

    option -worker_id

    constructor {args} {
        $self configurelist $args

        set up [ttk::button $win.up -text "^" -command [mymethod worker_up] -state disabled]
        set down [ttk::button $win.down -text "v" -command [mymethod worker_down] -state disabled]
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

        set upper_weight 0
        set lower_weight 0
        set worker_weight 0

        db eval {SELECT weight FROM workers WHERE id = $id} {
            set worker_weight $weight
        }
        db eval {SELECT weight FROM workers ORDER BY weight ASC LIMIT 1} {
            set lower_weight $weight
        }
        db eval {SELECT weight FROM workers ORDER BY weight DESC LIMIT 1} {
            set upper_weight $weight
        }

        if {$id == -1} {
            $win.up configure -state disabled
            $win.down configure -state disabled
            $win.delete configure -state disabled
            $win.cancel configure -state disabled
        } else {
            $win.delete configure -state normal
            $win.cancel configure -state normal

            if {$worker_weight > $lower_weight} {
                $win.up configure -state normal
            } else {
                $win.up configure -state disabled
            }
            if {$worker_weight < $upper_weight} {
                $win.down configure -state normal
            } else {
                $win.down configure -state disabled
            }
        }
    }

    method worker_up {args} {
        upvar $options(-worker_id) id

        db eval {SELECT weight FROM workers WHERE id = $id} {
            db transaction {
                db eval {
                    UPDATE workers
                    SET weight = $weight
                    WHERE weight = $weight - 1;
                }
                db eval {
                    UPDATE workers
                    SET weight = $weight - 1
                    WHERE id = $id
                }
            }
            event generate $win <<WorkerReordered>>
        }
    }

    method worker_down {args} {
        upvar $options(-worker_id) id

        db eval {SELECT weight FROM workers WHERE id = $id} {
            db transaction {
                db eval {
                    UPDATE workers
                    SET weight = $weight
                    WHERE weight = $weight + 1;
                }
                db eval {
                    UPDATE workers
                    SET weight = $weight + 1
                    WHERE id = $id
                }
            }
            event generate $win <<WorkerReordered>>
        }
    }
}
