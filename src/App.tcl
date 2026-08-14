snit::widget App {
    hulltype ttk::frame

    component calendar_tabs
    component panel_tabs
    component calendar_tab
    component workers_tab

    delegate option * to hull
    delegate method * to hull

    variable calendar_date {}
    variable selected_worker_id -1
    variable calendar_workers {}
    variable workers {}

    constructor {args} {
        set calendar_date_str [clock format [clock seconds] -format "01/%m/%Y 00:00:00"]
        set calendar_date [clock scan $calendar_date_str -format "%d/%m/%Y %H:%M:%S"]

        install calendar_tabs using ttk::notebook $win.calendar_tabs
        install calendar_tab using Calendar $win.calendar_tab \
            -calendar_date [myvar calendar_date] \
            -selected_worker_id [myvar selected_worker_id] \
            -calendar_workers [myvar calendar_workers]
        install panel_tabs using ttk::notebook $win.panel_tabs
        install workers_tab using Workers $win.workers_tab \
            -selected_worker_id [myvar selected_worker_id]

        $calendar_tabs add $calendar_tab -text "Guardias"
        $panel_tabs add $workers_tab -text "Plantilla"

        pack $calendar_tabs -side left -fill both -expand yes -padx 4
        pack $panel_tabs -side left -fill y -padx 4

        $self configurelist $args

        $self RefreshWorkers
    }

    method RefreshWorkers {args} {
        set first_month_day_date_str [clock format $calendar_date -format "01/%m/%Y 00:00:00"]
        set first_month_day_date [clock scan $first_month_day_date_str -format "%d/%m/%Y %H:%M:%S"]
        set last_month_day_date [clock add $first_month_day_date 1 month -1 day]

        set workers {}
        db eval {
            SELECT workers.id, workers.name, duties.date FROM duties
            INNER JOIN workers ON workers.id = duties.worker_id
            WHERE date BETWEEN :first_month_day_date AND :last_month_day_date
        } {
            dict set workers $date $id $name
        }
        set calendar_workers $workers
    }
}
