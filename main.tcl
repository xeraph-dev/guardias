package require snit
package require sqlite3
package require msgcat

namespace import msgcat::*

const APP_DIR [file dirname [info script]]
const SRC_DIR [file join $APP_DIR src]
const RES_DIR [file join $APP_DIR res]
const MSGS_DIR [file join $APP_DIR msgs]
const MIGRATIONS_DIR [file join $APP_DIR migrations]
const ICON_FILE [file join $RES_DIR icon.png]
const DB_FILE guardias.db

proc source-files {dir} {
    foreach file [glob -directory $dir *.tcl] {
        source $file
    }
    foreach dir [glob -directory $dir -types d *] {
        source-files $dir
    }
}

source-files $SRC_DIR
source-files $MIGRATIONS_DIR

sqlite3 db [file join [pwd] $DB_FILE]

db eval {PRAGMA foreign_keys = ON}
db eval {PRAGMA journal_mode = WAL}
db eval {PRAGMA synchronous = NORMAL}

mcload $MSGS_DIR
migrations run_pending

wm title . [mc window.title]

image create photo icon -file $ICON_FILE
wm iconphoto . icon

pack [App .app] -expand yes -fill both

update idletasks
wm minsize . [winfo reqwidth .] [winfo reqheight .]

wm protocol . WM_DELETE_WINDOW {
    db close
    destroy .
}
