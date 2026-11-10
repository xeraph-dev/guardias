snit::widget calendar-cell {
    hulltype ttk::frame

    component day
    component names

    option -calendar_date
    option -selected_date -configuremethod configure-selected_date
    option -cell_date -configuremethod configure-cell_date
    option -calendar_workers -configuremethod configure-calendar_workers

    delegate method * to hull
    delegate option * to hull

    variable day_text {}
    variable names_text {}

    constructor args {
        install day using ttk::label $win.day -textvariable [myvar day_text]
        install names using ttk::label $win.names -textvariable [myvar names_text] -wraplength 80

        pack $day -anchor ne -padx 4 -pady 4
        pack $names -anchor center -padx 4

        bind $win <Button-1> [mymethod on_click]
        bind $day <Button-1> [mymethod on_click]
        bind $names <Button-1> [mymethod on_click]

        $self configurelist $args
    }

    destructor {
        try {trace remove variable $options(-selected_date) write [mymethod refresh]}
        try {trace remove variable $options(-calendar_workers) write [mymethod refresh_worker_name]}
    }

    method configure-selected_date {option value} {
        set options($option) $value
        $self refresh
        trace add variable $options(-selected_date) write [mymethod refresh]
    }

    method configure-cell_date {option value} {
        set options($option) $value
        $self refresh
    }

    method configure-calendar_workers {option value} {
        set options($option) $value
        $self refresh_worker_name
        trace add variable $options(-calendar_workers) write [mymethod refresh_worker_name]
    }

    method refresh args {
        if {$options(-calendar_date) == {} || $options(-cell_date) == {}} { return }

        upvar $options(-calendar_date) calendar_date
        upvar $options(-selected_date) selected_date

        set calendar_month [clock format $calendar_date -format %B]
        set cell_day [clock format $options(-cell_date) -format %d]
        set cell_month [clock format $options(-cell_date) -format %B]
        set cell_month_short [clock format $options(-cell_date) -format %b]

        set day_text [clock format $options(-cell_date) -format %d]
        if {$cell_day == 1} { append day_text " $cell_month_short" }

        set now_date_str [clock format now -format "%d/%m/%Y 00:00:00"]
        set now_date [clock scan $now_date_str -format "%d/%m/%Y %H:%M:%S"]

        set foreground {}
        if {$calendar_month != $cell_month} { set foreground grey }
        if {$options(-cell_date) == $now_date} { set foreground red }
        if {$options(-cell_date) == $selected_date} { set foreground orange }

        $day configure -foreground $foreground
        $names configure -foreground $foreground

        $self refresh_worker_name
    }

    method refresh_worker_name args {
        if {$options(-calendar_workers) == {}} {return}
        upvar $options(-calendar_workers) calendar_workers

        set workers_names {}
        if {[dict exists $calendar_workers $options(-cell_date)]} {
            dict for {worker_id worker_name} [dict get $calendar_workers $options(-cell_date)] {
                lappend workers_names $worker_name
            }
        }
        set names_text [join $workers_names "\n"]
    }

    method on_click args {
        upvar $options(-selected_date) selected_date
        if {$options(-cell_date) != $selected_date} { set selected_date $options(-cell_date) }
    }
}
