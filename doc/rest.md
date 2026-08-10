# El paquete `rest` (tcllib): clientes REST sin boilerplate

`rest` es una capa sobre `http` + `json` (los que ya viste en la guía anterior) que te ahorra escribir a mano el manejo de tokens, headers, y parseo de respuestas. Tiene **dos modos de uso**: llamadas sueltas (`simple`) para casos puntuales, y **definición de interfaces completas** (`create_interface`) que genera comandos con nombre a partir de una tabla de definiciones — este segundo modo es el que más te conviene para encapsular tu API Go como hiciste con `::App::API::*` en la guía anterior, pero con menos código repetido.

```tcl
package require rest
```

---

## 1. Uso simple: `rest::get`, `rest::post`, etc.

```tcl
package require rest

set respuesta [rest::get "http://localhost:8080/api/productos" {}]
puts $respuesta
```
- Primer argumento: la URL.
- Segundo argumento: la **query** — una lista de pares clave/valor que se codifican como querystring (`?clave=valor&...`) para GET, o como los datos a enviar según el método.
- El resultado es directamente el cuerpo de la respuesta como texto — internamente `rest` ya llamó a `http::geturl` y a `http::cleanup` por ti.

### Con parámetros de query
```tcl
set respuesta [rest::get "http://localhost:8080/api/productos" {categoria alimentos activo 1}]
;# equivale a GET /api/productos?categoria=alimentos&activo=1
```

### POST con body
```tcl
set respuesta [rest::post "http://localhost:8080/api/productos" \
    {nombre Arroz precio 2.50 stock 100}]
```
Aquí la "query" (segundo argumento) se convierte en el cuerpo del POST, codificado como formulario por defecto — si necesitas enviar JSON real, usa el `config` (tercer argumento, ver §2).

### Comandos disponibles
```tcl
rest::simple url query ?config? ?body?    ;# genérico, el método se especifica en config
rest::get    url query ?config? ?body?
rest::post   url query ?config? ?body?
rest::put    url query ?config? ?body?
rest::patch  url query ?config? ?body?
rest::delete url query ?config? ?body?
rest::head   url query ?config? ?body?
```

---

## 2. El diccionario `config`: la parte más útil

El tercer argumento (opcional) es un `dict` con opciones de configuración de la llamada:

```tcl
set respuesta [rest::post "http://localhost:8080/api/productos" \
    {nombre Arroz precio 2.50 stock 100} \
    {
        format json
        content-type application/json
        headers {Authorization "Bearer miToken123"}
        timeout 5000
    }]
```

Claves disponibles en `config`:

| Clave | Uso |
|---|---|
| `method` | método HTTP (si usas `rest::simple` en vez de `rest::post`/`get`/etc.) |
| `format` | formato de la respuesta: `auto` (default, detecta xml/json), `json`, `xml`, `raw`, `discard` |
| `content-type` | Content-Type del request |
| `headers` | dict/lista de headers adicionales |
| `cookie` | lista de cookies a enviar |
| `auth` | autenticación (ver §4) |
| `timeout` | milisegundos — **siempre inclúyelo**, mismo motivo que con `http` puro |
| `error-body` | si `true`, incluye el cuerpo de la respuesta incluso en error |

### `format json`: la razón principal para usar `rest` en vez de `http` a mano
```tcl
set productos [rest::get "http://localhost:8080/api/productos" {} {format json}]
;# $productos ya es un dict/lista Tcl, NO necesitas llamar json::json2dict tú mismo
foreach p $productos {
    puts "[dict get $p nombre]: [dict get $p precio]"
}
```
Con `format json`, `rest` parsea automáticamente la respuesta JSON a la estructura Tcl equivalente (dict/lista anidada) — te ahorras el paso manual de `json::json2dict` que viste en la guía anterior.

Ejemplo real de la documentación oficial (Twitter API, formato antiguo pero ilustrativo de la sintaxis):
```tcl
set url   http://twitter.com/statuses/update.json
set query [list status $texto]
set res [rest::simple $url $query {
    method post
    auth   {basic user password}
    format json
}]
```

---

## 3. Interfaces completas: `rest::create_interface`

Esto es lo más valioso del paquete para tu caso de uso. En vez de escribir procs sueltas a mano (como en `::App::API::*` de la guía anterior), **defines una tabla de llamadas** y `rest` genera los comandos automáticamente.

```tcl
package require rest

set miApi(listarProductos) {
    url http://localhost:8080/api/productos
    method GET
    format json
}

set miApi(crearProducto) {
    url http://localhost:8080/api/productos
    method POST
    req_args { nombre: precio: stock: }
    format json
}

set miApi(venderProducto) {
    url http://localhost:8080/api/productos/%id%/vender
    method POST
    req_args { id: cantidad: }
    format json
}

rest::create_interface miApi

# Uso: cada entrada de la tabla se convierte en un comando dentro del namespace miApi::
set productos [miApi::listarProductos]
foreach p $productos {
    puts "[dict get $p nombre]: [dict get $p stock]"
}

miApi::crearProducto -nombre "Frijoles" -precio 1.80 -stock 50
miApi::venderProducto -id 3 -cantidad 2
```

Puntos clave de este modo:

- **El nombre del array (`miApi`) se vuelve el namespace** de los comandos generados (`miApi::listarProductos`, etc.) — exactamente el mismo patrón organizativo que ya usaste con namespaces en la guía de estado.
- **`req_args`** define argumentos obligatorios, expuestos como opciones con guion (`-nombre`, `-precio`) al llamar el comando generado — Tcl arma la validación por ti, sin que tengas que escribir tu propio parser de argumentos.
- **`%id%` en la URL** se sustituye automáticamente con el valor pasado en `-id` — útil para rutas con parámetros dinámicos como `/productos/:id/vender`.
- **`opt_args`** (no mostrado arriba) define argumentos opcionales, con la misma sintaxis (`nombre:` requiere valor, `nombre` es flag, `nombre:valor` define un default).

### Ejemplo con `opt_args` y valor por defecto
```tcl
set miApi(listarProductos) {
    url http://localhost:8080/api/productos
    method GET
    opt_args { categoria activo:1 }
    format json
}
rest::create_interface miApi

miApi::listarProductos                          ;# sin filtros
miApi::listarProductos -categoria alimentos      ;# con filtro
```

---

## 4. Autenticación

```tcl
set miApi(perfil) {
    url http://localhost:8080/api/perfil
    auth bearer
    format json
}
rest::create_interface miApi

set miApi::token "miTokenSecreto123"
puts [miApi::perfil]
```

Para basic auth:
```tcl
set miApi(datos) {
    url http://localhost:8080/api/datos
    auth basic
}
rest::create_interface miApi
miApi::basic_auth "usuario" "contraseña"    ;# comando generado automáticamente por el modo auth basic
```
`auth bearer` y `auth basic` generan automáticamente el comando/variable correspondiente dentro del namespace de tu interfaz para configurar las credenciales una sola vez, reutilizadas en todas las llamadas subsecuentes — evitas repetir el header de autorización en cada llamada como tuviste que hacer manualmente en la guía anterior.

---

## 5. Llamadas asíncronas (no bloquear la GUI)

Igual que con `http` puro, para no congelar una GUI Tk necesitas el modo async — aquí se activa con la opción `callback`:

```tcl
set miApi(listarProductos) {
    url http://localhost:8080/api/productos
    method GET
    format json
    callback manejarRespuestaProductos
}
rest::create_interface miApi

proc manejarRespuestaProductos {procNombre estado args} {
    if {$estado eq "OK"} {
        set productos [lindex $args 0]
        actualizarListaProductos $productos
    } else {
        puts stderr "Error en $procNombre: $args"
    }
}

button .btn -text "Cargar" -command {miApi::listarProductos}
```
Con `callback`, el comando generado (`miApi::listarProductos`) retorna inmediatamente el token HTTP (no bloquea), y tu callback se invoca cuando la respuesta llega — recibe el nombre de la llamada, el estado (`OK`/`ERROR`), y los datos ya parseados según `format`. El event loop debe estar corriendo (dentro de una app Tk normal, ya lo está).

---

## 6. Transformaciones de entrada/salida (`pre_transform`, `post_transform`)

Útil cuando la forma de los datos que devuelve tu API Go no coincide exactamente con lo que tu UI necesita — puedes normalizarlo en un solo lugar, dentro de la definición de la interfaz:

```tcl
set miApi(listarProductos) {
    url http://localhost:8080/api/productos
    method GET
    format json
    post_transform normalizarProductos
}

proc normalizarProductos {datos} {
    set resultado {}
    foreach p $datos {
        # ej. tu API devuelve "precio_centavos", tu UI quiere "precio" en formato decimal
        set precio [expr {[dict get $p precio_centavos] / 100.0}]
        lappend resultado [dict merge $p [dict create precio $precio]]
    }
    return $resultado
}
rest::create_interface miApi
```
Esto mantiene la lógica de adaptación de datos centralizada en la definición de la API, en vez de dispersa por cada lugar donde llamas al endpoint — coherente con el mismo principio de "una sola fuente de verdad" que ya viste en la guía de gestión de estado.

---

## 7. `rest::describe`: documentación automática de tu propia interfaz

```tcl
rest::describe miApi
```
Imprime a stdout un resumen legible de todos los comandos definidos en `miApi` (URLs, argumentos requeridos/opcionales, método) — útil como referencia rápida mientras desarrollas, sin tener que releer tu propia tabla de definiciones.

---

## 8. HTTPS

Igual que con `http` puro (la guía anterior, §8):
```tcl
package require tls
http::register https 443 ::tls::socket
```
`rest` corre sobre `http` internamente, así que hereda automáticamente el soporte HTTPS una vez registrado — no necesitas configurar nada adicional específico de `rest`.

---

## 9. Comparación: `rest` vs armar tu propio cliente con `http`+`json` a mano

| Aspecto | `http` + `json` a mano (guía anterior) | `rest::create_interface` |
|---|---|---|
| Control fino sobre cada detalle | Total | Menos (el paquete decide varias convenciones por ti) |
| Cantidad de código | Más boilerplate por endpoint | Una tabla de definiciones, comandos generados automáticamente |
| Parseo de JSON | Manual (`json::json2dict`) | Automático con `format json` |
| Validación de argumentos requeridos | Manual | Automática vía `req_args` |
| Autenticación repetida en cada llamada | Manual, la resuelves tú (como en `::App::API::Request`) | Se configura una vez (`basic_auth`, `-auth bearer`) |
| Curva de aprendizaje | Baja, ya conoces `http`/`json` por separado | Un poco más alta, sintaxis propia de definición |
| Dependencias | `http` (core) + `json` (tcllib) | `http` + `json` + `tdom` + `base64` (más pesado) |

**Recomendación práctica:** para 2-3 endpoints puntuales, el enfoque manual de la guía anterior es igual de rápido y con menos dependencias. Si tu herramienta termina consumiendo una API con **muchos** endpoints (10+, como probablemente sea el caso completo de tu ERP), `create_interface` te ahorra bastante repetición y te da documentación (`rest::describe`) casi gratis.

---

## 10. Resumen de referencia rápida

| Construcción | Uso |
|---|---|
| `rest::get/post/put/patch/delete url query ?config?` | llamada suelta, retorna el resultado directo |
| `config {format json ...}` | parsea automáticamente la respuesta como JSON a dict/lista Tcl |
| `config {timeout 5000}` | siempre inclúyelo |
| `set tabla(nombreCall) {url ... method ... req_args {...} format json}` | define una llamada en modo interfaz |
| `rest::create_interface tabla` | genera comandos `tabla::nombreCall` a partir de la tabla |
| `req_args { arg: }` | argumento requerido, expuesto como `-arg` |
| `opt_args { arg arg2:default }` | argumento opcional, con o sin valor por defecto |
| `%variable%` en la URL | sustitución dinámica desde los argumentos pasados |
| `auth basic` / `auth bearer` | genera comando/variable de configuración de credenciales |
| `callback proc` | vuelve la llamada asíncrona, no bloquea el event loop |
| `pre_transform` / `post_transform` | normaliza datos antes/después del parseo |
| `rest::describe tabla` | imprime documentación de todos los comandos generados |

---

## 11. Dónde esto te sirve directamente

Si tu herramienta satélite en Tcl termina hablando con **varios** endpoints de tu backend Go (no solo 2-3), reescribir el `::App::API::*` de la guía anterior usando `rest::create_interface` te da lo mismo con menos código repetido — defines tu API completa como una tabla declarativa (parecido a cómo definirías rutas en un router), y obtienes documentación automática con `rest::describe` sin esfuerzo extra. Para algo pequeño y puntual, el enfoque manual sigue siendo perfectamente válido y con una dependencia menos (`tdom` y `base64`, que `rest` arrastra aunque no los uses directamente).
