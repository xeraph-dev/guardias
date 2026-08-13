snit::widget WorkersAdd {
    hulltype ttk::frame

    component entry
    component button

    option -selected_worker_id -configuremethod ConfigureSelectedWorkerIdOption

    delegate option * to hull
    delegate method * to hull

    variable name {}

    constructor {args} {
        install entry using ttk::entry $win.entry -textvariable [myvar name]
        install button using ttk::button $win.button -text "agregar" -command [mymethod Save] -state disabled

        pack $entry -side left -fill both -expand yes -padx 4
        pack $button -side left -fill y -padx 4

        bind $entry <Return> [mymethod Save]

        $self configurelist $args

        trace add variable name write [mymethod NameChanged]
    }

    destructor {
        try {trace remove variable name write [mymethod NameChanged]}
        try {trace remove variable $options(-selected_worker_id) write [mymethod SelectedWorkerIdChanged]}
    }

    method Save {args} {
        upvar $options(-selected_worker_id) selected_worker_id

        if {[db exists {SELECT id FROM workers WHERE id <> :selected_worker_id AND name = :name}]} {
            tk_messageBox -type ok -icon info -title "Aviso" -message "$name ya existe"
            return
        }

        if {$selected_worker_id != -1} {
            db eval {UPDATE workers SET name = :name WHERE id = :selected_worker_id}
            $self CancelEditing
            event generate $win <<WorkerUpdated>> -data $selected_worker_id -when now
            return
        }

        set weight 0
        db eval {SELECT weight FROM workers ORDER BY weight DESC LIMIT 1} values {
            set weight [expr {$values(weight) + 1}]
        }
        db eval {INSERT INTO workers (name, weight) VALUES (:name, :weight)}

        $self CancelEditing
        event generate $win <<WorkerCreated>> -when now
    }

    method CancelEditing {args} {
        set name ""
    }

    method ConfigureSelectedWorkerIdOption {option value} {
        set options($option) $value
        $self SelectedWorkerIdChanged
        trace add variable $options(-selected_worker_id) write [mymethod SelectedWorkerIdChanged]
    }

    method NameChanged {args} {
        set state normal
        if {[string trim $name] == ""} {set state disabled}
        $button configure -state $state
    }

    method SelectedWorkerIdChanged {args} {
        upvar $options(-selected_worker_id) selected_worker_id
        $self CancelEditing
        set text "agregar"
        if {$selected_worker_id != -1} {
            set text "editar"
            db eval {SELECT name FROM workers WHERE id = :selected_worker_id} values {
                set name $values(name)
            }
        }

        $button configure -text $text
    }
}
