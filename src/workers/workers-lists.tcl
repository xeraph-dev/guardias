snit::widget workers-lists {
    hulltype ttk::frame

    component active_list

    delegate method * to hull
    delegate option * to hull

    constructor args {
        install active_list using workers-active-list $win.active

        pack $active_list -fill x -expand yes

        $self configurelist $args
    }
}
