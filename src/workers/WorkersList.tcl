snit::widget WorkersList {
    hulltype ttk::frame

    component tree
    component scroll

    option -selected_worker_id -configuremethod ConfigureSelectedworkerIdOption
    option -revisions -configuremethod ConfigureRevisionsOption
    option -active -readonly yes

    delegate option * to hull
    delegate method * to hull

    constructor {args} {
        install tree using ttk::treeview $win.tree -columns {id name weight} -displaycolumns {name} -show {}
        install scroll using ttk::scrollbar $win.scroll -orient vertical -command [list $tree yview]
        $tree configure -yscrollcommand [list $scroll set]
        $tree configure -selectmode browse

        pack $tree -side left -fill both -expand yes
        pack $scroll -side right -fill y

        bind $tree <<TreeviewSelect>> [mymethod Select]

        $self configurelist $args

        $self Refresh
    }

    destructor {
        try {trace remove variable $options(-revisions)(workers) write [mymethod Refresh]}
    }

    method ConfigureSelectedworkerIdOption {option value} {
        set options($option) $value
        $self SelectedWorkerIdChanged
        trace add variable $options(-selected_worker_id) write [mymethod SelectedWorkerIdChanged]
    }

    method ConfigureRevisionsOption {option value} {
        set options($option) $value
        trace add variable $options(-revisions)(workers) write [mymethod Refresh]
    }

    method SelectedWorkerIdChanged {args} {
        upvar $options(-selected_worker_id) selected_worker_id
        if {![$tree exists $selected_worker_id] || $selected_worker_id == -1} {
            $tree selection remove [$tree selection]
        }
    }

    method Refresh {args} {
        upvar $options(-selected_worker_id) selected_worker_id


        set active [expr {bool($options(-active))}]
        $tree delete [$tree children {}]
        db eval {SELECT id, name, weight FROM workers WHERE active = :active ORDER BY weight ASC} {
            $tree insert {} end -id $id -values [list $id $name $weight]
        }

        if {$options(-selected_worker_id) != "" && $selected_worker_id != -1 && [$tree exists $selected_worker_id]} {
            $win.tree selection set $selected_worker_id
        }
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
