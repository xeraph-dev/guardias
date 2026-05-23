snit::widget App {
    delegate option * to hull
    delegate method * to hull

    variable worker_id -1

    constructor {args} {
        $self configurelist $args

        set calendar [Calendar $win.calendar -worker_id [myvar worker_id]]
        set workers_panel [WorkersPanel $win.workers -worker_id [myvar worker_id]]

        pack $calendar -side left -fill both -expand yes -padx 4
        pack $workers_panel -side left -fill y -padx 4

        bind $workers_panel <<EditingCanceled>> [mymethod cancel_editing]
        bind $workers_panel <<WorkerDeleted>> [mymethod cancel_editing]
    }

    method cancel_editing {args} {
        set worker_id -1
        $win.calendar unselect_date
    }
}
