snit::widget App {
    delegate option * to hull
    delegate method * to hull

    variable selected_date 0
    variable selected_worker_id -1

    constructor {args} {
        $self configurelist $args

        set calendar [Calendar $win.calendar -selected_date [myvar selected_date] -selected_worker_id [myvar selected_worker_id]]
        set panels [ttk::notebook $win.panels]
        $panels add [SummaryPanel $win.panels.summary] -text "Resumen"
        $panels add [WorkersPanel $win.panels.workers -selected_worker_id [myvar selected_worker_id]] -text "Plantilla"

        pack $calendar -side left -fill both -expand yes -padx 4
        pack $panels -side left -fill y -padx 4
    }
}
