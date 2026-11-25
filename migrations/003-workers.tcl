migrations register 3 {
    db eval {PRAGMA foreign_keys = OFF}

    db eval {
        CREATE TABLE IF NOT EXISTS workers_new (
            id INTEGER PRIMARY KEY,
            name TEXT UNIQUE NOT NULL,
            weight INTEGER NOT NULL DEFAULT 0,
            active INTEGER NOT NULL DEFAULT TRUE,

            CONSTRAINT workers_name_not_empty CHECK (trim(name) <> ''),
            CONSTRAINT workers_weight_positive CHECK (weight >= 0)
        ) STRICT
    }

    db eval {INSERT INTO workers_new SELECT * FROM workers}
    db eval {DROP TABLE workers}
    db eval {ALTER TABLE workers_new RENAME to workers}

    db eval {PRAGMA foreign_keys = OFF}

    db eval {
        CREATE TRIGGER workers_weight_next
        AFTER INSERT ON workers
        WHEN NEW.weight = 0
        BEGIN
            UPDATE workers
            SET weight = (
                SELECT COALESCE(MAX(weight), 0) + 1
                FROM workers
                WHERE id <> NEW.id
            )
            WHERE id = NEW.id;
        END
    }

    db eval {
        CREATE TRIGGER workers_weight_compact
        AFTER DELETE ON workers
        BEGIN
            UPDATE workers
            SET weight = weight - 1
            WHERE weight > OLD.weight;
        END
    }
}
