lappend auto_path [file join [file dirname [info script]] lib]
package require fileutil

set APP_NAME guardias
set BUILD_DIR build

set exe_path [zipfs mount //zipfs:/app]
if {$exe_path eq ""} {
    error "a static interpreter is required"
}

set vfs_path [fileutil::maketempdir -suffix .vfs]

file delete -force $vfs_path
file delete -force build
file mkdir build

file copy $tcl_library [file join $vfs_path tcl_library]
file copy $tk_library [file join $vfs_path tk_library]
file copy lib [file join $vfs_path lib]
file copy main.tcl [file join $vfs_path main.tcl]
file copy src [file join $vfs_path src]
file copy res [file join $vfs_path res]

set out_path [file join build $APP_NAME.exe]
zipfs mkimg $out_path $vfs_path $vfs_path "" $exe_path

file delete -force $vfs_path

exit
