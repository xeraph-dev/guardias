# Managing the Database Layer — Cheatsheet

This guide covers how to structure database access in a Tcl/Tk application so persistence
stays decoupled from reactive state (see the Store pattern guide) and from the UI. It
builds on the `sqlite3` package basics guide — read that first for connection handling,
`db eval`, and transaction fundamentals.

## 1. The Layered Architecture

```
View (Tk/Snit)  →  Store (reactive state)  →  Repository / Service  →  db (sqlite3)
```

Each layer only talks to the one directly below it:

- **View** never calls `db` or a Repository directly — only talks to a `Store`.
- **Store** holds in-memory reactive state and notifies subscribers on change (see the
  Store pattern guide) — it delegates persistence to a Repository/Service, never runs SQL itself.
- **Repository** wraps SQL for a single table or closely related set of tables — the only
  layer that contains actual `db eval` calls.
- **Service** coordinates multiple Repositories for operations that span more than one
  domain, and owns transactions that cross repository boundaries.

This separation means: the Store is testable without a real database (inject a fake
Repository), the Repository is testable without Tk (plain `tcltest` + `:memory:`), and
swapping the storage engine later only touches the Repository layer.

## 2. Repository — Wrapping SQL for One Domain

```tcl
oo::class create ItemRepository {
    variable db

    constructor {dbHandle} {
        set db $dbHandle
    }

    method insert {item} {
        set price [dict get $item price]
        set active [dict get $item active]
        $db eval {INSERT INTO items (price, active) VALUES (:price, :active)}
        return [$db last_insert_rowid]
    }

    method loadAll {} {
        set result {}
        $db eval {SELECT id, price, active FROM items} {
            lappend result [dict create id $id price $price active $active]
        }
        return $result
    }

    method deleteById {id} {
        $db eval {DELETE FROM items WHERE id = :id}
    }

    method update {id item} {
        set price [dict get $item price]
        set active [dict get $item active]
        $db eval {UPDATE items SET price = :price, active = :active WHERE id = :id}
    }
}
```

- A Repository receives the `db` connection as a constructor dependency — it never opens
  or closes the connection itself (see connection lifecycle below).
- Its methods speak in domain terms (`insert`, `loadAll`) — callers never see raw SQL.
- Keep a Repository scoped to one table or a small tightly-related group of tables; if it
  starts needing to know about unrelated domains, that logic belongs in a Service instead.

## 3. Wiring a Store to Its Repository

The Store receives a Repository (or an interface-compatible fake) as a dependency, hydrates
its in-memory state from it at construction, and calls it to persist before updating
reactive state.

```tcl
oo::class create Cart {
    superclass Store
    variable items
    variable repository

    constructor {repo} {
        next
        set repository $repo
        set items [$repository loadAll]
        my Recalculate
    }

    method addItem {item} {
        $repository insert $item      ;# persist first
        lappend items $item
        my Recalculate                 ;# then update in-memory reactive state
    }

    method Recalculate {} {
        set t 0
        foreach item $items {
            if {[dict get $item active]} {incr t [dict get $item price]}
        }
        my set total $t
    }
}
```

**Persist-then-update-memory ordering matters for reliability**: if the write fails or the
machine loses power mid-operation, in-memory state never diverges from what's actually on
disk. Updating memory optimistically before persisting risks the UI showing state that
never actually got saved — especially relevant under unreliable power/connectivity.

## 4. Application Wiring at Startup

```tcl
sqlite3 db "app.db"
db eval {PRAGMA foreign_keys = ON}

set itemRepo [ItemRepository new db]
set cart [Cart new $itemRepo]

cartPanel .cp -model $cart
pack .cp
```

## 5. Single-Domain Transactions — Handled Inside the Repository

When an atomic operation only touches the tables one Repository already owns, wrap it
there — callers don't need to know a transaction happened.

```tcl
method insertBulk {items} {
    $db transaction {
        foreach item $items {
            set price [dict get $item price]
            set active [dict get $item active]
            $db eval {INSERT INTO items (price, active) VALUES (:price, :active)}
        }
    }
}
```

`db transaction` (see the sqlite3 guide) commits on success and rolls back automatically
if any error is raised inside the block — no manual `BEGIN`/`COMMIT`/`ROLLBACK` needed.

## 6. Cross-Domain Transactions — Handled by a Service

When an operation must atomically touch tables owned by more than one Repository, no single
Repository should silently wrap only its own part — the transaction needs to span all of
them. This is a Service's job: it receives the shared `db` handle plus the Repositories
involved, and owns the transaction boundary itself.

```tcl
oo::class create GuardAssignmentService {
    variable db
    variable guardsRepo
    variable scheduleRepo

    constructor {dbHandle gRepo sRepo} {
        set db $dbHandle
        set guardsRepo $gRepo
        set scheduleRepo $sRepo
    }

    method assignGuardAndLog {day person} {
        $db transaction {
            $guardsRepo assign $day $person
            $scheduleRepo logChange $day $person
        }
    }
}
```

If `logChange` raises an error, `assign`'s write is rolled back too — atomicity across both
tables, without either Repository needing to know about the other.

## 7. Connecting a Service Back to a Store

A Store that needs a cross-domain atomic write delegates to a Service instead of a plain
Repository, but the ordering principle from section 3 stays the same: persist (via the
Service's transaction) before updating in-memory state and notifying subscribers.

```tcl
oo::class create Guards {
    superclass Store
    variable service

    constructor {svc} {
        next
        set service $svc
    }

    method assignGuard {day person} {
        $service assignGuardAndLog $day $person   ;# whole transaction or nothing
        my set schedule $day $person                ;# only notify views after it's durably saved
    }
}
```

If the transaction raises an error, it propagates up through `assignGuard` uncaught (or
caught by the caller with `try`/`catch`) — the Store never reaches the `my set` call, so
subscribers are never notified of a change that didn't actually persist.

## 8. Connection Lifecycle — One Connection, Owned at the Top

Open the database connection once at application startup and close it once at shutdown —
not per-transaction, not per-repository. Repositories and Services all share the same
injected `db` handle; none of them open or close it themselves.

```tcl
# startup
sqlite3 db "app.db"
db eval {PRAGMA foreign_keys = ON}

# ... application runs, using db via repositories/services ...

# shutdown (e.g. hooked to WM_DELETE_WINDOW in a Tk app)
db close
```

See the sqlite3 guide for the reasoning (PRAGMA re-application cost, SQLite's own
concurrency handling, avoiding "database is locked" errors from repeated open/close).

## 9. Testing Each Layer in Isolation

**Repository, with a real in-memory database, no Tk:**

```tcl
test item-repo-insert-1 {} -setup {
    sqlite3 testdb :memory:
    testdb eval {CREATE TABLE items (id INTEGER PRIMARY KEY, price INTEGER, active INTEGER)}
    set repo [ItemRepository new testdb]
} -body {
    $repo insert {price 10 active 1}
    llength [$repo loadAll]
} -cleanup {
    testdb close
} -result 1
```

**Store, with a fake Repository, no database and no Tk:**

```tcl
oo::class create FakeItemRepository {
    variable stored
    constructor {} {set stored {}}
    method insert {item} {lappend stored $item; return [llength $stored]}
    method loadAll {} {return $stored}
}

test cart-total-1 {} -body {
    set cart [Cart new [FakeItemRepository new]]
    $cart addItem {price 10 active 1}
    $cart get total
} -result 10
```

**Service, with real repositories against `:memory:`, verifying rollback:**

```tcl
test guard-assign-rollback-1 {failed log rolls back the assignment} -setup {
    sqlite3 testdb :memory:
    testdb eval {CREATE TABLE guards (day TEXT, person TEXT)}
    # scheduleRepo deliberately fails to exercise rollback
    oo::class create FailingScheduleRepo {
        method logChange {day person} {error "simulated failure"}
    }
    set guardsRepo [GuardsRepository new testdb]
    set svc [GuardAssignmentService new testdb $guardsRepo [FailingScheduleRepo new]]
} -body {
    catch {$svc assignGuardAndLog "Monday" "Alice"}
    testdb eval {SELECT count(*) FROM guards}
} -cleanup {
    testdb close
} -result 0
```

This three-way separation is what makes the rollback behavior of section 6 actually
verifiable — without it, testing "did the transaction really roll back on partial failure"
would require exercising the whole application stack.

## 10. Handling Schema Setup / Migrations

For small apps, a straightforward approach: a dedicated init routine that creates tables if
they don't already exist, run once at startup before any Repository is used.

```tcl
proc initSchema {dbHandle} {
    $dbHandle eval {
        CREATE TABLE IF NOT EXISTS items (
            id INTEGER PRIMARY KEY,
            price INTEGER NOT NULL,
            active INTEGER NOT NULL DEFAULT 1
        )
    }
    $dbHandle eval {
        CREATE TABLE IF NOT EXISTS guards (
            day TEXT PRIMARY KEY,
            person TEXT NOT NULL
        )
    }
}

sqlite3 db "app.db"
initSchema db
```

For schema changes over an application's lifetime (adding columns, new tables to an
existing deployed database), track a version number and apply incremental migrations:

```tcl
proc currentSchemaVersion {dbHandle} {
    $dbHandle eval {CREATE TABLE IF NOT EXISTS schema_version (version INTEGER)}
    set v [$dbHandle eval {SELECT version FROM schema_version LIMIT 1}]
    if {$v eq ""} {
        $dbHandle eval {INSERT INTO schema_version (version) VALUES (0)}
        return 0
    }
    return $v
}

proc migrateSchema {dbHandle} {
    set v [currentSchemaVersion $dbHandle]
    $dbHandle transaction {
        if {$v < 1} {
            $dbHandle eval {ALTER TABLE items ADD COLUMN notes TEXT}
        }
        if {$v < 2} {
            $dbHandle eval {CREATE TABLE tags (id INTEGER PRIMARY KEY, name TEXT)}
        }
        $dbHandle eval {UPDATE schema_version SET version = 2}
    }
}
```

Running migrations inside a single transaction means a failed migration leaves the schema
at its previous consistent version rather than half-upgraded.

## 11. Gotchas

- A Repository that reaches beyond its own domain's tables (e.g. `ItemRepository` also
  touching a `guards` table) is a sign that logic belongs in a Service instead — keeping
  Repositories single-domain is what makes cross-domain transactions in section 6 possible
  without one Repository secretly depending on another's internal SQL.
- Letting a Repository open/close its own `db` connection (instead of receiving one via
  constructor injection) breaks the single-connection-for-app-lifetime principle from
  section 8, and makes it harder to wrap multi-repository operations in one transaction —
  always inject the shared connection.
- Updating a Store's in-memory state *before* the persistence call completes (rather than
  after, as shown in section 3) risks the UI reflecting unsaved data — if the app crashes
  or loses power between the optimistic memory update and the actual write, the next
  launch's `loadAll` hydration won't match what the user saw on screen right before the failure.
- Forgetting to wrap a multi-repository write in a Service-owned transaction means a partial
  failure (one repository's write succeeds, the next one errors) leaves the database in an
  inconsistent cross-table state with no automatic rollback — always identify upfront which
  operations are "single Repository, wrap internally" versus "spans repositories, needs a
  Service-owned transaction."
- Running schema migrations outside a transaction risks a half-applied schema if a later
  migration step fails partway through — wrap the whole migration run in `db transaction`
  so a failure leaves the previous, consistent schema version intact.
- Testing a Service's rollback behavior requires an actual (even if `:memory:`) database —
  a fully mocked Repository can't demonstrate real transactional rollback, since the
  atomicity guarantee comes from SQLite itself, not from the Service's own code.
