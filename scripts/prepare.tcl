package require cmdline

source [file join [file dirname [info script]] common.tcl]

set options [list \
    [list os.arg        $default_os         "target operating system (osx, win, linux, all)"] \
    [list arch.arg      $default_arch       "target architecture (arm64, x86_64, all)"] \
    [list threads.arg   $default_threads    "how many threads to use in the make install process"] \
    [list prefix.arg    $PREFIX             "prefix path"] \
    [list tcl.arg       $TCL_SRC            "tcl source path"] \
    [list tk.arg        $TK_SRC             "tk source path"] \
    [list tcllib.arg    $TCLLIB_SRC         "tcllib source path"] \
    [list tklib.arg     $TKLIB_SRC          "tklib source path"] \
    [list fresh         0                   "delete prefix path and recompile everything"] \
]

set usage ": tclsh prepare.tcl \[options] \noptions:"
try {
    array set params [cmdline::getoptions argv $options $usage]
} trap {CMDLINE USAGE} {msg o} {
    puts $msg; exit 1
}

foreach {dir os arch host} {
    unix    osx     arm64   aarch64-apple-darwin
    unix    osx     x86_64  x86_64-apple-darwin
    win     win     x86_64  x86_64-w64-mingw32
} {
    if {$params(os) ni "all $os"} continue
    if {$params(arch) ni "all $arch"} continue

    if {$os eq "osx"} {
        set make [list arch -$arch make]
        set configure [list arch -$arch ./configure CFLAGS=-mmacosx-version-min=$MACOS_VERSION LDFLAGS=-mmacosx-version-min=$MACOS_VERSION]
    } else {
        set make make
        set configure ./configure
    }

    set prefix [file join $params(prefix) $os $arch]

    if {$params(fresh)} {file delete -force $prefix}
    file mkdir $prefix

    if {![file exists [file join $prefix lib tcl9]]} {
        cd [file join $params(tcl) $dir]
        if {[file exists Makefile]} {cmd {*}$make distclean}
        cmd {*}$configure --host=$host --prefix=$prefix \
                          --enable-zipfs --enable-64bit --disable-shared
        cmd {*}$make install -j$params(threads)
    }

    if {![file exists [file join $prefix lib tk9.1]]} {
        cd [file join $params(tk) $dir]
        if {[file exists Makefile]} {cmd {*}$make distclean}
        cmd {*}$configure --host=$host --prefix=$prefix --with-tcl=[file join $prefix lib] \
                          --enable-zipfs --enable-64bit --disable-shared \
                          [expr {$os eq "osx" ? "--enable-aqua" : ""}]
        cmd {*}$make install -j$params(threads)
    }

    if {![file exists [file join $prefix lib tcllib2.0]]} {
        cd $params(tcllib)
        if {[file exists Makefile]} {cmd {*}$make distclean}
        cmd {*}$configure --prefix=$prefix --with-tclsh=[info nameofexecutable] \
                          --mandir=[file join $prefix share man]
        cmd {*}$make install -j$params(threads)
    }

    if {![file exists [file join $prefix lib tklib0.9]]} {
        cd $params(tklib)
        if {[file exists Makefile]} {cmd {*}$make distclean}
        cmd {*}$configure --prefix=$prefix --with-tclsh=[info nameofexecutable]
        cmd {*}$make install -j$params(threads)
    }
}
