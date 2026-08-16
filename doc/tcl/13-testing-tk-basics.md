# Testing Tk Widgets — Cheatsheet

Testing Tk code with `tcltest` requires a running Tk interpreter (a display, or a headless
X server on Linux) and careful handling of the event loop, since widget interactions are
asynchronous. This guide assumes familiarity with `tcltest` basics (see the dedicated guide).

```tcl
package require Tk
package require tcltest
namespace import ::tcltest::*
```

## 1. Core Principle — Separate Logic from Presentation

The most effective Tk-testing strategy is minimizing what actually needs a widget. Business
logic (state management, computation, validation) should live in plain procs/namespaces
testable with ordinary `tcltest`, with no Tk dependency at all. Reserve widget-based tests
for things that genuinely can't be verified without an actual widget — layout, visual
state, widget-specific event handling.

```tcl
# testable without Tk at all
test compute-1 {} -body {
    ::AppLogic::calculateTotal {10 20 30}
} -result 60

# needs a real widget — only for what actually requires one
test label-display-1 {} -setup {
    ttk::label .l -text ""
} -body {
    .l configure -text [::AppLogic::calculateTotal {10 20 30}]
    .l cget -text
} -cleanup {
    destroy .l
} -result 60
```

## 2. Widget Lifecycle in `-setup`/`-cleanup`

Always create widgets in `-setup` and destroy them in `-cleanup` — never leave widgets from
one test alive into the next, since Tk widget paths are global and a leftover `.entry`
collides with the next test trying to create the same path.

```tcl
test entry-basic-1 {entry stores typed text} -setup {
    set testVar ""
    ttk::entry .testEntry -textvariable testVar
    pack .testEntry
} -body {
    .testEntry insert 0 "hello"
    set testVar
} -cleanup {
    destroy .testEntry
} -result "hello"
```

`destroy` on a parent also destroys all descendants — for tests that build a small widget
tree, destroying just the top-level test container in `-cleanup` is enough.

```tcl
test form-1 {} -setup {
    ttk::frame .testForm
    ttk::entry .testForm.e
    pack .testForm.e
} -body {
    .testForm.e insert 0 "x"
    .testForm.e get
} -cleanup {
    destroy .testForm    ;# removes .testForm and .testForm.e together
} -result "x"
```

## 3. Simulating User Input — `event generate`

Rather than requiring actual mouse/keyboard interaction, tests synthesize events directly
on a widget.

```tcl
test button-click-1 {button command fires on click} -setup {
    set ::clicked 0
    ttk::button .testBtn -command {set ::clicked 1}
    pack .testBtn
} -body {
    event generate .testBtn <Button-1>
    event generate .testBtn <ButtonRelease-1>
    update
    set ::clicked
} -cleanup {
    destroy .testBtn
} -result 1
```

```tcl
test keypress-1 {Return key triggers binding} -setup {
    set ::submitted 0
    ttk::entry .testEntry
    bind .testEntry <Return> {set ::submitted 1}
    pack .testEntry
} -body {
    focus .testEntry
    event generate .testEntry <KeyPress> -keysym Return
    update
    set ::submitted
} -cleanup {
    destroy .testEntry
} -result 1
```

Common synthesized events: `<Button-1>`/`<ButtonRelease-1>` (click), `<Double-Button-1>`,
`<KeyPress>`/`<KeyRelease>` with `-keysym`, `<Enter>`/`<Leave>` (mouse hover), `<FocusIn>`/`<FocusOut>`.

## 4. `update` and `update idletasks` — Forcing the Event Loop to Catch Up

Synthesized events (and any state change with side effects, like a `trace`-driven UI
update) don't necessarily take effect the instant the triggering line runs — the actual
callback/redraw may be scheduled for the next event-loop pass.

```tcl
test reactive-label-1 {label reflects state change via trace} -setup {
    set ::AppState::total 0
    trace add variable ::AppState::total write ::updateLabelFromState
    ttk::label .lbl -textvariable ::AppState::total
} -body {
    set ::AppState::total 42
    update idletasks
    .lbl cget -text
} -cleanup {
    trace remove variable ::AppState::total write ::updateLabelFromState
    destroy .lbl
} -result 42
```

- `update idletasks` processes pending idle-time work (redraws, geometry recalculation) without processing new input events — usually sufficient and safer for tests, since it won't accidentally pick up unrelated queued events.
- `update` (no args) processes *all* pending events, including input — use when a test genuinely needs a full event-loop pass (e.g. after `event generate` for a click).
- Forgetting either after a synthesized event or a reactive state change is a common cause of tests reading stale widget state — a "the callback hasn't run yet" false negative, not a real bug in the code under test.

## 5. Testing `-textvariable`/`-variable` Bindings

```tcl
test checkbutton-var-1 {} -setup {
    set ::flag 0
    ttk::checkbutton .cb -variable ::flag
    pack .cb
} -body {
    .cb invoke
    set ::flag
} -cleanup {
    destroy .cb
} -result 1
```

`invoke` directly triggers a widget's associated command/state-toggle without needing to
synthesize a full click sequence — preferred over `event generate` when available (buttons,
checkbuttons, radiobuttons all support `invoke`), since it's more direct and less dependent
on platform-specific event details.

## 6. Testing Custom Widgets (Snit megawidgets)

Test a Snit-based widget the same way as any built-in widget — through its public options
and methods, not its internal component structure.

```tcl
test labeled-entry-1 {custom widget exposes typed value via textvariable} -setup {
    set myVar ""
    labeledEntry .le -label "Name:" -textvariable myVar
    pack .le
} -body {
    .le.e insert 0 "Alice"          ;# reaching into a known internal child, if needed
    set myVar
} -cleanup {
    destroy .le
} -result "Alice"
```

Reaching into a component's internal child path (`.le.e`) is sometimes unavoidable for
simulating input, but prefer exercising the widget's own public methods where the widget
design provides them (e.g. a `$widget setValue "Alice"` method), since that stays valid
even if internal component structure changes later.

## 7. Assessing Geometry / Layout

```tcl
test frame-size-1 {} -setup {
    ttk::frame .testFrame -width 200 -height 100
    pack .testFrame
    update idletasks
} -body {
    list [winfo width .testFrame] [winfo height .testFrame]
} -cleanup {
    destroy .testFrame
} -result {200 100}
```

`winfo width`/`winfo height`/`winfo reqwidth`/`winfo reqheight` return actual/requested
widget dimensions — always call `update idletasks` first, since geometry isn't finalized
until the geometry manager has actually run.

## 8. Headless / CI Environments

Tk needs a display. On Linux CI without a physical display, use a virtual X server:

```bash
xvfb-run -a tclsh mytest.test
```

```bash
# or manage Xvfb manually
Xvfb :99 -screen 0 1024x768x24 &
export DISPLAY=:99
tclsh mytest.test
```

On macOS, Tk requires an active graphical session (Aqua) — there isn't a direct headless
equivalent to `Xvfb`; CI runners need either a real logged-in session or a
virtualization/screen-sharing setup that provides one. Verify your specific CI provider's
support before assuming Tk tests will run unmodified in a macOS CI job.

## 9. Isolating Tests from Leftover Global/Widget State

```tcl
proc resetAppState {} {
    array unset ::AppState::*
    # re-initialize whatever defaults the app expects
}

test isolated-1 {} -setup {
    resetAppState
    ttk::label .l
} -body {
    # ...
} -cleanup {
    destroy .l
    resetAppState
}
```

Widgets are cheap to destroy/recreate per test; application-level namespace state (like a
singleton store) is easy to forget resetting between tests, and stale state there is a more
common source of order-dependent test failures than leftover widgets.

## 10. Gotchas

- Widget paths are global to the interpreter — two tests that both create `.testEntry` without destroying it in between will fail on the second creation with "window name already exists," not a subtle assertion failure; always pair every `-setup` widget creation with a matching `-cleanup` destroy.
- `event generate` fires the event but does not guarantee any resulting callback has *finished* running before the next line executes — always follow with `update`/`update idletasks` before reading state that a callback is expected to have changed.
- Some widget behaviors (native OS look, certain platform-specific bindings) differ across macOS/Windows/Linux — a test passing locally on one platform isn't a guarantee it behaves identically elsewhere; keep Tk-dependent tests focused on cross-platform-stable behavior where possible.
- `focus` matters for keyboard-event tests — synthesizing a `<KeyPress>` on a widget that isn't focused can behave differently than expected depending on the platform and binding tags involved; explicitly call `focus $widget` before key-event tests that depend on focus-sensitive bindings.
- Tests that leave `trace`s registered on shared/global variables without removing them in `-cleanup` can cause later, unrelated tests to trigger unexpected callbacks — always pair `trace add` in `-setup` with `trace remove` in `-cleanup`, same discipline as widget creation/destruction.
- Running Tk tests requires an actual interpreter with `package require Tk` succeeding — in strictly headless environments without any display server configured at all, the whole test file fails to even load, not just individual tests; confirm `Xvfb`/display setup is part of the CI pipeline before Tk-dependent tests are added to it.
