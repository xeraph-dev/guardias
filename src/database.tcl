db eval {PRAGMA foreign_keys = ON}

db eval {
    CREATE TABLE IF NOT EXISTS migrations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        version INTEGER
    ) STRICT
}

set version [db eval {SELECT version FROM migrations LIMIT 1}]
if {$version == ""} {
    set version 0
    db eval {INSERT INTO migrations (version) VALUES (:version)}
}

if {$version == 0} {
    db transaction {
        db eval {
            CREATE TABLE IF NOT EXISTS workers (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT UNIQUE NOT NULL,
                weight INTEGER NOT NULL,
                active INTEGER NOT NULL DEFAULT TRUE
            ) STRICT
        }

        db eval {
            CREATE TABLE IF NOT EXISTS schedules (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                worker_id INTEGER NOT NULL REFERENCES workers (id),
                date TEXT UNIQUE NOT NULL
            ) STRICT
        }

        incr version

        db eval {UPDATE migrations SET version = :version}
    }
}
