snit::widget WorkersActions {
    hulltype ttk::frame

    component up
    component down
    component delete
    component cancel

    option -selected_worker_id

    delegate option * to hull
    delegate method * to hull

    constructor {args} {
        install up using ttk::button $win.up -text "^" -command [mymethod Up] -state disabled
        install down using ttk::button $win.down -text "v" -command [mymethod Down] -state disabled
        install delete using ttk::button $win.delete -text "dar baja" -command [mymethod Delete] -state disabled
        install cancel using ttk::button $win.cancel -text "cancelar" -command [mymethod Cancel] -state disabled

        pack $cancel $delete $down $up -side right -fill y -padx 4

        $self configurelist $args
    }

    method Up {args} {}

    method Down {args} {}

    method Delete {args} {}

    method Cancel {args} {}
}
