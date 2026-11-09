migrations register 1 {
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

    db eval {
        CREATE TABLE IF NOT EXISTS vacations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            worker_id INTEGER NOT NULL REFERENCES workers (id),
            from_date TEXT NOT NULL,
            to_date TEXT NOT NULL
        ) STRICT
    }
}
