# upvar / uplevel Basics — Cheatsheet

`upvar` and `uplevel` let code reach across stack frames — linking a local variable to one
in a caller's scope, or running code as if it were written directly in a caller's context.
They're the mechanism behind pass-by-reference idioms, `variable`/`global` themselves
(both are implemented in terms of `upvar`), and custom control-structure commands.

## 1. Stack Levels — the Shared Concept

Both commands take a **level** argument specifying which frame to reach:

| Level syntax | Meaning |
|---|---|
| `1` (or omitted, default) | The immediate caller's frame |
| `2` | The caller's caller |
| `#0` | The absolute global frame |
| `#1` | The absolute frame 1 (first call after global) |

```tcl
proc a {} { b }
proc b {} { c }
proc c {} {
    # level 1 = b's frame, level 2 = a's frame, #0 = global
}
```

Relative levels (`1`, `2`, ...) count *upward from the current frame*. Absolute levels
(`#0`, `#1`, ...) count *downward from the global frame* — useful when you don't know how
deep the current call stack is, but know you want a specific absolute frame.

## 2. `upvar` — Linking a Local Name to a Variable in Another Frame

```tcl
proc setValue {varName value} {
    upvar 1 $varName localAlias
    set localAlias $value
}

set x 0
setValue x 42
puts $x      ;# 42
```

- `upvar level otherVar localName` creates `localName` as an alias for `otherVar` in the specified frame — writes to `localName` inside the current proc actually write to the caller's variable.
- This is how Tcl achieves pass-by-reference despite all arguments normally being passed by value (as copies) — the *proc's own local variable* becomes a live link to the caller's.
- Level `1` (the caller) is by far the most common case; that's why `global`/`variable` (which are really `upvar #0` / `upvar` into a namespace, respectively) exist as shorthands for the two most frequent patterns.

## 3. `global` and `variable` Are `upvar` Under the Hood

```tcl
# roughly equivalent:
proc a {} {
    global x
    # ...
}
proc a {} {
    upvar #0 x x
    # ...
}
```

Understanding this equivalence explains *why* `global`/`variable` behave the way they do:
they don't "import a value," they alias a local name to a variable living in another frame
(the global frame, or a namespace's storage) — exactly like manual `upvar`.

## 4. Multiple Variables in One Call

```tcl
proc swap {aName bName} {
    upvar 1 $aName a $bName b
    set tmp $a
    set a $b
    set b $tmp
}

set x 1; set y 2
swap x y
puts "$x $y"      ;# 2 1
```

`upvar` accepts multiple `otherVar localName` pairs in a single call, all resolved against
the same level.

## 5. `upvar` with Arrays

```tcl
proc showArray {arrName} {
    upvar 1 $arrName arr
    foreach key [array names arr] {
        puts "$key = $arr($key)"
    }
}

array set data {a 1 b 2}
showArray data
```

Aliasing an array name with `upvar` gives full read/write access to the caller's array
under the local name — the standard way to write procs that operate generically on
"whatever array the caller passes," without needing the caller to pass individual elements.

## 6. `uplevel` — Executing Code in Another Frame

```tcl
proc setInCaller {varName value} {
    uplevel 1 [list set $varName $value]
}

set x 0
setInCaller x 99
puts $x      ;# 99
```

- `uplevel level script` runs `script` *as if it had been typed directly* in the target frame — not just reading/writing a variable, but executing arbitrary code there.
- Prefer `[list ...]` to build the script argument safely — it guarantees proper quoting of variable values so they're treated as literal data, not re-evaluated as code (the same safety concern as building any dynamic Tcl command).
- `uplevel #0 script` runs code in the **global** frame — commonly used by libraries that need to define something globally regardless of how deeply nested the current call is (e.g. inside a deeply nested callback).

## 7. Writing Custom Control Structures

`uplevel` is what makes it possible to write commands that *feel* like language keywords —
because their body executes in the caller's scope, not the defining proc's own scope.

```tcl
proc myWhile {condition body} {
    while {[uplevel 1 [list expr $condition]]} {
        uplevel 1 $body
    }
}

set i 0
myWhile {$i < 3} {
    puts $i
    incr i
}
```

Without `uplevel`, `body` would execute inside `myWhile`'s own local scope, and `incr i`
would create/modify a variable local to `myWhile` instead of the caller's `i` — breaking
the illusion of a native control structure.

## 8. `upvar` vs `uplevel` — When to Use Which

| Need | Use |
|---|---|
| Read/write a specific variable in another frame | `upvar` |
| Run an arbitrary block of code in another frame's context | `uplevel` |
| Pass-by-reference into a helper proc | `upvar` |
| Implement a custom control structure (loop, conditional) | `uplevel` |
| Array pass-by-reference | `upvar` |

They're often combined: a command might use `uplevel` to run a caller-supplied script, and
`upvar` to expose a loop variable to that script.

```tcl
proc myForeachPair {varA varB list body} {
    upvar 1 $varA a $varB b
    foreach {a b} $list {
        uplevel 1 $body
    }
}

myForeachPair x y {1 2 3 4} {
    puts "$x-$y"
}
```

## 9. Common Pitfall: Level Confusion in Nested Helpers

If a proc using `upvar`/`uplevel` calls *another* proc that also needs to reach the original
caller, level `1` from the inner helper points to the **outer helper's** frame, not the
original caller — level counting is always relative to where the `upvar`/`uplevel` call
itself is written.

```tcl
proc outer {varName} {
    inner $varName    ;# inner's level 1 = outer's frame, NOT outer's caller
}

proc inner {varName} {
    upvar 1 $varName v      ;# WRONG if you wanted the original caller's variable
    upvar 2 $varName v      ;# RIGHT — reaches past outer to its caller
}
```

A more robust pattern when writing layered helpers: have the outer proc do its own `upvar`
to establish a local alias, then simply pass *that* value or a fixed reference forward,
rather than trying to guess levels across multiple indirections.

## 10. Gotchas

- Level counting is **dynamic** (based on the actual call chain at runtime), not lexical — the same proc body can be called from different depths and `upvar 1`/`uplevel 1` will correctly always mean "my immediate caller," but hardcoding a level like `2` breaks if the proc is ever called through an additional layer of indirection.
- `uplevel` re-parses and re-evaluates its script argument as Tcl code — building it via string concatenation instead of `list` risks the same code-injection-style bugs as any dynamically constructed command; always prefer `uplevel 1 [list cmd $arg]` over `uplevel 1 "cmd $arg"` when `$arg` isn't a fixed literal.
- `upvar` creates a link at the time it's called — reassigning the *name* passed in (`varName`) after the fact does not move the alias; the link is to whatever variable name was resolved at the `upvar` call itself.
- Using `upvar`/`uplevel` to reach arbitrarily deep, fragile call chains is a sign the code might be better structured with explicit return values or namespace/object state instead — reach for these commands primarily for pass-by-reference helpers and control-structure-style commands, not as a general substitute for normal data flow.
- Inside a coroutine, stack levels behave relative to the coroutine's own call chain, not the code that resumed it — `upvar`/`uplevel` used inside coroutine bodies should be tested carefully if the coroutine is entered from multiple different call sites.
