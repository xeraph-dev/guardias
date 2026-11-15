snit::widget workers-active-list-actions {
    hulltype ttk::frame

    component up_button
    component down_button
    component add_button
    component edit_button
    component layoff_button

    delegate method * to hull
    delegate option * to hull

    constructor args {
        install up_button using ttk::button $win.up -text ↑ -command [mymethod Up] -state disabled
        install down_button using ttk::button $win.down -text ↓ -command [mymethod Down] -state disabled
        install add_button using ttk::button $win.add -text + -command [mymethod Add]
        install edit_button using ttk::button $win.edit -text ✎ -command [mymethod Edit] -state disabled
        install layoff_button using ttk::button $win.delete -text [mc workers.layoff] -command [mymethod Layoff] -state disabled

        pack $up_button $down_button $add_button $edit_button $layoff_button -side left -fill both -expand yes

        $self configurelist $args
    }

    method Up {} {}

    method Down {} {}

    method Add {} {
        show_workers_edit_dialog $win
    }

    method Edit {} {}

    method Layoff {} {}
}
