snit::widget CalendarCell {
    delegate option * to hull
    delegate method * to hull

    variable day

    option -date
    option -cell_date
    option -selected_date

    constructor {args} {
        $self configurelist $args

        set label [ttk::label $win.label]
        $self update_label

        pack $label -side right -anchor n

        bind $win.label <Button-1> [mymethod on_click]
        bind $win <Button-1> [mymethod on_click]

        trace add variable $options(-date) write [mymethod update_label]
        trace add variable $options(-selected_date) write [mymethod update_label]
    }

    method on_click {} {
        set $options(-selected_date) $options(-cell_date)
    }

    method update_label {args} {
        upvar $options(-date) date
        upvar $options(-selected_date) selected_date

        $win.label configure -text [clock format $options(-cell_date) -format %d]

        set date_month [clock format $date -format %B]
        set cell_month [clock format $options(-cell_date) -format %B]

        set now_date_str [clock format now -format "%d/%m/%Y 00:00:00"]
        set now_date [clock scan $now_date_str -format "%d/%m/%Y %H:%M:%S"]

        $win.label configure -foreground {}
        if {$date_month != $cell_month} {
            $win.label configure -foreground grey
        }
        if {$options(-cell_date) == $now_date} {
            $win.label configure -foreground red
        }
        if {$options(-cell_date) == $selected_date} {
            $win.label configure -foreground orange
        }
    }
}

snit::widget CalendarPaginator {
    delegate option * to hull
    delegate method * to hull

    variable month
    variable year

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

        grid $prev_button -row 0 -column 1 -padx 4
        grid $month_selector -row 0 -column 2 -padx 4
        grid $separator -row 0 -column 3 -padx 4
        grid $year_selector -row 0 -column 4 -padx 4
        grid $next_button -row 0 -column 5 -padx 4

        grid columnconfigure $win 0 -weight 1 -uniform spacers
        grid columnconfigure $win 1 -weight 0 -uniform buttons
        grid columnconfigure $win 5 -weight 0 -uniform buttons
        grid columnconfigure $win 6 -weight 1 -uniform spacers

        bind $month_selector <<ComboboxSelected>> [mymethod month_changed]
        bind $year_selector <<Decrement>> [mymethod prev_year]
        bind $year_selector <<Increment>> [mymethod next_year]
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

snit::widget Calendar {
    delegate option * to hull
    delegate method * to hull

    set months {}
    set days {}

    variable date {}
    variable selected_date {}

    constructor {args} {
        $self configurelist $args

        set date_str [clock format now -format "01/%m/%Y 00:00:00"]
        set date [clock scan $date_str -format "%d/%m/%Y %H:%M:%S"]

        for {set month 1} {$month <= 12} {incr month} {
            set time [clock scan $month -format %N]
            lappend months [clock format $time -format %B]
        }

        for {set day 1} {$day <= 7} {incr day} {
            set time [clock scan $day -format %u]
            lappend days [clock format $time -format %A]
        }

        set paginator [CalendarPaginator $win.paginator -months $months -date [myvar date]]
        set grid [CalendarGrid $win.grid -days $days -date [myvar date] -selected_date [myvar selected_date]]

        pack $paginator -fill x -padx 4 -pady 4
        pack $grid -fill both -expand yes -padx 4 -pady 4

        trace add variable date write [mymethod date_changed]
        trace add variable selected_date write [mymethod date_selected]
    }

    method date_changed {args} {
        puts [clock format $date -format "%B/%Y"]
    }

    method date_selected {args} {
        puts [clock format $selected_date -format "%d/%B/%Y"]
    }
}
