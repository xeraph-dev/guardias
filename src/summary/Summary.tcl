snit::widget Summary {
    hulltype ttk::frame

    component tree
    component scroll

    option -calendar_date -configuremethod ConfigureCalendarDateOption
    option -revisions -configuremethod ConfigureRevisionsOption

    delegate option * to hull
    delegate method * to hull

    constructor {args} {
        install tree using ttk::treeview $win.tree -columns {id name duties} -displaycolumns {name duties} -show headings -selectmode none
        install scroll using ttk::scrollbar $win.scroll -orient vertical -command [list $tree yview]
        $tree configure -yscrollcommand [list $scroll set]
        $tree heading name -text "Trabajador"
        $tree heading duties -text "Vacaciones"
        $tree column name -minwidth 80
        $tree column duties -minwidth 80 -width 80
        $tree column duties -anchor e

        pack $tree -side left -fill both -expand yes
        pack $scroll -side right -fill y

        $self configurelist $args

        $self Refresh
    }

    destructor {
        try {trace remove variable $options(-revisions)(workers) write [mymethod Refresh]}
        try {trace remove variable $options(-calendar_date) write [mymethod Refresh]}
    }

    method ConfigureRevisionsOption {option value} {
        set options($option) $value
        trace add variable $options(-revisions)(workers) write [mymethod Refresh]
    }

    method ConfigureCalendarDateOption {option value} {
        set options($option) $value
        trace add variable $options(-calendar_date) write [mymethod Refresh]
    }

    method Refresh {args} {
        upvar $options(-calendar_date) calendar_date

        set first_month_day [clock format $calendar_date -format "01/%m/%Y 00:00:00"]
        set first_month_day_date [clock scan $first_month_day -format "%d/%m/%Y %H:%M:%S"]

        set last_month_day_date [clock add $first_month_day_date 1 month -1 day]

        $tree delete [$tree children {}]
        db eval {
            SELECT workers.id, workers.name, COUNT(schedules.id) as vacations FROM workers
            INNER JOIN schedules ON workers.id = schedules.worker_id
            WHERE schedules.date BETWEEN :first_month_day_date AND :last_month_day_date
            GROUP BY workers.id
        } {
            $tree insert {} end -id $id -values [list $id $name $vacations]
        }
    }
}
