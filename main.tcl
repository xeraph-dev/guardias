lappend auto_path lib

package require snit
package require sqlite3
package require defer

namespace import defer::defer

sqlite3 db "guardias.db"

source src/macros.tcl

source src/database.tcl

source src/App.tcl

source src/calendar/Calendar.tcl
source src/calendar/CalendarCell.tcl
source src/calendar/CalendarGrid.tcl
source src/calendar/CalendarPaginator.tcl

source src/workers/Workers.tcl
source src/workers/WorkersActions.tcl
source src/workers/WorkersAdd.tcl
source src/workers/WorkersList.tcl

source src/summary/Summary.tcl

wm title . "Guardias"

image create photo icon -file "res/icon.png"
wm iconphoto . icon

pack [App .app] -expand yes -fill both

update idletasks
wm minsize . [winfo reqwidth .] [winfo reqheight .]

wm protocol . WM_DELETE_WINDOW {
    db close
    destroy .
}
