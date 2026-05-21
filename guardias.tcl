package require Tk
package require snit
package require sqlite3

wm title . "Guardias"

image create photo icon -file "icon.png"
wm iconphoto . icon

update idletasks
wm minsize . [winfo reqwidth .] [winfo reqheight .]

tkwait window .
