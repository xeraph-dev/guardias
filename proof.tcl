package require sqlite3

sqlite3 db "guardias.db"

oo::class create Worker {
    variable id name weight

    constructor {_id _name _weight} {
        set id $_id
        set name $_name
        set weight $_weight
    }
}

array set workers {}
set workers(7) [list 7 jhf 0]

proc written {args} {
    puts "written"
}

proc unwrite {args} {
    puts "unwrite"
}

trace add variable workers(1) write written
trace add variable workers(7) unset unwritten

set ids {}
db eval {SELECT id, name, weight FROM workers} {
    array set workers [list $id [list $id $name $weight]]
    lappend ids $id
}


parray workers
set extra_ids {}
array for {id worker} workers {
    if {[lsearch -exact $ids $id] == -1} {
        lappend extra_ids $id
    }
}

foreach id $extra_ids {
    array unset workers $id
}

# puts $ids
# parray workers
