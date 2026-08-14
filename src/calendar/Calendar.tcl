snit::widget Calendar {
    hulltype ttk::frame

    component paginator
    component grid

    delegate option -selected_worker_id to paginator
    delegate option -calendar_workers to grid

    delegate option * to hull
    delegate method * to hull

    propagate -calendar_date to {paginator grid}

    variable selected_date 0

    constructor {args} {
        install paginator using CalendarPaginator $win.paginator -selected_date [myvar selected_date]
        install grid using CalendarGrid $win.grid -selected_date [myvar selected_date]

        pack $paginator -fill x -padx 4 -pady 4
        pack $grid -fill both -expand yes -padx 4 -pady 4

        $self configurelist $args
    }
}
