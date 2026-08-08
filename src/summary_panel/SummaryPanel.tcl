snit::widget SummaryPanel {
    delegate option * to hull
    delegate method * to hull

    constructor {args} {
        $self configurelist $args
    }
}
