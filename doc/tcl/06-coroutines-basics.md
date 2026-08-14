# Coroutines Basics — Cheatsheet

Coroutines (Tcl 8.6+) let a procedure suspend mid-execution and resume later, preserving
its local call stack. They're the primitive behind generators, cooperative async patterns,
and non-blocking event-driven code without threads or explicit callback chains.

## 1. Core Concept

A coroutine wraps a command in its own **execution context**. Calling `yield` inside that
context suspends it and returns control to the caller; calling the coroutine's name again
resumes execution right after the `yield`.

```tcl
coroutine myCoro apply {{} {
    puts "start"
    yield
    puts "resumed once"
    yield
    puts "resumed twice"
}}

myCoro     ;# -> prints "resumed once"
myCoro     ;# -> prints "resumed twice"
```

- `coroutine name command args...` creates and **immediately starts** the coroutine, running until the first `yield` (or completion, if it never yields).
- `name` becomes a callable command — invoking it resumes execution from the last `yield`.
- Once a coroutine's body finishes running to the end (no more `yield`), the coroutine command ceases to exist; calling it again is an error.

## 2. Passing Values Through `yield`

`yield` both sends a value *out* (to whoever resumes it) and receives a value *in* (passed
on the next resume call) — a two-way channel.

```tcl
coroutine gen apply {{} {
    set x [yield "first"]
    puts "got: $x"
    set y [yield "second"]
    puts "got: $y"
    return "done"
}}

gen                  ;# -> "first" (initial call, argument ignored)
gen "hello"          ;# -> prints "got: hello", returns "second"
gen "world"          ;# -> prints "got: world", returns "done"
```

- The value passed to `coroutine name cmd` initially, or the argument given to a resuming call, becomes `yield`'s return value *inside* the coroutine body.
- The argument to `yield expr` becomes what the *caller* sees as the coroutine command's return value.

## 3. Generators — the Classic Use Case

```tcl
proc range {n} {
    set i 0
    while {$i < $n} {
        yield $i
        incr i
    }
    return -code break   ;# signal exhaustion cleanly
}

coroutine counter range 5

while 1 {
    set val [counter]
    if {$val eq ""} break
    puts $val
}
```

A common idiom: wrap generator logic in a plain `proc` that calls `yield`, then create the
coroutine from that proc — keeps the generator's logic reusable/testable outside coroutine context if needed.

## 4. `yield` vs `yieldto` — Chaining Coroutines

`yieldto` transfers control to *another* coroutine (or resumes it) directly, rather than
just yielding back to whoever called this one — used for coroutine-to-coroutine handoff patterns.

```tcl
coroutine inner apply {{} {
    puts "inner start"
    yield
    puts "inner resumed"
}}

coroutine outer apply {{} {
    puts "outer start"
    yieldto inner
    puts "outer resumed after inner"
}}
```

`yieldto` is mainly relevant for advanced control-flow chaining; most everyday async code
only needs `yield`.

## 5. Non-Blocking I/O Pattern (the primary real-world use)

Coroutines shine for writing code that *reads like* sequential blocking I/O but is actually
event-driven under the hood — avoids nested callback pyramids.

```tcl
proc asyncRead {chan} {
    set coro [info coroutine]
    fileevent $chan readable [list $coro]
    yield
    fileevent $chan readable {}
    return [read $chan]
}

coroutine reader apply {{} {
    set chan [open "somefile.txt" r]
    fconfigure $chan -blocking 0
    set data [asyncRead $chan]
    close $chan
    puts "read: $data"
}}
```

- `info coroutine` returns the name of the currently-running coroutine (or empty string if not inside one) — used to get a self-reference for scheduling a resume via `fileevent`/`after`.
- The pattern: register a callback (`fileevent`, `after`) that simply calls the coroutine again, then `yield` immediately — when the event fires, the coroutine resumes exactly where it left off, with the rest of the proc reading like normal blocking code.

## 6. `after` + Coroutine — Non-Blocking Delay

```tcl
proc asyncSleep {ms} {
    set coro [info coroutine]
    after $ms [list $coro]
    yield
}

coroutine worker apply {{} {
    puts "before sleep"
    asyncSleep 1000
    puts "after 1 second, non-blocking"
}}
```

This achieves a "sleep" that doesn't block the Tk/event-loop main thread, unlike `after $ms`
used alone without an event loop context (which does block if not paired with `vwait`).

## 7. Coroutines and the Event Loop

Coroutines don't run in parallel — they cooperate with the **single-threaded event loop**.
A coroutine only resumes when something explicitly calls it again (directly, or via a
scheduled `fileevent`/`after` callback). This means:

- No race conditions between coroutines — only one executes at a time.
- A coroutine that never yields blocks everything else, same as any long-running Tcl code.
- Coroutines are a structuring tool for async *code style*, not a concurrency/threading mechanism.

## 8. Cleanup / Early Termination

```tcl
coroutine c apply {{} {
    try {
        while 1 {
            yield
            puts "working"
        }
    } finally {
        puts "cleanup ran"
    }
}}

c
rename c {}     ;# destroying the coroutine command runs pending `finally` blocks
```

Deleting the coroutine's command (`rename coroName {}`) unwinds its stack, triggering any
`finally` blocks — the standard way to force-terminate a coroutine that would otherwise loop
indefinitely waiting on `yield`.

## 9. Coroutine-Backed Iterator Wrapper

A common ergonomic pattern: hide the "call repeatedly until empty" boilerplate behind a
`foreach`-like helper.

```tcl
proc coroForeach {varName coroName script} {
    upvar 1 $varName var
    while 1 {
        set var [$coroName]
        if {[info exists ::coroDone($coroName)]} break
        uplevel 1 $script
    }
}
```

(Exact "done" signaling varies by convention — some generators return a sentinel value,
others use `return -code break` and let the caller catch the coroutine's termination error;
pick one convention and apply it consistently across a codebase.)

## 10. Gotchas

- A coroutine's local variables persist across suspensions (that's the whole point), but each coroutine has its **own separate call stack** — variables aren't shared with the caller unless passed explicitly through `yield`'s values or accessed via `upvar`/globals/namespace variables.
- Calling a coroutine command *after* its body has run to completion (no trailing `yield`) raises `invalid command name` — the command is deleted automatically on natural completion, same as after explicit `rename ... {}`.
- Nesting coroutines (a coroutine that itself creates another coroutine) works, but keeping track of which `info coroutine` context you're in matters — `info coroutine` always refers to the *innermost* running coroutine, not necessarily the one you think initiated a call chain.
- Forgetting to reset `fileevent`/cancel `after` handlers before a coroutine exits (natural completion or forced `rename`) can leave dangling callbacks trying to resume a now-deleted coroutine — always pair registration with cleanup, ideally via `try ... finally`.
- `yieldto` has different semantics from `yield` (control transfer vs. suspend-and-return) — don't use them interchangeably; most application code only needs `yield`.
