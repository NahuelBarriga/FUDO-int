# Arquitectura

Cómo está organizado el código, cómo viaja un request y qué garantías tiene la creación asíncrona.

---

## 1. Procesos

| Proceso | Qué hace | Cómo arranca |
|---|---|---|
| `api` | Atiende HTTP (Puma + Rack). Encola jobs | `bundle exec puma` → `config/puma.rb` + `config.ru` |
| `worker` | Ejecuta los jobs de creación de productos (Sidekiq) | `bundle exec sidekiq -r ./config/worker.rb` |
| `postgres` | Fuente de verdad: usuarios, productos, solicitudes | Imagen `postgres:18` |
| `redis` | Cola de jobs y contadores de rate limiting | Imagen `redis:8.10` (persistencia AOF) |

`api` y `worker` usan la **misma imagen** con distinto comando. Los dos cargan `config/boot.rb` (Bundler, variables de entorno, conexión a la base, configuración de Sidekiq).

**Concurrencia:** Puma con 3 threads y 0 workers por defecto (la API es casi toda espera de I/O; los threads liberan el GVL mientras esperan). Se escala con `WEB_CONCURRENCY` (procesos) sin tocar código. El worker escala aparte, con `SIDEKIQ_CONCURRENCY` o más procesos. El pool de conexiones a la base (`DB_POOL`) es ≥ threads de cada proceso.

---

## 2. Estructura del código

```
app/
├── http/
│   ├── endpoints/        # un archivo por acción: auth/, products/, product_requests/, health, authors
│   ├── middleware/       # error_handler (conoce los errores de la app)
│   ├── serializers/      # qué campos de cada recurso ve el cliente
│   ├── authenticated.rb  # envoltorio de rutas protegidas
│   └── request_body.rb   # parseo y estructura estricta del body
├── services/             # casos de uso (reglas de negocio)
├── models/               # Sequel::Model (users, products, product_requests)
├── jobs/                 # Sidekiq (create_product)
└── errors.rb             # errores de dominio (code + mensaje)
lib/                      # código genérico, no conoce nada de app/
├── router.rb
├── middleware/           # request_id, request_logger, rate_limiter
├── access_token.rb       # JWT
├── password.rb           # bcrypt
├── json_logger.rb, json_response.rb, uuid.rb
config/                   # boot, env, database, sidekiq, puma, routes, rate_limits, worker
db/migrations/            # 001 users, 002 products, 003 product_requests
spec/                     # replica app/ y lib/, más requests/ (la app entera por HTTP)
```

**Reglas de dependencia**
- `app/` usa `lib/`; `lib/` nunca usa `app/` (se podría copiar a otro proyecto).
- Los **endpoints** traducen HTTP ↔ datos: parsean, llaman a un servicio y arman la respuesta. No tienen reglas de negocio.
- Los **servicios** tienen las reglas, lanzan errores de dominio y no conocen HTTP ni JSON (los reutiliza el job).
- Los **modelos** no validan: las reglas de valores están en los servicios y las invariantes en la base.
- El nombre de cada clase refleja su ruta: `app/http/endpoints/products/show.rb` → `Http::Endpoints::Products::Show`.
- Cada archivo hace `require_relative` de lo que usa (carga explícita, sin autoload).

---

## 3. Recorrido de un request

La pila de middlewares (`config.ru`), de afuera hacia adentro:

| # | Capa | Responsabilidad |
|---|---|---|---|
| 0 | `Rack::Head` | Quita el body en los `HEAD` |
| 1 | `RequestId` | Asigna `X-Request-Id` (reusa el del cliente si es válido) |
| 2 | `RequestLogger` | Una línea JSON por request: método, path, status, duración, request id |
| 3 | `Rack::Deflater` | gzip si el cliente lo pide (`Vary: Accept-Encoding`) |
| 4 | `ErrorHandler` | Excepción → status + `{ error: { code, message } }` |
| 5 | `RateLimiter` | Límites por IP y por username → `429` |
| 6 | `Router` | Método + path → endpoint; `404` / `405` con `Allow` | Centro de la pila 
| — | `Authenticated` | Solo en rutas protegidas: verifica el JWT y deja el id del usuario en el env |

Un `POST /products`:

1. Puma asigna un thread y arma el `env`; el request atraviesa las capas 0–5.
2. El router elige `Products::Create`, envuelto por `Authenticated`, que valida el token.
3. `RequestBody` parsea el JSON y exige la estructura `{ "name": String }` (si no, `400`).
4. `Services::RequestProductCreation` recorta y valida el nombre (`422`), hace el pre-chequeo de duplicados (`409`), guarda la solicitud `pending` y agenda el job a 5 s.
5. El endpoint responde `202` con `Location` y `Retry-After`; la respuesta vuelve por las capas (se comprime, se loguea, lleva el request id).

---

## 4. Creación asíncrona y sus garantías

Patrón *Asynchronous Request-Reply*: `202 Accepted` + un recurso de estado (`product_requests`) que el cliente consulta.


**Por qué existe la tabla `product_requests`** si los jobs están en Redis: Redis es la cola (trabajo pendiente, efímero, Sidekiq borra los jobs terminados); la tabla es el estado de negocio (durable, consultable por dueño, base de la idempotencia y del manejo del *dual write*).
**Reinicio de Redis** Persistencia AOF: los jobs agendados sobreviven
**Base de datos caida** el job lanza la excepción y Sidekiq reintenta (5 veces, con backoff). Al agotarse: `failed` / `creation_failed`. Toda solicitud llega a un estado final |

---

## 5. Autenticación

- Passwords con **bcrypt** (lento a propósito, con salt). Costo configurable (`BCRYPT_COST`).
- **JWT HS256** con `sub` (id del usuario), `iat` y `exp` (1 h). Al verificar se fija el algoritmo (evita `alg: none`) y se exigen `sub` y `exp`. El secret (`JWT_SECRET`, ≥ 32 bytes) es obligatorio: sin él la app no arranca.
- **Login sin filtrar información:** usuario inexistente y contraseña incorrecta responden igual; si el usuario no existe se compara contra un hash falso para que los dos casos tarden lo mismo (*timing attack*).
- **Rutas protegidas:** `Http::Authenticated` envuelve a cada endpoint protegido en `config/routes.rb`. Guarda solo el id en el `env` (sin consulta a la base por request).
- **Autorización por *scoping*:** toda consulta filtra por `user_id`. Lo ajeno responde `404`, igual que lo inexistente.
- Las respuestas autenticadas llevan `Cache-Control: no-store`.

---

## 6. Errores

| Status | Cuándo | `code` |
|---|---|---|
| 400 | Body vacío o JSON inválido | `invalid_json` |
| 400 | El body no respeta la estructura (no es objeto, falta un campo, tipo incorrecto, campo de más) | `invalid_body` |
| 401 | Credenciales inválidas | `invalid_credentials` |
| 401 | Token ausente, inválido o vencido | `unauthorized` |
| 404 | Ruta inexistente; recurso inexistente o ajeno; id mal formado | `not_found` |
| 405 | Método no permitido (con `Allow`) | `method_not_allowed` |
| 409 | Username o nombre de producto tomado | `username_taken`, `name_taken` |
| 422 | Un valor no cumple una regla (largo, caracteres, paginación) | `validation_failed` |
| 429 | Límite de requests superado (con `Retry-After`) | `rate_limited` |
| 503 | No se pudo encolar la creación | `service_unavailable` |
| 500 | Error no previsto (el detalle va solo al log) | `internal_error` |

Los errores de dominio (`app/errors.rb`) tienen un `code` pero no un status: el status lo decide el `ErrorHandler`, la única pieza que conoce HTTP. Así el mismo error (`name_taken`) es un `409` en la API y el motivo guardado en una solicitud fallida en el job.

---

## 7. Configuración y operación

- **Variables de entorno** para todo lo que cambia por entorno (ver `.env.example`). Las obligatorias (`DATABASE_URL`, `REDIS_URL`, `JWT_SECRET`) no tienen default: la app falla al arrancar si faltan (*fail fast*).
- **Logs** en JSON a stdout, una línea por request con su request id; los errores no previstos con clase, mensaje y backtrace. No se registran query strings, headers ni bodies (pueden tener tokens o contraseñas).
- **`GET /health`:** `ok`, `degraded` (worker caído: la API sigue atendiendo, `200`) o `down` (Postgres o Redis caídos, `503`).
- **Rate limiting** en Redis (ventana fija). Si Redis no responde, deja pasar (*fail open*): es una protección, no una función del negocio.
- **Timeouts:** 2 s para conectar a Postgres (`DB_CONNECT_TIMEOUT`); Redis, 1 s.

---

## 8. Tests

- **RSpec + rack-test.** Unitarios de `lib/` y `app/`, y tests de request contra la app completa (la misma pila de `config.ru`, sin Puma).
- Cada test corre en una transacción que se deshace: la base siempre arranca vacía.
- **Sidekiq en modo `fake`:** se verifica que el endpoint encola (con 5 s de delay) y se ejecutan los jobs con `drain` para simular que pasó el tiempo. El rate limiter cuenta en memoria. Los tests solo necesitan Postgres.
- Cobertura con SimpleCov (~100% de `app/` y `lib/`).
