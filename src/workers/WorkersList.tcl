snit::widget WorkersList {
    hulltype ttk::frame

    component tree
    component scroll

    option -selected_worker_id

    delegate option * to hull
    delegate method * to hull

    constructor {args} {
        install tree using ttk::treeview $win.tree -columns {id name weight} -displaycolumns {name} -show {}
        install scroll using ttk::scrollbar $win.scroll -orient vertical -command [list $tree yview]
        $tree configure -yscrollcommand [list $scroll set]
        $tree configure -selectmode browse

        pack $tree -side left -fill both -expand yes
        pack $scroll -side right -fill y

        bind . <<WorkerCreated>> [mymethod Refresh]
        bind . <<WorkerUpdated>> [mymethod Update %d]
        bind . <<WorkerDeleted>> [mymethod Delete %d]
        bind . <<WorkerUp>> [mymethod Up %d]
        bind . <<WorkerDown>> [mymethod Down %d]
        bind . <<WorkerEditCanceled>> [mymethod Cancel]
        bind $tree <<TreeviewSelect>> [mymethod Select]

        $self configurelist $args

        $self Refresh
    }

    method Refresh {args} {
        $tree delete [$tree children {}]
        db eval {SELECT id, name, weight FROM workers ORDER BY weight ASC} {
            $tree insert {} end -id $id -values [list $id $name $weight]
        }
    }

    method Update {worker_id} {
        db eval {SELECT id, name, weight weight FROM workers WHERE id = :worker_id} {
            $tree item $id -values [list $id $name $weight]
        }
    }

    method Delete {worker_id} {
        $tree delete $worker_id
    }

    method Up {worker_id} {
        set index [$tree index $worker_id]
        $tree move $worker_id {} [expr {$index - 1}]
    }

    method Down {worker_id} {
        set index [$tree index $worker_id]
        $tree move $worker_id {} [expr {$index + 1}]
    }

    method Cancel {} {
        $tree selection remove [$tree selection]
    }

    method Select {args} {
        upvar $options(-selected_worker_id) selected_worker_id

        set sel [$tree selection]
        if {$sel == ""} {return}

        set values [$tree item $sel -values]
        lassign $values worker_id
        set selected_worker_id $worker_id
    }
}
