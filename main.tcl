set app_dir [file dirname [info script]]
lappend auto_path [file join $app_dir lib]

package require snit
package require sqlite3
package require defer

namespace import defer::defer

sqlite3 db "guardias.db"

source [file join $app_dir src database.tcl]

source [file join $app_dir src macros.tcl]

source [file join $app_dir src database.tcl]

source [file join $app_dir src App.tcl]

source [file join $app_dir src calendar Calendar.tcl]
source [file join $app_dir src calendar CalendarCell.tcl]
source [file join $app_dir src calendar CalendarGrid.tcl]
source [file join $app_dir src calendar CalendarPaginator.tcl]

source [file join $app_dir src workers Workers.tcl]
source [file join $app_dir src workers WorkersActions.tcl]
source [file join $app_dir src workers WorkersAdd.tcl]
source [file join $app_dir src workers WorkersList.tcl]

source [file join $app_dir src summary Summary.tcl]

wm title . "Guardias"

image create photo icon -file [file join $app_dir res icon.png]
wm iconphoto . icon

pack [App .app] -expand yes -fill both

update idletasks
wm minsize . [winfo reqwidth .] [winfo reqheight .]

wm protocol . WM_DELETE_WINDOW {
    db close
    destroy .
}
