# package / Module Organization Basics — Cheatsheet

Tcl's `package` system is how code gets split across multiple files and declared as
reusable units with version numbers, without a built-in module/import system like some
other languages. It's built on `package provide`/`package require` plus a lightweight
discovery mechanism (`pkgIndex.tcl`) that lets `package require` find and load code lazily,
on first use, rather than requiring an explicit file path.

## 1. Core Vocabulary

```tcl
package provide MyLib 1.0     ;# declares "this file/script implements MyLib version 1.0"
package require MyLib          ;# declares "I need MyLib, load it if not already loaded"
package require MyLib 1.0-     ;# version constraint: 1.0 or higher
package require MyLib 1.0      ;# exact-ish match (compatible with 1.x per Tcl's version rules)
```

- `package provide` is a **declaration**, not a loader — it just registers that a name/version is now available in the interpreter. It's typically the last line of a library file.
- `package require` is the **consumer-side** request — it triggers the discovery mechanism to find and `source`/load whatever satisfies that name/version if it isn't already loaded.
- Versions follow `major.minor.patch` dotted numbering; `package require` version constraints support ranges (`1.0-2.0`), minimums (`1.0-`), and exact matches.

## 2. The Simplest Case — Direct `source`

For small projects, skip the package system entirely and just `source` files directly —
perfectly valid, and often clearer for a handful of files with a fixed load order.

```tcl
source lib/core.tcl
source lib/ui.tcl
source lib/utils.tcl
```

The formal `package` mechanism earns its complexity when: multiple modules need to declare
dependencies on each other, you want lazy/on-demand loading, or you're distributing a
library meant to be dropped into other projects without the consumer needing to know exact
file paths.

## 3. `pkgIndex.tcl` — the Discovery File

A directory containing a library places a `pkgIndex.tcl` file describing what it provides
and how to load it. This is what lets `package require MyLib` work without the caller
knowing the library's internal file layout.

```
mylib/
├── pkgIndex.tcl
├── core.tcl
└── helpers.tcl
```

```tcl
# mylib/pkgIndex.tcl
package ifneeded MyLib 1.0 [list source [file join $dir core.tcl]]
```

- `package ifneeded name version script` registers *how* to load a package without loading it yet — `script` runs only when something actually calls `package require MyLib`.
- `$dir` is automatically set by the package mechanism to the directory containing `pkgIndex.tcl` — always use it rather than a hardcoded path, so the library works regardless of where it's installed/copied.
- If a library spans multiple files, `core.tcl` typically `source`s the others itself (`helpers.tcl`, etc.) — `pkgIndex.tcl` only needs to know the single entry point.

```tcl
# mylib/core.tcl
source [file join [file dirname [info script]] helpers.tcl]

namespace eval ::MyLib {
    # ... implementation ...
}

package provide MyLib 1.0
```

`[info script]`/`[file dirname ...]` inside a library file is the standard way to locate
sibling files relative to *this file's own location*, regardless of the caller's working
directory.

## 4. Making a Package Directory Discoverable — `auto_path`

`package require` only finds `pkgIndex.tcl` files in directories the interpreter already
knows to look in — `auto_path`.

```tcl
lappend auto_path [file join [file dirname [info script]] lib]
package require MyLib
```

- `auto_path` is a list of directories scanned for packages.
- A common pattern: prepend your project's own `lib/` directory (relative to the main script) to `auto_path` at startup, so bundled/local libraries are found the same way system-installed ones are.
- `TCLLIBPATH` (an environment variable) can also seed `auto_path` at interpreter startup, useful for deployment-time configuration without modifying source.

## 5. Full Minimal Example — Two-File Library + Consumer

```
project/
├── main.tcl
└── lib/
    └── mathutils/
        ├── pkgIndex.tcl
        └── mathutils.tcl
```

```tcl
# lib/mathutils/pkgIndex.tcl
package ifneeded mathutils 1.0 [list source [file join $dir mathutils.tcl]]
```

```tcl
# lib/mathutils/mathutils.tcl
namespace eval ::mathutils {
    namespace export square cube

    proc square {x} {return [expr {$x * $x}]}
    proc cube {x} {return [expr {$x * $x * $x}]}
}

package provide mathutils 1.0
```

```tcl
# main.tcl
lappend auto_path [file join [file dirname [info script]] lib]
package require mathutils

puts [::mathutils::square 5]      ;# 25
```

## 6. Namespaces + Packages — How They Combine

`package` handles *file loading and versioning*; `namespace` handles *naming/scoping*.
They're independent mechanisms that are conventionally paired: one package = one namespace,
with the package name and namespace name matching for clarity.

```tcl
namespace eval ::mathutils { ... }
package provide mathutils 1.0
```

Nothing in the language *requires* this pairing — a package could define multiple
namespaces, or none — but matching them 1:1 is the overwhelmingly common convention and
makes a codebase easier to navigate.

## 7. `package require` Failure Handling

```tcl
if {[catch {package require OptionalFeature} err]} {
    puts "Optional feature not available: $err"
}
```

`package require` raises a normal Tcl error if the requested package/version can't be
found — catchable like any other error, useful for genuinely optional dependencies.

## 8. Querying Loaded Packages

```tcl
package versions MyLib          ;# list of versions of MyLib currently registered via ifneeded
package present MyLib            ;# errors if not loaded; returns version if it is
info loaded                       ;# list of loaded binary/C extensions (different from Tcl-level packages)
```

## 9. Reloading During Development

Tcl has no built-in "hot reload" for packages — once `package provide` has registered a
name/version as loaded, a subsequent `package require` of the same version is a no-op
(it assumes it's already satisfied). During active development, re-sourcing a file
directly is more practical than fighting the package cache:

```tcl
source lib/mathutils/mathutils.tcl    ;# re-run directly to pick up edits, bypassing package require's cache
```

Some projects use `package forget name` to clear the registration, forcing a subsequent
`package require` to re-run its `ifneeded` script — but this only works cleanly if the
library's own file doesn't do things that break when re-sourced twice (e.g. redefining an
`oo::class` in a way that conflicts with the still-live original).

## 10. Structuring a Multi-Module Application

A common layout for a project with several internally-related modules, each following the
one-namespace-per-package convention:

```
project/
├── main.tcl
├── lib/
│   ├── store/
│   │   ├── pkgIndex.tcl
│   │   └── store.tcl          # namespace ::Store, package "store"
│   ├── ui/
│   │   ├── pkgIndex.tcl
│   │   └── ui.tcl             # namespace ::UI, package "ui"
│   └── models/
│       ├── pkgIndex.tcl
│       └── models.tcl          # namespace ::Models, package "models"
```

```tcl
# main.tcl
lappend auto_path [file join [file dirname [info script]] lib]
package require store
package require models
package require ui

::Store::init "app.db"
::UI::launch
```

Each module declares only the packages *it* directly depends on inside its own file
(e.g. `ui.tcl` might `package require models` internally if it needs model types) —
dependencies cascade automatically through `package require`'s own resolution, so `main.tcl`
doesn't need to know the full transitive dependency graph.

## 11. Gotchas

- `package provide` must match the name/version `pkgIndex.tcl` promised via `ifneeded` — a mismatch (e.g. file says `package provide MyLib 1.1` but `pkgIndex.tcl` registered `1.0`) causes `package require MyLib 1.0` to fail even though the file did load, because the actual provided version doesn't satisfy what was requested.
- Forgetting to add a library's containing directory to `auto_path` is the most common "package require can't find X" bug — the package mechanism does not scan arbitrary directories by default, only ones explicitly registered.
- `pkgIndex.tcl` scripts should stay minimal (just the `package ifneeded` call) — avoid putting real logic there, since it may be evaluated during a directory scan even for packages never actually required, and errors there can break discovery of unrelated packages in the same scan.
- `package require` without a version loads whatever's the highest version registered via `ifneeded` for that name — relying on this in library code that must run against a specific version can silently pick up an incompatible newer one if multiple versions happen to be installed; pin a version constraint when it matters.
- Circular package dependencies (A requires B, B requires A) will fail or behave unpredictably — structure shared code into a third, lower-level package both depend on instead.
- Re-sourcing a file that does `oo::class create` or `namespace eval` with class/proc redefinitions is usually safe (Tcl allows redefinition), but re-sourcing one that does one-time initialization (e.g. opening a database connection at file-load time) will re-run that initialization — be deliberate about what lives at a package's top level versus inside an explicit `init` proc.
