snit::widget CalendarPaginator {
    delegate option * to hull
    delegate method * to hull

    option -date
    option -selected_date -readonly yes
    option -selected_worker_id

    constructor {args} {
        $self configurelist $args

        set months {}
        for {set month 1} {$month <= 12} {incr month} {
            set time [clock scan $month -format %N]
            lappend months [clock format $time -format %B]
        }

        set prev_button [ttk::button $win.prev -text "<" -command [mymethod prev_month]]
        set month_selector [ttk::combobox $win.month -values $months -state readonly -width 8]
        set separator [ttk::label $win.separator -text "-"]
        set year_selector [ttk::spinbox $win.year -from 2000 -to 2100 -increment 1 -state readonly -width 8 -command [mymethod year_month_changed]]
        set next_button [ttk::button $win.next -text ">" -command [mymethod next_month]]
        set assign_button [ttk::button $win.assign -text "assign" -command [mymethod assign_worker]]

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

        bind $month_selector <<ComboboxSelected>> [mymethod year_month_changed]

        trace add variable $options(-date) write [mymethod date_changed]
        trace add variable $options(-selected_worker_id) write [mymethod selected_worker_id_changed]

        $self date_changed
        $self selected_worker_id_changed
    }

    destructor {
        trace remove variable $options(-date) write [mymethod date_changed]
        trace remove variable $options(-selected_worker_id) write [mymethod selected_worker_id_changed]
    }

    method date_changed {args} {
        upvar $options(-date) date
        $self.month set [clock format $date -format %B]
        $self.year set [clock format $date -format %Y]
    }

    method selected_worker_id_changed {args} {
        upvar $options(-selected_date) date
        upvar $options(-selected_worker_id) worker_id

        if {$worker_id != -1 && $date != 0} {
            $win.assign configure -state normal
        } else {
            $win.assign configure -state disabled
        }
    }

    method year_month_changed {args} {
        upvar $options(-date) date
        set date [clock scan "01/[$self.month get]/[$self.year get]" -format "01/%B/%Y"]
    }

    method prev_month {} {
        upvar $options(-date) date
        set date [clock add $date -1 month]
    }

    method next_month {} {
        upvar $options(-date) date
        set date [clock add $date 1 month]
    }

    method assign_worker {args} {
        upvar $options(-selected_date) date
        upvar $options(-selected_worker_id) worker_id

        store calendar assign -worker_id $worker_id -date $date
    }
}
