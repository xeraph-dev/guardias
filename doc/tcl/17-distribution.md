# Distribution

## compile from macOS arm64 to macOS arm64

Compile a statically linked tcl

```shell
cd ~/dev/external/tcltk/tcl/unix
```

```shell
./configure --disable-shared --enable-zipfs \
  --prefix=/Users/xeraph/opt/tcl/9.0/osx/arm64
```

```shell
make -j$(sysctl -n hw.ncpu) install
```

Compile a statically linked tk

```shell
cd ~/dev/external/tcltk/tk/unix
```

```shell
./configure --disable-shared --enable-zipfs --enable-aqua \
  --prefix=/Users/xeraph/opt/tcl/9.0/osx/arm64 \
  --with-tcl=/Users/xeraph/opt/tcl/9.0/osx/arm64/lib
```

```shell
make -j$(sysctl -n hw.ncpu) install
```

Compile a statically linked tclsqlite extension

```shell
cd ~/dev/external/sqlite
```

```shell
./configure
```

```shell
make -j$(sysctl -n hw.ncpu) sqlite3.c
```

```shell
gcc -c sqlite3.c -o sqlite3-osx-arm64.o -O2 \
  -DSQLITE_THREADSAFE=1
```

```shell
gcc -c src/tclsqlite.c -o tclsqlite-osx-arm64.o \
  -I. \
  -I/Users/xeraph/opt/tcl/9.0/osx/arm64/include
```

```shell
gcc -o ~/opt/tcl/9.0/osx/arm64/bin/tcl /Users/xeraph/dev/tcl-main.c \
  /Users/xeraph/dev/external/sqlite/sqlite3-osx-arm64.o /Users/xeraph/dev/external/sqlite/tclsqlite-osx-arm64.o \
  ~/opt/tcl/9.0/osx/arm64/lib/libtcl9.0.a ~/opt/tcl/9.0/osx/arm64/lib/libtcl9tk9.0.a \
  -I/Users/xeraph/opt/tcl/9.0/osx/arm64/include \
  -framework CoreFoundation -framework Cocoa -framework Carbon \
  -framework IOKit -framework QuartzCore -framework UniformTypeIdentifiers \
  -lz -lpthread
```

```shell
cat ~/dev/external/tcltk/tk/unix/libtk9.0.3.zip >> ~/opt/tcl/9.0/osx/arm64/bin/tcl
```

## cross compile from macOS to Windows x86_64

Compile a statically linked tcl

```shell
cd ~/dev/external/tcltk/tcl/win
```

```shell
./configure \
  --host=x86_64-w64-mingw32 \
  --enable-64bit \
  --disable-shared \
  --enable-zipfs \
  --prefix=/Users/xeraph/opt/tcl/9.0/win/x86_64
```

```shell
make -j$(sysctl -n hw.ncpu) install
```

Compile a statically linked tk

```shell
cd ~/dev/external/tcltk/tk/win
```

```shell
./configure \
  --host=x86_64-w64-mingw32 \
  --enable-64bit \
  --disable-shared \
  --enable-zipfs \
  --prefix=/Users/xeraph/opt/tcl/9.0/win/x86_64 \
  --with-tcl=/Users/xeraph/opt/tcl/9.0/win/x86_64/lib
```

```shell
make -j$(sysctl -n hw.ncpu) install
```

Compile a statically linked tclsqlite extension

```shell
cd ~/dev/external/sqlite
```

```shell
./configure
```

```shell
make -j$(sysctl -n hw.ncpu) sqlite3.c
```

```shell
x86_64-w64-mingw32-gcc -c sqlite3.c -o sqlite3-win-x86_64.o -O2 \
  -DSTATIC_BUILD \
  -DSQLITE_THREADSAFE=1
```

```shell
x86_64-w64-mingw32-gcc -c src/tclsqlite.c -o tclsqlite-win-x86_64.o \
  -DSTATIC_BUILD \
  -I. \
  -I/Users/xeraph/opt/tcl/9.0/win/x86_64/include
```

```shell
x86_64-w64-mingw32-gcc -o ~/opt/tcl/9.0/win/x86_64/bin/tcl /Users/xeraph/dev/tcl-main.c \
  /Users/xeraph/dev/external/sqlite/sqlite3-win-x86_64.o /Users/xeraph/dev/external/sqlite/tclsqlite-win-x86_64.o \
  -Wl,--start-group \
    ~/opt/tcl/9.0/win/x86_64/lib/libtclstub.a \
    ~/opt/tcl/9.0/win/x86_64/lib/libtkstub.a \
    ~/opt/tcl/9.0/win/x86_64/lib/libtcl90.a \
    ~/opt/tcl/9.0/win/x86_64/lib/libtcl9tk90.a \
  -Wl,--end-group \
  -DSTATIC_BUILD \
  -I/Users/xeraph/opt/tcl/9.0/win/x86_64/include \
  -O2 -fomit-frame-pointer \
  -D__USE_MINGW_ANSI_STDIO=0 \
  -lnetapi32 -lkernel32 -luser32 -ladvapi32 -luserenv -lws2_32 -lgdi32 -lcomdlg32 -limm32 -lcomctl32 -lshell32 -luuid -lole32 -loleaut32 -lwinspool \
  -mwindows -pipe -static-libgcc -municode -Wl,--disable-high-entropy-va -Wl,--enable-auto-image-base
```

```shell
cat /Users/xeraph/dev/external/tcltk/tk/win/libtk9.0.3.zip >> ~/opt/tcl/9.0/win/x86_64/bin/tcl.exe
```
