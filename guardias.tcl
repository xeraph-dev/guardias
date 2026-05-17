package require Tk
package require snit
package require sqlite3

sqlite3 db "guardias.db"

db eval {
    CREATE TABLE IF NOT EXISTS workers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS calendar (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        worker_id INTEGER NOT NULL REFERENCES workers (id),
        date TEXT UNIQUE NOT NULL
    );
}

variable calendar_date [clock seconds]
variable calendar_year [clock format "$calendar_date" -format %Y -locale es_ES -timezone America/Havana]
variable calendar_month [clock format "$calendar_date" -format %B -locale es_ES -timezone America/Havana]
variable selected_worker -1

set months {}
for {set month 1} {$month <= 12} {incr month} {
    set time [clock scan $month -format %N -locale es_ES -timezone America/Havana]
    lappend months [clock format $time -format %B -locale es_ES -timezone America/Havana]
}

set days {}
for {set day 1} {$day <= 7} {incr day} {
    set time [clock scan $day -format %u -locale es_ES -timezone America/Havana]
    lappend days [clock format $time -format %A -locale es_ES -timezone America/Havana]
}

snit::widgetadaptor calendar_cell {
    delegate option * to hull
    delegate method * to hull

    variable day_str
    variable day_color ""

    option -date -configuremethod set_date
    option -curr_date

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
        if {[expr {"$options(-curr_date)" ne ""}]} {
            $self update_day
        }
    }

    method update_day {} {
        set date "$options(-date)"

        set day_str [clock format $date -format "%e" -locale es_ES -timezone America/Havana]

        set now_date_str [clock format now -format "%D" -locale es_ES -timezone America/Havana]
        set date_str [clock format $date -format "%D" -locale es_ES -timezone America/Havana]

        set curr_month [clock format $::calendar_date -format "%m" -locale es_ES -timezone America/Havana]
        set date_month [clock format $date -format "%m" -locale es_ES -timezone America/Havana]

        set day_color ""
        if {[expr {$now_date_str eq $date_str}]} {
            set day_color red
        }
        if {[expr {$curr_month ne $date_month}]} {
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
        set month_selector [ttk::combobox $win.month_selector -values $::months -textvariable [myvar month] -state readonly -width 8]
        set separator [ttk::label $win.separator -text "-"]
        set year_selector [ttk::spinbox $win.year_selector -from 2000 -to 2100 -increment 1 -textvariable [myvar year] -state readonly -width 8]
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

        trace add variable [myvar month] write [mymethod update_date]
        trace add variable [myvar year] write [mymethod update_date]
    }

    destructor {
        trace remove variable [myvar month] write [mymethod update_date]
        trace remove variable [myvar year] write [mymethod update_date]
    }

    method prev_month {} {
        set ::calendar_date [clock add "$::calendar_date" -1 month]
    }

    method next_month {} {
        set ::calendar_date [clock add "$::calendar_date" 1 month]
    }

    method update_date {args} {
        set ::calendar_date [clock scan "01/$month/$year" -format "%d/%B/%Y" -locale es_ES -timezone America/Havana]
    }
}

snit::widgetadaptor calendar_grid {
    delegate option * to hull
    delegate method * to hull

    variable first_cell_date

    constructor {args} {
        installhull using ttk::frame
        $self configurelist $args

        $self set_date
        $self update_cell_dates

        for {set col 1} {$col <= 7} {incr col} {
            set header [ttk::label $win.hcol_$col -text [lindex $::days [expr {$col - 1}]] -anchor center]
            grid $header -row 0 -column $col -sticky nsew
        }

        set cell_date $first_cell_date

        for {set row 1} {$row <= 6} {incr row} {
            set week_num [clock format $cell_date -format "%V" -locale es_ES -timezone America/Havana]
            set header [ttk::label $win.hrow_$row -text $week_num]
            grid $header -row $row -column 0 -sticky nsew

            for {set col 1} {$col <= 7} {incr col} {
                set cell [calendar_cell $win.cell_${row}x${col} -date $cell_date]
                grid $cell -row $row -column $col -sticky nsew -padx 1 -pady 1

                set cell_date [clock add $cell_date 1 day -locale es_ES -timezone America/Havana]
            }
        }

        grid columnconfigure $win 0 -weight 0 -minsize 30
        for {set col 1} {$col <= 7} {incr col} {
            grid columnconfigure $win $col -weight 1 -uniform days -minsize 80
        }
        grid rowconfigure $win 0 -weight 0 -minsize 25
        for {set row 1} {$row <= 6} {incr row} {
            grid rowconfigure $win $row -weight 1 -uniform weeks -minsize 80
        }

        trace add variable "$::calendar_date" write [mymethod update_date]
    }

    destructor {
        trace remove variable "$::calendar_date" write [mymethod update_date]
    }

    method set_date {args} {
        set ::year [clock format "$::calendar_date" -format %Y -locale es_ES -timezone America/Havana]
        set ::month [clock format "$::calendar_date" -format %B -locale es_ES -timezone America/Havana]
    }

    method update_cell_dates {args} {
        set first_month_day [clock scan "01/$::month/$::year" -format "%d/%B/%Y" -locale es_ES -timezone America/Havana]
        set week_day [clock format $first_month_day -format "%u" -locale es_ES -timezone America/Havana]
        set first_cell_date [clock add $first_month_day -[expr {$week_day - 1}] days -locale es_ES -timezone America/Havana]
    }

    method update_date {args} {
        $self set_date
        $self update_cell_dates

        set cell_date $first_cell_date

        for {set row 1} {$row <= 6} {incr row} {
            set week_num [clock format $cell_date -format "%V" -locale es_ES -timezone America/Havana]
            $win.hrow_$row configure -text $week_num

            for {set col 1} {$col <= 7} {incr col} {
                $win.cell_${row}x${col} configure -date $cell_date

                set cell_date [clock add $cell_date 1 day -locale es_ES -timezone America/Havana]
            }
        }
    }

    method update {args} {
        set first_month_day [clock scan "01/$month/$year" -format "%d/%B/%Y" -locale es_ES -timezone America/Havana]
        set week_day [clock format $first_month_day -format "%u" -locale es_ES -timezone America/Havana]
        set cell_date [clock add $first_month_day -[expr {$week_day - 1}] days -locale es_ES -timezone America/Havana]

        for {set row 1} {$row <= 6} {incr row} {
            set week_num [clock format $cell_date -format "%V" -locale es_ES -timezone America/Havana]
            $win.hrow_$row configure -text $week_num

            for {set col 1} {$col <= 7} {incr col} {
                $win.cell_${row}x${col} configure -date $cell_date
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

        grid $paginator -row 0 -column 0 -sticky nsew
        grid $grid -row 1 -column 0 -sticky nsew

        grid rowconfigure $win 0 -weight 0
        grid rowconfigure $win 1 -weight 1
        grid columnconfigure $win 0 -weight 1
    }
}

snit::widgetadaptor workers_panel_list {
    delegate option * to hull
    delegate method * to hull

    variable editing_name ""
    variable editing_id -1

    constructor {args} {
        installhull using ttk::frame
        $self configurelist $args

        set add_frame [ttk::frame $win.add]
        set add_entry [ttk::entry $add_frame.entry -textvariable [myvar editing_name]]
        set add_button [ttk::button $add_frame.button -text "agregar" -command [mymethod add_worker]]

        set actions_frame [ttk::frame $win.actions]
        set actions_delete [ttk::button $actions_frame.delete -text "dar baja" -command [mymethod delete_worker]]
        set actions_cancel [ttk::button $actions_frame.cancel -text "cancelar" -command [mymethod cancel_editing]]

        set list_frame [ttk::frame $win.list]
        set list_tree [ttk::treeview $win.list.tree -columns {id name} -show headings]
        set list_scroll [ttk::scrollbar $win.list.scroll -orient vertical -command [list $list_tree yview]]
        $list_tree configure -yscrollcommand [list $list_scroll set]

        $list_tree heading id -text "ID"
        $list_tree heading name -text "Nombre"
        $list_tree column id -width 20
        $list_tree configure -selectmode browse

        $self update_list

        pack $add_entry -side left -fill both -expand yes -padx 4
        pack $add_button -side left -fill y -padx 4

        pack $actions_cancel -side right -fill y -padx 4
        pack $actions_delete -side right -fill y -padx 4

        pack $list_tree -side left -fill both -expand yes
        pack $list_scroll -side right -fill y

        pack $add_frame $actions_frame -fill x -pady 4
        pack $list_frame -fill both -expand yes -pady 4

        bind $add_entry <Return> [mymethod add_worker]
        bind $list_tree <Double-1> [mymethod edit_worker]
    }

    method update_list {} {
        $win.list.tree delete [$win.list.tree children {}]
        db eval {SELECT id, name FROM workers} {
            $win.list.tree insert {} end -values [list $id $name]
        }
    }

    method edit_worker {args} {
        set sel [$win.list.tree selection]
        if {$sel ne ""} {
            $win.add.button configure -text "editar"
            set values [$win.list.tree item $sel -values]
            lassign $values id name
            set editing_id $id
            set editing_name $name
        }
    }

    method add_worker {} {
        if {$editing_name eq ""} { return }

        if {[db eval {SELECT EXISTS(SELECT id FROM workers WHERE id <> $editing_id AND name = $editing_name)}]} {
            tk_messageBox -type ok -icon info -title "Aviso" -message "El usuario ya existe"
            return
        }

        if {$editing_id > -1} {
            db eval {UPDATE workers SET name = $editing_name WHERE id = $editing_id}
        } else {
            db eval {INSERT INTO workers (name) VALUES ($editing_name)}
        }

        set editing_id -1
        set editing_name ""

        $self update_list
    }

    method delete_worker {} {
        if {$editing_id ne -1} {
            set answer [tk_messageBox -type yesno -icon question -title "Dar de baja" -message "¿Seguro que desa dar de baja a $editing_name?"]
            if {$answer eq yes} {
                db eval {DELETE FROM workers WHERE id = $editing_id}

                $self cancel_editing
                $self update_list
            }
        }
    }

    method cancel_editing {} {
        set editing_id -1
        set editing_name ""
        $win.add.button configure -text "agregar"
    }
}

snit::widgetadaptor workers_panel_stats {
    delegate option * to hull
    delegate method * to hull

    constructor {args} {
        installhull using ttk::frame
        $self configurelist $args
    }
}

snit::widgetadaptor workers_panel {
    delegate option * to hull
    delegate method * to hull

    constructor {args} {
        installhull using ttk::frame
        $self configurelist $args

        set tabs [ttk::notebook $win.tabs]
        $tabs add [workers_panel_stats $win.tabs.stats] -text "Estadisticas"
        $tabs add [workers_panel_list $win.tabs.list] -text "Plantilla"

        pack $tabs -expand yes -fill both
    }
}

snit::widgetadaptor App {
    delegate option * to hull
    delegate method * to hull

    constructor {args} {
        installhull using ttk::frame -padding 8
        $self configurelist $args

        set calendar [calendar $win.calendar]
        set workers [workers_panel $win.workers]

        grid $calendar -row 0 -column 0 -sticky nsew
        grid $workers -row 0 -column 1 -sticky nsew

        grid columnconfigure $win 0 -weight 1
        grid columnconfigure $win 1 -weight 0
        grid rowconfigure $win 0 -weight 1
    }
}

wm title . "Guardias"
pack [App .app] -expand yes -fill both

update idletasks
wm minsize . [winfo reqwidth .] [winfo reqheight .]

tkwait window .
db close
