package require cmdline
package require fileutil

namespace import fileutil::cat

source [file join [file dirname [info script]] common.tcl]

set options [list \
    [list os.arg        $default_os         "target operating system (osx, win, linux, all)"] \
    [list arch.arg      $default_arch       "target architecture (arm64, x86_64, all)"] \
    [list prefix.arg    $PREFIX             "prefix path"] \
]

set usage ": tclsh build.tcl \[options] \noptions:"
try {
    array set params [cmdline::getoptions argv $options $usage]
} trap {CMDLINE USAGE} {msg o} {
    puts $msg; exit 1
}

if {![file exists build]} {file mkdir build}

foreach {os arch exe} {
    osx arm64   wish9.1
    osx x86_64  wish9.1
    win x86_64  wish91s.exe
} {
    if {$params(os) ni "all $os"} continue
    if {$params(arch) ni "all $arch"} continue

    set prefix [file join $params(prefix) $os $arch]
    set vfs [file join [file tempdir] $APP_NAME-$os-$arch.vfs]

    file delete -force $vfs
    file mkdir $vfs

    set mnt //zipfs:/base-$os-$arch
    zipfs mount [file join $prefix bin $exe] $mnt
    file copy [file join $mnt tcl_library] [file join $vfs tcl_library]
    file copy [file join $mnt tk_library] [file join $vfs tk_library]
    zipfs unmount $mnt

    foreach item $APP_ITEMS {
        if {[file exists $item]} {file copy $item [file join $vfs $item]}
    }

    foreach pkg $PKGS        {file copy [file join $prefix lib $pkg] [file join $vfs lib $pkg]}
    foreach pkg $TCLLIB_PKGS {file copy [file join $prefix lib tcllib2.0 $pkg] [file join $vfs lib $pkg]}
    foreach pkg $TKLIB_PKGS  {file copy [file join $prefix lib tklib0.9 $pkg] [file join $vfs lib $pkg]}

    switch -exact -- $os {
        osx     {set app_exe $APP_NAME-$os-$arch}
        win     {set app_exe $APP_NAME-$arch.exe}
        default {puts stderr "unsupported operating system"}
    }
    zipfs mkimg [file join build $app_exe] $vfs $vfs "" [file join $prefix bin $exe]

    file delete -force $vfs
}
