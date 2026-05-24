snit::widget CalendarCell {
    delegate option * to hull
    delegate method * to hull

    option -date
    option -cell_date
    option -selected_date

    constructor {args} {
        $self configurelist $args

        set label [ttk::label $win.label]
        $self update_label

        pack $label -side right -anchor n

        bind $win.label <Button-1> [mymethod on_click]
        bind $win <Button-1> [mymethod on_click]

        trace add variable $options(-date) write [mymethod update_label]
        trace add variable $options(-selected_date) write [mymethod update_label]
    }

    destructor {
        trace remove variable $options(-date) write [mymethod update_label]
        trace remove variable $options(-selected_date) write [mymethod update_label]
    }

    method on_click {} {
        set $options(-selected_date) $options(-cell_date)
    }

    method update_label {args} {
        upvar $options(-date) date
        upvar $options(-selected_date) selected_date

        $win.label configure -text [clock format $options(-cell_date) -format %d]

        set date_month [clock format $date -format %B]
        set cell_month [clock format $options(-cell_date) -format %B]

        set now_date_str [clock format now -format "%d/%m/%Y 00:00:00"]
        set now_date [clock scan $now_date_str -format "%d/%m/%Y %H:%M:%S"]

        $win.label configure -foreground {}
        if {$date_month != $cell_month} {
            $win.label configure -foreground grey
        }
        if {$options(-cell_date) == $now_date} {
            $win.label configure -foreground red
        }
        if {$options(-cell_date) == $selected_date} {
            $win.label configure -foreground orange
        }
    }
}
