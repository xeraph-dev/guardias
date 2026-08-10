snit::widget WorkersPanel {
    delegate option * to hull
    delegate method * to hull

    option -selected_worker_id

    constructor {args} {
        $self configurelist $args

        set list [WorkersPanelList $win.list -selected_worker_id $options(-selected_worker_id)]

        pack $list -fill both -expand yes -pady 4
    }
}
