# HTTP y JSON en Tcl: hablar con tu backend (o cualquier API)

Este es el puente más directo entre una herramienta Tcl/Tk y tu backend real en Go: hacer requests HTTP y parsear/generar JSON. Tcl trae `http` en su librería estándar; JSON requiere un paquete de tcllib (`json`), casi siempre disponible junto a cualquier instalación completa de Tcl.

```tcl
package require http
package require json
package require json::write   ;# para generar JSON, no solo parsearlo
```

---

## 1. GET básico

```tcl
package require http

set token [http::geturl "http://localhost:8080/api/productos"]
puts [http::data $token]           ;# cuerpo de la respuesta, como string
puts [http::status $token]         ;# "ok", "error", "timeout", etc.
puts [http::code $token]           ;# "HTTP/1.1 200 OK"
puts [http::ncode $token]          ;# 200 (solo el código numérico)
http::cleanup $token                ;# libera memoria asociada al request — SIEMPRE llamarlo
```

`http::geturl` es **sincrónico/bloqueante por defecto** — congela tu event loop mientras espera respuesta (mismo problema que viste en la guía de event loop con operaciones largas). Para GUIs, necesitas la versión asíncrona (§5).

`http::cleanup` es fácil de olvidar y causa fugas de memoria acumulativas en apps de larga duración — trátalo como el `defer resp.Body.Close()` de Go: siempre debe ejecutarse, incluso si el request falla.

---

## 2. Verificar errores correctamente

```tcl
proc hacerGet {url} {
    set token [http::geturl $url -timeout 5000]
    set resultado {}
    if {[http::status $token] eq "ok" && [http::ncode $token] == 200} {
        set resultado [http::data $token]
    } else {
        puts stderr "Error HTTP: [http::status $token] / código [http::ncode $token]"
    }
    http::cleanup $token
    return $resultado
}
```
`-timeout 5000` (milisegundos) es importante en tu contexto de conectividad intermitente — sin timeout, un `geturl` puede quedar colgado indefinidamente si el servidor no responde ni cierra la conexión. `http::status` puede ser `ok` (el request se completó, aunque el código HTTP sea 404/500), `error` (fallo de red/DNS), o `timeout`.

---

## 3. POST con JSON

```tcl
package require http
package require json::write

set cuerpo [json::write object \
    nombre [json::write string "Arroz"] \
    precio 2.50 \
    stock 100]

set token [http::geturl "http://localhost:8080/api/productos" \
    -method POST \
    -type "application/json" \
    -query $cuerpo \
    -timeout 5000]

puts [http::ncode $token]     ;# 201, por ejemplo
puts [http::data $token]      ;# respuesta del servidor
http::cleanup $token
```
`-type` fija el `Content-Type`; `-query` es el cuerpo del request (a pesar del nombre histórico "query", funciona para el body de POST/PUT igual). `json::write object` construye JSON válido con el citado correcto — evita construirlo a mano concatenando strings (mismo motivo que evitas `eval` con concatenación: fácil de romper con caracteres especiales, comillas o acentos en los valores).

---

## 4. `json::write`: generar JSON correctamente

```tcl
package require json::write

# Objeto simple
json::write object nombre [json::write string "Arroz"] precio 2.50

# Valores: string necesita json::write string, números van directo, booleanos como palabras literales
json::write object \
    nombre  [json::write string "Frijoles"] \
    precio  1.80 \
    activo  true \
    stock   50

# Arrays
set items {}
foreach p {Arroz Frijoles Maíz} {
    lappend items [json::write string $p]
}
json::write array {*}$items

# Anidado: array de objetos (el caso más común en APIs reales)
proc productoAJson {nombre precio stock} {
    return [json::write object \
        nombre [json::write string $nombre] \
        precio $precio \
        stock $stock]
}

set productos {}
lappend productos [productoAJson "Arroz" 2.50 100]
lappend productos [productoAJson "Frijoles" 1.80 50]
set jsonFinal [json::write array {*}$productos]
puts $jsonFinal
```
Regla clave: `json::write string` **escapa correctamente** comillas, backslashes, y caracteres especiales dentro del valor — nunca construyas el string JSON a mano con `"nombre": "$valor"` directo, porque un producto con comillas o un backslash en el nombre rompería el JSON generado silenciosamente.

`json::write indented 1` (o `json::write::indented 1` según versión) activa formato legible con indentación, útil para debugging — por defecto genera JSON compacto en una línea.

---

## 5. Requests asíncronos (no bloquear la GUI)

Igual que con cualquier I/O lento (guía de event loop, §4-5), nunca hagas un `http::geturl` sincrónico dentro de un `-command` de botón en una app Tk real:

```tcl
proc cargarProductosAsync {} {
    .btn configure -state disabled -text "Cargando..."
    http::geturl "http://localhost:8080/api/productos" \
        -command procesarRespuestaProductos \
        -timeout 5000
}

proc procesarRespuestaProductos {token} {
    .btn configure -state normal -text "Recargar"
    if {[http::status $token] eq "ok" && [http::ncode $token] == 200} {
        set datos [http::data $token]
        set productos [json::json2dict $datos]
        actualizarListaProductos $productos
    } else {
        tk_messageBox -message "Error al cargar productos" -icon error
    }
    http::cleanup $token
}
```
`-command callback` convierte el request en asíncrono: `http::geturl` retorna inmediatamente (el event loop sigue libre), y tu callback se dispara cuando la respuesta llega — el token se pasa como único argumento. Este es el patrón correcto para **cualquier** llamada de red desde una GUI Tk, sin excepciones.

### Versión con coroutines (más limpio, conectando con la guía de event loop)
```tcl
proc httpGetAsync {url} {
    set token [http::geturl $url -command [info coroutine] -timeout 5000]
    yield
    return $token
}

proc cargarProductosCoro {} {
    .btn configure -state disabled -text "Cargando..."
    set token [httpGetAsync "http://localhost:8080/api/productos"]
    if {[http::status $token] eq "ok"} {
        set productos [json::json2dict [http::data $token]]
        actualizarListaProductos $productos
    }
    http::cleanup $token
    .btn configure -state normal -text "Recargar"
}

button .btn -text "Cargar" -command {coroutine cargaCoro cargarProductosCoro}
```
Esto te deja escribir el flujo async como código secuencial normal (mismo patrón `await` que viste en la guía de event loop), en vez de encadenar callbacks — mucho más legible cuando tienes varias llamadas HTTP en secuencia (ej. login → obtener token → cargar datos).

---

## 6. Parsear JSON: `json::json2dict`

```tcl
package require json

set respuestaJson {{"nombre": "Arroz", "precio": 2.50, "stock": 100, "activo": true}}
set datos [json::json2dict $respuestaJson]

puts [dict get $datos nombre]    ;# Arroz
puts [dict get $datos precio]    ;# 2.50
```

### Arrays JSON se convierten en listas de dicts
```tcl
set respuestaJson {[
    {"nombre": "Arroz", "precio": 2.50},
    {"nombre": "Frijoles", "precio": 1.80}
]}
set productos [json::json2dict $respuestaJson]

foreach producto $productos {
    puts "[dict get $producto nombre]: \$[dict get $producto precio]"
}
```

### JSON anidado
```tcl
set respuestaJson {{
    "cliente": {"nombre": "Adrian", "id": 1},
    "items": [
        {"producto": "Arroz", "cantidad": 3},
        {"producto": "Frijoles", "cantidad": 2}
    ]
}}
set datos [json::json2dict $respuestaJson]

puts [dict get $datos cliente nombre]       ;# Adrian, acceso anidado directo con dict get
foreach item [dict get $datos items] {
    puts "[dict get $item producto] x[dict get $item cantidad]"
}
```
`dict get` soporta múltiples claves para navegar directamente estructuras anidadas (`dict get $datos cliente nombre`), sin necesitar acceso encadenado especial — es una de las razones por las que `json2dict` (en vez de convertir a arrays anidados) es la representación más cómoda de trabajar en Tcl moderno.

---

## 7. Manejo robusto de errores de parseo

```tcl
proc parsearJsonSeguro {texto} {
    if {[catch {json::json2dict $texto} resultado]} {
        puts stderr "JSON inválido: $resultado"
        return {}
    }
    return $resultado
}
```
Un servidor que devuelve HTML de error (ej. un 502 de un proxy) en vez de JSON hará que `json2dict` lance un error de parseo — siempre envuelve el parseo en `catch`, especialmente si consumes APIs de terceros o tu propio backend en un estado inesperado (caído, error 500 con cuerpo no-JSON).

---

## 8. HTTPS / TLS

```tcl
package require http
package require tls

::tls::init -tls1.3 1
http::register https 443 ::tls::socket

set token [http::geturl "https://api.example.com/datos"]
```
`package require tls` (basado en OpenSSL) es necesario para HTTPS — `http` por sí solo solo maneja HTTP plano. `http::register https 443 ::tls::socket` le dice al paquete `http` que use el socket TLS para el scheme `https`. En tu contexto de red local (tu app hablando con tu propio backend en `localhost`), probablemente no necesites esto — pero sí si tu herramienta consulta cualquier API externa por HTTPS.

---

## 9. Headers custom (auth, content negotiation)

```tcl
set token [http::geturl "http://localhost:8080/api/productos" \
    -headers [list Authorization "Bearer $miToken" Accept "application/json"] \
    -timeout 5000]
```
`-headers` toma una lista plana clave-valor (como cualquier estructura par-par de Tcl) — útil para autenticación con tu backend Go si expone una API protegida por token.

---

## 10. Patrón completo: cliente de tu API Go, encapsulado

Siguiendo el mismo espíritu de capa DAO de la guía de SQLite, aquí un cliente HTTP encapsulado y reutilizable:

```tcl
package require http
package require json
package require json::write

namespace eval ::App::API {
    variable baseUrl "http://localhost:8080/api"
    variable token ""

    proc configurar {url {authToken ""}} {
        variable baseUrl
        variable token
        set baseUrl $url
        set token $authToken
    }

    proc Request {metodo ruta {cuerpo ""}} {
        variable baseUrl
        variable token
        set url "$baseUrl$ruta"
        set headers {Accept application/json}
        if {$token ne ""} {
            lappend headers Authorization "Bearer $token"
        }

        set args [list -method $metodo -headers $headers -timeout 5000]
        if {$cuerpo ne ""} {
            lappend args -type "application/json" -query $cuerpo
        }

        set t [http::geturl $url {*}$args]
        set codigo [http::ncode $t]
        set status [http::status $t]

        if {$status ne "ok"} {
            http::cleanup $t
            error "fallo de red: $status"
        }

        set data [http::data $t]
        http::cleanup $t

        if {$codigo >= 200 && $codigo < 300} {
            if {$data eq ""} { return {} }
            return [json::json2dict $data]
        } else {
            error "error HTTP $codigo: $data"
        }
    }

    proc obtenerProductos {} {
        return [Request GET "/productos"]
    }

    proc crearProducto {nombre precio stock} {
        set cuerpo [json::write object \
            nombre [json::write string $nombre] \
            precio $precio \
            stock  $stock]
        return [Request POST "/productos" $cuerpo]
    }

    proc venderProducto {id cantidad} {
        set cuerpo [json::write object cantidad $cantidad]
        return [Request POST "/productos/$id/vender" $cuerpo]
    }
}

::App::API::configurar "http://localhost:8080/api"

if {[catch {::App::API::obtenerProductos} productos]} {
    puts "Error: $productos"
} else {
    foreach p $productos {
        puts "[dict get $p nombre]: [dict get $p stock] unidades"
    }
}
```
Este módulo (`::App::API::*`) juega el mismo rol que `::App::DB::*` en la guía de SQLite: aísla completamente los detalles de HTTP/JSON del resto de tu app, y se conecta naturalmente al `dispatch` del store de la guía de gestión de estado — la única diferencia con el ejemplo de SQLite es que aquí la fuente de verdad vive detrás de tu API Go en vez de en un archivo local.

**Nota importante:** para uso real en una GUI, la versión de `Request` de arriba es sincrónica (bloquea mientras espera). Conviértela a asíncrona con `-command`/coroutines (§5) antes de usarla dentro de callbacks de widgets — el ejemplo se mantiene sincrónico aquí solo por claridad.

---

## 11. Resumen de referencia rápida

| Tarea | Comando |
|---|---|
| GET simple | `http::geturl $url` |
| POST con body | `http::geturl $url -method POST -type "application/json" -query $cuerpo` |
| Timeout | `-timeout ms` (siempre inclúyelo) |
| Async (no bloquea GUI) | `-command callback`, o coroutine + `yield` |
| Verificar éxito | `http::status $token eq "ok"` Y `http::ncode $token` en rango 200 |
| Cuerpo de respuesta | `http::data $token` |
| Liberar memoria | `http::cleanup $token` (siempre, incluso en error) |
| Generar JSON | `json::write object/array/string` |
| Parsear JSON | `json::json2dict $texto` (envuelto en `catch`) |
| HTTPS | `package require tls` + `http::register https 443 ::tls::socket` |
| Headers custom | `-headers [list Clave valor ...]` |

---

## 12. Dónde esto te sirve directamente

Si construyes cualquier herramienta Tcl/Tk satélite de tu ERP (panel de diagnóstico, cliente de administración liviano, utilidad de importación masiva), este es el mecanismo exacto para que hable con tu backend Go real sin duplicar lógica de negocio — la app Tcl se vuelve un cliente delgado sobre la misma API que ya expone tu backend a tu frontend React, en vez de reimplementar reglas de negocio o tocar SQLite directamente y arriesgar inconsistencias con lo que tu servidor Go espera.
