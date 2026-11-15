source [file join [file dirname [info script]] common.tcl]


cmd man -M [file join $PREFIX $default_os $default_arch share man] {*}$argv
