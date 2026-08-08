namespace eval store {
    namespace eval worker {
        proc exists {id name} {
            db exists {
                SELECT id FROM workers
                WHERE id <> $id
                  AND name = $name
            }
        }

        proc list {} {
            db eval {
                SELECT id, name, weight
                FROM workers
                ORDER BY weight ASC
            }
        }

        namespace export *
        namespace ensemble create
    }

    namespace eval calendar {
        proc assign {worker_id date} {
            db eval {
                INSERT INTO calendar (worker_id, date)
                VALUES ($worker_id, $date)
                ON CONFLICT (date) DO UPDATE
                SET worker_id = $worker_id
            }
        }

        namespace export *
        namespace ensemble create
    }

    namespace export *
    namespace ensemble create
}
