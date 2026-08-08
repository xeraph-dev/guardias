snit::widget App {
    delegate option * to hull
    delegate method * to hull

    constructor {args} {
        $self configurelist $args

        set calendar [Calendar $win.calendar]

        pack $calendar -side left -fill both -expand yes -padx 4
    }
}
