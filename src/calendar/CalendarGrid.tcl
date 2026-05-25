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
                    $win.cell_${row}x${col} update
                } else {
                    set cell [CalendarCell $win.cell_${row}x${col} -date $options(-date) -cell_date $cell_date -selected_date $options(-selected_date) -relief solid -borderwidth 2]
                    grid $cell -row $row -column $col -padx 1 -pady 1 -sticky nsew
                }
                set cell_date [clock add $cell_date 1 day]
            }
        }
    }
}
