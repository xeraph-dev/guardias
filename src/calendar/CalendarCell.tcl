snit::widget CalendarCell {
    hulltype ttk::frame

    component day
    component names

    option -calendar_date
    option -selected_date -configuremethod ConfigureSelectedDateOption
    option -cell_date -configuremethod ConfigureCellDateOption
    option -calendar_workers -configuremethod ConfigureCalendarWorkersOption

    delegate option * to hull
    delegate method * to hull

    variable day_text {}
    variable names_text {}

    constructor {args} {
        install day using ttk::label $win.day -textvariable [myvar day_text]
        install names using ttk::label $win.names -textvariable [myvar names_text] -foreground cyan -wraplength 80

        pack $day -anchor ne -padx 4 -pady 4
        pack $names -anchor center -padx 4

        bind $win <Button-1> [mymethod OnClick]
        bind $day <Button-1> [mymethod OnClick]
        bind $names <Button-1> [mymethod OnClick]

        $self configurelist $args
    }

    destructor {
        try {trace remove variable $options(-selected_date) write [mymethod RefreshDates]}
        try {trace remove variable $options(-calendar_workers) write [mymethod RefreshCalendarWorkersNames]}
    }

    method ConfigureSelectedDateOption {option value} {
        set options($option) $value
        $self RefreshDates
        trace add variable $options(-selected_date) write [mymethod RefreshDates]
    }

    method ConfigureCellDateOption {option value} {
        set options($option) $value
        $self RefreshDates
    }

    method ConfigureCalendarWorkersOption {option value} {
        set options($option) $value
        $self RefreshCalendarWorkersNames
        trace add variable $options(-calendar_workers) write [mymethod RefreshCalendarWorkersNames]
    }

    method RefreshDates {args} {
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

        $day configure -foreground {}
        if {$calendar_month != $cell_month} { $day configure -foreground grey }
        if {$options(-cell_date) == $now_date} { $day configure -foreground red }
        if {$options(-cell_date) == $selected_date} { $day configure -foreground orange }

        $self RefreshCalendarWorkersNames
    }

    method RefreshCalendarWorkersNames {args} {
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

    method OnClick {args} {
        upvar $options(-selected_date) selected_date
        if {$options(-cell_date) != $selected_date} { set selected_date $options(-cell_date) }
    }
}
