snit::widget workers-active-list {
    hulltype ttk::frame

    component tree
    component scroll

    option -revisions -configuremethod Configure-revisions

    delegate method * to hull
    delegate option * to hull

    constructor args {
        install tree using ttk::treeview $win.tree -columns {name} -show {} -selectmode browse
        install scroll using ttk::scrollbar $win.scroll -orient vertical -command [list $tree yview]

        pack $tree -side left -fill both -expand yes
        pack $scroll -side right -fill y

        $tree configure -yscrollcommand [list $scroll set]

        $self configurelist $args

        $self Refresh
    }

    destructor {
        try {trace remove variable $options(-revisions) write [mymethod Refresh]}
    }

    method Configure-revisions {option value} {
        set options($option) $value

        trace add variable $options($option) write [mymethod Refresh]
    }

    method Refresh args {
        $tree delete [$tree children {}]
        db eval {SELECT id, name FROM workers WHERE active ORDER BY weight} {
            $tree insert {} end -id $id -values [list $name]
        }
    }
}
