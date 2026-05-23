
snit::widget CalendarPaginator {
    delegate option * to hull
    delegate method * to hull

    variable month
    variable year

    option -worker_id
    option -months
    option -date

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

snit::widget CalendarGrid {
    delegate option * to hull
    delegate method * to hull

    option -date
    option -days
    option -selected_date

    constructor {args} {
        $self configurelist $args

        for {set col 1} {$col <= 7} {incr col} {
            set header [ttk::label $win.hcol_$col -text [lindex $options(-days) [expr {$col - 1}]] -anchor center]
            grid $header -row 0 -column $col
        }

        $self update_cells

        grid columnconfigure $win 0 -weight 0 -minsize 30
        for {set col 1} {$col <= 7} {incr col} {
            grid columnconfigure $win $col -weight 1 -uniform days -minsize 80
        }

        grid rowconfigure $win 0 -weight 0 -minsize 25
        for {set row 1} {$row <= 6} {incr row} {
            grid rowconfigure $win $row -weight 1 -uniform weeks -minsize 80
        }

        trace add variable $options(-date) write [mymethod update_cells]
    }

    destructor {
        trace remove variable $options(-date) write [mymethod update_cells]
    }

    method update_cells {args} {
        upvar $options(-date) date

        set week_day [clock format $date -format %u]
        set cell_date [clock add $date -[expr {$week_day - 1}] days]

        for {set row 1} {$row <= 6} {incr row} {
            set week_num [clock format $cell_date -format %V]
            if {[winfo exists $win.hrow_$row]} {
                $win.hrow_$row configure -text $week_num
            } else {
                set header [ttk::label $win.hrow_$row -text $week_num]
                grid $header -row $row -column 0
            }

            for {set col 1} {$col <= 7} {incr col} {
                if {[winfo exists $win.cell_${row}x${col}]} {
                    $win.cell_${row}x${col} configure -cell_date $cell_date
                } else {
                    set cell [CalendarCell $win.cell_${row}x${col} -date $options(-date) -cell_date $cell_date -selected_date $options(-selected_date) -relief solid -borderwidth 2]
                    grid $cell -row $row -column $col -padx 1 -pady 1 -sticky nsew
                }
                set cell_date [clock add $cell_date 1 day]
            }
        }
    }
}
