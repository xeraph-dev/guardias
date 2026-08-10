namespace eval store {
    namespace eval worker {
        proc exists {id name} {
            array set opts {
                -name ""
                -weight -1
            }
            array set opts $args

            if {$opts(-name) == ""} { error "-name required" }
            if {$opts(-weight) == -1} { error "-weight required" }

            db exists {
                SELECT id FROM workers
                WHERE id <> $opts(-id)
                  AND name = $opts(-name)
            }
        }

        proc get_all {{script ""}} {
            uplevel 1 [list db eval {
                SELECT id, name, weight
                FROM workers
                ORDER BY weight ASC
            } $script]
        }

        namespace export *
        namespace ensemble create
    }

    namespace eval calendar {
        proc assign {args} {
            array set opts {
                -worker_id 0
                -date {}
            }
            array set opts $args

            if {$opts(-worker_id) == 0} { error "-worker_id required" }
            if {$opts(-date) == {}} { error "-date required" }


            uplevel 1 [list db eval {
                INSERT INTO calendar (worker_id, date)
                VALUES ($opts(-worker_id), $opts(-date))
                ON CONFLICT (date) DO UPDATE
                SET worker_id = $opts(-worker_id)
            }]
        }

        namespace export *
        namespace ensemble create
    }

    namespace export *
    namespace ensemble create
}
