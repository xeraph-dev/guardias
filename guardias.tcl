package require Tk
package require snit
package require sqlite3

source database.tcl
source state.tcl
source calendar.tcl
source workers.tcl

snit::widgetadaptor App {
    delegate option * to hull
    delegate method * to hull

    constructor {args} {
        installhull using ttk::frame -padding 8
        $self configurelist $args

        set calendar [calendar $win.calendar]
        set workers [workers_panel $win.workers]

        pack $calendar -side left -fill both -expand yes
        pack $workers -side left -fill y
    }
}

wm title . "Guardias"
pack [App .app] -expand yes -fill both

update idletasks
wm minsize . [winfo reqwidth .] [winfo reqheight .]

tkwait window .
db close
