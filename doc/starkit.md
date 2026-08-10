# Empaquetado y distribución: Starkit, Starpack y tclkit

Esta es la guía que más conecta con tu filosofía de "single-binary, offline-first, deployment sin dependencias" que ya usas con Go+Wails. Tcl tiene su propio ecosistema para lograr exactamente eso — un solo archivo ejecutable, sin instalar Tcl en la máquina destino, sin `node_modules`, sin conexión a internet.

---

## 0. El problema que resuelve

Un script `.tcl` normal necesita que la máquina destino tenga Tcl/Tk instalado, con la versión correcta y todos los paquetes (`sqlite3`, `Img`, tu propio código en múltiples archivos) accesibles en el `auto_path`. Eso es exactamente el tipo de fricción que evitas con Go compilando a un binario estático. El ecosistema Starkit resuelve lo mismo para Tcl:

```
tu-herramienta.tcl + assets/ + librerías → [empaquetado] → tu-herramienta (un solo archivo ejecutable)
```

---

## 1. Los tres niveles: tclkit, Starkit, Starpack

| Concepto | Qué es |
|---|---|
| **tclkit** | Un único binario ejecutable que contiene Tcl/Tk completo + un sistema de archivos virtual (VFS) montado dentro de sí mismo. Es tu "runtime". |
| **Starkit** (`.kit`) | Un archivo que contiene tu código + assets, pero necesita que un tclkit lo ejecute (`tclkit miapp.kit`). Portable entre SOs (mismo `.kit` corre en Windows/Linux/Mac si tienes el tclkit correspondiente). |
| **Starpack** (`.exe` / binario) | Un Starkit **fusionado** con un tclkit específico de una plataforma, dando un único ejecutable nativo, standalone, sin ninguna dependencia externa — esto es lo que le entregas al usuario final. |

Analogía directa con tu stack: tclkit es como tener el runtime de Go instalado; Starkit es como un `.go` que necesita `go run`; Starpack es como el binario final de `go build` — autocontenido, lista para copiar y ejecutar.

---

## 2. Conseguir tclkit

No siempre está en los repos oficiales de paquetes de tu SO — normalmente se descarga precompilado:

```bash
# Desde https://www.equi4.com/pub/tk/ o https://core.tcl-lang.org/tclkit/
# Ejemplos de nombres de archivo típicos:
# tclkit-8.6.13-linux-x86_64
# tclkit-8.6.13-win32.exe
# tclkit-8.6.13-macosx

chmod +x tclkit-8.6.13-linux-x86_64
./tclkit-8.6.13-linux-x86_64 miscript.tcl    ;# ejecuta un script normal con este runtime
```
Dado tu entorno de conectividad intermitente, **descarga el tclkit una sola vez y guárdalo localmente** — lo necesitarás cada vez que generes un nuevo Starpack, y los binarios pesan varios MB.

---

## 3. Estructura de un Starkit

Un Starkit es, internamente, un filesystem virtual con esta estructura estándar:

```
miapp.vfs/
├── main.tcl              ← punto de entrada, se ejecuta automáticamente
├── lib/
│   └── app/
│       ├── pkgIndex.tcl
│       └── app.tcl
└── assets/
    └── icono.png
```

**main.tcl:**
```tcl
package require Tk
lappend auto_path [file join [file dirname [info script]] lib]
package require app

app::iniciar
```

**lib/app/pkgIndex.tcl:**
```tcl
package ifneeded app 1.0 [list source [file join $dir app.tcl]]
```

**lib/app/app.tcl:**
```tcl
namespace eval app {
    proc iniciar {} {
        wm title . "Mi Herramienta ERP"
        ttk::label .l -text "Hola desde el Starkit"
        pack .l -padx 20 -pady 20
    }
}
```

### Empaquetar la carpeta `.vfs` en un `.kit`
```bash
tclkit sdx.kit wrap miapp.kit -runtime tclkit
```
`sdx.kit` (Starkit Developer eXtension) es la herramienta estándar para crear/inspeccionar Starkits — también se descarga precompilada. `wrap` toma la carpeta `miapp.vfs/` y la empaqueta en `miapp.kit`.

---

## 4. Generar el Starpack final (el binario standalone)

```bash
tclkit sdx.kit wrap miapp -runtime tclkit-8.6.13-linux-x86_64
```
Esto fusiona tu `miapp.vfs/` con el runtime tclkit específico de la plataforma, produciendo `miapp` — un único ejecutable que **no necesita Tcl instalado en la máquina destino**. Para distribuir en Windows y Linux, repites el proceso con el tclkit correspondiente a cada plataforma (no hay compilación cruzada real; necesitas el runtime nativo de cada SO, similar a como necesitas `GOOS=windows go build` con el toolchain correcto, pero aquí el "toolchain" es directamente el binario tclkit de esa plataforma).

```bash
# Linux
tclkit-linux sdx.kit wrap miapp-linux -runtime tclkit-8.6.13-linux-x86_64

# Windows (requiere el tclkit .exe de Windows disponible)
tclkit-linux sdx.kit wrap miapp-win.exe -runtime tclkit-8.6.13-win32.exe
```
Nota: puedes generar el `.exe` de Windows **desde Linux**, siempre que tengas el tclkit runtime de Windows disponible localmente — `sdx` solo necesita el binario runtime como input, no necesita correr en esa plataforma. Esto es una ventaja real para tu flujo de trabajo con conectividad limitada: descargas ambos runtimes una vez, y generas ambos ejecutables sin necesitar una VM de Windows.

---

## 5. Inspeccionar y editar un Starkit ya empaquetado

```bash
tclkit sdx.kit unwrap miapp.kit    ;# extrae de vuelta a miapp.vfs/ para editar
# edita archivos dentro de miapp.vfs/...
tclkit sdx.kit wrap miapp.kit       ;# re-empaqueta
```
Útil para depurar un Starkit de terceros, o para hacer parches rápidos sin reconstruir todo desde cero.

---

## 6. Acceso a archivos dentro del VFS en runtime

Una vez empaquetado, tu código sigue corriendo "dentro" del archivo virtual — leer tus propios assets funciona normal con `file`/`open`, Tcl resuelve la ruta virtual transparentemente:

```tcl
set rutaIcono [file join [file dirname [info script]] assets icono.png]
image create photo icono -file $rutaIcono
```
La clave es usar siempre rutas relativas a `[info script]` o `[file dirname [info script]]`, nunca rutas absolutas del sistema de archivos real — así tu código funciona igual corriendo como script suelto (`tclsh main.tcl`) o empaquetado (`./miapp`).

### Escribir datos de usuario (fuera del VFS, que es de solo lectura en Starpack)
```tcl
# El VFS empaquetado es de solo lectura una vez compilado a Starpack.
# Para datos que el usuario genera (config, tu base SQLite), usa una ruta del sistema real:
set dirDatos [file join $::env(HOME) ".miapp"]
file mkdir $dirDatos
set rutaDB [file join $dirDatos "inventario.db"]
```
Este es un detalle importante y fácil de pasar por alto: **todo lo empaquetado dentro del `.vfs` es de solo lectura en el Starpack final**. Tu base de datos SQLite, archivos de configuración, logs — todo eso debe vivir en una ruta real del sistema de archivos del usuario (home directory, `%APPDATA%` en Windows, etc.), nunca dentro del propio ejecutable.

---

## 7. Alternativas modernas a Starkit/tclkit

El ecosistema Starkit es maduro pero su desarrollo activo se ha ralentizado con los años. Alternativas a considerar según tu prioridad:

### `basekit` / `tclkit` mantenidos por ActiveState
Versiones más recientes mantenidas comercialmente, con mejor soporte de Tcl 8.6/9.0 — vale la pena revisar si el tclkit "clásico" de equi4.com está desactualizado para tu versión de Tcl.

### Empaquetado manual con `tar`/`zip` autoextraíble
Para casos simples, un script wrapper que descomprime tu carpeta de código + un tclsh/wish embebido puede ser más simple que aprender todo el flujo de `sdx`:
```bash
#!/bin/sh
# self-extracting shell script que descomprime y ejecuta
ARCHIVE=$(awk '/^__ARCHIVE__/{print NR+1; exit}' "$0")
tail -n+$ARCHIVE "$0" | tar xz -C /tmp/miapp
/tmp/miapp/tclkit /tmp/miapp/main.tcl
exit 0
__ARCHIVE__
```
Más artesanal, pero cero dependencia de herramientas Starkit externas — coherente con tu filosofía de minimizar dependencias de build.

### Distribuir el `.kit` + pedir al usuario que instale un tclkit una vez
Si tu "usuario" eres tú mismo o tu equipo interno (herramientas de diagnóstico, no producto final para clientes), a veces no vale la pena generar Starpacks por plataforma — basta con tener un tclkit instalado una vez en cada máquina de desarrollo, y distribuir solo los `.kit` (mucho más livianos, sin el runtime duplicado en cada uno).

---

## 8. Comparación con tu stack real (Wails)

| Aspecto | Wails (Go) | Starpack (Tcl/Tk) |
|---|---|---|
| Tamaño típico del binario | ~10-15MB | ~3-8MB (tclkit es más liviano que un runtime + WebView) |
| Requiere WebView del sistema | Sí (WebView2 en Windows, WebKitGTK en Linux) | No, Tk es autocontenido |
| Compilación cruzada | Nativa con `GOOS`/`GOARCH` | Requiere el tclkit runtime de cada plataforma disponible localmente |
| Madurez del ecosistema | Alta, activamente mantenido | Estable pero con desarrollo más lento |
| UI moderna/CSS | Sí, HTML/CSS completo | Limitada a lo que ttk permite (temas, no CSS real) |
| Adecuado para tu producto principal (ERP) | Sí | No — solo para herramientas satélite |

Esta tabla resume por qué, dado tu contexto, Starpack tiene sentido específicamente para **herramientas internas de soporte** (inspectores, utilidades de diagnóstico, scripts con GUI mínima) y no para tu producto principal — donde Wails ya te da más flexibilidad visual y un ecosistema más vivo, aunque a costa de un binario algo más pesado y la dependencia del WebView del sistema (que en Windows 7 / Android 4, tus hardware objetivo más viejos, puede ser un problema real que Starpack no tendría, ya que Tk no depende de ningún WebView).

---

## 9. Nota práctica sobre hardware viejo (Windows 7)

Dado que mencionas Windows 7 como hardware objetivo: esto es un punto a favor genuino de considerar Starpack para alguna herramienta específica. Wails depende de WebView2, que en Windows 7 **no está disponible de forma nativa** (WebView2 requiere Windows 10+; en Windows 7 necesitarías el runtime de Edge legacy o CEF como fallback, ambos con fricción adicional). Un Starpack de Tcl/Tk con un tclkit de Tcl 8.6 corre nativamente en Windows 7 sin ninguna dependencia de WebView — si alguna vez necesitas una herramienta mínima garantizada de funcionar en ese hardware específico, este es el escenario donde Tcl/Tk gana claramente sobre tu stack principal.

---

## 10. Resumen de referencia rápida

| Comando/concepto | Uso |
|---|---|
| `tclkit` | runtime standalone: Tcl/Tk completo en un binario |
| `sdx.kit wrap carpeta.kit -runtime tclkit` | empaqueta una carpeta `.vfs` en un Starkit |
| `sdx.kit wrap nombre -runtime tclkit-plataforma` | genera un Starpack (binario final standalone) |
| `sdx.kit unwrap archivo.kit` | extrae un Starkit ya empaquetado, para inspección/edición |
| `[info script]` | ruta del script actual, funciona igual empaquetado o no |
| VFS de solo lectura | assets/código empaquetado no se puede escribir en runtime |
| Datos de usuario | siempre en una ruta real del sistema (`$::env(HOME)`, etc.), nunca dentro del `.vfs` |

---

## 11. Ruta práctica si decides usar esto

1. Descarga tclkit para Linux (tu entorno de desarrollo) y para Windows (tu hardware objetivo más antiguo) una sola vez, guárdalos localmente.
2. Descarga `sdx.kit` una sola vez.
3. Estructura tu herramienta en `miapp.vfs/` con `main.tcl` como entry point.
4. Genera el Starpack para cada plataforma objetivo con el tclkit correspondiente.
5. Distribuye el ejecutable final — cero instalación, cero dependencias, corre incluso en Windows 7 sin WebView.
