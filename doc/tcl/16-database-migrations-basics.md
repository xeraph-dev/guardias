# Database Migrations — Cheatsheet

Schema migrations let an application evolve its database structure over time across
already-deployed installations, without losing existing data. This guide builds on the
database layer guide — read that first for the Repository/Service/Store architecture this
fits into.

## 1. Core Idea

Track a schema version number stored in the database itself. On startup, compare it to the
highest version the application knows about, and apply any migrations in between, in order,
each wrapped in its own transaction.

```tcl
namespace eval ::Migrations {
    variable steps {}

    proc register {version script} {
        variable steps
        dict set steps $version $script
    }
}
```

Each migration is registered as a version number plus a script — data, not a cascading
chain of `if` statements — which keeps the runner simple and each migration self-contained
and independently readable.

## 2. Schema Version Tracking

```tcl
namespace eval ::Migrations {
    proc currentVersion {dbHandle} {
        $dbHandle eval {CREATE TABLE IF NOT EXISTS schema_version (version INTEGER)}
        set v [$dbHandle eval {SELECT version FROM schema_version LIMIT 1}]
        if {$v eq ""} {
            $dbHandle eval {INSERT INTO schema_version (version) VALUES (0)}
            return 0
        }
        return $v
    }
}
```

A companion history table records *when* each migration ran — valuable for diagnosing
issues in a deployed installation later, beyond just knowing the current version number.

```tcl
$dbHandle eval {
    CREATE TABLE IF NOT EXISTS schema_migrations (
        version INTEGER PRIMARY KEY,
        applied_at INTEGER
    )
}
```

## 3. The Runner

```tcl
namespace eval ::Migrations {
    proc runPending {dbHandle} {
        variable steps
        $dbHandle eval {
            CREATE TABLE IF NOT EXISTS schema_migrations (
                version INTEGER PRIMARY KEY,
                applied_at INTEGER
            )
        }
        set current [currentVersion $dbHandle]

        foreach version [lsort -integer [dict keys $steps]] {
            if {$version <= $current} continue
            set script [dict get $steps $version]

            $dbHandle transaction {
                apply [list {db} $script] $dbHandle
                $dbHandle eval {UPDATE schema_version SET version = :version}
                set now [clock seconds]
                $dbHandle eval {
                    INSERT INTO schema_migrations (version, applied_at)
                    VALUES (:version, :now)
                }
            }
            puts "Applied migration $version"
        }
    }
}
```

- `lsort -integer` on the registered version numbers determines execution order — not the
  order `register` calls happened to run in, so load order of migration files doesn't
  matter for correctness (though see section 5 for why it still matters for readability).
- Each migration runs inside its own `db transaction` — a failure rolls back only that
  migration's changes, leaving the schema at the last successfully applied version rather
  than partially upgraded.
- `runPending` is safe to call every time the application starts: if nothing is pending, the
  loop simply doesn't execute, so there's no need for a "did I already migrate this
  session" flag.

## 4. Writing a Migration

```tcl
::Migrations::register 1 {
    $db eval {ALTER TABLE items ADD COLUMN notes TEXT}
}

::Migrations::register 2 {
    $db eval {CREATE TABLE tags (id INTEGER PRIMARY KEY, name TEXT)}
}
```

Inside the script, `$db` refers to the connection passed to `runPending` — the `apply`
call in the runner binds it as the script's only argument, so every migration body can
assume `$db` is available without any extra setup.

Migrations that transform existing data (not just add structure) are the case most prone
to bugs — test these against a copy of a real, previously-migrated database, not just an
empty one.

```tcl
::Migrations::register 3 {
    $db eval {ALTER TABLE guards ADD COLUMN priority INTEGER}
    $db eval {UPDATE guards SET priority = 1 WHERE priority IS NULL}
}
```

## 5. File Organization

One file per migration, numbered to match its version, loaded before `runPending` is called.

```
lib/migrations/
├── loader.tcl
├── 001_add_notes_column.tcl
├── 002_create_tags_table.tcl
└── 003_add_guard_priority.tcl
```

```tcl
# lib/migrations/loader.tcl
proc loadMigrations {dir} {
    foreach f [lsort [glob [file join $dir *.tcl]]] {
        if {[file tail $f] ne "loader.tcl"} {
            source $f
        }
    }
}
```

The numeric filename prefix (`001_`, `002_`) is purely for a human browsing the directory
to understand the sequence at a glance — the runner's actual execution order comes from the
registered version numbers (section 3), not file load order. Keep both in sync anyway, to
avoid confusion.

## 6. Application Startup Sequence

Migrations run once, immediately after opening the connection and before constructing any
Repository, Service, or Store — never lazily mid-execution.

```tcl
# 1. open connection
sqlite3 db "app.db"
db eval {PRAGMA foreign_keys = ON}

# 2. load migration definitions
loadMigrations [file join $appDir lib migrations]

# 3. run any pending migrations — before anything else touches the schema
if {[catch {::Migrations::runPending db} err]} {
    tk_messageBox -type ok -icon error \
        -message "Could not update the database: $err"
    exit 1
}

# 4. only now build repositories/services/stores
set itemRepo [ItemRepository new db]
set cart [Cart new $itemRepo]

# 5. only now bring up the UI
cartPanel .cp -model $cart
pack .cp
```

Running migrations before any Repository is constructed avoids a Repository's SQL failing
with a confusing "no such column" error simply because the schema hadn't been brought up to
date yet. Running them before the UI appears means a migration failure surfaces as a clear
startup error rather than a partially-loaded window or a crash mid-session.

## 7. Backing Up Before Migrating

Because SQLite is a single file, a pre-migration backup is cheap and provides a real safety
net — especially relevant on hardware prone to power loss mid-operation.

```tcl
proc backupBeforeMigration {dbPath} {
    set backupPath "${dbPath}.pre-migration-[clock seconds].bak"
    file copy $dbPath $backupPath
    return $backupPath
}
```

```tcl
sqlite3 db "app.db"
backupBeforeMigration "app.db"
::Migrations::runPending db
```

If a migration fails partway (even though the transaction wrapper already prevents a
corrupt intermediate schema), the backup gives a straightforward recovery path: restore the
file from before migrations ran at all.

## 8. Testing Migrations

Test the runner and individual migrations directly, without any Tk dependency — same
approach as testing a Repository (see the database layer and tcltest guides).

```tcl
test migration-003-1 {adds priority column with default} -setup {
    sqlite3 testdb :memory:
    testdb eval {CREATE TABLE guards (day TEXT, person TEXT)}
    testdb eval {CREATE TABLE schema_version (version INTEGER)}
    testdb eval {INSERT INTO schema_version (version) VALUES (2)}
} -body {
    ::Migrations::runPending testdb
    testdb eval {SELECT priority FROM guards WHERE day = 'Monday'}
} -cleanup {
    testdb close
} -result {}
```

```tcl
test migration-runner-idempotent-1 {calling runPending twice is a no-op the second time} -setup {
    sqlite3 testdb :memory:
} -body {
    ::Migrations::runPending testdb
    set v1 [::Migrations::currentVersion testdb]
    ::Migrations::runPending testdb
    set v2 [::Migrations::currentVersion testdb]
    expr {$v1 == $v2}
} -cleanup {
    testdb close
} -result 1
```

For data-transforming migrations, seed the test database with representative pre-migration
data (not just an empty schema) so the test actually exercises the transformation logic,
not just the structural change.

## 9. Rules for Adding a New Migration

1. Find the highest currently-registered version (check the migrations directory, or
   inspect `[lsort -integer [dict keys $::Migrations::steps]]` in a dev session).
2. Create the next numbered file (`004_something_new.tcl`).
3. Write the `register` call with that version and the necessary SQL/logic.
4. Test it against a copy of a real, previously-migrated database — not only an empty one.
5. **Never edit a migration that has already shipped.** If version 3 has a bug and was
   already deployed to real installations, add version 4 to fix it — don't rewrite version 3.
   The version number is effectively a contract with every installation that already ran it.

## 10. Gotchas

- Editing an already-shipped migration instead of adding a new one is the single most
  damaging mistake in this system — installations that already applied the original version
  will never re-run it (their `schema_version` already shows it as done), so the fix never
  reaches them; only new installations starting from scratch would see the edited version,
  creating silently divergent schemas across deployed copies.
- Forgetting to wrap a migration's statements in the transaction the runner already provides
  isn't usually possible with this design (the runner wraps every migration automatically),
  but manually running migration SQL outside of `runPending` for a one-off fix bypasses that
  safety net — always go through the registered migration system, even for what seems like
  a trivial one-time change.
- A migration that assumes a particular starting state (e.g. assumes a column is always
  NULL before its own `UPDATE`) can behave unexpectedly on an installation that skipped
  several versions at once and applies many migrations back-to-back in a single run — test
  the full chain from version 0 occasionally, not just each migration in isolation from its
  immediate predecessor.
- Running `backupBeforeMigration` on every single startup (even when no migration is
  actually pending) wastes disk space and I/O — only back up when `currentVersion` is
  actually behind the highest registered version, not unconditionally on every launch.
- File load order (section 5) affects nothing about correctness since the runner sorts by
  version number, but a missing or misnamed migration file that never gets `source`d simply
  means that version silently never registers — `runPending` won't error, it will just skip
  straight past that version number as if it didn't exist, which can leave the schema
  quietly behind what the application code expects.
