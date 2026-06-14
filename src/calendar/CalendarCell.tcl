snit::widget CalendarCell {
    delegate option * to hull
    delegate method * to hull

    option -date
    option -cell_date
    option -selected_date

    constructor {args} {
        $self configurelist $args

        set label [ttk::label $win.label]
        set worker [ttk::label $win.worker]
        $self update

        pack $label -side right -anchor n
        pack $worker -side left -anchor center -padx 4

        bind $win.label <Button-1> [mymethod on_click]
        bind $win.worker <Button-1> [mymethod on_click]
        bind $win <Button-1> [mymethod on_click]

        trace add variable $options(-date) write [mymethod update]
        trace add variable $options(-selected_date) write [mymethod update]
    }

    destructor {
        trace remove variable $options(-date) write [mymethod update]
        trace remove variable $options(-selected_date) write [mymethod update]
    }

    method on_click {} {
        set $options(-selected_date) $options(-cell_date)
    }

    method update {args} {
        upvar $options(-date) date
        upvar $options(-selected_date) selected_date

        $win.label configure -text [clock format $options(-cell_date) -format %d]

        set date_month [clock format $date -format %B]
        set cell_month [clock format $options(-cell_date) -format %B]

        set now_date_str [clock format [clock seconds] -format "%d/%m/%Y 00:00:00"]
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

        $win.worker configure -text ""
        db eval {SELECT workers.name FROM workers
                 INNER JOIN calendar ON workers.id = calendar.worker_id
                 WHERE calendar.date = $options(-cell_date)} {
            $win.worker configure -text $name
        }
    }
}
