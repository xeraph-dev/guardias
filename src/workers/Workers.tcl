snit::widget Workers {
    hulltype ttk::frame

    component add
    component actions
    component active
    component inactive
    component active_list
    component inactive_list

    delegate option -selected_date to actions

    delegate option * to hull
    delegate method * to hull

    propagate -selected_worker_id to {add actions active_list inactive_list}
    propagate -revisions to {add actions active_list inactive_list}

    constructor {args} {
        install add using WorkersAdd $win.add
        install actions using WorkersActions $win.actions
        install active using ttk::labelframe $win.active -text "Trabajadores activos"
        install inactive using ttk::labelframe $win.inactive -text "Trabajadores de baja"
        install active_list using WorkersList $active.list -active yes
        install inactive_list using WorkersList $inactive.list -active no

        pack $active_list -fill both -expand yes
        pack $inactive_list -fill both -expand yes

        pack $add $actions -fill x -pady 4
        pack $active -fill both -expand yes -pady 4
        pack $inactive -fill both -pady 4

        $self configurelist $args
    }
}
