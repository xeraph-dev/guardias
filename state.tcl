namespace eval state {
    set guardias [dict create]

    namespace eval calendar {
        variable month [clock format now -format %B -locale es_ES -timezone America/Havana]
        variable year [clock format now -format %Y -locale es_ES -timezone America/Havana]

        set months {}
        for {set it 1} {$it <= 12} {incr it} {
            set time [clock scan $it -format %N -locale es_ES -timezone America/Havana]
            lappend months [clock format $time -format %B -locale es_ES -timezone America/Havana]
        }

        set days {}
        for {set it 1} {$it <= 7} {incr it} {
            set time [clock scan $it -format %u -locale es_ES -timezone America/Havana]
            lappend days [clock format $time -format %A -locale es_ES -timezone America/Havana]
        }

        proc get_date {} {
            return [clock scan "01/$::state::calendar::month/$::state::calendar::year" -format "%d/%B/%Y" -locale es_ES -timezone America/Havana]
        }
    }

    namespace eval worker {
        variable id -1
        variable name ""

        proc exists {} {
            return [db eval {SELECT EXISTS(SELECT id FROM workers WHERE id <> $::state::worker::id AND name = $::state::worker::name)}]
        }

        proc save {} {
            if {$::state::worker::id > -1} {
                db eval {UPDATE workers SET name = $::state::worker::name WHERE id = $::state::worker::id}
            } else {
                db eval {INSERT INTO workers (name) VALUES ($::state::worker::name)}
            }
        }

        proc delete {} {
            db eval {DELETE FROM workers WHERE id = $::state::worker::id}
        }

        proc clear {} {
            set ::state::worker::id -1
            set ::state::worker::name ""
        }
    }
}
