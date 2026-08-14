# TclOO Basics — Cheatsheet

TclOO is Tcl's built-in (since 8.6) object system — the foundation other frameworks
(including Snit's newer variants) can build on. It provides classes, single and multiple
inheritance, mixins, and method resolution introspection as core language features.

```tcl
package require TclOO   ;# not usually needed explicitly in 8.6+/9.0, it's built in
```

## 1. Defining a Class

```tcl
oo::class create Point {
    variable x y

    constructor {ix iy} {
        set x $ix
        set y $iy
    }

    method getX {} {return $x}
    method getY {} {return $y}

    method move {dx dy} {
        incr x $dx
        incr y $dy
    }

    method toString {} {
        return "($x, $y)"
    }
}

set p [Point new 3 4]
$p getX          ;# 3
$p move 1 1
$p toString       ;# (4, 5)
```

- `variable x y` declares **instance variables**, visible unqualified in all methods (unlike Snit's `options` array, no special access syntax needed).
- `constructor {args} {...}` runs on `new`/`create`.
- `new` creates an object with an auto-generated name (`::oo::Obj12...`); `create name` creates one with an explicit name.

```tcl
set p1 [Point new 0 0]           ;# auto-named
Point create p2 5 5               ;# explicitly named ::p2
p2 getX                            ;# 5
```

## 2. Methods

```tcl
oo::class create Account {
    variable balance

    constructor {{initial 0}} {
        set balance $initial
    }

    method deposit {amount} {
        incr balance $amount
        return $balance
    }

    method withdraw {amount} {
        if {$amount > $balance} {
            error "Insufficient funds"
        }
        incr balance [expr {-$amount}]
        return $balance
    }

    method balance {} {
        return $balance
    }
}

set a [Account new 100]
$a deposit 50      ;# 150
$a withdraw 30      ;# 120
$a balance           ;# 120
```

`self` (a command, not a variable) gives access to the current object/method context inside a method body:

```tcl
method describe {} {
    return "I am [self object] of class [self class]"
}
```

## 3. Inheritance

```tcl
oo::class create Animal {
    variable name

    constructor {n} {
        set name $n
    }

    method speak {} {
        return "$name makes a sound"
    }
}

oo::class create Dog {
    superclass Animal

    method speak {} {
        return "[next] ... specifically, barks"
    }
}

set d [Dog new "Rex"]
$d speak      ;# "Rex makes a sound ... specifically, barks"
```

- `superclass ClassName` declares the parent; the constructor is inherited automatically if not overridden.
- `next` calls the same method in the next class up the method resolution order (like `super` in other languages) — must be called from *within* an overriding method.
- Multiple inheritance is allowed: `superclass ClassA ClassB` — resolution order follows C3 linearization (first-listed class takes priority on conflicts).

## 4. `oo::define` — Modifying Classes After Creation

Equivalent to writing inside the `oo::class create` body, but usable to extend a class later
(e.g. splitting a definition across files, or patching at runtime).

```tcl
oo::define Point {
    method distanceFromOrigin {} {
        return [expr {sqrt($x**2 + $y**2)}]
    }
}

oo::define Point {
    variable label
    method setLabel {l} {set label $l}
}
```

## 5. Private State and Methods

TclOO has no formal `private` keyword; conventions substitute:

```tcl
oo::class create Widget {
    variable state

    constructor {} {
        set state [my Init]
    }

    method Init {} {
        # leading-uppercase method: convention for "internal use only"
        return "initialized"
    }
}
```

`my` is how a method calls **another method on the same object**, equivalent to `self` used
as a command prefix — `my methodName` inside a body is the standard way to invoke internal
helper methods, especially unexported ones (see `unexport` below).

## 6. Exporting/Unexporting Methods

```tcl
oo::class create Sample {
    method PrivateHelper {} {return "internal"}
    method publicApi {} {return [my PrivateHelper]}

    unexport PrivateHelper    ;# blocks calling it as: $obj PrivateHelper
}
```

`unexport methodName` prevents external callers from invoking a method directly through the
object command, while it remains callable internally via `my`.

## 7. Destructor

```tcl
oo::class create Resource {
    variable handle

    constructor {} {
        set handle [openSomeHandle]
    }

    destructor {
        closeHandle $handle
    }
}

set r [Resource new]
$r destroy      ;# runs destructor
```

## 8. Abstract-Style Classes

TclOO has no formal `abstract` keyword — the idiom is a class with no useful constructor
and methods meant to be overridden, often combined with `error` stubs:

```tcl
oo::class create Shape {
    method area {} {
        error "area must be implemented by subclass"
    }
}

oo::class create Circle {
    superclass Shape
    variable r

    constructor {radius} {set r $radius}

    method area {} {
        return [expr {3.14159 * $r * $r}]
    }
}
```

## 9. Mixins — Composition Without Full Inheritance

Mixins inject a class's methods into an object or class without it being a formal
superclass — useful for cross-cutting behavior (logging, validation) shared across unrelated
class hierarchies.

```tcl
oo::class create Loggable {
    method log {msg} {
        puts "\[LOG\] $msg"
    }
}

oo::class create Service {
    mixin Loggable

    method run {} {
        my log "running"
    }
}

set s [Service new]
$s run          ;# [LOG] running
```

`mixin` can also be applied to a single instance rather than a whole class:

```tcl
oo::objdefine $someObject mixin Loggable
```

## 10. Filters — Method Interception

A filter wraps every call to an object's methods, useful for cross-cutting concerns like
logging or access control without modifying each method individually.

```tcl
oo::class create Traced {
    method trace {name args} {
        puts "calling $name with $args"
        set result [next {*}$args]
        puts "returned: $result"
        return $result
    }
}

oo::class create MyService {
    mixin Traced
    filter trace

    method doWork {x} {
        return [expr {$x * 2}]
    }
}

set s [MyService new]
$s doWork 5
# calling doWork with 5
# returned: 10
```

## 11. Forwarding — Delegation to Another Object

`forward` maps a method name directly onto a call to another command/object, similar in
spirit to Snit's `delegate` but simpler/more manual.

```tcl
oo::class create Logger {
    method write {msg} {puts "LOG: $msg"}
}

oo::class create App {
    variable logger

    constructor {} {
        set logger [Logger new]
    }

    forward log $logger write   ;# App's "log" method calls $logger's "write" method
}

set app [App new]
$app log "started"      ;# LOG: started
```

## 12. Introspection

```tcl
info object class $obj              ;# class of an instance
info object methods $obj             ;# methods defined directly on it
info object isa object $obj           ;# boolean check
info class superclasses ClassName      ;# parent classes
info class instances ClassName          ;# all live instances
$obj destroy
```

## 13. Common Full Skeleton

```tcl
oo::class create Base {
    variable id

    constructor {objId} {
        set id $objId
    }

    method getId {} {return $id}

    method Log {msg} {
        # leading-uppercase: internal convention
        puts "\[$id\] $msg"
    }

    destructor {
        my Log "destroyed"
    }
}

oo::class create Derived {
    superclass Base
    variable extra

    constructor {objId extraVal} {
        next $objId
        set extra $extraVal
    }

    method describe {} {
        my Log "describing"
        return "[my getId]: $extra"
    }
}

set d [Derived new "obj1" "extra-data"]
$d describe
```

## 14. Gotchas

- `variable x y` inside the class body only declares instance variable *names* for method bodies — it does not initialize them; use the constructor for that, or values will be unset until first assigned.
- `next` outside of an overriding method (i.e. when there's no matching method further up the chain) raises an error — expected when overriding, but a bug if the superclass hierarchy doesn't actually define that method.
- Object names created via `new` are internal auto-generated identifiers (`::oo::Obj7`) — don't hardcode assumptions about their format; always store the returned handle.
- `destroy` must be called explicitly — TclOO objects are **not garbage collected** automatically when they go out of scope; a `set obj [MyClass new]` that goes out of scope without `$obj destroy` leaks the object.
- Mixing `mixin` and `superclass` on overlapping method names follows a defined but non-obvious precedence (roughly: mixins are inserted ahead of the class's own linearization) — use `info class linearize $classname` (or `self call`/introspection during debugging) if resolution order matters and is unclear.
- Filters apply to *all* method calls on the object, including ones triggered internally via `my` — this can cause unexpected double-logging or recursive tracing if not scoped carefully.
