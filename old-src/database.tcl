db eval {PRAGMA foreign_keys = ON}

db eval {
    CREATE TABLE IF NOT EXISTS migrations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        version INTEGER
    )
}

set version [db eval {SELECT version FROM migrations LIMIT 1}]
if {$version == ""} {
    set version 0
    db eval {INSERT INTO migrations (version) VALUES ($version)}
}

if {$version == 0} {
    db eval {
        CREATE TABLE IF NOT EXISTS workers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL,
            weight INTEGER NOT NULL
        )
    }

    db eval {
        CREATE TABLE IF NOT EXISTS calendar (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            worker_id INTEGER NOT NULL REFERENCES workers (id),
            date TEXT UNIQUE NOT NULL
        )
    }

    incr version
    db eval {UPDATE migrations SET version = $version}
}
