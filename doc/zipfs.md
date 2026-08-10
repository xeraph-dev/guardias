# zipfs: empaquetado nativo en Tcl 9 (reemplazo de Starkit/sdx)

Esto corrige y moderniza la guía anterior de Starkit/Starpack. `zipfs` es un sistema de archivos virtual **incorporado al núcleo de Tcl** (no un paquete externo, no necesitas `sdx.kit` ni un tclkit de terceros) que te permite montar un archivo ZIP como si fuera parte del filesystem, y —lo más importante— **concatenar ese ZIP directamente al final del ejecutable `tclsh`/`wish`** para producir un solo binario standalone. Es, en esencia, Starkit/Starpack pero nativo del lenguaje, sin herramientas externas.

La funcionalidad entró como TIP 430, disponible desde Tcl 8.6/8.7 como característica del core, y en Tcl 9.0 está completamente integrada y es la vía recomendada para empaquetado — el ecosistema Starkit/tclkit de terceros que describí antes queda efectivamente obsoleto para proyectos nuevos en Tcl 9.

---

## 1. El concepto central: un ZIP pegado al final de un ejecutable

Un archivo ejecutable (ELF en Linux, PE en Windows) no le importa que le agregues bytes extra al final — el loader del SO solo lee la parte que necesita desde el inicio. Un archivo ZIP, por su parte, guarda su índice al **final** del archivo. Esto significa que puedes literalmente hacer:

```bash
cat tclsh miapp.zip > miapp
chmod +x miapp
```

Y el resultado es un único archivo que sigue siendo un ejecutable válido (el SO lo ejecuta normal) **y** un ZIP válido (herramientas ZIP normales aún pueden leerlo desde el final). Tcl detecta este ZIP concatenado al arrancar, lo monta automáticamente como un filesystem virtual, y si encuentra un `main.tcl` en la raíz, lo ejecuta. Todo esto sin ninguna herramienta externa — es simplemente cómo Tcl 9 arranca.

---

## 2. `zipfs mount`: montar un ZIP en runtime

```tcl
zipfs mount miarchivo.zip /app
# ahora puedes leer archivos dentro del zip como si fueran del filesystem real:
set f [open /app/main.tcl r]
puts [read $f]
close $f

zipfs unmount /app
```
El punto de montaje raíz especial es `//zipfs:/` (o `zipfs:/` en Windows) — cuando Tcl monta automáticamente el ZIP pegado a su propio ejecutable, lo hace en `//zipfs:/app`.

---

## 3. Crear el ZIP de tu aplicación: `zipfs mkzip`

```tcl
zipfs mkzip miapp.zip miapp.vfs
```
Toma una carpeta (`miapp.vfs/`, misma estructura que en Starkit: `main.tcl` en la raíz, tu código y assets debajo) y la comprime en un `.zip` normal — inspeccionable con cualquier herramienta zip estándar (`unzip -l miapp.zip`).

Estructura recomendada (idéntica a la de Starkit):
```
miapp.vfs/
├── main.tcl
├── lib/
│   └── app/
│       ├── pkgIndex.tcl
│       └── app.tcl
└── assets/
    └── icono.png
```

---

## 4. Crear el ejecutable final: `zipfs mkimg`

Este es el comando que reemplaza directamente a `sdx.kit wrap ... -runtime tclkit`:

```tcl
zipfs mkimg miapp miapp.vfs
```
Genera `miapp`, un ejecutable standalone que arranca, monta el ZIP internamente, y corre tu `main.tcl` — todo en un solo paso, sin `sdx`, sin descargar un tclkit de terceros. Por defecto usa el propio `tclsh`/`wish` que está corriendo el comando como plantilla base del ejecutable resultante.

```tcl
# Firma completa
zipfs mkimg outfile indir ?strip? ?password? ?infile?
```
- `strip`: prefijo a remover de las rutas internas (normalmente el nombre de tu carpeta fuente).
- `password`: protege el contenido del ZIP con contraseña ofuscada (no es seguridad criptográfica fuerte, pero dificulta la inspección casual).
- `infile`: qué ejecutable usar como base — **crítico para compilación cruzada** (ver §6).

### Requisito importante: build estático
Para que el resultado sea un ejecutable verdaderamente standalone (sin depender de `.so`/`.dll` de Tcl instalados en la máquina destino), la plantilla `tclsh`/`wish` que uses como base debe ser una **build estática**. Un `tclsh` normal instalado vía apt/homebrew típicamente está linkeado dinámicamente contra `libtcl.so` — sirve para desarrollo, pero el ejecutable resultante de `zipfs mkimg` seguirá necesitando esa librería presente en la máquina destino. Para distribución real necesitas conseguir o compilar tú mismo una build estática de `tclsh`/`wish` (el wiki de Tcl referencia binarios estáticos precompilados en magicsplat.com y el sitio de BAWT apps).

---

## 5. `zipfs mkzip` vs `zipfs mkimg`: cuándo usar cada uno

| Comando | Resultado | Cuándo usarlo |
|---|---|---|
| `zipfs mkzip` | Un `.zip` normal | Cuando distribuyes a alguien que ya tiene un `tclsh`/`wish` instalado — ellos hacen `tclsh miapp.zip` |
| `zipfs mkimg` | Un ejecutable standalone | Cuando quieres el equivalente exacto a un binario de Go: cero dependencias, un archivo, doble-click o `./miapp` |

Para tu caso de uso (herramientas internas que corren en máquinas sin Tcl preinstalado, incluido el escenario de Windows 7 mencionado en la guía anterior), casi siempre quieres `mkimg`.

---

## 6. Compilación cruzada real (mejor que con Starkit)

```tcl
# Generar el ejecutable de Windows DESDE Linux,
# usando un tclsh/wish estático de Windows como plantilla
zipfs mkimg miapp-win.exe miapp.vfs "" "" tclsh-static-windows.exe
```
El cuarto argumento (`infile`) te deja especificar explícitamente qué ejecutable usar como base, sin importar en qué plataforma estás corriendo el comando `zipfs mkimg` — igual que con `sdx`, necesitas tener disponible localmente el binario estático de la plataforma destino, pero el flujo es más directo (un comando nativo de Tcl, no una herramienta externa con su propia sintaxis).

---

## 7. Solo lectura, igual que Starkit — mismo cuidado con datos de usuario

```tcl
# El ZIP montado (ya sea standalone o vía zipfs mount) es de solo lectura.
# Tus datos reales (SQLite, config, logs) siguen viviendo fuera, en el filesystem real:
set dirDatos [file join $::env(HOME) ".miapp"]
file mkdir $dirDatos
sqlite3 db [file join $dirDatos "inventario.db"]
```
Esta restricción no cambió respecto a Starkit — sigue siendo válida la misma regla: código/assets empaquetados = solo lectura; datos generados por el usuario = filesystem real.

---

## 8. Detectar si estás corriendo empaquetado o no (útil para desarrollo)

```tcl
set rutaExe [zipfs mount //zipfs:/app]
if {$rutaExe eq ""} {
    puts "corriendo sin empaquetar (script suelto)"
} else {
    puts "corriendo empaquetado, zip montado desde: $rutaExe"
}
```
Patrón útil durante desarrollo: puedes tener un solo `main.tcl` que se comporta igual corriendo suelto con `tclsh main.tcl` o ya empaquetado como Starpack-vía-zipfs — sin ramas de código especiales, siempre que uses rutas relativas a `[info script]`/`[file dirname [info script]]` como ya se recomendaba con Starkit.

---

## 9. Contraseña / ofuscación básica del contenido

```tcl
zipfs mkimg miapp miapp.vfs "" "miClaveSecreta"
```
Si te importa que tu código fuente no sea trivialmente extraíble con `unzip miapp` (para herramientas internas con lógica que preferirías no exponer), la contraseña dificulta la inspección casual. No es cifrado fuerte de nivel criptográfico — no lo trates como protección real contra alguien decidido a extraer el contenido, solo como una fricción básica.

---

## 10. Ejemplo completo de flujo, de script suelto a ejecutable final

```bash
# 1. Estructura del proyecto
mkdir -p miapp.vfs/lib/app
cat > miapp.vfs/main.tcl << 'EOF'
package require Tk
lappend auto_path [file join [zipfs mount //zipfs:/app] lib]
package require app
app::iniciar
EOF

cat > miapp.vfs/lib/app/pkgIndex.tcl << 'EOF'
package ifneeded app 1.0 [list source [file join $dir app.tcl]]
EOF

cat > miapp.vfs/lib/app/app.tcl << 'EOF'
namespace eval app {
    proc iniciar {} {
        wm title . "Mi Herramienta"
        ttk::label .l -text "Hola desde zipfs"
        pack .l -padx 20 -pady 20
    }
}
EOF

# 2. Generar el ejecutable (desde una wish estática)
tclsh -c "zipfs mkimg miapp miapp.vfs" 2>/dev/null || \
echo 'zipfs mkimg miapp miapp.vfs' | tclsh

# 3. Distribuir
chmod +x miapp
./miapp
```

---

## 11. Qué cambia respecto a lo que te conté de Starkit/sdx

| Antes (Starkit clásico) | Ahora (zipfs, Tcl 9) |
|---|---|
| Requiere descargar `tclkit` de terceros (equi4.com) | `zipfs` es parte del núcleo de Tcl, no necesitas nada externo |
| Requiere `sdx.kit` como herramienta de empaquetado | `zipfs mkzip`/`mkimg` son comandos Tcl nativos |
| Formato `.kit` propietario del ecosistema Starkit | ZIP estándar, inspeccionable con cualquier herramienta zip |
| Ecosistema con desarrollo más lento/comunitario | Parte oficial y mantenida del lenguaje mismo |
| Sigue siendo válido para Tcl 8.6 si no puedes migrar a 9 | Requiere Tcl 8.6+ (mejor soportado en 8.7/9.0) |

**Recomendación práctica:** si vas a empezar algo nuevo hoy, usa `zipfs` directamente y omite todo el flujo de `sdx`/tclkit de terceros que describí en la guía anterior — sigue siendo información válida si alguna vez necesitas mantener algo legado construido con Starkit clásico, pero para proyectos nuevos `zipfs` es estrictamente más simple y no depende de infraestructura de terceros, lo cual encaja aún mejor con tu filosofía de minimizar dependencias externas.

---

## 12. Resumen de referencia rápida

| Comando | Uso |
|---|---|
| `zipfs mount archivo.zip punto` | monta un zip como filesystem virtual |
| `zipfs unmount punto` | desmonta |
| `zipfs mkzip out.zip carpeta` | comprime una carpeta a un `.zip` normal |
| `zipfs mkimg out carpeta ?strip? ?password? ?infile?` | genera un ejecutable standalone |
| `//zipfs:/` | punto de montaje raíz del sistema zipfs (Windows: `zipfs:/`) |
| Build estática de tclsh/wish | requisito para que el resultado sea verdaderamente standalone |
| `infile` en `mkimg` | permite compilación cruzada usando un binario de otra plataforma como base |
