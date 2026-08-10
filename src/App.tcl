snit::widget App {
    hulltype ttk::frame

    component calendar
    component tabs

    delegate option * to hull
    delegate method * to hull

    variable calendar_date

    constructor {args} {
        set calendar_date_str [clock format [clock seconds] -format "01/%m/%Y 00:00:00"]
        set calendar_date [clock scan $calendar_date_str -format "%d/%m/%Y %H:%M:%S"]

        install calendar using Calendar $win.calendar -date [myvar calendar_date]
        install tabs using ttk::notebook $win.tabs

        pack $calendar -side left -fill both -expand yes -padx 4
        pack $tabs -side left -fill y -padx 4

        $self configurelist $args
    }
}
