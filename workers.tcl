snit::widgetadaptor workers_panel_list {
    delegate option * to hull
    delegate method * to hull

    constructor {args} {
        installhull using ttk::frame
        $self configurelist $args

        set add_frame [ttk::frame $win.add]
        set add_entry [ttk::entry $add_frame.entry -textvariable ::state::worker::name]
        set add_button [ttk::button $add_frame.button -text "agregar" -command [mymethod save_worker]]

        set actions_frame [ttk::frame $win.actions]
        set actions_delete [ttk::button $actions_frame.delete -text "dar baja" -command [mymethod delete_worker]]
        set actions_cancel [ttk::button $actions_frame.cancel -text "cancelar" -command [mymethod cancel_editing]]

        set list_frame [ttk::frame $win.list]
        set list_tree [ttk::treeview $win.list.tree -columns {id name} -displaycolumns {name} -show {}]
        set list_scroll [ttk::scrollbar $win.list.scroll -orient vertical -command [list $list_tree yview]]
        $list_tree configure -yscrollcommand [list $list_scroll set]
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

        bind $add_entry <Return> [mymethod save_worker]
        bind $list_tree <<TreeviewSelect>> [mymethod edit_worker]
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

    method cancel_editing {} {
        $win.list.tree selection remove [$win.list.tree selection]
        ::state::worker::clear
        $self update_list
    }

    method save_worker {} {
        if {$::state::worker::name eq ""} { return }

        if {[::state::worker::exists]} {
            tk_messageBox -type ok -icon info -title "Aviso" -message "$::state::worker::name ya existe"
            return
        }

        ::state::worker::save
        $self cancel_editing
    }

    method delete_worker {} {
        if {$::state::worker::id > -1} {
            set answer [tk_messageBox -type yesno -icon question -title "Dar de baja" -message "¿Seguro que desa dar de baja a $::state::worker::name?"]
            if {$answer eq yes} {
                ::state::worker::delete
                $self cancel_editing
            }
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
