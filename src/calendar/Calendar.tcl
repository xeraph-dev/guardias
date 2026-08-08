snit::widget Calendar {
    delegate option * to hull
    delegate method * to hull

    option -worker_id

    variable date {}
    variable selected_date {}

    constructor {args} {
        $self configurelist $args

        set date_str [clock format [clock seconds] -format "01/%m/%Y 00:00:00"]
        set date [clock scan $date_str -format "%d/%m/%Y %H:%M:%S"]

        set paginator [CalendarPaginator $win.paginator -date [myvar date] -selected_date [myvar selected_date]]
        set grid [CalendarGrid $win.grid -date [myvar date] -selected_date [myvar selected_date]]


        pack $paginator -fill x -padx 4 -pady 4
        pack $grid -fill both -expand yes -padx 4 -pady 4

        trace add variable selected_date write [mymethod date_selected]
    }

    destructor {
        trace remove variable selected_date write [mymethod date_selected]
    }

    method date_selected {args} {
        puts [clock format $selected_date -format %D]
    }
}
