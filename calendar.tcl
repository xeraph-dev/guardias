snit::widgetadaptor calendar_cell {
    delegate option * to hull
    delegate method * to hull

    variable day_str
    variable day_color ""

    option -date -configuremethod set_date

    constructor {args} {
        installhull using ttk::frame -relief solid -borderwidth 2
        $self configurelist $args

        $win update_day
        set label [ttk::label $win.label -text $day_str -foreground $day_color]

        pack $label -side right -anchor n

        bind $win <Button-1> [mymethod on_click]
    }

    method on_click {} {
        puts "Cell $options(-date)"
    }

    method set_date {option value} {
        set options($option) $value
        $self update_day
    }

    method update_day {} {
        set date "$options(-date)"

        set day_str [clock format $date -format %e -locale es_ES -timezone America/Havana]

        set now_date_str [clock format now -format %D -locale es_ES -timezone America/Havana]
        set date_str [clock format $date -format %D -locale es_ES -timezone America/Havana]

        set date_month [clock format $date -format %B -locale es_ES -timezone America/Havana]

        set day_color ""
        if {[expr {$now_date_str eq $date_str}]} {
            set day_color red
        }
        if {[expr {$::state::calendar::month ne $date_month}]} {
            set day_color grey
        }

        if {[winfo exists $win.label]} {
            $win.label configure -text $day_str -foreground $day_color
        }
    }
}

snit::widgetadaptor calendar_paginator {
    delegate option * to hull
    delegate method * to hull

    constructor {args} {
        installhull using ttk::frame
        $self configurelist $args

        set prev_button [ttk::button $win.prev_button -text "<" -command [mymethod prev_month]]
        set month_selector [ttk::combobox $win.month_selector -values $::state::calendar::months -textvariable ::state::calendar::month -state readonly -width 8]
        set separator [ttk::label $win.separator -text "-"]
        set year_selector [ttk::spinbox $win.year_selector -from 2000 -to 2100 -increment 1 -textvariable ::state::calendar::year -state readonly -width 8]
        set next_button [ttk::button $win.next_button -text ">" -command [mymethod next_month]]

        grid $prev_button -row 0 -column 1 -padx 4
        grid $month_selector -row 0 -column 2 -padx 4
        grid $separator -row 0 -column 3
        grid $year_selector -row 0 -column 4 -padx 4
        grid $next_button -row 0 -column 5 -padx 4

        grid columnconfigure $win 0 -weight 1 -uniform spacers
        grid columnconfigure $win 1 -weight 0 -uniform buttons
        grid columnconfigure $win 5 -weight 0 -uniform buttons
        grid columnconfigure $win 6 -weight 1 -uniform spacers
    }

    method prev_month {} {
        set date [::state::calendar::get_date]
        set date [clock add "$date" -1 month]
        set ::state::calendar::month [clock format $date -format %B -locale es_ES -timezone America/Havana]
        set ::state::calendar::year [clock format $date -format %Y -locale es_ES -timezone America/Havana]
    }

    method next_month {} {
        set date [::state::calendar::get_date]
        set date [clock add "$date" 1 month]
        set ::state::calendar::month [clock format $date -format %B -locale es_ES -timezone America/Havana]
        set ::state::calendar::year [clock format $date -format %Y -locale es_ES -timezone America/Havana]
    }
}

snit::widgetadaptor calendar_grid {
    delegate option * to hull
    delegate method * to hull

    variable first_cell_date

    constructor {args} {
        installhull using ttk::frame
        $self configurelist $args

        for {set col 1} {$col <= 7} {incr col} {
            set header [ttk::label $win.hcol_$col -text [lindex $::state::calendar::days [expr {$col - 1}]] -anchor center]
            grid $header -row 0 -column $col -sticky nsew
        }

        $self update

        grid columnconfigure $win 0 -weight 0 -minsize 30
        for {set col 1} {$col <= 7} {incr col} {
            grid columnconfigure $win $col -weight 1 -uniform days -minsize 80
        }
        grid rowconfigure $win 0 -weight 0 -minsize 25
        for {set row 1} {$row <= 6} {incr row} {
            grid rowconfigure $win $row -weight 1 -uniform weeks -minsize 80
        }

        trace add variable ::state::calendar::month write [mymethod update]
        trace add variable ::state::calendar::year write [mymethod update]
    }

    destructor {
        trace remove variable state::calendar::month write [mymethod update]
        trace remove variable state::calendar::year write [mymethod update]
    }

    method update {args} {
        set first_month_day [clock scan "01/$::state::calendar::month/$::state::calendar::year" -format "%d/%B/%Y" -locale es_ES -timezone America/Havana]
        set week_day [clock format $first_month_day -format "%u" -locale es_ES -timezone America/Havana]
        set cell_date [clock add $first_month_day -[expr {$week_day - 1}] days -locale es_ES -timezone America/Havana]

        for {set row 1} {$row <= 6} {incr row} {
            set week_num [clock format $cell_date -format "%V" -locale es_ES -timezone America/Havana]
            if {[winfo exists $win.hrow_$row]} {
                $win.hrow_$row configure -text $week_num
            } else {
                set header [ttk::label $win.hrow_$row -text $week_num]
                grid $header -row $row -column 0 -sticky nsew
            }

            for {set col 1} {$col <= 7} {incr col} {
                if {[winfo exists $win.cell_${row}x${col}]} {
                    $win.cell_${row}x${col} configure -date $cell_date
                } else {
                    set cell [calendar_cell $win.cell_${row}x${col} -date $cell_date]
                    grid $cell -row $row -column $col -sticky nsew -padx 1 -pady 1
                }

                set cell_date [clock add $cell_date 1 day -locale es_ES -timezone America/Havana]
            }
        }
    }
}

snit::widgetadaptor calendar {
    delegate option * to hull
    delegate method * to hull

    constructor {args} {
        installhull using ttk::frame
        $self configurelist $args

        set paginator [calendar_paginator $win.paginator]
        set grid [calendar_grid $win.grid]

        pack $paginator -fill x
        pack $grid -fill both -expand yes
    }
}
