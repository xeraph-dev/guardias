
snit::widget WorkersPanelList {
    delegate option * to hull
    delegate method * to hull

    option -worker_id

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
        db eval {SELECT id, name, weight FROM workers ORDER BY weight ASC} {
            $win.tree insert {} end -id $id -values [list $id $name $weight]
        }
    }

    method recover_selection {} {
        upvar $options(-worker_id) id
        set sel [$win.tree selection]
        if {$sel == "" && $id != -1} {
            $win.tree selection add $id
        }
    }

    method cancel_editing {} {
        $win.tree selection remove [$win.tree selection]
    }

    method worker_selected {args} {
         set sel [$win.tree selection]
         if {$sel == ""} {
             return
         }

         set values [$win.tree item $sel -values]
         lassign $values id
         set $options(-worker_id) $id
    }
}
