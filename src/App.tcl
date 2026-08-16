snit::widget App {
    hulltype ttk::frame

    component calendar_tabs
    component panel_tabs
    component schedules_tab
    component workers_tab

    delegate option * to hull
    delegate method * to hull

    variable revisions -array {
        workers 0
    }

    variable selected_date 0
    variable selected_worker_id -1
    variable calendar_date [clock seconds]
    variable calendar_workers {}

    constructor {args} {
        install calendar_tabs using ttk::notebook $win.calendar_tabs -padding 12
        install schedules_tab using Calendar $win.schedules_tab \
            -selected_date [myvar selected_date] \
            -calendar_date [myvar calendar_date] \
            -calendar_workers [myvar calendar_workers]
        install panel_tabs using ttk::notebook $win.panel_tabs -padding {0 12 12 12}
        install workers_tab using Workers $win.workers_tab \
            -selected_date [myvar selected_date] \
            -selected_worker_id [myvar selected_worker_id] \
            -revisions [myvar revisions]

        $calendar_tabs add $schedules_tab -text "Guardias"

        $panel_tabs add $workers_tab -text "Plantilla"

        pack $calendar_tabs -side left -fill both -expand yes
        pack $panel_tabs -side left -fill y

        $self configurelist $args

        $self RefreshCalendarWorkers

        trace add variable calendar_date write [mymethod RefreshCalendarWorkers]
        trace add variable revisions(workers) write [mymethod RefreshCalendarWorkers]
    }

    destructor {
        try {trace remove variable calendar_date write [mymethod RefreshCalendarWorkers]}
        try {trace remove variable revisions(workers) write [mymethod RefreshCalendarWorkers]}
    }

    method RefreshCalendarWorkers {args} {
        set first_month_day [clock format $calendar_date -format "01/%m/%Y 00:00:00"]
        set first_month_day_date [clock scan $first_month_day -format "%d/%m/%Y %H:%M:%S"]

        set week_day [clock format $first_month_day_date -format %u]
        set first_date [clock add $first_month_day_date -[expr {$week_day - 1}] days]
        set last_date [clock add $first_date 41 days]

        set workers {}
        db eval {
            SELECT workers.id, workers.name, schedules.date FROM schedules
            INNER JOIN workers ON workers.id = schedules.worker_id
            WHERE date BETWEEN :first_date AND :last_date
        } {
            dict set workers $date $id $name
        }
        set calendar_workers $workers
    }
}
