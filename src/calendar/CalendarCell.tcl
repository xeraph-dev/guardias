snit::widget CalendarCell {
    hulltype ttk::frame

    component label

    option -calendar_date
    option -selected_date -configuremethod ConfigureSelectedDateOption
    option -cell_date -configuremethod ConfigureCellDateOption

    delegate option * to hull
    delegate method * to hull

    constructor {args} {
        install label using ttk::label $win.label

        pack $label -side right -anchor n

        bind $win <Button-1> [mymethod OnClick]
        bind $win.label <Button-1> [mymethod OnClick]

        $self configurelist $args
    }

    destructor {
        try {trace remove variable $options(-calendar_date) write [mymethod Refresh]}
        try {trace remove variable $options(-selected_date) write [mymethod Refresh]}
    }

    method ConfigureSelectedDateOption {option value} {
        set options($option) $value
        $self Refresh
        trace add variable $options(-selected_date) write [mymethod Refresh]
    }

    method ConfigureCellDateOption {option value} {
        set options($option) $value
        $self Refresh
    }

    method Refresh {args} {
        if {$options(-cell_date) == {}} {
            return
        }

        upvar $options(-calendar_date) calendar_date
        upvar $options(-selected_date) selected_date

        set calendar_date_month [clock format $calendar_date -format %B]
        set cell_day [clock format $options(-cell_date) -format %d]
        set cell_month [clock format $options(-cell_date) -format %B]
        set cell_month_short [clock format $options(-cell_date) -format %b]

        set now_date_str [clock format now -format "%d/%m/%Y 00:00:00"]
        set now_date [clock scan $now_date_str -format "%d/%m/%Y %H:%M:%S"]


        set label_text [clock format $options(-cell_date) -format %d]
        if {$cell_day == 1} {
            append label_text " $cell_month_short"
        }

        set foreground {}
        if {$calendar_date_month != $cell_month} {
            set foreground grey
        }
        if {$options(-cell_date) == $now_date} {
            set foreground red
        }
        if {$options(-cell_date) == $selected_date} {
            set foreground orange
        }
        $label configure -text $label_text -foreground $foreground
    }

    method OnClick {args} {
        upvar $options(-selected_date) selected_date
        set selected_date $options(-cell_date)
    }
}
