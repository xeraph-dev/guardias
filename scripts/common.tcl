const MACOS_VERSION 15.4

const APP_NAME guardias
const APP_ITEMS {lib migrations msgs res src main.tcl}

const PKGS {sqlite3.53.4}
const TCLLIB_PKGS {snit math}
const TKLIB_PKGS {widget}

const PREFIX [file join [file home] opt tcl 9.1.0]
const TCL_SRC [file join [file home] src tcl9.1.0]
const TK_SRC [file join [file home] src tk9.1.0]
const TCLLIB_SRC [file join [file home] src tcllib-2.0]
const TKLIB_SRC [file join [file home] src tklib-0.9]

switch -exact -- $tcl_platform(os) {
    "Windows NT"    {set default_os win; set default_exe wish9.1.exe}
    Darwin          {set default_os osx; set default_exe wish9.1}
    Linux           {set default_os linux; set default_exe wish9.1}
    default         {puts stderr "unsupported target operating system"}
}

switch -exact -- $tcl_platform(machine) {
    arm64           {set default_arch arm64}
    x86_64 - amd64  {set default_arch x86_64}
    default         {puts stderr "unsupported target architecture"}
}

switch -exact -- $tcl_platform(os) {
    "Windows NT" {set default_threads $env(NUMBER_OF_PROCESSORS)}
    Darwin {
        try {
            set default_threads [exec sysctl -n hw.ncpu]
        }
    }
    Linux {
        try {
            set default_threads 0
            set chan [open [file join / proc cpuinfo] r]
            while {[gets $chan line] >= 0} {
                if {[string match "processor*" $line]} {
                    incr default_threads
                }
            }
            close $chan
        }
    }
    default {puts stderr "unsupported target operating system"}
}

if {![info exists default_threads] || $default_threads == 0} {set default_threads 1}

proc cmd args {puts $args; exec {*}$args >@stdout 2>@stderr}
