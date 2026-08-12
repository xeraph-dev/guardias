snit::widget Workers {
    hulltype ttk::frame

    component add
    component actions
    component list

    delegate option * to hull
    delegate method * to hull

    propagate -selected_worker_id to {add actions list}

    constructor {args} {
        install add using WorkersAdd $win.add
        install actions using WorkersActions $win.actions
        install list using WorkersList $win.list

        pack $add $actions -fill x -pady 4
        pack $list -fill both -expand yes -pady 4

        $self configurelist $args
    }
}
