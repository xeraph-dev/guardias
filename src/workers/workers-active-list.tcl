snit::widget workers-active-list {
    hulltype ttk::frame

    component tree
    component actions

    delegate method * to hull
    delegate option * to hull

    constructor args {
        install tree using ttk::treeview $win.tree
        install actions using workers-active-list-actions $win.actions

        pack $tree -fill both -expand yes
        pack $actions -fill x -expand yes

        $self configurelist $args
    }
}
