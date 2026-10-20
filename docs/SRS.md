# Especificación de requisitos

Versión liviana inspirada en IEEE 830. Para el detalle de la API, ver [`openapi.yaml`](../openapi.yaml).

---

## 1. Introducción

### 1.1 Propósito
API RESTful para gestionar productos por usuario, con autenticación y creación asíncrona mediante una cola de trabajos.

### 1.2 Alcance
- Registro y autenticación de usuarios.
- Creación asíncrona de productos y consulta del estado de cada solicitud.
- Consulta de los productos propios: listado paginado y por id.
- Un archivo estático `AUTHORS`, cacheable.

### 1.3 Definiciones

| Término | Definición |
|---|---|
| Producto | Recurso que pertenece a un usuario. Tiene, como mínimo, `id` y `name` |
| Solicitud de creación (`product_request`) | Registro de un pedido de creación asíncrona y su estado |
| JWT | JSON Web Token firmado que identifica al usuario en cada request |
| Job | Unidad de trabajo que se encola y procesa un worker en segundo plano |
| Nombre normalizado | El nombre sin espacios en los extremos y en minúsculas; se usa para comparar |

---

## 2. Descripción general

### 2.1 Actores
- **Visitante:** sin autenticar. Puede registrarse, hacer login, consultar `AUTHORS` y `health`.
- **Usuario autenticado:** envía un JWT válido. Gestiona sus propios productos.
- **Worker:** proceso de sistema que ejecuta los jobs de creación.

### 2.2 Restricciones
- Ruby con Rack, sin frameworks web.
- La creación de productos se procesa en un sistema de colas (Sidekiq + Redis).
- Persistencia en PostgreSQL 18.
- Respuestas comprimidas con gzip cuando el cliente lo solicita.

### 2.3 Supuestos
- El cliente es una aplicación o una herramienta HTTP (curl, Postman), no necesariamente un navegador.
- Un solo rol de usuario: no hay administración.

---

## 3. Requisitos funcionales

| ID | Requisito | Origen |
|---|---|---|
| RF-01 | Registrar un usuario con username y password | Agregado (facilita las pruebas) |
| RF-02 | Autenticar con username y password y devolver un JWT | Consigna |
| RF-03 | Devolver los datos del usuario autenticado (`GET /auth/me`) | Agregado |
| RF-04 | Solicitar la creación de un producto. La respuesta **no** confirma la creación: `202` + identificador de la solicitud | Consigna |
| RF-05 | El producto queda disponible **no antes de 5 segundos** después de la solicitud | Consigna |
| RF-06 | Consultar el estado de una solicitud propia (`pending` / `completed` / `failed`) | Agregado (lo permite la consigna) |
| RF-07 | Listar **solo los** productos propios, paginados con `limit` y `offset` | Consigna |
| RF-08 | `GET /AUTHORS` con nombre y apellido del autor, cacheable 24 h | Consigna |
| RF-09 | `GET /health` para chequeos de disponibilidad | Agregado |
| RF-10 | Consultar un producto propio por id (`GET /products/{id}`) | Agregado (cierra el flujo asíncrono) |

---

## 4. Reglas de negocio

| ID | Regla |
|---|---|
| RN-01 | Un usuario no puede tener dos productos con el mismo **nombre normalizado** (`"Coca"` = `" coca "`) |
| RN-02 | El nombre se guarda tal como lo envió el usuario, sin espacios en los extremos |
| RN-03 | La unicidad la garantiza la base de datos (índice único), no solo la aplicación |
| RN-04 | `POST /products` hace un pre-chequeo de duplicados contra los productos y las solicitudes `pending` del usuario, para responder `409` rápido. Las `failed` no bloquean |
| RN-05 | Si al procesarse el job el nombre ya existe, la solicitud pasa a `failed` con `name_taken`, sin reintentos |
| RN-06 | Un usuario no puede ver productos ni solicitudes de otro. Lo ajeno responde `404` (no `403`, para no revelar que existe) |
| RN-07 | El username es único sin distinguir mayúsculas; se guarda como lo escribió el usuario |
| RN-08 | Ante credenciales inválidas, el login responde un error genérico: no distingue "el usuario no existe" de "la contraseña es incorrecta" |

### 4.1 Validaciones de entrada

| Campo | Regla |
|---|---|
| `username` | 3–50 caracteres; letras, números, `_`, `.`, `-` |
| `password` | 8–72 **bytes** (72 es el límite de bcrypt); sin reglas de composición |
| `name` (producto) | 1–100 caracteres después de recortar los espacios; cualquier carácter |
| `limit` | Entero de 1 a 100; default 20 |
| `offset` | Entero ≥ 0; default 0 |

### 4.2 Formato (400) vs valores (422)

| Status | Cuándo | Código |
|---|---|---|
| `400` | Body vacío o JSON inválido | `invalid_json` |
| `400` | JSON que no es un objeto; falta un campo; un campo tiene otro tipo; hay un campo que no está en la estructura (estricto) | `invalid_body` |
| `422` | La estructura es correcta pero un valor no cumple las reglas de 4.1 | `validation_failed` |

### 4.3 Ciclo de vida de una solicitud
`pending` → `completed` (con `product_id`), o `pending` → `failed` (con `error`). Los estados finales no cambian.

---

## 5. Requisitos no funcionales

| ID | Requisito |
|---|---|
| RNF-01 | **Seguridad:** contraseñas con hash bcrypt, nunca en texto plano |
| RNF-02 | **Seguridad:** JWT HS256 con expiración de 1 h; secret por variable de entorno (≥ 32 bytes) |
| RNF-03 | **Compresión:** gzip si el request trae `Accept-Encoding: gzip`, con `Vary: Accept-Encoding` |
| RNF-04 | **Cache:** `AUTHORS` con `Cache-Control: public, max-age=86400`, ETag y Last-Modified; respuestas autenticadas con `no-store` |
| RNF-05 | **Confiabilidad:** jobs idempotentes; errores técnicos reintentados, errores de negocio no; toda solicitud llega a un estado final |
| RNF-06 | **Observabilidad:** logs JSON con request id; `GET /health` con estado de cada dependencia |
| RNF-07 | **Errores:** formato JSON único `{ "error": { "code", "message" } }`; `500` con mensaje genérico (el detalle, solo en el log) |
| RNF-08 | **Configuración:** todo valor sensible o dependiente del entorno por variables de entorno; las obligatorias sin default |
| RNF-09 | **Documentación:** API documentada en OpenAPI; README con instalación y pruebas |
| RNF-10 | **Rate limiting:** límite general por IP; más estricto en login (por IP y por username) y en registro |
| RNF-11 | **Testing:** tests automatizados de los flujos principales, ejecutables dentro de Docker |

---

## 6. Interfaz

| Método | Path | Auth | Éxito | Errores principales |
|---|---|---|---|---|
| POST | `/auth/register` | No | `201` | `400`, `409`, `422`, `429` |
| POST | `/auth/login` | No | `200` `{ access_token, token_type, expires_in }` | `400`, `401`, `429` |
| GET | `/auth/me` | JWT | `200` | `401` |
| POST | `/products` | JWT | `202` + `Location` + `Retry-After` | `400`, `401`, `409`, `422`, `429`, `503` |
| GET | `/product_requests/{id}` | JWT | `200` | `401`, `404` |
| GET | `/products?limit&offset` | JWT | `200` `{ data, meta: { limit, offset, total } }` | `401`, `422` |
| GET | `/products/{id}` | JWT | `200` | `401`, `404` |
| GET | `/AUTHORS` | No | `200` text/plain, `304` | — |
| GET | `/health` | No | `200` (`ok` / `degraded`) | `503` (`down`) |

---

## 7. Fuera de alcance
- Editar y borrar productos.
- Refresh tokens y revocación de JWT.
- Roles y permisos.
- Notificaciones push (SSE / WebSockets) del resultado de una solicitud.
- Frontend.
