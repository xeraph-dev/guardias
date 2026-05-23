set exe_path [zipfs mount //zipfs:/app]
if {$exe_path eq ""} {
    puts "error: Se requiere un intérprete estático"
    exit
}

file delete -force build
file mkdir build

file copy $tcl_library [file join guardias.vfs tcl_library]
file copy $tk_library [file join guardias.vfs tk_library]
file copy ./lib [file join guardias.vfs lib]

file copy guardias.tcl [file join guardias.vfs main.tcl]
file copy src [file join guardias.vfs src]
file copy res [file join guardias.vfs res]

zipfs mkimg [file join build guardias.exe] guardias.vfs guardias.vfs "" $exe_path

file delete -force guardias.vfs
exit
