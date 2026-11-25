source [file normalize [file join [file dirname [info script]] common.tcl]]
source [file normalize [file join [file dirname [info script]] .. src helpers.tcl]]

set dbfile [file join [get_data_dir] $APP_NAME.db]

puts "About to delete: $dbfile"
puts "(also $dbfile-wal and $dbfile-shm if present)"
puts -nonewline "Type 'yes' to continue: "
flush stdout

if {[string trim [gets stdin]] ne "yes"} {
    puts "Cancelled."
    exit 0
}

foreach f [list $dbfile $dbfile-wal $dbfile-shm] {
    if {[file exists $f]} {
        file delete -force -- $f
        puts "Deleted: $f"
    }
}

puts "Done. Start the app to let migrations recreate an empty database."
