# Tk Basics — Core GUI Toolkit Cheatsheet

Tk is Tcl's native GUI toolkit. Widgets are created as commands bound to a path name;
that same command is then used to configure/query/destroy the widget. This guide targets
Tk 8.6+/9.0, including `ttk` (themed widgets, preferred over classic `tk` widgets for new UIs).

## 1. Core Model

Every widget has a **path name** starting with `.` (the root window), forming a tree:

```tcl
package require Tk

button .b -text "Click me" -command {puts "clicked"}
pack .b

# nested widget: dot-separated path reflects parent-child hierarchy
frame .f
button .f.b -text "Nested"
pack .f
pack .f.b
```

The widget command name **is** the path name — `.b configure -text "New"` reconfigures it,
`.b cget -text` reads a value, `destroy .b` removes it.

```tcl
.b configure -text "Updated"
.b cget -text
destroy .b
```

## 2. Classic vs Themed (`ttk`) Widgets

Prefer `ttk` for anything user-facing — native look, theming support, more consistent styling.

| Classic | Themed (`ttk`) |
|---|---|
| `button` | `ttk::button` |
| `label` | `ttk::label` |
| `entry` | `ttk::entry` |
| `frame` | `ttk::frame` |
| `checkbutton` | `ttk::checkbutton` |
| `radiobutton` | `ttk::radiobutton` |
| `scrollbar` | `ttk::scrollbar` |

Classic widgets remain necessary for: `text`, `canvas`, `listbox`, `menu` (no ttk equivalents),
and cases needing per-widget bg/fg color control that ttk theming restricts.

```tcl
ttk::button .b -text "Themed button" -command doThing
pack .b -padx 10 -pady 10
```

## 3. Geometry Managers

A widget is invisible until placed by exactly **one** geometry manager. The three are mutually exclusive per parent — don't mix `pack` and `grid` on children of the same container.

### `pack` — stack widgets along edges

```tcl
pack .a -side top -fill x
pack .b -side left -fill y -expand 1
pack .c -side bottom -pady 5
```

Key options: `-side` (top/bottom/left/right), `-fill` (x/y/both/none), `-expand` (0/1),
`-padx`/`-pady`, `-anchor`.

### `grid` — row/column table layout (most common for forms)

```tcl
grid .lbl1 -row 0 -column 0 -sticky e
grid .ent1 -row 0 -column 1 -sticky ew
grid .lbl2 -row 1 -column 0 -sticky e
grid .ent2 -row 1 -column 1 -sticky ew

grid columnconfigure . 1 -weight 1   ;# let column 1 stretch on resize
grid rowconfigure . 0 -weight 1
```

`-sticky` uses compass directions (`n s e w` combined, e.g. `nsew` = fill cell entirely).
`-columnspan` / `-rowspan` merge cells.

### `place` — absolute/relative positioning (rare, use sparingly)

```tcl
place .w -x 10 -y 10
place .w -relx 0.5 -rely 0.5 -anchor center
```

## 4. Common Widgets

```tcl
ttk::label .l -text "Static text"
ttk::entry .e -textvariable myVar
ttk::button .b -text "Go" -command doAction
ttk::checkbutton .c -text "Enable" -variable enabledFlag
ttk::radiobutton .r1 -text "A" -variable choice -value A
ttk::radiobutton .r2 -text "B" -variable choice -value B
ttk::combobox .cb -values {Alpha Beta Gamma} -textvariable selection
ttk::progressbar .p -mode determinate -maximum 100 -variable progress
ttk::notebook .nb                        ;# tabbed container
ttk::treeview .tv -columns {c1 c2} -show headings

text .txt -wrap word -height 10
canvas .cv -width 300 -height 200
listbox .lb -listvariable myList
scrollbar .sb -command {.txt yview}
.txt configure -yscrollcommand {.sb set}
menu .m
.m add command -label "Open" -command doOpen
```

### Widget variables — the reactive link between UI and data

`-textvariable`, `-variable` bind a widget to a Tcl variable. Setting the variable updates
the widget; editing the widget updates the variable. This is the primitive most reactive
patterns (`trace`-based state management) build on.

```tcl
set myVar "initial"
ttk::entry .e -textvariable myVar
set myVar "changed"     ;# .e now displays "changed"
```

## 5. Events & Bindings

```tcl
bind .w <Button-1>       {puts "left click"}
bind .w <Double-Button-1> {puts "double click"}
bind .w <KeyPress-Return> {puts "enter pressed"}
bind .w <Enter>            {%W configure -bg lightblue}   ;# mouse enters widget
bind .w <Leave>            {%W configure -bg white}
bind .w <FocusIn>          {puts "focused"}
bind .w <Configure>        {puts "resized to %wx%h"}
```

Common substitutions inside binding scripts: `%W` (widget path), `%x %y` (pointer coords),
`%K` (keysym), `%w %h` (new width/height on `<Configure>`).

Binding tags allow shared bindings across widget classes:

```tcl
bind Entry <Return> {puts "any entry got Enter"}   ;# applies to all Entry-class widgets
```

## 6. Window Management

```tcl
wm title . "My Application"
wm geometry . "800x600+100+100"   ;# WxH+X+Y
wm minsize . 400 300
wm resizable . 1 1                ;# allow x/y resize
wm protocol . WM_DELETE_WINDOW {onCloseHandler}

toplevel .dialog
wm title .dialog "Dialog"
wm transient .dialog .             ;# child of main window
grab set .dialog                   ;# modal
```

## 7. The Event Loop

Tk scripts end by entering an event loop (`vwait` or implicit when run via `wish`).
GUI updates happen through callbacks — never block the main thread with long-running code.

```tcl
vwait forever          ;# park the script here, dispatch events until variable changes
```

For long tasks, use `after` to yield periodically or delegate to `coroutine`s (see coroutines guide).

```tcl
after 1000 {puts "one second later"}
after idle {doWhenEventLoopIsFree}
after cancel $afterId
```

## 8. Dialogs

```tcl
tk_messageBox -message "Done!" -type ok -icon info
tk_getOpenFile -filetypes {{"Text files" .txt} {"All files" *}}
tk_getSaveFile -defaultextension ".txt"
tk_chooseColor
```

## 9. Styling (`ttk::style`)

```tcl
ttk::style theme use clam
ttk::style configure TButton -font {Arial 12} -padding 6
ttk::style configure Accent.TButton -foreground white -background "#3366cc"
ttk::button .b -text "Styled" -style Accent.TButton
```

Style names follow `Class` or `CustomName.Class` convention; apply with `-style`.

## 10. Layout Composition Pattern

Typical structure: outer `ttk::frame` per logical section, `grid` inside each for alignment,
`pack` for the top-level arrangement of sections.

```tcl
ttk::frame .main -padding 10
pack .main -fill both -expand 1

ttk::frame .main.form
grid .main.form -row 0 -column 0 -sticky ew

ttk::label .main.form.l -text "Name:"
ttk::entry .main.form.e -textvariable nameVar
grid .main.form.l -row 0 -column 0 -sticky e
grid .main.form.e -row 0 -column 1 -sticky ew
grid columnconfigure .main.form 1 -weight 1
```

## 11. Gotchas

- Mixing `pack` and `grid` as geometry managers **within the same parent container** causes a deadlock error — pick one per container (nesting different managers in different sub-frames is fine).
- Widget paths must be unique and hierarchical; `.` alone refers to the root window.
- `-textvariable`/`-variable` must reference a **global or namespace variable** — a local proc variable goes out of scope and breaks the link unless declared with `global`/`variable`.
- Long-running work on the main thread freezes the UI; there's no automatic threading — use `after`, event-driven callbacks, or coroutines to stay responsive.
- Classic widgets and `ttk` widgets can visually clash (native theming vs plain widgets) — avoid mixing them for user-facing elements unless intentional.
- `destroy` on a parent destroys all descendant widgets recursively.
