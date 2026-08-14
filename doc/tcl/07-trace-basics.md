# Trace Basics — Cheatsheet

`trace` lets you attach callbacks to variable reads/writes/unsets, command renames/deletes,
and command execution. It's the primitive that makes reactive, event-driven state management
possible in pure Tcl — a variable write can automatically trigger UI updates, persistence,
validation, or any other side effect, without the writer needing to know about the listeners.

## 1. Variable Traces — Core Syntax

```tcl
trace add variable varName ops callback
trace remove variable varName ops callback
trace info variable varName
```

`ops` is one or more of: `read`, `write`, `unset`, `array` (for whole-array operations).

```tcl
set x 0

proc onWrite {varName index op} {
    puts "write! new value: [set $varName]"
}

trace add variable x write onWrite
set x 5      ;# -> prints "write! new value: 5"
```

- The callback receives `(varName, index, op)` appended after any args you configure.
- `index` is the array index if tracing an array element, or empty for a scalar.
- `op` is the specific operation that fired (`read`, `write`, or `unset`) — useful when a single callback is registered for multiple ops.
- Inside the callback, re-read the value via `set $varName` (or `upvar`) — the callback does **not** receive the new value directly as an argument.

## 2. Read Traces

```tcl
proc onRead {varName index op} {
    puts "someone read $varName"
}
trace add variable x read onRead
set y $x      ;# triggers onRead before the read completes
```

Read traces fire *before* the value is returned to the reader — useful for lazy computation
(compute the value on first access) or access logging. Rare in practice compared to write traces.

## 3. Unset Traces

```tcl
proc onUnset {varName index op} {
    puts "$varName was unset"
}
trace add variable x unset onUnset
unset x      ;# -> prints "x was unset"
```

Fires when the variable goes away — either an explicit `unset` or the variable going out of
scope (e.g. a local proc variable when the proc returns), useful for cleanup logic tied to
a variable's lifetime.

## 4. Array Traces

```tcl
array set arr {a 1 b 2}

proc onArrayWrite {varName index op} {
    puts "arr($index) changed to $arr($index)"
}
trace add variable arr write onArrayWrite

set arr(a) 99      ;# -> prints "arr(a) changed to 99"
```

Tracing the array name (without `()`) with `write` fires on **any** element write. To watch
only a specific element, trace `arr(a)` directly instead of `arr`.

## 5. The Reactive State Pattern

The core idiom used to wire application state to UI or persistence: **write to the source
of truth → reload/recompute → reassign the variable → let `trace` propagate the update**,
rather than manually calling update functions everywhere data changes.

```tcl
namespace eval ::AppState {
    variable currentItems {}

    proc reload {} {
        variable currentItems
        # e.g. re-fetch from a data source
        set currentItems [computeLatestItems]
        # the act of `set`-ing here is what fires any registered trace
    }
}

proc refreshUI {varName index op} {
    puts "UI would now redraw using: [set ::AppState::currentItems]"
}

trace add variable ::AppState::currentItems write refreshUI

::AppState::reload      ;# triggers refreshUI automatically
```

This pattern decouples the code that *changes* state from the code that *reacts* to it —
the state-mutating proc doesn't need to know who's listening, and listeners don't need to
be manually invoked after every mutation site.

## 6. Binding a Trace to a Widget Update

A common concrete use: keep a Tk widget in sync with a data variable that changes for
reasons other than direct user typing (e.g. programmatic reload, computed value).

```tcl
set totalLabel ""

proc updateLabel {varName index op} {
    global totalLabel
    .lbl configure -text "Total: $totalLabel"
}

trace add variable totalLabel write updateLabel
set totalLabel 42      ;# .lbl text updates automatically
```

Note: `-textvariable` already does this specific job for simple text display without a
manual trace — reach for an explicit `trace` when the reaction is more than "display this
value verbatim" (e.g. reformatting, triggering a re-fetch, cascading to multiple widgets).

## 7. Removing Traces

```tcl
trace remove variable x write onWrite
```

Arguments must match exactly what was passed to `trace add` (same var, same ops list, same
callback command) — a common bug is trying to remove a trace with a differently-formatted
`ops` list (e.g. `{write}` vs `write`) that doesn't match what was actually registered.

```tcl
trace info variable x
# -> {write onWrite}
```

`trace info` is the reliable way to inspect what's currently registered before attempting removal.

## 8. Command Traces

```tcl
proc greet {} {puts "hi"}

proc onRename {oldName newName op} {
    puts "$oldName renamed to $newName"
}
trace add command greet rename onRename

rename greet hello
# -> prints "greet renamed to hello"
```

`ops` for command traces: `rename`, `delete`. Less commonly used than variable traces;
mostly relevant for framework/introspection code tracking command lifecycle.

## 9. Execution Traces

Fires when a command is actually invoked — useful for logging/profiling/instrumentation
without modifying the command's own body.

```tcl
proc compute {x} {return [expr {$x * 2}]}

proc onEnter {cmdString op} {
    puts "about to run: $cmdString"
}
trace add execution compute enter onEnter

compute 5
# -> prints "about to run: compute 5"
# -> returns 10
```

`ops` for execution traces: `enter` (before running), `leave` (after running, sees the
result), `enterstep`/`leavestep` (fires for every command *inside* a proc body, not just
the proc call itself — powerful but can be expensive if used broadly).

```tcl
proc onLeave {cmdString code result op} {
    puts "finished: $cmdString -> $result"
}
trace add execution compute leave onLeave
```

## 10. Ordering & Multiple Traces

Multiple traces on the same variable/op fire in the order they were added. Each fires
independently — one callback erroring doesn't automatically prevent others from running,
but an error inside a trace callback does propagate as an error from the triggering
`set`/`unset` statement itself unless caught.

```tcl
trace add variable x write firstCallback
trace add variable x write secondCallback
set x 1   ;# firstCallback runs, then secondCallback
```

## 11. Gotchas

- A trace callback that itself writes to the same traced variable can cause **infinite recursion** unless guarded — e.g. a write trace that reformats a value by writing it back triggers itself again. Common guard: a namespace-level "currently updating" flag checked at the top of the callback, or writing to a different variable and having only *that* write chain forward.
- The callback signature differs by trace type — variable traces get `(name, index, op)`, command traces get `(oldName, newName, op)` or `(name, op)` for delete, execution traces get `(cmdString, op)` for `enter`/`enterstep` and `(cmdString, code, result, op)` for `leave`/`leavestep`. Mixing these up is a common source of "wrong number of args" errors when trace fires.
- Traces on a variable inside a proc's local scope are automatically removed when the proc returns and the variable goes out of scope — long-lived reactive state generally needs to live in a namespace or global variable, not a proc-local one, for the trace to persist meaningfully.
- `trace add variable arrName write cb` (whole array) fires once per element write, not once per `array set` call — a single `array set arr {a 1 b 2}` can trigger the callback multiple times (once per key), which surprises people expecting one callback per statement.
- Performance: traces (especially `enterstep`/`leavestep` execution traces) add overhead to every operation they cover — fine for state variables changed occasionally, potentially costly if attached to something written in a tight loop.
- `trace remove` silently does nothing (no error) if the exact signature you pass doesn't match a registered trace — always verify with `trace info` if a removal doesn't seem to take effect.
