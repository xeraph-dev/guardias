snit::widget workers-panel {
    hulltype ttk::frame

    component tabs
    component lists_tab

    delegate method * to hull
    delegate option * to hull

    constructor args {
        install tabs using ttk::notebook $win.tabs
        install lists_tab using workers-lists $win.tabs.lists

        $tabs add $lists_tab -text [mc workers.lists-tab]

        pack $tabs -fill both -expand yes

        $self configurelist $args
    }
}
