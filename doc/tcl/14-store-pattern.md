# Store Pattern — Reactive State Without Global Variables

A common need in Tcl/Tk applications: keep views (widgets) in sync with application state,
without relying on globally-named variables or namespace singletons. The **Store pattern**
solves this with a base TclOO class that wraps `trace` internally and exposes a small,
explicit API — `set`/`get` for data access, `subscribe`/`unsubscribe` for reactivity —
so views never touch `trace` or namespace-qualified variable names directly.

This guide assumes familiarity with TclOO, `trace`, and Snit basics (see the dedicated
guides for each).

## 1. The Problem This Solves

Two common anti-patterns this pattern avoids:

- **Namespace singletons** (`::AppState::total`) — works, but every consumer is coupled to
  one fixed global name, making isolated testing and multiple independent instances hard.
- **Direct `trace` from views** — works, but each view needs to know the model's internal
  namespace-qualified variable name and re-implement array-field filtering logic itself.

The Store pattern centralizes both the data-access API and the subscription mechanism in
one reusable base class, so domain models (`Cart`, `Settings`, etc.) get reactivity "for
free" just by inheriting from it.

## 2. Base `Store` Class

```tcl
oo::class create Store {
    variable subscriptions

    constructor {} {
        set subscriptions [dict create]
    }

    # ---- generic data access ----

    # set varName value           -> scalar
    # set varName field value      -> array field
    method set {varName args} {
        switch [llength $args] {
            1 {
                set [my Namespaced $varName] [lindex $args 0]
            }
            2 {
                lassign $args field value
                set [my Namespaced $varName]($field) $value
            }
            default {
                error "wrong # args: should be \"set varName ?field? value\""
            }
        }
    }

    # get varName          -> scalar
    # get varName field     -> array field
    method get {varName args} {
        switch [llength $args] {
            0 { return [set [my Namespaced $varName]] }
            1 { return [set [my Namespaced $varName]([lindex $args 0])] }
            default {
                error "wrong # args: should be \"get varName ?field?\""
            }
        }
    }

    # ---- subscription ----

    # subscribe varName callback           -> scalar, or "any field" of an array
    # subscribe varName field callback      -> specific array field
    method subscribe {varName args} {
        set callback [lindex $args end]
        set field [expr {[llength $args] > 1 ? [lindex $args 0] : ""}]

        set fullVarName [my Namespaced $varName]
        set handler [list [self] HandleTrace $field $callback]

        trace add variable $fullVarName write $handler
        dict set subscriptions [list $varName $field $callback] $handler
    }

    # unsubscribe with the same signature as subscribe
    method unsubscribe {varName args} {
        set callback [lindex $args end]
        set field [expr {[llength $args] > 1 ? [lindex $args 0] : ""}]

        set key [list $varName $field $callback]
        if {[dict exists $subscriptions $key]} {
            trace remove variable [my Namespaced $varName] write [dict get $subscriptions $key]
            dict unset subscriptions $key
        }
    }

    method Namespaced {varName} {
        return [info object namespace [self]]::$varName
    }

    # name1 = variable name, name2 = array index (empty for scalars)
    method HandleTrace {field callback name1 name2 op} {
        if {$field ne "" && $name2 ne $field} {
            return    ;# array was written, but not the field this subscriber cares about
        }
        {*}$callback
    }

    destructor {
        # safety net for any subscriber that forgot to unsubscribe
        dict for {key handler} $subscriptions {
            catch {
                trace remove variable [my Namespaced [lindex $key 0]] write $handler
            }
        }
    }
}
```

- `my Namespaced varName` resolves a bare variable name to its fully-qualified form inside
  *this specific instance's* private namespace — every `Store` instance has isolated state
  by construction, since TclOO gives each object its own internal namespace.
- `subscribe`/`unsubscribe` share the same call signature (`varName ?field? callback`),
  making it easy to remember and pair them correctly in constructors/destructors.
- The destructor's cleanup loop is a safety net, not a substitute for explicit
  `unsubscribe` calls in views — see gotchas.

## 3. Domain Model — Inheriting from `Store`

```tcl
oo::class create Cart {
    superclass Store
    variable items

    constructor {} {
        next            ;# required: initializes Store's internal subscription state
        set items {}
        my set total 0
    }

    method addItem {item} {
        lappend items $item
        my Recalculate
    }

    method Recalculate {} {
        set t 0
        foreach item $items {
            if {[dict get $item active]} {incr t [dict get $item price]}
        }
        my set total $t     ;# triggers any subscribers to "total" automatically
    }
}
```

```tcl
set cart [Cart new]
$cart get total          ;# 0
$cart addItem {price 10 active 1}
$cart get total            ;# 10
```

`next` in the subclass constructor is mandatory — skipping it leaves `subscriptions`
uninitialized, and any `subscribe`/`unsubscribe` call on the instance fails.

## 4. Array-Backed State (e.g. a schedule keyed by day)

```tcl
oo::class create Guards {
    superclass Store
    constructor {} {next}
}

set g [Guards new]
$g set schedule Monday "Alice"
$g get schedule Monday          ;# Alice
```

## 5. Views Subscribe Without Knowing Internals

```tcl
snit::widget cartPanel {
    option -model -readonly yes

    constructor {args} {
        $self configurelist $args
        ttk::label $win.total -text ""
        pack $win.total

        $options(-model) subscribe total [mymethod OnTotalChanged]
        my OnTotalChanged     ;# sync initial display
    }

    method OnTotalChanged {} {
        $win.total configure -text "Total: [$options(-model) get total]"
    }

    destructor {
        catch {$options(-model) unsubscribe total [mymethod OnTotalChanged]}
    }
}
```

```tcl
set cart [Cart new]
cartPanel .cp -model $cart
pack .cp
```

The view never sees a namespace-qualified variable name or calls `trace` itself — only
`subscribe`/`unsubscribe`/`get`. Swapping the underlying storage mechanism inside `Store`
later (e.g. moving off `trace` entirely) would not require touching any view code.

## 6. Subscribing to a Specific Array Field

```tcl
snit::widget dayCell {
    option -model -readonly yes
    option -day -readonly yes

    constructor {args} {
        $self configurelist $args
        ttk::label $win.name -text ""
        pack $win.name

        $options(-model) subscribe schedule $options(-day) [mymethod OnGuardChanged]
        my OnGuardChanged
    }

    method OnGuardChanged {} {
        $win.name configure -text [$options(-model) get schedule $options(-day)]
    }

    destructor {
        catch {$options(-model) unsubscribe schedule $options(-day) [mymethod OnGuardChanged]}
    }
}
```

Each `dayCell` only reacts to writes on *its own* day's field — other days changing does
not trigger this instance's callback, thanks to the field filtering in `Store::HandleTrace`.

## 7. Multiple Independent Stores — Composition, Not One Giant Store

Avoid collapsing all application state into a single `Store` instance — that just
reintroduces the singleton problem in object form. Prefer several small, domain-scoped
stores, instantiated once at startup and passed down explicitly to whatever needs them.

```tcl
set guardsModel   [Guards new]
set settingsModel [Settings new]

mainWindow .app -guardsModel $guardsModel -settingsModel $settingsModel
```

Cross-domain logic (needing data from more than one store) belongs in a separate service
object that receives the relevant stores as constructor dependencies — not inside either
store itself:

```tcl
oo::class create GuardScheduleService {
    variable guardsModel
    variable settingsModel

    constructor {gModel sModel} {
        set guardsModel $gModel
        set settingsModel $sModel
    }

    method totalHoursFor {person} {
        # combine data from both stores here
    }
}
```

This keeps each `Store` subclass small and single-purpose, and keeps coordination logic
in one clearly-named place instead of scattered across models that shouldn't know about
each other.

## 8. `set`/`get` vs Domain Methods — Where to Draw the Line

Generic `set`/`get` are a good fit for simple config/state bags (e.g. a `Settings` store
with no invariants to maintain). For models with real business rules (`Cart`, `Guards`),
prefer exposing **domain methods** (`addItem`, `assignGuard`) as the public API, with
`set`/`get` used internally by those methods rather than called directly from views. This
keeps invariants (like recalculating a total, or validating an assignment) enforced in one
place instead of relying on every caller to remember to do the right follow-up work after
a raw `set`.

```tcl
# preferred: view calls a domain method
$cart addItem {price 10 active 1}

# avoid: view bypasses domain logic with a raw set, skipping Recalculate
$cart set total 999
```

## 9. Testing a `Store`-based Model Without Tk

Because the model never references Tk, it's fully testable with plain `tcltest`:

```tcl
test cart-total-1 {} -body {
    set cart [Cart new]
    $cart addItem {price 10 active 1}
    $cart addItem {price 20 active 0}
    $cart get total
} -result 10
```

```tcl
test cart-subscribe-1 {subscriber fires on change} -body {
    set cart [Cart new]
    set ::seen ""
    $cart subscribe total {set ::seen "changed"}
    $cart addItem {price 5 active 1}
    set ::seen
} -result "changed"
```

## 10. Gotchas

- Forgetting `next` in a `Store` subclass's constructor leaves `subscriptions` uninitialized — any later `subscribe`/`unsubscribe` call raises an error about an unset variable rather than a clear "you forgot `next`" message; always call `next` as the first line of the subclass constructor.
- Views must pair every `subscribe` in a constructor with a matching `unsubscribe` in the destructor — the base class destructor's cleanup loop is a safety net for objects that outlive their subscribers, not a substitute for explicit cleanup, since a `Store` instance can easily outlive a specific widget that subscribed to it.
- Writing an entire array at once (`array set arr {...}`) still fires the underlying trace once per key, same as plain `trace` — a subscriber registered for "any field" of an array (no field argument) will be notified once per key changed in a bulk update, not once per bulk operation. If that matters, add an explicit method on the model (e.g. `bulkSet`) that performs the batch update and fires one consolidated notification manually.
- `my Namespaced` relies on TclOO's per-instance private namespace — this pattern is TclOO-specific; adapting it to Snit types/widgets would need Snit's own instance-variable-naming mechanism (`myvar`) instead.
- The generic `set`/`get` API bypasses any domain invariants a model's own methods maintain — treat direct `set` calls from outside the model's own methods as a code smell in anything beyond a plain config/settings store.
- Composing many small stores instead of one big one means cross-domain logic needs a deliberate home (a service object) — resist the temptation to have one store reach into another store's internals directly, which reintroduces tight coupling between otherwise-independent models.
