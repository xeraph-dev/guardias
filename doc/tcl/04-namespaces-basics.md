# Namespaces Basics — Cheatsheet

Namespaces partition the global command/variable table into separate hierarchical scopes,
similar to modules/packages in other languages. They're the standard way to avoid naming
collisions and to build **singleton stores** (module-level state shared across a program).

## 1. Declaration & Nesting

```tcl
namespace eval ::MyModule {
    # body runs immediately, like a script
}

# nested namespaces
namespace eval ::App::Data {
    variable cache {}
}
```

- `::` is the root namespace separator (like `/` for paths). `::App::Data` is a fully-qualified name.
- `namespace eval` can be called multiple times on the same namespace — it reopens/extends it rather than recreating it, so a module's definition can be split across files or added to incrementally.
- Names without a leading `::` are relative to the *current* namespace context when the code runs, not necessarily where it's textually written — this is a common source of bugs (see Gotchas).

## 2. Variables in Namespaces

```tcl
namespace eval ::Counter {
    variable count 0

    proc increment {} {
        variable count
        incr count
    }

    proc get {} {
        variable count
        return $count
    }
}

::Counter::increment
::Counter::increment
::Counter::get           ;# 2
```

- `variable name value` inside a `namespace eval` block declares/initializes a namespace-scoped variable.
- Inside a `proc` defined in that namespace, `variable name` (no value) *imports* the namespace variable into local scope — without this line, the proc sees an undeclared local variable, not the namespace one.
- This import step is required even though the proc lives inside the namespace — Tcl does not implicitly share scope between a namespace and its procs.

## 3. Procedures in Namespaces

```tcl
namespace eval ::Math {
    proc square {x} {
        return [expr {$x * $x}]
    }
    proc cube {x} {
        return [expr {$x * [square $x]}]   ;# unqualified call resolves within the namespace first
    }
}

::Math::square 4      ;# 16
::Math::cube 3         ;# 27
```

Unqualified command calls made *from inside* a namespace's procs resolve against that
namespace first, then fall back to the global namespace — so `square` inside `cube` doesn't
need the `::Math::` prefix. Calls from *outside* the namespace need the full path (or `namespace import`, see below).

## 4. Exporting & Importing

```tcl
namespace eval ::Geometry {
    namespace export area perimeter

    proc area {w h} {return [expr {$w * $h}]}
    proc perimeter {w h} {return [expr {2 * ($w + $h)}]}
    proc InternalHelper {} {}   ;# not exported — convention: leading uppercase = private
}

namespace import ::Geometry::*
area 3 4        ;# 12 — usable unqualified after import
```

- `namespace export pattern...` declares which commands are importable (glob patterns allowed).
- `namespace import ns::*` pulls exported commands into the *current* namespace as local aliases.
- Importing is optional — fully-qualified calls (`::Geometry::area`) always work without exporting/importing anything; export/import exists purely for ergonomics.
- Leading-uppercase proc names are a **common convention** (not a language rule) to signal "internal, not exported."

## 5. Namespaces as Singleton Stores

The most common practical use: a namespace holding module-wide state, accessed through its procs — a lightweight substitute for a "static class" or singleton object.

```tcl
namespace eval ::AppState {
    variable currentUser ""
    variable settings [dict create theme dark lang en]

    proc setUser {name} {
        variable currentUser
        set currentUser $name
    }

    proc getUser {} {
        variable currentUser
        return $currentUser
    }

    proc getSetting {key} {
        variable settings
        return [dict get $settings $key]
    }
}

::AppState::setUser "alice"
::AppState::getUser              ;# alice
::AppState::getSetting theme      ;# dark
```

This pattern gives you: one shared instance by construction (no `create`/instantiation step),
encapsulated state (variables aren't directly reachable without going through `::AppState::`
unless the caller fully-qualifies the variable name), and a stable access path from anywhere
in the program via the fully-qualified namespace name.

## 6. Ensembles — Namespace as a Single Dispatched Command

`namespace ensemble` turns a namespace's exported procs into subcommands of one dispatcher
command, giving an object-like `command subcommand args` calling convention without a full
object system.

```tcl
namespace eval ::Stack {
    namespace export push pop peek
    variable items {}

    proc push {val} {
        variable items
        lappend items $val
    }
    proc pop {} {
        variable items
        set val [lindex $items end]
        set items [lrange $items 0 end-1]
        return $val
    }
    proc peek {} {
        variable items
        return [lindex $items end]
    }

    namespace ensemble create
}

::Stack push 1
::Stack push 2
::Stack pop          ;# 2
```

`namespace ensemble create` must run **after** the procs it dispatches to are defined.
Calling `::Stack push 1` is equivalent to `::Stack::push 1`, but reads like a single object
with subcommands — useful for singleton stores that want a cleaner call syntax.

## 7. Introspection

```tcl
namespace exists ::MyModule
namespace children ::               ;# list of top-level namespaces
namespace current                    ;# fully-qualified name of the namespace currently executing
info procs ::MyModule::*             ;# list procs in a namespace
namespace which -command foo         ;# resolve a command name to its fully-qualified form
namespace delete ::MyModule          ;# remove a namespace and everything in it
```

## 8. Variable Resolution Details

```tcl
namespace eval ::A {
    variable x 10
}

namespace eval ::B {
    proc show {} {
        puts $::A::x     ;# fully-qualified reference works from anywhere, no import needed
    }
}
::B::show      ;# 10
```

You can always reach a namespace variable via its fully-qualified name (`$::Ns::var`)
without declaring it with `variable` first — the `variable` command is only needed to
create a *local alias* inside a proc so you can use the short name and have `set`/`incr`
write back to the namespace copy.

## 9. Gotchas

- `namespace eval ::Foo { proc bar {} {...} }` — inside `bar`'s body, unqualified variable references do **not** automatically see `::Foo`'s variables; you still need `variable varName` at the top of `bar` even though `bar` is lexically defined inside the `namespace eval` block. Namespace scoping applies to where a proc's *name* lives, not automatic variable capture.
- Relative (non-`::`-prefixed) command/variable names resolve based on the *namespace context active when the code executes*, which for a proc is the namespace it was defined in — but sourcing/`eval`-ing code can shift this in surprising ways; prefer fully-qualified names in library code meant to be safe regardless of caller context.
- `namespace import` can silently fail to overwrite an existing command with the same name unless `-force` is passed: `namespace import -force ::Geometry::*`.
- Deleting a namespace (`namespace delete`) does **not** automatically clean up traces or external references held elsewhere (e.g. widget `-textvariable` bindings) — clean those up explicitly first.
- A namespace and a global-scope variable/command of the same base name are entirely distinct entities — `::x` and `::Foo::x` never collide, which is the whole point, but can also mask a missing `variable` import as a "works with wrong data" bug rather than an obvious error.
