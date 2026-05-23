db eval {
    CREATE TABLE IF NOT EXISTS workers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        weight INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS calendar (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        worker_id INTEGER NOT NULL REFERENCES workers (id),
        date TEXT UNIQUE NOT NULL
    );
}
