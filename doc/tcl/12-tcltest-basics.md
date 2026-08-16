# tcltest Basics — Cheatsheet

`tcltest` is Tcl's standard testing framework, bundled with every Tcl installation. Tests
are declared with `test`, organized into `.test` files, and run via `tclsh` — no external
dependency needed for basic unit testing.

```tcl
package require tcltest
namespace import ::tcltest::*
```

## 1. Minimal Test File

```tcl
package require tcltest
namespace import ::tcltest::*

test add-1 {adds two positive numbers} -body {
    expr {2 + 3}
} -result 5

test add-2 {adds negative numbers} -body {
    expr {-2 + -3}
} -result -5

cleanupTests
```

Run it:

```
tclsh mytest.test
```

Output reports pass/fail per test and a summary count at the end.

## 2. Anatomy of a `test` Command

```tcl
test testName {description} {
    -setup      {script run before -body}
    -body       {the code under test; its result is compared}
    -cleanup    {script run after -body, even on failure}
    -result     expectedValue
    -returnCodes {ok}
    -match      exact
}
```

- `testName` should be unique within the file — convention: `feature-N` (e.g. `parser-1`, `parser-2`) or `feature-description-N`.
- `-body` is the only required piece besides a comparison (`-result` or similar); everything else is optional.
- The overall test passes if `-body`'s result (and return code) matches what `-result`/`-returnCodes` specify.

## 3. Common Matching Modes

```tcl
test match-exact {} -body {
    return "hello"
} -result "hello" -match exact

test match-glob {} -body {
    return "error: file not found"
} -result "error: *" -match glob

test match-regexp {} -body {
    return "user123"
} -result {user\d+} -match regexp
```

`-match` defaults to `exact`; `glob` and `regexp` are useful when exact output is
unpredictable (timestamps, generated IDs) but the *shape* of the result matters.

## 4. Testing Errors

```tcl
test error-1 {raises on invalid input} -body {
    error "invalid input"
} -returnCodes error -result "invalid input"

test error-2 {custom error code} -body {
    return -code error -errorcode {MYAPP BADINPUT} "bad value"
} -returnCodes error -errorCode {MYAPP BADINPUT}
```

- `-returnCodes` lists acceptable Tcl return codes (`ok`, `error`, `return`, `break`, `continue`) — a test expecting an error must declare `-returnCodes error`, or a raised error is treated as an unexpected test failure rather than the expected outcome.
- `-errorCode` checks the structured error code (see the error-handling guide) rather than just the message text — more robust than matching error message strings, since messages can change wording without changing semantics.

## 5. `-setup` and `-cleanup`

```tcl
test db-insert-1 {inserts a row} -setup {
    sqlite3 testdb :memory:
    testdb eval {CREATE TABLE t (id INTEGER, name TEXT)}
} -body {
    testdb eval {INSERT INTO t VALUES (1, 'x')}
    testdb eval {SELECT count(*) FROM t}
} -cleanup {
    testdb close
} -result 1
```

`-cleanup` runs **even if `-body` fails or errors**, so resources (open connections, temp
files, mock state) are reliably released between tests — avoid relying on test execution
order for cleanup.

## 6. Fixtures Shared Across Multiple Tests

For setup/cleanup repeated across many tests in a file, define procs instead of repeating
`-setup`/`-cleanup` scripts inline.

```tcl
proc setupDb {} {
    sqlite3 testdb :memory:
    testdb eval {CREATE TABLE users (id INTEGER, name TEXT)}
}
proc teardownDb {} {
    testdb close
}

test users-1 {} -setup {setupDb} -cleanup {teardownDb} -body {
    testdb eval {INSERT INTO users VALUES (1, 'Alice')}
    testdb eval {SELECT name FROM users WHERE id = 1}
} -result Alice

test users-2 {} -setup {setupDb} -cleanup {teardownDb} -body {
    testdb eval {SELECT count(*) FROM users}
} -result 0
```

## 7. Constraints — Conditionally Skipping Tests

```tcl
testConstraint hasNetwork [expr {[catch {socket -async example.com 80}] == 0}]

test network-1 {requires network} -constraints hasNetwork -body {
    # ...
} -result ok
```

- `testConstraint name boolean` registers a named condition.
- `-constraints name` on a `test` skips it (reported as "skipped", not failed) if the named constraint evaluates false.
- Common built-in constraints already provided by `tcltest` include platform checks (`unix`, `win`, `macosx`) usable directly without registering them yourself.

```tcl
test windows-only-1 {} -constraints win -body {
    # only runs on Windows
} -result ok
```

## 8. Organizing Multiple Test Files

Convention: one `.test` file per module/feature, named to mirror the source file it covers.

```
lib/mathutils/mathutils.tcl
tests/mathutils.test
```

```tcl
# tests/mathutils.test
package require tcltest
namespace import ::tcltest::*

lappend auto_path [file join [file dirname [info script]] .. lib]
package require mathutils

test square-1 {} -body {::mathutils::square 4} -result 16
test cube-1 {} -body {::mathutils::cube 3} -result 27

cleanupTests
```

### Running all test files in a directory

```tcl
package require tcltest
::tcltest::runAllTests
```

Or from the shell, loop over files:

```
for f in tests/*.test; do tclsh "$f"; done
```

## 9. `configure` — Controlling Test Run Behavior

```tcl
::tcltest::configure -verbose {pass fail skip}
::tcltest::configure -match {feature-*}      ;# only run tests whose name matches this glob
::tcltest::configure -skip {feature-3}         ;# explicitly skip specific tests
```

- `-verbose` controls what gets printed per test (by default, only failures are noisy).
- `-match`/`-skip` are useful for running a subset while debugging a specific area without commenting out other tests.
- These can also be set via command-line arguments when invoking `tclsh mytest.test -verbose {pass fail}`.

## 10. Assertions Beyond `-result`

For checks that don't fit the "single return value" model, use `catch`/manual `puts`
inside `-body`, or simply structure the body to return a boolean:

```tcl
test complex-check-1 {multiple conditions} -body {
    set r [computeSomething]
    expr {[dict get $r status] eq "ok" && [dict get $r count] > 0}
} -result 1
```

For more structured multi-assertion tests, some projects use a helper proc that runs
several checks and returns a summary — `tcltest` itself stays intentionally minimal and
doesn't include a rich assertion library like some other language's testing frameworks.

## 11. `cleanupTests` — Required at End of File

```tcl
cleanupTests
```

Prints the final pass/fail/skip summary for the file and resets internal `tcltest` state.
Omitting it doesn't break individual tests, but breaks the summary reporting and can affect
behavior when multiple test files are run in the same interpreter session (e.g. via
`runAllTests`).

## 12. Gotchas

- A test whose `-body` raises an unexpected error (when `-returnCodes` wasn't set to expect one) is reported as a failure with the error message shown — easy to misdiagnose as "the assertion failed" when actually the code under test crashed before producing a comparable result at all; read the failure output carefully to distinguish the two cases.
- `-cleanup` scripts that themselves error can mask the real pass/fail outcome of `-body` — keep cleanup scripts simple and defensive (e.g. wrap in `catch` if a resource might already be gone).
- Test names must be unique per file; reusing a name silently overwrites reporting for the earlier test with the same name rather than raising an error.
- `namespace import ::tcltest::*` pulls test commands into the current namespace — if a test file also defines its own procs with colliding names (`test`, `body`, etc. are unlikely, but generic helper names are not), there's potential for shadowing; keep test-file helper proc names distinct from anything in the `tcltest` command set.
- Tests relying on shared global/namespace state without proper `-setup`/`-cleanup` can pass or fail depending on execution order — a good rule is that any single test file should be safely runnable with tests in any order or in isolation.
- `testConstraint`-based skips report as "skipped," not "passed" — verify skip counts explicitly if a CI pipeline should fail when constraints unexpectedly hide real bugs (e.g. a constraint that's supposed to be true in CI silently evaluating false due to an environment difference).
