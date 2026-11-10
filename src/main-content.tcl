snit::widget main-content {
    hulltype ttk::frame

    component calendar
    component assign
    component workers

    delegate method * to hull
    delegate option * to hull

    variable revisions -array {
        workers 0
    }

    variable selected_worker_id -1

    constructor args {
        install calendar using calendar $win.calendar -revisions [myvar revisions]
        install assign using assign-panel $win.assign -revisions [myvar revisions]
        install workers using workers-panel $win.workers -revisions [myvar revisions]

        grid $calendar  -row 0 -column 0
        grid $assign    -row 1 -column 0
        grid $workers   -row 0 -column 1 -rowspan 2

        grid columnconfigure $win 0 -weight 1
        grid rowconfigure $win 0 -weight 1

        $self configurelist $args
    }
}
