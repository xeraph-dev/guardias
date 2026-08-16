snit::widget CalendarGrid {
    hulltype ttk::frame

    foreach col [lseq 1 to 7] {
        component col_header_$col
    }

    foreach row [lseq 1 to 6] {
        component row_header_$row

        foreach col [lseq 1 to 7] {
            component cell_${row}x${col}
        }
    }

    option -calendar_date -configuremethod ConfigureCalendarDateOption

    delegate option * to hull
    delegate method * to hull

    propagate -selected_date to [concat {*}[
        lmap row [lseq 1 to 6] {
            lmap col [lseq 1 to 7] {
                list cell_${row}x${col}
            }
        }
    ]]
    propagate -calendar_workers to [concat {*}[
        lmap row [lseq 1 to 6] {
            lmap col [lseq 1 to 7] {
                list cell_${row}x${col}
            }
        }
    ]]

    constructor {args} {
        set days [lmap day [lseq 1 to 7] {
            set time [clock scan $day -format %u]
            clock format $time -format %A
        }]

        foreach col [lseq 1 to 7] {
            set week_day [lindex $days [expr {$col - 1}]]
            install col_header_$col using ttk::label $win.hcol_$col -text $week_day -anchor center
        }

        foreach row [lseq 1 to 6] {
            install row_header_${row} using ttk::label $win.hrow_$row

            foreach col [lseq 1 to 7] {
                install cell_${row}x${col} using CalendarCell $win.cell_${row}x${col} -relief solid -borderwidth 2
            }
        }

        grid columnconfigure $win 0 -weight 0 -minsize 30
        foreach col [lseq 1 to 7] {
            grid [set col_header_${col}] -row 0 -column $col
            grid columnconfigure $win $col -weight 1 -uniform days -minsize 80
        }

        grid rowconfigure $win 0 -weight 0 -minsize 25
        foreach row [lseq 1 to 6] {
            grid [set row_header_${row}] -row $row -column 0
            grid rowconfigure $win $row -weight 1 -uniform weeks -minsize 80

            foreach col [lseq 1 to 7] {
                grid [set cell_${row}x${col}] -row $row -column $col -sticky nsew
            }
        }

        $self configurelist $args
    }

    destructor {
        try {trace remove variable $options(-calendar_date) write [mymethod CalendarDateChanged]}
    }

    method ConfigureCalendarDateOption {option value} {
        set options($option) $value
        foreach row [lseq 1 to 6] {
            foreach col [lseq 1 to 7] {
                [set cell_${row}x${col}] configure -calendar_date $options(-calendar_date)
            }
        }
        $self CalendarDateChanged
        trace add variable $options(-calendar_date) write [mymethod CalendarDateChanged]
    }

    method CalendarDateChanged {args} {
        upvar $options(-calendar_date) calendar_date

        set first_month_day [clock format $calendar_date -format "01/%m/%Y 00:00:00"]
        set first_month_day_date [clock scan $first_month_day -format "%d/%m/%Y %H:%M:%S"]

        set week_day [clock format $first_month_day_date -format %u]
        set cell_date [clock add $first_month_day_date -[expr {$week_day - 1}] days]

        foreach row [lseq 1 to 6] {
            [set row_header_${row}] configure -text [clock format $cell_date -format %V]

            foreach col [lseq 1 to 7] {
                [set cell_${row}x${col}] configure -cell_date $cell_date
                set cell_date [clock add $cell_date 1 day]
            }
        }
    }
}
