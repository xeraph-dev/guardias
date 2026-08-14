# Tcl Basics — Core Language Cheatsheet

Tcl (Tool Command Language) is a dynamically typed, string-based scripting language.
Every value is a string; other interpretations (int, list, dict) are lazy and cached ("Tcl_Obj shimmering").
This guide targets Tcl 8.6+/9.0 syntax.

## 1. Syntax Fundamentals

Everything is a command. A command is a list of words separated by whitespace, terminated by newline or `;`.

```tcl
command arg1 arg2 arg3
puts "Hello, World!"
set x 10; set y 20    ;# semicolon separates commands on one line
```

### Substitution rules (happen once, left to right, before the command runs)

| Syntax | Meaning | Example |
|---|---|---|
| `$name` | Variable substitution | `puts $x` |
| `[cmd]` | Command substitution (result inlined) | `set y [expr {1+2}]` |
| `"..."` | String with substitutions enabled | `"Value: $x"` |
| `{...}` | Literal block, **no substitution** | `{$x stays literal}` |
| `\` | Escape character | `\n`, `\t`, `\$`, `\{` |

Braces `{}` are the most important construct in Tcl: they pass text through unevaluated.
This is why control structures and procedure bodies are almost always written in braces —
it delays evaluation until the receiving command chooses to `eval`/`uplevel` it.

```tcl
# WRONG: $x substituted immediately, before if runs
if $x > 5 {puts big}

# RIGHT: expression braced, evaluated by `if`/`expr` internally
if {$x > 5} {puts big}
```

### Comments
`#` only starts a comment when it appears where a command is expected (start of a statement).

```tcl
# this is a comment
set x 1 ;# this is NOT a comment unless preceded by ; or newline
```

## 2. Variables

```tcl
set x 10          ;# set/create
set x              ;# read (returns 10) — same command reads and writes
unset x            ;# delete
info exists x       ;# boolean check
incr x              ;# x += 1
incr x -1           ;# x -= 1
append s "more text" ;# string concatenation in place
```

Variable names are dynamic strings — no declarations, no static typing.

### Scope
- Procedure bodies have **local scope** by default.
- `global varName` imports a global into local scope.
- `variable varName` imports/creates a namespace variable into local scope.
- `upvar level varName localName` links to a variable in a caller's frame (used by pass-by-reference idioms).

```tcl
set counter 0
proc bump {} {
    global counter
    incr counter
}
```

## 3. Data Structures

### Lists
A list is just a string with a specific quoting convention — words separated by whitespace, braces group elements with embedded spaces.

```tcl
set l {a b c}
set l [list a b {c d} 3]     ;# safer: handles special chars correctly
lindex $l 0                  ;# a
llength $l                   ;# 4
lappend l e                  ;# append element
linsert $l 1 X               ;# insert at index
lset l 0 Z                   ;# mutate element at index
lrange $l 1 2                ;# sublist
lsearch $l c                 ;# index or -1
lsort $l                     ;# sorted copy
foreach item $l {puts $item}
foreach {a b} {1 2 3 4} {puts "$a-$b"}  ;# multi-var stepping
```

### Dicts (ordered key-value maps, Tcl 8.5+)

```tcl
set d [dict create name Alice age 30]
dict get $d name              ;# Alice
dict set d city NYC           ;# add/update
dict unset d age               ;# remove key
dict exists $d name             ;# boolean
dict keys $d
dict values $d
dict for {k v} $d {puts "$k=$v"}
dict with d {puts $name}        ;# unpack keys as local vars in scope
```

### Arrays (legacy hash tables, still widely used, esp. `::env`, options)

```tcl
set arr(key1) "value1"
set arr(key2) "value2"
puts $arr(key1)
array names arr                 ;# list of keys
array size arr
foreach key [array names arr] {puts "$key -> $arr($key)"}
```

Arrays are **not** first-class values (can't be passed around like a variable);
prefer `dict` for new code unless interfacing with array-based APIs (e.g. Tk options, `::env`).

## 4. Expressions — `expr`

Arithmetic/logical evaluation is NOT automatic; you must call `expr`. Always brace the expression.

```tcl
set r [expr {3 + 4 * 2}]     ;# 11
expr {$x > 0 && $y < 10}
expr {$x eq "foo"}           ;# string equality
expr {$x == 5}               ;# numeric equality
expr {[string length $s] > 0}
```

Operators: `+ - * / %` (numeric), `eq ne` (string equality/inequality), `== != < > <= >=` (numeric or string, context-sensitive), `&& || !` (logical), `in ni` (list membership, 8.5+).

```tcl
expr {"b" in {a b c}}   ;# 1
```

## 5. Control Flow

```tcl
if {$x > 10} {
    puts big
} elseif {$x > 0} {
    puts small
} else {
    puts nonpositive
}

while {$i < 10} {
    incr i
}

for {set i 0} {$i < 10} {incr i} {
    puts $i
}

switch $val {
    a       {puts "got a"}
    b - c   {puts "got b or c"}
    default {puts "other"}
}
```

`break` / `continue` work as expected inside loops.

## 6. Procedures

```tcl
proc greet {name {greeting "Hello"}} {
    return "$greeting, $name!"
}
greet "World"              ;# Hello, World!
greet "World" "Hi"         ;# Hi, World!

# Variadic
proc sumAll {args} {
    set total 0
    foreach n $args {incr total $n}
    return $total
}
sumAll 1 2 3 4              ;# 10
```

- Default values via `{argName default}`.
- `args` as the last parameter captures remaining arguments as a list.
- Return value is the last expression's result, or explicit `return`.
- `return -code error "msg"` / `error "msg"` to raise an error.

## 7. Error Handling

```tcl
if {[catch {risky_command} result]} {
    puts "Error: $result"
} else {
    puts "Success: $result"
}

# Modern form (8.6+), captures full error dict
try {
    risky_command
} on error {msg opts} {
    puts "Failed: $msg"
} finally {
    cleanup
}
```

## 8. Strings

```tcl
string length $s
string index $s 0
string range $s 0 3
string toupper $s
string tolower $s
string trim $s
string map {a A b B} $s        ;# multi-replace
string replace $s 0 2 "new"
string match "a*c" $s          ;# glob-style match
regexp {(\d+)-(\d+)} $s -> a b ;# regex with capture groups
regsub -all {\s+} $s " "        ;# regex replace
split $s ","                    ;# -> list
join $list ","                  ;# list -> string
format "%s is %d" $name $age    ;# printf-style
```

## 9. I/O Basics

```tcl
set f [open "file.txt" r]
set content [read $f]
close $f

set f [open "out.txt" w]
puts $f "line of text"
close $f

foreach line [split [read [open "file.txt" r]] "\n"] {
    puts $line
}
```

## 10. Namespaces (preview — see dedicated guide)

```tcl
namespace eval ::MyModule {
    variable counter 0
    proc incrCounter {} {
        variable counter
        incr counter
    }
}
::MyModule::incrCounter
```

## 11. Useful Introspection

```tcl
info exists varName
info commands pat*
info procs pat*
info level                  ;# call stack depth
info body procName
llength [info args procName]
```

## 12. Gotchas

- `set x [list 1 2 3]` and `set x {1 2 3}` are usually equivalent, but `list` correctly quotes elements with spaces/braces — prefer it when building lists programmatically.
- Numeric comparison with `==`/`!=` requires actual numeric strings; use `eq`/`ne` for arbitrary string comparison to avoid errors on non-numeric input.
- `expr` without braces double-evaluates and is a common source of bugs/security issues — **always brace `expr` arguments**.
- Empty string `{}` and 0/false are distinct — check with `info exists` or `eq {}`, not truthiness.
- Tcl has no `null`; “absence” is usually modeled with `info exists` or a sentinel value.
