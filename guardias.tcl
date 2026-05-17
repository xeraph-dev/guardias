package require Tk
package require snit
package require sqlite3

sqlite3 db "guardias.db"

db eval {
    CREATE TABLE IF NOT EXISTS workers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL
    );

    CREATE TABLE IF NOT EXISTS calendar (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        worker_id INTEGER NOT NULL REFERENCES workers (id),
        date TEXT UNIQUE NOT NULL
    );
}

namespace eval state {
    set guardias [dict create]

    namespace eval calendar {
        variable month [clock format now -format %B -locale es_ES -timezone America/Havana]
        variable year [clock format now -format %Y -locale es_ES -timezone America/Havana]

        set months {}
        for {set it 1} {$it <= 12} {incr it} {
            set time [clock scan $it -format %N -locale es_ES -timezone America/Havana]
            lappend months [clock format $time -format %B -locale es_ES -timezone America/Havana]
        }

        set days {}
        for {set it 1} {$it <= 7} {incr it} {
            set time [clock scan $it -format %u -locale es_ES -timezone America/Havana]
            lappend days [clock format $time -format %A -locale es_ES -timezone America/Havana]
        }

        proc get_date {} {
            return [clock scan "01/$::state::calendar::month/$::state::calendar::year" -format "%d/%B/%Y" -locale es_ES -timezone America/Havana]
        }
    }

    namespace eval worker {
        variable id -1
        variable name ""

        proc exists {} {
            return [db eval {SELECT EXISTS(SELECT id FROM workers WHERE id <> $::state::worker::id AND name = $::state::worker::name)}]
        }

        proc save {} {
            if {$::state::worker::name eq ""} { return }

            if {[::state::worker::exists]} {
                tk_messageBox -type ok -icon info -title "Aviso" -message "El usuario ya existe"
                return
            }

            if {$::state::worker::id > -1} {
                db eval {UPDATE workers SET name = $::state::worker::name WHERE id = $::state::worker::id}
            } else {
                db eval {INSERT INTO workers (name) VALUES ($::state::worker::name)}
            }

            ::state::worker::clear
            event generate . <<WorkerSaved>>
        }

        proc delete {} {
            if {$::state::worker::id > -1} {
                set answer [tk_messageBox -type yesno -icon question -title "Dar de baja" -message "¿Seguro que desa dar de baja a $::state::worker::name?"]
                if {$answer eq yes} {
                    db eval {DELETE FROM workers WHERE id = $::state::worker::id}
                    ::state::worker::clear
                    event generate . <<WorkerDeleted>>
                }
            }
        }

        proc clear {} {
            set ::state::worker::id -1
            set ::state::worker::name ""
        }
    }
}

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

snit::widgetadaptor workers_panel_list {
    delegate option * to hull
    delegate method * to hull

    constructor {args} {
        installhull using ttk::frame
        $self configurelist $args

        set add_frame [ttk::frame $win.add]
        set add_entry [ttk::entry $add_frame.entry -textvariable ::state::worker::name]
        set add_button [ttk::button $add_frame.button -text "agregar" -command ::state::worker::save]

        set actions_frame [ttk::frame $win.actions]
        set actions_delete [ttk::button $actions_frame.delete -text "dar baja" -command ::state::worker::delete]
        set actions_cancel [ttk::button $actions_frame.cancel -text "cancelar" -command ::state::worker::clear]

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

        bind $add_entry <Return> ::state::worker::save
        bind $list_tree <Double-1> [mymethod edit_worker]

        bind . <<WorkerSaved>> [mymethod update_list]
        bind . <<WorkerDeleted>> [mymethod update_list]
    }

    method update_list {} {
        $win.add.button configure -text "agregar"
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
            set ::state::worker::id $id
            set ::state::worker::name $name
        }
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

        pack $calendar -side left -fill both -expand yes
        pack $workers -side left -fill y
    }
}

wm title . "Guardias"
pack [App .app] -expand yes -fill both

update idletasks
wm minsize . [winfo reqwidth .] [winfo reqheight .]

tkwait window .
db close
