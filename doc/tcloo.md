# TclOO: orientación a objetos nativa en Tcl

TclOO es el sistema de clases incorporado al núcleo de Tcl desde la versión 8.6 (Snit, que ya conoces, está construido *sobre* TclOO internamente). Lo usas cuando necesitas objetos con identidad y comportamiento propio, pero **sin** interfaz gráfica — para eso está Snit. Todo el código de esta guía fue verificado en un `tclsh` real (TclOO no depende de Tk en absoluto).

---

## 1. Lo básico: clase, constructor, métodos

```tcl
oo::class create Persona {
    variable Nombre

    constructor {nombre} {
        set Nombre $nombre
    }

    method saludar {} {
        return "Hola, soy $Nombre"
    }
}

set p [Persona new "Adrian"]
puts [$p saludar]    ;# Hola, soy Adrian
```

- `oo::class create Nombre { ... }` define la clase.
- `variable` declara variables de instancia (privadas, cada instancia tiene su propia copia — igual que en Snit).
- `constructor {args} {...}` corre al crear una instancia.
- `method nombre {args} {cuerpo}` define un método público.
- **`new`** crea una instancia con nombre autogenerado (`::oo::Obj12`); **`create nombreFijo`** te deja elegir el nombre tú mismo:

```tcl
Persona create juan "Juan"
puts [juan saludar]
```

---

## 2. La regla de privacidad que probablemente no sabías: mayúscula = privado real

Esto es lo más importante de esta guía, y lo verifiqué directamente porque no es intuitivo: **un método cuyo nombre empieza con mayúscula no es invocable desde fuera del objeto**, aunque lo hayas definido con `method` normal, sin ningún `unexport` explícito.

```tcl
oo::class create Worker {
    variable Peso

    constructor {peso} {
        my Validar $peso     ;# se llama con "my" desde adentro, funciona
        set Peso $peso
    }

    method Validar {peso} {   ;# Mayúscula -> privado automático
        if {$peso <= 0} { error "peso inválido" }
    }

    method peso {} { return $Peso }
}

set w [Worker new 5]
puts [$w peso]          ;# 5, funciona normal (minúscula = público)
$w Validar -1            ;# ERROR: unknown method "Validar"
```
Verificado exactamente así: `$w Validar -1` da `unknown method "Validar": must be destroy or peso` — Tcl ni siquiera lo lista como opción válida. Puedes llamarlo desde **dentro** de cualquier método del mismo objeto con `my Validar ...`, pero nunca desde afuera con `$objeto Validar ...`.

Esto es una diferencia real con Snit, donde "Mayúscula = privado" es **solo una convención humana** — en Snit, técnicamente sí puedes llamar un método con mayúscula desde afuera si quieres, Tcl no te lo impide. En TclOO, **sí te lo impide de verdad**. Vale la pena que sepas esta diferencia si vienes de haber leído la guía de Snit.

### `unexport`: hacer privado un método que empieza en minúscula
Si quieres que un método público-por-defecto (minúscula) sea privado, usa `unexport` explícitamente:

```tcl
oo::class create ConSecreto {
    method publico {} { return [my privado] }
    method privado {} { return "secreto" }
}
oo::define ConSecreto {
    unexport privado
}

set c [ConSecreto new]
puts [$c publico]    ;# "secreto" -- funciona, lo llama internamente con "my"
$c privado             ;# ERROR: unknown method "privado"
```

---

## 3. Herencia: `superclass` y `next`

```tcl
oo::class create Persona {
    variable Nombre
    constructor {nombre} { set Nombre $nombre }
    method saludar {} { return "Hola, soy $Nombre" }
}

oo::class create Trabajador {
    superclass Persona
    variable Peso
    constructor {nombre peso} {
        next $nombre          ;# llama al constructor de Persona
        set Peso $peso
    }
    method saludar {} {
        set base [next]        ;# llama al saludar() de Persona, y lo extiende
        return "$base (peso: $Peso)"
    }
}

set t [Trabajador new "Juan" 2]
puts [$t saludar]    ;# Hola, soy Juan (peso: 2)
```
Verificado tal cual. `next` es el equivalente a `super()`/`super.metodo()` de otros lenguajes — llama a la implementación de la superclase del método (o constructor) que se está ejecutando actualmente. Puedes usarlo tanto para extender (llamar a `next` y luego agregar algo) como para reemplazar completamente (no llamar a `next` en absoluto).

---

## 4. Mixins: composición sin herencia

Un mixin agrega comportamiento a una clase **sin** que sea una relación "es-un" real — útil cuando varias clases no relacionadas necesitan la misma capacidad (logging, comparabilidad, serialización).

```tcl
oo::class create Logueable {
    method log {msg} {
        puts "LOG [self]: $msg"
    }
}

oo::class create Trabajador {
    superclass Persona
    mixin Logueable
}

set t [Trabajador new "Ana"]
$t log "creado"    ;# LOG ::oo::Obj16: creado
```
Verificado: `Trabajador` obtiene el método `log` de `Logueable` sin que `Logueable` sea su superclase — es composición horizontal, no vertical. Si mañana quieres que `CalendarDay` (o cualquier otra clase, con o sin GUI) también sepa loguearse igual, mezclas el mismo `Logueable` sin tocar su jerarquía de herencia.

---

## 5. `forward`: delegar métodos a otro objeto/comando

Ya viste el equivalente en Snit (`delegate method`). En TclOO se llama `forward`:

```tcl
;# forward a un comando GLOBAL fijo, declarado directo en la clase
oo::class create Logger {
    forward log puts
}
set l [Logger new]
$l log "esto se reenvía directo al comando puts"
```

### Cuando el destino depende de una variable de instancia
`forward` declarado directamente en `oo::class create` es **fijo, compartido por toda la clase** — no puede referenciar una variable de instancia (falla en tiempo de definición, lo verifiqué). Si el objeto al que delegar se crea dinámicamente por instancia (como un componente en Snit), usa `oo::objdefine [self] forward ...` **dentro del constructor**:

```tcl
oo::class create Motor {
    method encender {} { return "motor encendido" }
    method apagar {} { return "motor apagado" }
}

oo::class create Auto {
    variable MotorObj
    constructor {} {
        set MotorObj [Motor new]
        oo::objdefine [self] forward arrancar $MotorObj encender
        oo::objdefine [self] forward detener $MotorObj apagar
    }
}

set a [Auto new]
puts [$a arrancar]    ;# motor encendido
```
Verificado exactamente así — el primer intento (declarando `forward` directo en la clase con `$MotorObj`) falló con `can't read "MotorObj": no such variable`, porque en ese punto la variable de instancia todavía no existe (se evalúa la clase una sola vez, no por instancia). `oo::objdefine [self] forward ...` dentro del constructor sí funciona porque se ejecuta **por instancia**, ya con `MotorObj` resuelto.

---

## 6. Métodos de clase ("estáticos"): `oo::objdefine`

Ya lo usamos en el ejemplo de `Worker`/`validarPeso` de esta conversación. Un método normal (`method`) pertenece a las **instancias**; para un método que pertenece a la **clase misma** (invocable sin crear ningún objeto), usas `oo::objdefine` sobre la clase — porque la clase misma es, técnicamente, un objeto de la metaclase `oo::class`:

```tcl
oo::class create Worker {
    variable Peso
    constructor {peso} {
        [self class] validarPeso $peso
        set Peso $peso
    }
}
oo::objdefine Worker {
    method validarPeso {peso} {
        if {$peso <= 0} { error "peso inválido" }
    }
}

Worker validarPeso -3    ;# ERROR: sin crear ninguna instancia
```
`[self class]` dentro de un método de instancia te da el nombre de la clase (`::Worker`), para poder llamar de vuelta a su método de clase sin hardcodear el nombre — útil si la clase se usa como base de otras (subclases heredan el `validarPeso` correcto de su propia clase, no de `Worker` a la fuerza).

---

## 7. Introspección

```tcl
oo::class create Introspector {
    method info {} {
        return "soy instancia de [self class], mi comando es [self]"
    }
}
set i [Introspector new]
puts [$i info]    ;# soy instancia de ::Introspector, mi comando es ::oo::Objxx
```

```tcl
info class methods NombreClase          ;# métodos públicos propios (no heredados)
info class methods NombreClase -all      ;# incluyendo heredados
info class methods NombreClase -all -private   ;# incluyendo privados (mayúscula/unexport)
info class superclasses NombreClase      ;# de qué hereda
info object class $instancia              ;# de qué clase es esta instancia
info object methods $instancia -all        ;# métodos disponibles en esta instancia
```
Verificado: `info class methods Derivada -all` sobre una clase con una superclase `Base` sí incluye los métodos heredados (`a`, `b`, `c` — los de `Base` y los propios de `Derivada` juntos).

---

## 8. Destructor

```tcl
oo::class create Conexion {
    variable Socket
    constructor {host puerto} {
        set Socket [socket $host $puerto]
    }
    destructor {
        catch {close $Socket}
    }
}
```
Igual que en Snit: cualquier recurso que el objeto adquiera (sockets, archivos, traces sobre variables externas) debe liberarse en el `destructor`, o queda huérfano cuando el objeto se destruye.

---

## 9. `my` vs llamar directo: la diferencia

Dentro de cualquier método, `my` es la forma de invocar **otro método del mismo objeto**, incluyendo los privados:

```tcl
method publico {} {
    return [my privado]     ;# CORRECTO: via "my", funciona con privados también
}
```
No existe una forma de llamar un método privado propio "directo" sin `my` — `my` es obligatorio para invocación interna, sea el método público o privado.

---

## 10. Comparando TclOO con Snit: cuándo cada uno

| Necesitas... | Usa |
|---|---|
| Un objeto con comportamiento/estado, **sin** presencia visual en pantalla | TclOO (`Worker`, `Motor`, cualquier objeto de dominio) |
| Un widget que se renderiza en la ventana | `snit::widget` (TclOO no puede producir esto por sí solo) |
| Privacidad real de un método (no solo convención) | TclOO — mayúscula ya es privado automático, o `unexport` |
| Delegar a un widget nativo con opciones (`-font`, `-text`) | `delegate option` de Snit (más integrado con Tk que `forward`) |
| Delegar a un objeto interno arbitrario, sin relación con Tk | `forward` de TclOO |
| Composición de comportamiento no jerárquica | `mixin` (existe en TclOO; Snit no tiene un equivalente directo) |

Snit **está construido sobre TclOO** — cuando escribes `snit::widget`, por debajo hay clases TclOO haciendo el trabajo. Por eso muchos conceptos se sienten familiares entre ambos (`method`, `variable`, `constructor`, `destructor`) — la diferencia real es que Snit agrega toda la maquinaria específica de Tk (`option`, `component`, `install`, `hulltype`) que TclOO no tiene ni necesita para objetos sin GUI.

---

## 11. Resumen de referencia rápida

| Construcción | Uso |
|---|---|
| `oo::class create Nombre {...}` | define una clase |
| `Nombre new` / `Nombre create nombreFijo` | crea una instancia (nombre autogenerado / nombre elegido) |
| `constructor {args} {...}` / `destructor {...}` | ciclo de vida |
| `variable v1 v2 ...` | variables de instancia privadas |
| `method nombre {args} {...}` | método público (si empieza en minúscula) o privado automático (si empieza en mayúscula) |
| `my metodo ...` | invocar otro método del mismo objeto, público o privado |
| `superclass Otra` | herencia |
| `next ?args?` | llamar a la implementación de la superclase |
| `mixin Otra` | agregar comportamiento sin relación de herencia |
| `forward alias comando ?args?` | delegar un método a otro comando/objeto (fijo, a nivel de clase) |
| `oo::objdefine [self] forward ...` | delegar dinámicamente, por instancia (dentro del constructor) |
| `oo::objdefine Clase { method ... }` | método de clase ("estático"), sin necesitar instancia |
| `unexport metodo` | hacer privado un método que por defecto sería público |
| `[self]` / `[self class]` | el objeto actual / su clase, desde dentro de un método |
| `info class methods/superclasses` | introspección de la clase |
| `info object class/methods` | introspección de una instancia |

---

## 12. Dónde esto te sirve directamente

Para tu app de guardias: `Worker` ya es TclOO (lo construimos juntos), y ahora sabes que su `Validar`/`validarPeso` ya estaban correctamente protegidos por la regla de mayúscula, sin que tuvieras que hacer nada extra. Si en algún momento necesitas una jerarquía real (ej. `TrabajadorTemporal` que hereda de `Worker` pero valida reglas adicionales de fecha de vencimiento del contrato), `superclass`/`next` te dan exactamente ese mecanismo. Y si `Worker` y una futura clase `Vacacion` comparten comportamiento no jerárquico (ej. ambos "son cosas que ocupan un rango de fechas"), `mixin` es la herramienta correcta antes que forzar una herencia artificial entre ellos.
