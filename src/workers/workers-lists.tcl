snit::widget workers-lists {
    hulltype ttk::frame

    component active_list
    component active_actions

    delegate method * to hull
    delegate option * to hull

    propagate -revisions to {active_list active_actions}

    constructor args {
        install active_list    using workers-active-list    $win.active
        install active_actions using workers-active-actions $win.active_actions

        pack $active_list    -fill both -expand yes -pady {0 4}
        pack $active_actions -fill x    -expand yes

        $self configurelist $args
    }
}
