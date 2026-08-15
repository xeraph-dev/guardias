snit::widget CalendarPaginator {
    hulltype ttk::frame

    component prev_button
    component month_selector
    component separator
    component year_selector
    component next_button

    option -calendar_date -configuremethod ConfigureCalendarDateOption

    delegate option * to hull
    delegate method * to hull

    constructor {args} {
        set months [lmap month [lseq 1 to 12] {
            set time [clock scan $month -format %N]
            clock format $time -format %B
        }]

        install prev_button using ttk::button $win.prev -text "<" -command [mymethod PrevMonth]
        install month_selector using ttk::combobox $win.month -values $months -state readonly -width 8
        install separator using ttk::label $win.separator -text "-"
        install year_selector using ttk::spinbox $win.year -from 2000 -to 2100 -increment 1 -state readonly -width 8 -command [mymethod UpdateCalendarDate]
        install next_button using ttk::button $win.next -text ">" -command [mymethod NextMonth]

        grid $prev_button -row 0 -column 1 -padx 4
        grid $month_selector -row 0 -column 2 -padx 4
        grid $separator -row 0 -column 3 -padx 4
        grid $year_selector -row 0 -column 4 -padx 4
        grid $next_button -row 0 -column 5 -padx 4

        grid columnconfigure $win 0 -weight 1 -uniform spacers
        grid columnconfigure $win 1 -weight 0 -uniform buttons
        grid columnconfigure $win 5 -weight 0 -uniform buttons
        grid columnconfigure $win 6 -weight 1 -uniform spacers

        bind $month_selector <<ComboboxSelected>> [mymethod UpdateCalendarDate]

        $self configurelist $args
    }

    destructor {
        try {trace remove variable $options(-calendar_date) write [mymethod CalendarDateChanged]}
    }

    method ConfigureCalendarDateOption {option value} {
        set options($option) $value
        $self CalendarDateChanged
        trace add variable $options(-calendar_date) write [mymethod CalendarDateChanged]
    }

    method CalendarDateChanged {args} {
        upvar $options(-calendar_date) calendar_date
        $month_selector set [clock format $calendar_date -format %B]
        $year_selector set [clock format $calendar_date -format %Y]
    }

    method UpdateCalendarDate {args} {
        upvar $options(-calendar_date) calendar_date
        set month [$month_selector get]
        set year [$year_selector get]
        set new_calendar_date [clock scan "01/$month/$year" -format "01/%B/%Y"]
        if {$new_calendar_date != $calendar_date} { set calendar_date $new_calendar_date }
    }

    method PrevMonth {args} {
        upvar $options(-calendar_date) calendar_date
        set calendar_date [clock add $calendar_date -1 month]
    }

    method NextMonth {args} {
        upvar $options(-calendar_date) calendar_date
        set calendar_date [clock add $calendar_date 1 month]
    }
}
