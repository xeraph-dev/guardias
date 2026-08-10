snit::widget WorkersPanelList {
    delegate option * to hull
    delegate method * to hull

    option -selected_worker_id

    constructor {args} {
        $self configurelist $args

        set tree [ttk::treeview $win.tree -columns {id name weight} -displaycolumns {name} -show {}]
        set scroll [ttk::scrollbar $win.scroll -orient vertical -command [list $tree yview]]
        $tree configure -yscrollcommand [list $scroll set]
        $tree configure -selectmode browse

        $self update_list

        pack $tree -side left -fill both -expand yes
        pack $scroll -side right -fill y

        bind $tree <<TreeviewSelect>> [mymethod worker_selected]
    }

    method update_list {} {
        $win.tree delete [$win.tree children {}]
        store worker get_all {
            $win.tree insert {} end -id $id -values [list $id $name $weight]
        }
    }

    method worker_selected {args} {
        upvar $options(-selected_worker_id) selected_worker_id

        set sel [$win.tree selection]
        if {$sel == ""} {
            return
        }

        set values [$win.tree item $sel -values]
        lassign $values id
        set selected_worker_id $id
    }
}
