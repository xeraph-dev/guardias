# Snit Basics — Object & Megawidget Framework Cheatsheet

Snit is a pure-Tcl object system, most commonly used to build **megawidgets** (composite Tk
widgets assembled from primitive widgets) but equally usable for plain non-GUI objects.
Its defining feature is **option/method delegation**, which makes wrapping and composing
Tk widgets concise. This guide targets Snit 2.x (bundled with Tcl 8.6+/9.0 via `tcllib`).

```tcl
package require snit
```

## 1. The Three Definition Forms

| Form | Use case |
|---|---|
| `snit::type` | Plain object, no GUI (data model, service, controller) |
| `snit::widget` | New composite widget, becomes its own Tk widget with a path name |
| `snit::widgetadaptor` | Wraps/extends an *existing* single Tk widget, hijacking its command |

```tcl
snit::type counter { ... }              ;# ::counter create c1  -> object, not a widget
snit::widget mywidget { ... }           ;# .mw = mywidget .mw   -> real Tk widget path
snit::widgetadaptor styledentry { ... } ;# wraps an existing entry-like widget
```

## 2. Plain Type — Options, Variables, Methods

```tcl
snit::type Point {
    option -x -default 0
    option -y -default 0

    variable computedFlag 0    ;# private instance variable, not exposed as an option

    constructor {args} {
        $self configurelist $args
    }

    method distanceFromOrigin {} {
        return [expr {sqrt($options(-x)**2 + $options(-y)**2)}]
    }

    method move {dx dy} {
        set options(-x) [expr {$options(-x) + $dx}]
        set options(-y) [expr {$options(-y) + $dy}]
    }
}

set p [Point create %AUTO% -x 3 -y 4]
$p distanceFromOrigin      ;# 5.0
$p move 1 1
$p cget -x                  ;# 4
$p configure -x 10
```

- `option -name -default value` declares a configurable option, stored in the `options` array inside methods.
- `%AUTO%` generates a unique instance name (e.g. `::Point1`); use an explicit name instead if you want a specific handle.
- `$self` refers to the current instance inside methods — use it to call other methods on the same object.
- `constructor {args}` + `$self configurelist $args` is the standard pattern to accept `-option value` pairs at creation time.

## 3. Type Variables & Type Methods (class-level, shared across instances)

```tcl
snit::type Counter {
    typevariable totalInstances 0

    typemethod totalCount {} {
        return $totalInstances
    }

    constructor {} {
        incr totalInstances
    }
}

Counter create c1
Counter create c2
Counter totalCount     ;# 2 — called on the type itself, not an instance
```

## 4. Widgets — `snit::widget`

A `snit::widget` becomes a real Tk widget. Inside its body, `$win` (or `$hull`, see below)
refers to the widget's own path; child widgets are created as `$win.something`.

```tcl
snit::widget labeledEntry {
    option -label -default "Label:" -configuremethod ConfigLabel
    option -textvariable

    constructor {args} {
        ttk::label $win.l -text $options(-label)
        ttk::entry $win.e
        pack $win.l -side left
        pack $win.e -side left -fill x -expand 1

        $self configurelist $args
        if {$options(-textvariable) ne ""} {
            $win.e configure -textvariable $options(-textvariable)
        }
    }

    method ConfigLabel {option value} {
        set options($option) $value
        $win.l configure -text $value
    }
}

labeledEntry .le -label "Name:" -textvariable nameVar
pack .le
```

- `$win` is the widget's own path name (e.g. `.le`), automatically created as a `frame`/`hull` container before the constructor runs.
- `-configuremethod` intercepts `configure -option value` calls to run custom logic (e.g. propagate the change to a child widget) instead of just storing the value.
- By default the underlying hull is a `frame`; declare `hulltype` to change it: `snit::widget mywidget { hulltype toplevel ... }` for a widget that's actually a top-level window.

## 5. `snit::widgetadaptor` — Wrapping an Existing Widget

Used when you want to *extend* a single primitive widget (add validation, new methods)
rather than compose several widgets into a container.

```tcl
snit::widgetadaptor validatingEntry {
    constructor {args} {
        installhull using entry
        $self configurelist $args
        bind [$self widget] <KeyRelease> [mymethod Validate]
    }

    method Validate {} {
        set val [$self get]
        if {![string is integer -strict $val]} {
            $hull configure -foreground red
        } else {
            $hull configure -foreground black
        }
    }

    delegate method * to hull
    delegate option * to hull
}

validatingEntry .ve
pack .ve
```

- `installhull using entry` makes the adapted widget itself an `entry` — `$hull` refers to it.
- `delegate method * to hull` / `delegate option * to hull` forward all unrecognized methods/options straight to the underlying widget, so the wrapper behaves like a normal entry plus your additions.

## 6. Delegation (the core Snit idiom)

Delegation avoids re-declaring every option/method a component already supports.

```tcl
snit::widget panel {
    delegate option -text to titleLabel
    delegate option * to hull   ;# catch-all: anything else goes to hull

    delegate method * to content

    constructor {args} {
        install titleLabel using ttk::label $win.title
        install content using ttk::frame $win.content
        pack $win.title -side top -fill x
        pack $win.content -side top -fill both -expand 1
        $self configurelist $args
    }
}
```

- `component name` (implicit via `install name using ...`) declares a named sub-widget.
- `install varName using widgetCommand args...` creates the component and stores its path.
- `delegate option -name to component` forwards a *specific* option; `delegate option * to component` forwards everything not explicitly declared elsewhere.
- `delegate method -name to component` / `delegate method * to component` do the same for methods.
- `delegate option * to component except {-text}` excludes specific names from a wildcard delegation.

## 7. Validation

```tcl
snit::type Age {
    option -value -default 0 -configuremethod ConfigValue

    method ConfigValue {option value} {
        if {![string is integer -strict $value] || $value < 0} {
            error "Age must be a non-negative integer"
        }
        set options($option) $value
    }
}
```

Snit also ships built-in validating types (`snit::integer`, `snit::double`, etc.) usable as
`-type` constraints on options in more advanced declarations — consult `tcllib` docs for the full list.

## 8. Destructor & Lifecycle

```tcl
snit::type Resource {
    variable handle

    constructor {} {
        set handle [openSomeResource]
    }

    destructor {
        closeResource $handle
    }
}

set r [Resource create %AUTO%]
$r destroy     ;# runs destructor, cleans up
```

For widgets, `destroy $win` (the normal Tk destroy) triggers the Snit destructor automatically.

## 9. `mymethod` / `myproc` — Safe Callbacks

Passing `-command $self mymethod` as a literal string breaks if `$self` changes context.
Use `mymethod` inside the type body to build a properly-scoped callback reference:

```tcl
snit::widget clicker {
    constructor {} {
        ttk::button $win.b -text "Click" -command [mymethod OnClick]
        pack $win.b
    }
    method OnClick {} {
        puts "clicked, self = $self"
    }
}
```

`mymethod` expands to a fully-qualified callback bound to the current instance, safe to
pass to `-command`, `bind`, `after`, `trace`, etc.

## 10. Common Full Skeleton

```tcl
snit::widget MyWidget {
    hulltype frame

    option -value -default "" -configuremethod ConfigValue
    delegate option -text to label
    delegate option * to hull

    component label
    component entry

    variable internalState 0

    constructor {args} {
        install label using ttk::label $win.label
        install entry using ttk::entry $win.entry -textvariable [myvar internalState]
        pack $win.label $win.entry -side left
        $self configurelist $args
    }

    method ConfigValue {option value} {
        set options($option) $value
        # propagate to internal widgets/state as needed
    }

    method reset {} {
        set internalState 0
    }

    destructor {
        # cleanup if needed
    }
}
```

`[myvar internalState]` yields the fully-qualified variable name for the instance, useful
when passing an instance variable to something needing `-textvariable`/`-variable`.

## 11. Gotchas

- `option` declarations use `$options(-name)`, not `$name` — always access via the `options` array inside methods.
- Forgetting `$self configurelist $args` in the constructor means `-option value` pairs passed at creation are silently ignored.
- `delegate option * to hull` combined with explicit `option -something` for the same name is a conflict — explicit declarations take precedence, but avoid overlapping definitions to prevent confusion.
- `snit::widget` automatically creates a hull frame; if you need the widget's root to be a different widget class (e.g. `toplevel`, `labelframe`), set `hulltype` explicitly rather than nesting another frame inside.
- Instance/type method names starting with uppercase are a *convention* (not enforced) for "private" methods not meant to be called from outside — Snit does not have real access modifiers.
- `%AUTO%` names are per-type sequential (`Point1`, `Point2`, ...) — don't rely on exact values across runs if type-creation order can vary.
