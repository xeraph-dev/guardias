
snit::widget CalendarPaginator {
    delegate option * to hull
    delegate method * to hull

    variable month
    variable year

    option -worker_id
    option -months
    option -date
    option -selected_date

    constructor {args} {
        $self configurelist $args

        upvar $options(-date) date

        set month [clock format $date -format %B]
        set year [clock format $date -format %Y]

        set prev_button [ttk::button $win.prev -text "<" -command [mymethod prev_month]]
        set month_selector [ttk::combobox $win.month -values $options(-months) -textvariable [myvar month] -state readonly -width 8]
        set separator [ttk::label $win.separator -text "-"]
        set year_selector [ttk::spinbox $win.year -from 2000 -to 2100 -increment 1 -textvariable [myvar year] -state readonly -width 8]
        set next_button [ttk::button $win.next -text ">" -command [mymethod next_month]]
        set assign_button [ttk::button $win.assign -text "assign" -command [mymethod assign_worker] -state disabled]

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

        bind $month_selector <<ComboboxSelected>> [mymethod month_changed]
        bind $year_selector <<Decrement>> [mymethod prev_year]
        bind $year_selector <<Increment>> [mymethod next_year]

        trace add variable $options(-worker_id) write [mymethod worker_id_changed]
    }

    destructor {
        trace remove variable $options(-worker_id) write [mymethod worker_id_changed]
    }

    method worker_id_changed {args} {
        upvar $options(-date) date
        upvar $options(-worker_id) id
        if {$id != -1 && $date != 0} {
            $win.assign configure -state normal
        } else {
            $win.assign configure -state disabled
        }
    }

    method assign_worker {args} {
        upvar $options(-worker_id) id
        upvar $options(-selected_date) date

        db eval {INSERT INTO calendar (worker_id, date)
                 VALUES ($id, $date)
                 ON CONFLICT (date) DO UPDATE
                 SET worker_id = $id}

        event generate $win <<WorkerAssigned>>
    }

    method month_changed {args} {
        set $options(-date) [clock scan "01/$month/$year" -format "01/%B/%Y"]
    }

    method prev_month {} {
        upvar $options(-date) date
        set $options(-date) [clock add $date -1 month]
        set month [clock format $date -format %B]
        set year [clock format $date -format %Y]
    }

    method next_month {} {
        upvar $options(-date) date
        set $options(-date) [clock add $date 1 month]
        set month [clock format $date -format %B]
        set year [clock format $date -format %Y]
    }

    method prev_year {} {
        upvar $options(-date) date
        set $options(-date) [clock add $date -1 year]
    }


    method next_year {} {
        upvar $options(-date) date
        set $options(-date) [clock add $date 1 year]
    }
}
