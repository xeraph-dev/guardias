# tablelist Basics — Cheatsheet

`tablelist` is a widely-used third-party Tk widget package providing a multi-column,
sortable, editable table/listbox — far more capable than the built-in `listbox` or
`ttk::treeview` for data-grid-style UIs (spreadsheet-like editing, embedded widgets per
cell, rich per-column formatting). It's a classic (non-`ttk`) widget package, written in
pure Tcl/Tk — no C compilation needed, unlike binary extensions such as `sqlite3`.

```tcl
package require tablelist
```

## 1. Creating a Basic Table

```tcl
package require tablelist

tablelist::tablelist .tbl \
    -columns {0 "Name" left
              0 "Age"  right
              0 "City" left} \
    -stretch all

pack .tbl -fill both -expand 1
```

- `-columns` takes triples: `width title alignment`, repeated for each column. A width of
  `0` means "auto-size to content."
- `-stretch all` makes every column expand to fill available width when the widget is
  resized; `-stretch {0 2}` stretches only specific column indices (0-based).

## 2. Populating Rows

```tcl
.tbl insert end {Alice 30 "New York"}
.tbl insert end {Bob   25 "London"}
.tbl insert end {Carol 40 "Berlin"}
```

```tcl
# insert at a specific position instead of the end
.tbl insert 0 {Dave 22 "Paris"}

# insert several rows at once
.tbl insert end {Eve 35 "Tokyo"} {Frank 28 "Madrid"}
```

```tcl
.tbl delete 0                ;# delete row at index 0
.tbl delete 0 2                ;# delete rows 0 through 2
.tbl delete end                ;# delete last row
.tbl get 0                      ;# retrieve the values of row 0 as a list
.tbl size                        ;# number of rows
```

## 3. Populating From a Data Source

The common real-world pattern: clear and repopulate from whatever the model/Store returns,
rather than manually tracking individual row diffs.

```tcl
proc refreshTable {tbl rows} {
    $tbl delete 0 end
    foreach row $rows {
        $tbl insert end $row
    }
}

refreshTable .tbl [$repository loadAll]
```

For a reactive UI (see the Store pattern guide), this refresh proc is what a
`subscribe` callback would call whenever the underlying data changes.

## 4. Selection

```tcl
.tbl selection set 0                ;# select row 0, clearing prior selection
.tbl selection set 0 2                ;# select rows 0 through 2
.tbl selection clear 0 end             ;# clear all selection

.tbl curselection                       ;# list of currently selected row indices
.tbl get [.tbl curselection]             ;# values of the selected rows
```

```tcl
bind .tbl <<TablelistSelect>> {
    puts "Selected rows: [.tbl curselection]"
}
```

`<<TablelistSelect>>` is a virtual event fired whenever the selection changes — the
standard hook for reacting to row selection (e.g. populating a detail panel).

## 5. Sorting

```tcl
.tbl configure -columns {0 "Name" left
                          0 "Age"  right}
.tbl sortbycolumn 0                   ;# sort ascending by column 0
.tbl sortbycolumn 0 -decreasing         ;# sort descending
```

Enabling interactive header-click sorting (clicking a column header toggles sort order):

```tcl
tablelist::tablelist .tbl \
    -columns {0 "Name" left 0 "Age" right} \
    -labelcommand tablelist::sortByColumn
```

`-labelcommand tablelist::sortByColumn` wires up the built-in click-to-sort behavior
without writing any sorting logic yourself.

## 6. Editing Cells

`tablelist` supports interactive in-place cell editing, unlike `ttk::treeview`.

```tcl
tablelist::tablelist .tbl \
    -columns {0 "Name" left 0 "Age" right} \
    -editstartcommand onEditStart \
    -editendcommand onEditEnd

.tbl columnconfigure 0 -editable yes
.tbl columnconfigure 1 -editable yes -editwindow entry
```

```tcl
proc onEditStart {tbl row col text} {
    # return the text to show in the edit widget (often just $text unchanged)
    return $text
}

proc onEditEnd {tbl row col text} {
    # validate/transform before it's committed; return the value to actually store
    if {$col == 1 && ![string is integer -strict $text]} {
        return -code error "Age must be a number"
    }
    return $text
}
```

- `-editwindow` chooses the widget type used while editing a cell: `entry` (default),
  `checkbutton`, `spinbox`, `combobox`, or a custom widget class.
- Returning `-code error` from `-editendcommand` rejects the edit and keeps the cell in
  edit mode — the standard way to enforce validation before a value is committed.

## 7. Embedded Widgets Per Cell

Beyond simple text editing, a cell can permanently host an interactive widget (checkbox,
button, combobox) rather than plain text — a capability `ttk::treeview` doesn't have.

```tcl
.tbl columnconfigure 2 -name active

.tbl insert end {Alice 30 ""}
set rowIdx [expr {[.tbl size] - 1}]
set cellPath [.tbl cellpath $rowIdx active]

checkbutton $cellPath.cb -variable activeVar($rowIdx)
.tbl cellconfigure $rowIdx,active -window $cellPath.cb
```

Embedded widgets are more expensive (one real widget per cell) than plain text rendering —
reserve this for columns that genuinely need interactive controls, not for every column in
a large table.

## 8. Formatting Cell Content

```tcl
.tbl columnconfigure 1 -formatcommand formatAge

proc formatAge {value} {
    return "${value} yrs"
}
```

`-formatcommand` transforms the stored value into display text without changing the
underlying data — `get` still returns the raw value, only the rendered text changes.

```tcl
.tbl columnconfigure 1 -sortmode integer      ;# numeric sort instead of lexical
.tbl columnconfigure 0 -sortmode dictionary     ;# case-insensitive natural sort
```

## 9. Column Configuration Reference

```tcl
.tbl columnconfigure 0 \
    -name name \
    -width 20 \
    -stretchable yes \
    -sortmode dictionary \
    -editable no
```

Common per-column options: `-width`, `-stretchable`, `-editable`, `-sortmode`,
`-formatcommand`, `-name` (lets you reference the column by symbolic name instead of a
numeric index in later calls, e.g. `.tbl columnconfigure name -editable yes`).

## 10. Scrollbars

```tcl
ttk::frame .container
tablelist::tablelist .container.tbl -columns {0 Name left 0 Age right}
ttk::scrollbar .container.vsb -orient vertical -command {.container.tbl yview}
.container.tbl configure -yscrollcommand {.container.vsb set}

grid .container.tbl .container.vsb -sticky nsew
grid columnconfigure .container 0 -weight 1
grid rowconfigure .container 0 -weight 1
pack .container -fill both -expand 1
```

Standard scrollbar wiring, same pattern as any scrollable Tk widget (`text`, `canvas`) —
`tablelist` doesn't require anything special here.

## 11. Hierarchical (Tree-Style) Rows

`tablelist` can also display parent/child rows, similar in spirit to `ttk::treeview`, using
indices in dotted "path" notation.

```tcl
tablelist::tablelist .tbl -columns {0 Name left 0 Type left} -treecolumn 0

.tbl insert end {Documents folder}
.tbl insertchild end {Report.docx file}
.tbl insertchild {end} {Invoice.pdf file}
```

`-treecolumn` designates which column shows the expand/collapse triangle and indentation.
This is a more advanced use case — for a flat table (the common case), `-treecolumn` isn't needed.

## 12. Row Coloring / Conditional Styling

```tcl
.tbl rowconfigure 0 -background "#ffe0e0" -foreground black
```

For conditional formatting based on data (e.g. highlighting overdue items), apply this
inside the same refresh/populate step that fills the table, rather than as a separate pass:

```tcl
proc refreshTable {tbl rows} {
    $tbl delete 0 end
    set i 0
    foreach row $rows {
        $tbl insert end $row
        if {[dict get $row overdue]} {
            $tbl rowconfigure $i -background "#ffe0e0"
        }
        incr i
    }
}
```

## 13. Keybindings and Navigation

`tablelist` provides sensible default keyboard navigation out of the box (arrow keys,
Page Up/Down, Home/End move the selection). Custom bindings layer on top the same way as
any other Tk widget:

```tcl
bind .tbl <Delete> {
    foreach idx [.tbl curselection] {
        .tbl delete $idx
    }
}

bind .tbl <Double-1> {
    set row [.tbl curselection]
    if {$row ne ""} {
        puts "Double-clicked row: [.tbl get $row]"
    }
}
```

## 14. Theming Limitations (see also the Tk basics guide)

`tablelist` is a classic Tk widget, not `ttk` — it does **not** automatically pick up
`ttk::style theme` changes, including native themes like `aqua`/`vista`. To keep its
appearance visually consistent with the rest of a themed `ttk` UI, configure its colors
manually:

```tcl
tablelist::tablelist .tbl \
    -background systemWindowBody \
    -foreground systemModelessDialogActiveText \
    -selectbackground systemHighlight \
    -selectforeground systemModelessDialogActiveText \
    -font TkDefaultFont
```

Third-party theme packages such as `tcl-awthemes` (`awdark`/`awlight`) include built-in
`tablelist` theming support, applying consistent colors automatically when both packages
are loaded together — a simpler path than manually matching colors if broader cross-platform
visual consistency (not native-per-OS look) is the goal.

## 15. Typical Full Example

```tcl
package require tablelist

ttk::frame .main
pack .main -fill both -expand 1

tablelist::tablelist .main.tbl \
    -columns {0 "Name" left
              0 "Age"  right
              0 "City" left} \
    -stretch all \
    -labelcommand tablelist::sortByColumn \
    -yscrollcommand {.main.vsb set}

ttk::scrollbar .main.vsb -orient vertical -command {.main.tbl yview}

grid .main.tbl .main.vsb -sticky nsew
grid columnconfigure .main 0 -weight 1
grid rowconfigure .main 0 -weight 1

foreach row {{Alice 30 "New York"} {Bob 25 "London"} {Carol 40 "Berlin"}} {
    .main.tbl insert end $row
}

bind .main.tbl <<TablelistSelect>> {
    puts "Selected: [.main.tbl get [.main.tbl curselection]]"
}
```

## 16. Gotchas

- `tablelist` is a classic widget, so `-background`/`-foreground` behave like traditional
  Tk color options (always settable), unlike `ttk::entry`/`ttk::frame` where background
  color is often locked by native themes (see the Tk basics guide) — this is actually an
  advantage for `tablelist` when custom coloring matters, but means it never blends
  perfectly with a native `ttk` theme automatically.
- Embedded per-cell widgets (section 7) are real, separate Tk widgets — a table with
  thousands of rows all using embedded widgets in every cell will be noticeably slower than
  one using plain formatted text; reserve embedded widgets for columns that genuinely need
  them, and only for the visible/loaded rows if implementing any kind of virtualization.
- `-editendcommand` returning a plain error (via `error` instead of `return -code error`)
  may not reject the edit the way you expect — use `return -code error` explicitly to signal
  validation failure and keep the cell in edit mode.
- Sorting via `sortbycolumn` operates on the currently displayed data — if rows are
  repopulated afterward (e.g. via the refresh pattern in section 3), the sort is not
  "sticky" automatically; re-apply `sortbycolumn` after a refresh if persistent sort order
  across data reloads is required.
- Column indices in most `tablelist` commands are 0-based and shift when columns are
  added/removed — prefer `-name` (section 9) and referencing columns symbolically in
  application code that outlives a single column layout, rather than hardcoding numeric
  indices everywhere.
- Because `tablelist` is pure Tcl/Tk (no compiled component), it doesn't carry any of the
  cross-compilation complexity that binary extensions like `sqlite3` do — it can simply be
  bundled as script files inside a `zipfs`-packaged single-binary app with no special
  extraction-to-temp handling needed (unlike `load`-based binary packages).
