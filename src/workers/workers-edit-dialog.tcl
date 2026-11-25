snit::widgetadaptor workers-edit-dialog {
    component entry

    delegate method * to hull
    delegate option * to hull

    option -id -configuremethod Configure-id

    variable name {}

    constructor args {
        installhull using widget::dialog

        set frame [$self getframe]

        install entry using ttk::entry $frame.entry -textvariable [myvar name]

        pack $entry -fill both -expand yes -padx 4 -pady 4

        $self add button -text [mc common.cancel] -command [list $self close cancel]
        $self add button -text [mc common.save] -command [mymethod Save] -default active

        $self configurelist $args
        $self configure -focus $entry

        bind $win <Return> [mymethod Save]
    }

    method Configure-id {option value} {
        set options($option) $value

        if {$options(-id) > -1} {
            db eval {SELECT name FROM workers WHERE id = :options(-id)} {}
            $self configure -title [mc workers.dialog.edit.title $name]
        } else {
            set name {}
            $self configure -title [mc workers.dialog.edit.title-new]
        }
    }

    method Save {} {
        set name [string trim $name]

        try {
            if {$options(-id) > -1} {
                db eval {
                    UPDATE workers
                    SET name = :name
                    WHERE id = :options(-id)
                }
            } else {
                db eval {
                    INSERT INTO workers (name)
                    VALUES (:name)
                }
            }
        } on error {msg opts} {
            switch -regexp -nocase -matchvar m -- $msg {
                {^UNIQUE constraint failed: workers\.(\w+)} {
                    set key workers.dialog.edit.form.[lindex $m 1].unique
                }
                {^CHECK constraint failed: workers_(\w+?)_(\w+)$} {
                    set key workers.dialog.edit.form.[lindex $m 1].[lindex $m 2]
                }
                default {
                    return -options $opts $msg
                }
            }
            tk_messageBox -type ok -icon error -title [mc common.error] -message [mc $key]
            focus $entry
            return
        }

        $self close save
    }
}

proc show_workers_edit_dialog {parent {id -1}} {
    set win .edit_dialog
    defer {catch {destroy $win}}

    if {[winfo exists $win]} {
        $win configure -id $id
    } else {
        workers-edit-dialog $win -parent $parent -id $id
    }

    return [$win display]
}
