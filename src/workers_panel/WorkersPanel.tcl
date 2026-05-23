

snit::widgetadaptor WorkersPanel {
    delegate option * to hull
    delegate method * to hull

    option -worker_id

    constructor {args} {
        installhull using ttk::labelframe -text "Plantilla"
        $self configurelist $args

        set add [WorkersPanelAdd $win.add -worker_id $options(-worker_id)]
        set actions [WorkersPanelActions $win.actions -worker_id $options(-worker_id)]
        set list [WorkersPanelList $win.list -worker_id $options(-worker_id)]

        pack $add $actions -fill x -pady 4
        pack $list -fill both -expand yes -pady 4

        bind $add <<WorkerSaved>> [mymethod worker_saved]
        bind $actions <<EditingCanceled>> [mymethod cancel_editing]
        bind $actions <<WorkerDeleted>> [mymethod worker_deleted]
        bind $actions <<WorkerReordered>> [mymethod worker_reordered]
    }

    method worker_saved {args} {
        $win.list update_list

        event generate $win <<WorkerSaved>>
    }

    method worker_deleted {args} {
        $win.add cancel_editing
        $win.list cancel_editing
        $win.list update_list

        event generate $win <<WorkerDeleted>>
    }

    method cancel_editing {args} {
        $win.add cancel_editing
        $win.list cancel_editing

        event generate $win <<EditingCanceled>>
    }

    method worker_reordered {args} {
        $win.list update_list
        $win.list recover_selection
        $win.actions worker_id_updated

        event generate $win <<WorkerReordered>>
    }
}
