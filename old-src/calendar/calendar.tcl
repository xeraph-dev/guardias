snit::widget calendar {
    hulltype ttk::frame

    component paginator
    component grid

    delegate option -selected_date to grid
    delegate option -calendar_workers to grid

    delegate method * to hull
    delegate option * to hull

    propagate -calendar_date to {paginator grid}

    constructor args {
        install paginator using calendar-paginator $win.paginator
        install grid using calendar-grid $win.grid

        pack $paginator -fill x -padx 4 -pady 4
        pack $grid -fill both -expand yes -padx 4 -pady 4

        $self configurelist $args
    }
}
