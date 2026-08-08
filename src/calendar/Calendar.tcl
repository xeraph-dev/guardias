snit::widget Calendar {
    delegate option * to hull
    delegate method * to hull

    variable date {}

    option -selected_date
    option -selected_worker_id

    constructor {args} {
        $self configurelist $args

        set date_str [clock format [clock seconds] -format "01/%m/%Y 00:00:00"]
        set date [clock scan $date_str -format "%d/%m/%Y %H:%M:%S"]

        set paginator [CalendarPaginator $win.paginator -date [myvar date] -selected_date $options(-selected_date) -selected_worker_id $options(-selected_worker_id)]
        set grid [CalendarGrid $win.grid -date [myvar date] -selected_date $options(-selected_date)]

        pack $paginator -fill x -padx 4 -pady 4
        pack $grid -fill both -expand yes -padx 4 -pady 4
    }
}
