package require Tk
package require snit
package require sqlite3

sqlite3 db "guardias.db"

source src/app.tcl
source src/calendar.tcl
source src/database.tcl
source src/workers_panel.tcl

wm title . "Guardias"

image create photo icon -file "res/icon.png"
wm iconphoto . icon

pack [App .app] -expand yes -fill both -padx 4 -pady 4

update idletasks
wm minsize . [winfo reqwidth .] [winfo reqheight .]

tkwait window .

db close
