snit::widget CalendarPaginator {
    hulltype ttk::frame

    component title_label
    component prev_button
    component today_button
    component next_button

    option -calendar_date -configuremethod ConfigureCalendarDateOption

    delegate option * to hull
    delegate method * to hull

    variable title_text ""

    constructor {args} {
        install title_label using ttk::label $win.title_button -textvariable [myvar title_text]
        install prev_button using ttk::button $win.prev_button -text "<" -command [mymethod PrevMonth]
        install today_button using ttk::button $win.today_button -text "hoy" -command [mymethod Today]
        install next_button using ttk::button $win.next_button -text ">" -command [mymethod NextMonth]

        pack $title_label -side left -fill both -expand true -padx 4
        pack $prev_button $today_button $next_button -side left -fill both -padx 4

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
        set month [clock format $calendar_date -format %B]
        set year [clock format $calendar_date -format %Y]
        set title_text "$month $year"
    }

    method PrevMonth {args} {
        upvar $options(-calendar_date) calendar_date
        set calendar_date [clock add $calendar_date -1 month]
    }

    method NextMonth {args} {
        upvar $options(-calendar_date) calendar_date
        set calendar_date [clock add $calendar_date 1 month]
    }

    method Today {args} {
        upvar $options(-calendar_date) calendar_date
        set calendar_date_str [clock format [clock seconds] -format "01/%m/%Y 00:00:00"]
        set calendar_date [clock scan $calendar_date_str -format "%d/%m/%Y %H:%M:%S"]
    }
}
