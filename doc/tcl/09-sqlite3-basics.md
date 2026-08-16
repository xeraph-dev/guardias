# sqlite3 (Tcl Package) Basics — Cheatsheet

The `sqlite3` package provides Tcl bindings for SQLite, exposing a database connection as
a Tcl command (same convention as Tk widgets — the handle name *is* the command). It ships
as a loadable extension; on most modern Tcl distributions it's available via `package require`.

```tcl
package require sqlite3
```

## 1. Opening a Connection

```tcl
sqlite3 db "myapp.db"      ;# creates command "db" bound to this file
sqlite3 db2 ":memory:"      ;# in-memory database, useful for tests/caching

db close                      ;# close when done
```

- The first argument is the command name you choose (convention: `db`); the second is the file path (or `:memory:`).
- Like Tk widgets, the connection becomes a command — `db eval ...`, `db close`, etc. — not an object you pass around as data.
- Multiple simultaneous connections are fine: `sqlite3 db1 "a.db"`, `sqlite3 db2 "b.db"`.

## 2. Running Queries — `eval`

```tcl
db eval {CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, age INTEGER)}

db eval {INSERT INTO users (name, age) VALUES ('Alice', 30)}
db eval {INSERT INTO users (name, age) VALUES ('Bob', 25)}

db eval {SELECT id, name, age FROM users} {
    puts "$id: $name ($age)"
}
```

- `db eval script` with a trailing script block runs it **once per result row**, with each
  selected column automatically available as a same-named Tcl variable inside the block —
  no manual column-to-variable mapping needed.
- Without a trailing block, `eval` returns all results as a single flat list (row-major,
  column values concatenated) — useful for small result sets consumed directly.

```tcl
set allNames [db eval {SELECT name FROM users}]
# -> {Alice Bob}

set rows [db eval {SELECT name, age FROM users}]
# -> {Alice 30 Bob 25}   -- flat, alternating columns; use foreach with matching var count to unpack
foreach {name age} $rows {
    puts "$name is $age"
}
```

## 3. Parameter Binding — Avoiding SQL Injection

Never interpolate Tcl variables directly into SQL text. Use `:varName` or `$varName`
placeholders — the package binds them automatically from **Tcl variables already in scope**
at the point of the `eval` call.

```tcl
set searchName "Alice"
db eval {SELECT * FROM users WHERE name = :searchName} {
    puts "$id: $name"
}
```

```tcl
# WRONG — string interpolation, vulnerable to injection and quoting bugs
db eval "SELECT * FROM users WHERE name = '$searchName'"

# RIGHT — bound parameter, safe regardless of content
db eval {SELECT * FROM users WHERE name = :searchName}
```

The `:name` placeholder matches a Tcl variable of the same name visible in the calling
scope — no separate "bind" call needed, unlike lower-level APIs in other languages.

## 4. Inserts, Updates, Deletes

```tcl
db eval {INSERT INTO users (name, age) VALUES (:name, :age)}

db eval {UPDATE users SET age = :newAge WHERE id = :userId}

db eval {DELETE FROM users WHERE id = :userId}
```

```tcl
db changes            ;# number of rows affected by the last INSERT/UPDATE/DELETE
db last_insert_rowid    ;# rowid of the most recently inserted row (auto-increment id)
```

## 5. Transactions

```tcl
db eval {BEGIN}
db eval {INSERT INTO users (name, age) VALUES ('Carol', 40)}
db eval {INSERT INTO users (name, age) VALUES ('Dave', 22)}
db eval {COMMIT}
```

Preferred idiom — `db transaction` wraps a script, auto-committing on success and rolling
back if any error occurs inside it (avoids manually pairing BEGIN/COMMIT/ROLLBACK):

```tcl
db transaction {
    db eval {INSERT INTO users (name, age) VALUES ('Carol', 40)}
    db eval {INSERT INTO users (name, age) VALUES ('Dave', 22)}
}
```

If an error is raised anywhere inside the `transaction` block, all changes in it are
automatically rolled back and the error propagates to the caller.

## 6. Prepared Statement Handles — `db statement`

For queries run **repeatedly** (e.g. in a tight loop), pre-preparing avoids re-parsing SQL
each time.

```tcl
set stmt [db prepare {INSERT INTO users (name, age) VALUES (:name, :age)}]

foreach {n a} {Alice 30 Bob 25 Carol 40} {
    set name $n
    set age $a
    $stmt eval
}

$stmt finalize
```

For most application code, plain `db eval` is fast enough — reach for `prepare` only when
profiling shows statement re-parsing is actually a bottleneck (bulk inserts, hot loops).

## 7. Schema Introspection

```tcl
db eval {SELECT name FROM sqlite_master WHERE type='table'}
db eval {PRAGMA table_info(users)}
```

```tcl
proc tableExists {dbCmd tableName} {
    return [expr {[$dbCmd eval {SELECT count(*) FROM sqlite_master WHERE type='table' AND name=:tableName}] > 0}]
}
```

## 8. Common Pragmas

```tcl
db eval {PRAGMA foreign_keys = ON}        ;# enforce FK constraints (off by default per-connection)
db eval {PRAGMA journal_mode = WAL}        ;# better concurrent read/write behavior
db eval {PRAGMA synchronous = NORMAL}      ;# durability/performance tradeoff, pairs with WAL
```

`foreign_keys` defaults to OFF for backward compatibility and must be re-enabled on
**every new connection** (it's a per-connection setting, not persisted in the database file).

## 9. Error Handling

```tcl
if {[catch {
    db eval {INSERT INTO users (name) VALUES ('Eve')}
} err]} {
    puts "DB error: $err"
}
```

```tcl
try {
    db eval {INSERT INTO nonexistent_table (x) VALUES (1)}
} on error {msg} {
    puts "Failed: $msg"
}
```

SQLite errors (constraint violations, syntax errors, locked database) surface as regular
Tcl errors — catchable with `catch`/`try` like any other command failure.

## 10. Busy/Locked Database Handling

```tcl
db timeout 5000      ;# wait up to 5000ms for a lock before raising SQLITE_BUSY
```

Useful when multiple processes/connections might contend for the same file — especially
relevant with `journal_mode = WAL`, which improves but doesn't eliminate contention
between writers.

## 11. Closing

```tcl
db close
```

Always close connections when done (app shutdown, end of a script) — an open connection
holds a file lock and unflushed state; forgetting to close is a common source of
"database is locked" errors on the next run.

## 12. Wrapping Access Behind a Namespace (common application pattern)

A frequent structural pattern: hide the raw `sqlite3` command behind a namespace so callers
never touch SQL directly, centralizing query logic and connection lifecycle in one place.

```tcl
namespace eval ::Store {
    variable dbHandle ""

    proc init {path} {
        variable dbHandle
        sqlite3 ::Store::conn $path
        set dbHandle ::Store::conn
        $dbHandle eval {PRAGMA foreign_keys = ON}
    }

    proc getUser {id} {
        variable dbHandle
        return [$dbHandle eval {SELECT name, age FROM users WHERE id = :id}]
    }

    proc close {} {
        variable dbHandle
        if {$dbHandle ne ""} {
            $dbHandle close
            set dbHandle ""
        }
    }
}

::Store::init "myapp.db"
::Store::getUser 1
```

## 13. Gotchas

- `db eval` with a trailing script block runs the block **once per row** — forgetting the block turns the same call into a "return everything as one flat list" call instead, a common source of confusion when copy-pasting between the two forms.
- Bound `:varName` parameters resolve against Tcl variables **visible in the calling scope at the time of the `eval` call** — if the variable is inside a different scope (e.g. set in a namespace but the `eval` runs inside a plain proc without importing it), the binding silently fails to find it and raises a "no such variable" error, not a silent NULL.
- `foreign_keys` enforcement is OFF by default per connection — must be explicitly turned on every time a new connection is opened; relying on it being enforced without setting the pragma is a common bug.
- SQLite's dynamic typing (columns don't strictly enforce declared types unless using `STRICT` tables, SQLite 3.37+) means a column declared `INTEGER` can still silently accept a string — validate application-side if strict typing matters and `STRICT` tables aren't in use.
- Flat-list results from `db eval` without a script block interleave columns positionally — unpacking them with the wrong variable count in `foreach {a b} $rows` silently misaligns data instead of raising an error, since `foreach` just cycles through groups of N.
- Long-running write transactions block other writers (SQLite allows only one writer at a time regardless of journal mode) — keep `db transaction` blocks short and avoid slow operations (network calls, heavy computation) inside them.
