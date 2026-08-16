# zipfs Basics — Single-Binary Packaging Cheatsheet

`zipfs` (native in Tcl 8.6+, fully integrated in Tcl 9) lets a Tcl interpreter mount a ZIP
archive as a virtual filesystem, and — critically — an executable can have a ZIP archive
appended to itself and still run normally. This is what makes true single-binary
deployment possible without external tools (replaces the older Starkit/SDX ecosystem,
which relied on a separate runtime + VFS layer bolted on top of vanilla Tcl).

## 1. Core Concept

A ZIP file appended to the end of an executable doesn't corrupt it — the executable format
is read from the front, the ZIP central directory is read from the end. `zipfs` exploits
this: your app's Tcl scripts, images, and other assets get zipped up and appended to a
copy of `tclsh`/`wish` (or your compiled app), producing one file that is simultaneously a
valid executable and a valid ZIP archive.

```
[normal executable bytes][zip archive of your app's files]
```

## 2. Mounting a ZIP Archive

```tcl
zipfs mount archive.zip /myapp
```

This makes the archive's contents available under `/myapp` as if it were a real directory
— `open`, `source`, `glob`, `file exists`, etc. all work transparently against paths inside it.

```tcl
zipfs mount archive.zip /myapp
source /myapp/lib/utils.tcl
set data [read [open /myapp/data/config.json r]]
```

```tcl
zipfs unmount /myapp
```

## 3. Mounting the Running Executable Itself

The key trick for single-binary apps: a running program can mount **itself** (if it has a
ZIP appended) to access its own bundled files.

```tcl
zipfs mount [info nameofexecutable] /app
source /app/main.tcl
```

Combined with build-time packaging (see below), this is how the whole "one file contains
interpreter + your entire app" model works.

## 4. Building a Self-Contained Executable

Basic workflow: create your app's file tree, zip it, append the ZIP to a copy of the Tcl
runtime.

```tcl
# 1. Build the zip archive from a directory of your app's Tcl/asset files
zipfs mkzip app.zip /path/to/app_source_dir

# 2. Copy the base interpreter binary and append the archive to it
file copy /usr/bin/tclsh myapp
set fout [open myapp a]
fconfigure $fout -translation binary
set fin [open app.zip r]
fconfigure $fin -translation binary
fcopy $fin $fout
close $fin
close $fout
```

The resulting `myapp` file is both a runnable Tcl interpreter and a ZIP archive with your
code appended — `zipfs mount [info nameofexecutable] /app` inside your `main.tcl` (itself
bundled in the zip) lets the running program find and load the rest of its own files.

For static app-startup wiring, `zipfs mkimg` (Tcl 8.6.10+/9.0) automates building a
self-booting executable in one step rather than manual concatenation:

```tcl
zipfs mkimg outputExe app_source_dir tclsh_path
```

Exact flags/behavior vary by Tcl version — check `zipfs mkimg` usage in your target version
before relying on it in a build script.

## 5. Auto-Mounting Convention — `main.tcl`

If a mounted (or self-appended) archive contains a file named `main.tcl` at its root, and
the app is launched via the appended-executable mechanism, Tcl's startup sequence can
auto-source it — check your specific Tcl/Tk build's startup behavior, as auto-detection
conventions have evolved across 8.6.x point releases into 9.0. The explicit and portable
approach — safe across versions — is to mount and source manually at the very top of your
entry script:

```tcl
# entry point of the appended interpreter
if {[info exists ::env(APP_SELF_MOUNTED)] == 0} {
    zipfs mount [info nameofexecutable] /app
    source /app/main.tcl
}
```

## 6. Reading Assets from a Mounted Archive

Once mounted, all standard file-reading commands work unmodified against the virtual paths:

```tcl
zipfs mount app.zip /app

# Tcl source files
source /app/lib/helpers.tcl

# Static assets
set icon [image create photo -file /app/assets/icon.png]

# Config/data files
set cfg [open /app/config/settings.json r]
set json [read $cfg]
close $cfg
```

Mounted paths are **read-only** — you cannot write into a mounted zip archive at runtime.
Application data that needs to be written (databases, logs, user settings) must live
outside the mount, at a real filesystem path (e.g. next to the executable, or in a
platform-appropriate app-data directory).

## 7. Listing / Inspecting Mounts

```tcl
zipfs mount              ;# with no args: lists all current mount points
```

```tcl
if {"/app" in [dict keys [zipfs mount]]} {
    puts "already mounted"
}
```

(Exact return format of `zipfs mount` with no arguments varies slightly by version —
inspect it directly with `puts [zipfs mount]` when writing version-portable code.)

## 8. Password-Protected Archives

```tcl
zipfs mount archive.zip /app mypassword
```

`zipfs mkzip` also supports a password argument at creation time. This provides light
obfuscation (deterring casual inspection of bundled source), not real security — the
password/algorithm is a standard ZIP feature, not cryptographically strong protection
against a determined attacker with access to the binary.

## 9. Typical Project Layout for zipfs Packaging

```
app_source/
├── main.tcl              # entry point, sourced first
├── lib/
│   ├── core.tcl
│   └── ui.tcl
├── assets/
│   ├── icon.png
│   └── style.tcl
└── data/
    └── default_config.json
```

Build step zips `app_source/` and appends it to the interpreter binary, producing a single
distributable file that mounts itself and sources `main.tcl` at startup.

## 10. Why zipfs Replaces Starkit/SDX

Older Tcl deployment relied on **Starkits** (a VFS layer implemented as a Tcl package,
requiring `tclkit` as the runtime) and **SDX** (a separate tool to wrap/unwrap them).
`zipfs` achieves the same practical outcome — one file, no installation, bundled
assets — as a **native interpreter feature**, with no external package or custom runtime
required. Projects targeting Tcl 8.6+/9.0 exclusively can drop the Starkit/SDX toolchain
entirely in favor of `zipfs mkzip`/`zipfs mount`/`zipfs mkimg`.

## 11. Application Icons

Two entirely separate things are meant by "app icon," handled by different mechanisms:

### Window icon (runtime, pure Tcl/Tk)

The icon shown in the title bar/taskbar while the app is running — set from within the
script itself, and can be read straight out of the mounted archive since it's just a file read.

```tcl
zipfs mount [info nameofexecutable] /app

# Windows-native .ico
wm iconbitmap . -default "/app/assets/icon.ico"

# cross-platform, via a loaded image
image create photo appIcon -file "/app/assets/icon.png"
wm iconphoto . -default appIcon
```

### Executable file icon (build-time, OS-level, not a Tcl/Tk concern)

The icon shown in Windows Explorer for the `.exe` file itself — before the app is even
opened. This is embedded in the executable's PE resource section, a build/link-time
concern entirely outside Tcl/Tk's scope. Building an executable via the copy-and-append
zipfs approach (section 4) inherits whatever icon the base interpreter binary
(`wish.exe`/`tclsh.exe`) already had — typically Tcl's generic default icon.

To set a custom `.exe` icon without recompiling the interpreter from source, post-process
the already-built executable with a resource-editing tool:

```bash
rcedit myapp.exe --set-icon icon.ico
```

`rcedit` (github.com/electron/rcedit, MIT license) is a command-line tool that edits a
Windows executable's embedded resources — icon, version strings, product name, execution
level — after the fact, no recompilation needed. Prebuilt binaries are available from its
GitHub releases; it's also installable via `npm install -g rcedit` if Node is already part
of the build toolchain.

```bash
rcedit myapp.exe --set-icon icon.ico --set-version-string "ProductName" "MyApp" --set-file-version "1.0.0"
```

Run this as the final step of the build pipeline, after the zipfs-based executable has
already been assembled.

**Cross-compiling from macOS/Linux**: `rcedit`'s own binary is a Windows executable. On
non-Windows build machines it requires Wine 1.6+ installed and on the `PATH` to run; on a
Windows CI runner it works natively with no extra dependency.

## 12. Gotchas

- Mounted archive contents are **read-only** at runtime — don't design app logic that tries to write config/state files back into the mounted path; write real files to a normal filesystem location instead (e.g. alongside the executable, or a user data directory).
- Appending a ZIP to an executable must preserve the executable's own format integrity — always open both files in **binary mode** (`fconfigure ... -translation binary`) when concatenating, or platform-specific line-ending translation can corrupt the result.
- `zipfs mount` paths are a **virtual namespace**, not real filesystem paths — some external tools/processes that expect a real file on disk (e.g. spawning a subprocess that needs to `open()` a file itself, outside the Tcl interpreter) won't be able to see into a mounted archive; extract to a temp file first if you need to hand a path to external code.
- Password protection on a `zipfs` archive is not a substitute for genuine access control or encryption — treat it as light deterrence only.
- Because `zipfs mkimg`/append-based builds can behave slightly differently across Tcl point releases, pin and test against the specific Tcl 9 version your build pipeline targets rather than assuming behavior documented for one release carries over exactly to another.
- Self-mounting (`zipfs mount [info nameofexecutable] /app`) must run **before** anything tries to `source` bundled files — placing this call anywhere other than the very first lines of the entry script is a common source of "file not found" errors during startup.
- Confusing window icon and executable-file icon is a common source of "I set the icon but it's still showing the default" reports — `wm iconphoto`/`wm iconbitmap` only ever affects the running window, never what Explorer shows for the file itself, and vice versa: `rcedit` only affects the file icon, not the window icon shown once the app is actually running. Both are typically needed together for a fully polished distributable.
