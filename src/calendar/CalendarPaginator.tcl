snit::widget CalendarPaginator {
    hulltype ttk::frame

    component prev_button
    component month_selector
    component separator
    component year_selector
    component next_button
    component assign_button

    option -date -configuremethod configure_date_option
    option -worker_id -readonly yes -configuremethod configure_worker_id
    option -selected_date -readonly yes

    delegate option * to hull
    delegate method * to hull

    constructor {args} {
        set months {}
        for {set month 1} {$month <= 12} {incr month} {
            set time [clock scan $month -format %N]
            lappend months [clock format $time -format %B]
        }

        install prev_button using ttk::button $win.prev -text "<" -command [mymethod prev_month]
        install month_selector using ttk::combobox $win.month -values $months -state readonly -width 8
        install separator using ttk::label $win.separator -text "-"
        install year_selector using ttk::spinbox $win.year -from 2000 -to 2100 -increment 1 -state readonly -width 8 -command [mymethod update_date]
        install next_button using ttk::button $win.next -text ">" -command [mymethod next_month]
        install assign_button using ttk::button $win.asign -text "assign" -command [mymethod assign] -state disabled

        grid $prev_button -row 0 -column 2 -padx 4
        grid $month_selector -row 0 -column 3 -padx 4
        grid $separator -row 0 -column 4 -padx 4
        grid $year_selector -row 0 -column 5 -padx 4
        grid $next_button -row 0 -column 6 -padx 4
        grid $assign_button -row 0 -column 8 -padx 4

        grid columnconfigure $win 0 -weight 0 -uniform actions
        grid columnconfigure $win 1 -weight 1 -uniform spacers
        grid columnconfigure $win 2 -weight 0 -uniform buttons
        grid columnconfigure $win 6 -weight 0 -uniform buttons
        grid columnconfigure $win 7 -weight 1 -uniform spacers
        grid columnconfigure $win 8 -weight 0 -uniform actions

        bind $month_selector <<ComboboxSelected>> [mymethod update_date]

        $self configurelist $args
    }

    destructor {
        try {
            trace remove variable $options(-date) write [mymethod date_changed]
        }
    }

    method configure_date_option {option value} {
        set options($option) $value
        $self date_changed
        trace add variable $options(-date) write [mymethod date_changed]
    }

    method configure_worker_id {option value} {
        set options($option) $value
        $self worker_id_changed
        trace add variable $options(-worker_id) write [mymethod worker_id_changed]
    }

    method date_changed {args} {
        upvar $options(-date) date
        $month_selector set [clock format $date -format %B]
        $year_selector set [clock format $date -format %Y]
    }

    method worker_id_changed {args} {
        upvar $options(-selected_date) selected_date
        upvar $options(-worker_id) worker_id

        if {$worker_id != -1 && selected_Date != 0} {
            $assign_button configure -state normal
        } else {
            $assign_button configure -state disabled
        }
    }

    method update_date {args} {
        upvar $options(-date) date
        set month [$month_selector get]
        set year [$year_selector get]
        set date [clock scan "01/$month/$year" -format "01/%B/%Y"]
    }

    method prev_month {args} {
        upvar $options(-date) date
        set date [clock add $date -1 month]
    }

    method next_month {args} {
        upvar $options(-date) date
        set date [clock add $date 1 month]
    }

    method assign {args} {
        upvar $options(-selected_date) selected_date
        upvar $options(-worker_id) worker_id

        db eval {
            INSERT INTO calendar (worker_id, date)
            VALUES (:worker_id, :selected_date)
            ON CONFLICT (date) DO UPDATE
            SET worker_id = :worker_id
        }
    }
}
