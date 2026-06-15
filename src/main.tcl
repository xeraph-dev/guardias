lappend auto_path [file join [file dirname [info script]] lib]

package require snit
package require sqlite3

sqlite3 db "guardias.db"

source src/database.tcl

source src/App.tcl

source src/calendar/Calendar.tcl
source src/calendar/CalendarPaginator.tcl
source src/calendar/CalendarGrid.tcl
source src/calendar/CalendarCell.tcl

source src/workers_panel/WorkersPanel.tcl
source src/workers_panel/WorkersPanelActions.tcl
source src/workers_panel/WorkersPanelAdd.tcl
source src/workers_panel/WorkersPanelList.tcl

wm title . "Guardias"

image create photo icon -file "res/icon.png"
wm iconphoto . icon

pack [App .app] -expand yes -fill both -padx 4 -pady 4

update idletasks
wm minsize . [winfo reqwidth .] [winfo reqheight .]
