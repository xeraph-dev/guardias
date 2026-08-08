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

        pack $paginator -fill x -padx 4 -pady 4
    }
}
