snit::widget Calendar {
    hulltype ttk::frame

    component paginator
    component grid

    delegate option -date to paginator
    delegate option -worker_id to paginator

    delegate option * to hull
    delegate method * to hull

    variable selected_date {}

    constructor {args} {
        install paginator using CalendarPaginator $win.paginator -selected_date [myvar selected_date]
        install grid using CalendarGrid $win.grid

        pack $paginator -fill x -padx 4 -pady 4
        pack $grid -fill both -expand yes -padx 4 -pady 4

        $self configurelist $args
    }
}
