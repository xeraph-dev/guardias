const PREFIX [file join [file home] opt tcl 9.1.0]

switch -exact -- $tcl_platform(os) {
    "Windows NT"    {set os win; set exe wish9.1.exe}
    Darwin          {set os osx; set exe wish9.1}
    Linux           {set os linux; set exe wish9.1}
    default         {puts stderr "unsupported target operating system"}
}

switch -exact -- $tcl_platform(machine) {
    arm64           {set arch arm64}
    x86_64 - amd64  {set arch x86_64}
    default         {puts stderr "unsupported target architecture"}
}

proc cmd args {puts $args; exec {*}$args >@stdout 2>@stderr}

cmd [file join $PREFIX $os $arch bin $exe] main.tcl
