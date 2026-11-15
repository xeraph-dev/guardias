# snit::widgetadaptor workers-edit-dialog {
#     delegate method * to hull
#     delegate option * to hull
#
#     constructor args {
#         installhull using widget::dialog -title []
#
#         $self configurelist $args
#     }
# }

snit::widget workers-edit-dialog {
    hulltype toplevel

    option -parent -readonly yes
    option -id -default -1 -readonly yes

    delegate method * to hull
    delegate option * to hull

    variable name {}

    constructor args {
        wm withdraw $win

        $self configurelist $args
        $self SetTitle

        wm protocol $win WM_DELETE_WINDOW [list destroy $win]

        update idletasks
        wm minsize . [winfo reqwidth .] [winfo reqheight .]
        set parent [winfo toplevel $options(-parent)]
        set x [expr {[winfo rootx $parent] + [winfo reqwidth $parent]/2 - [winfo reqwidth $win]/2}]
        set y [expr {[winfo rooty $parent] + [winfo reqheight $parent]/2 - [winfo reqheight $win]/2}]
        wm geometry $win +$x+$y
        wm deiconify $win
    }

    method SetTitle {} {
        set id $options(-id)
        if {$id > -1} {
            wm title $win [mc workers.dialog.edit.title $name]
        } elseif {$id == -1} {
            wm title $win [mc workers.dialog.edit.title-new]
        }
    }
}

proc show_workers_edit_dialog {parent {id -1}} {
    set win .edit_dialog
    if {[winfo exists $win]} {
        focus $win
    } else {
        workers-edit-dialog $win -parent $parent -id $id]
    }
}
