snit::widget Calendar {
    delegate option * to hull
    delegate method * to hull

    option -worker_id

    set months {}
    set days {}

    variable date {}
    variable selected_date {}

    constructor {args} {
        $self configurelist $args

        set date_str [clock format [clock seconds] -format "01/%m/%Y 00:00:00"]
        set date [clock scan $date_str -format "%d/%m/%Y %H:%M:%S"]

        for {set month 1} {$month <= 12} {incr month} {
            set time [clock scan $month -format %N]
            lappend months [clock format $time -format %B]
        }

        for {set day 1} {$day <= 7} {incr day} {
            set time [clock scan $day -format %u]
            lappend days [clock format $time -format %A]
        }

        set paginator [CalendarPaginator $win.paginator -months $months -date [myvar date] -selected_date [myvar selected_date] -worker_id $options(-worker_id)]
        set grid [CalendarGrid $win.grid -days $days -date [myvar date] -selected_date [myvar selected_date]]

        pack $paginator -fill x -padx 4 -pady 4
        pack $grid -fill both -expand yes -padx 4 -pady 4

        bind $paginator <<WorkerAssigned>> [mymethod worker_assigned]

        trace add variable date write [mymethod date_changed]
        trace add variable selected_date write [mymethod date_selected]
    }

    destructor {
        trace remove variable date write [mymethod date_changed]
        trace remove variable selected_date write [mymethod date_selected]
    }

    method worker_assigned {args} {
        $win.grid update_cells
    }

    method date_changed {args} {
        puts [clock format $date -format "%B/%Y"]
    }

    method date_selected {args} {
        puts [clock format $selected_date -format "%d/%B/%Y"]
    }

    method unselect_date {} {
        set selected_date 0
    }
}
