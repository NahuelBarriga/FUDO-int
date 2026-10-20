# FUDO — API de productos (Ruby + Rack)

API RESTful en Ruby sobre Rack, **sin frameworks web**. Usuarios con autenticación JWT, creación **asíncrona** de productos mediante una cola de trabajos (Sidekiq + Redis) y un archivo estático `AUTHORS` cacheable.

- **Documentación de la API:** [`openapi.yaml`](openapi.yaml) (OpenAPI 3.1).
- **Arquitectura y garantías:** [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).
- **Modelo de datos:** [`docs/MER.md`](docs/MER.md) · **Requisitos:** [`docs/SRS.md`](docs/SRS.md).
- **Despliegue** (Docker local y VPS con HTTPS): [`docs/DEPLOY.md`](docs/DEPLOY.md).

---

## Stack

| Pieza | Elección |
|---|---|
| Lenguaje | Ruby 4.0.7 |
| HTTP | Rack 3 + router propio, servido por Puma |
| Base de datos | PostgreSQL 18 (Sequel) |
| Cola de trabajos | Sidekiq 8 + Redis 8.10 |
| Autenticación | JWT (HS256) + bcrypt |
| Tests / calidad | RSpec + rack-test + SimpleCov · RuboCop |
| Entorno | Docker Compose |

---

## Requisitos

- **Docker** con **Docker Compose v2** (`docker compose version`).

Nada más para levantar, probar y correr los tests. Para desarrollar sin Docker, ver [Desarrollo local](#desarrollo-local).

---

## Levantar el proyecto

**1. Configurar las variables de entorno**

```bash
cp .env.example .env
```

Completar en `.env` (cada variable está comentada en el archivo):

| Variable | Qué poner |
|---|---|
| `POSTGRES_PASSWORD` | Cualquier contraseña (solo letras y números) |
| `JWT_SECRET` | Un secret aleatorio de al menos 32 bytes: `openssl rand -hex 32` |

El resto tiene valores por defecto. `DATABASE_URL` y `REDIS_URL` del `.env` son para desarrollo local: en Docker, el compose las reemplaza por los hosts internos.

**2. Construir y levantar**

```bash
docker compose up -d --build
```

Levanta 4 servicios: `api` (puerto 9292), `worker` (Sidekiq), `postgres` y `redis`.

**3. Crear las tablas (obligatorio la primera vez)**

```bash
docker compose run --rm api bundle exec rake db:migrate
```

Debe responder `Esquema en la versión 3`.

**4. Verificar**

```bash
curl -s localhost:9292/health
# {"status":"ok","checks":{"postgres":"up","redis":"up","worker":"up"}}
```

**Apagar:** `docker compose down` (los datos quedan en volúmenes) · `docker compose down -v` (borra también los datos).

---

## Correr los tests

```bash
docker compose run --rm --build test
```

Construye una imagen de test (separada de la de entrega), migra la base de test y corre la suite completa (unitarios y tests de request contra la app). El servicio `test` no arranca con `docker compose up`.

---

## Probar el flujo completo

Con `curl` (o importando [`openapi.yaml`](openapi.yaml) en Postman, Insomnia o [Swagger Editor](https://editor.swagger.io)):

```bash
# 1. Registrarse
curl -s -X POST localhost:9292/auth/register -H "Content-Type: application/json" \
  -d '{"username":"nahuel","password":"supersecreta"}'

# 2. Login: copiar el access_token de la respuesta
curl -s -X POST localhost:9292/auth/login -H "Content-Type: application/json" \
  -d '{"username":"nahuel","password":"supersecreta"}'

TOKEN=<access_token>

# 3. Pedir la creación de un producto -> 202 + Location + Retry-After
curl -si -X POST localhost:9292/products -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" -d '{"name":"Coca"}'

# 4. Consultar la solicitud (el id está en el header Location):
#    "pending" durante ~5 s, después "completed" con product_id
curl -s -H "Authorization: Bearer $TOKEN" localhost:9292/product_requests/<id>

# 5. Listar los productos (aparece recién cuando la solicitud está completed)
curl -s -H "Authorization: Bearer $TOKEN" "localhost:9292/products?limit=20&offset=0"

# 6. Un producto puntual
curl -s -H "Authorization: Bearer $TOKEN" localhost:9292/products/<product_id>

# 7. AUTHORS: headers de cache, gzip y revalidación
curl -I localhost:9292/AUTHORS
curl -sv --compressed localhost:9292/AUTHORS
curl -si -H 'If-None-Match: W/"<etag>"' localhost:9292/AUTHORS   # 304
```

Casos de error para probar: pedir dos veces el mismo nombre (`409`), un nombre vacío (`422`), un campo de más en el body (`400`), sin token (`401`), la solicitud de otro usuario (`404`), 11 logins seguidos con contraseña incorrecta (`429`).

---

## Endpoints

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
| GET | `/health` | No | `200` `ok` / `degraded` | `503` `down` |

Todos los `GET` aceptan `HEAD`. Todas las respuestas llevan `X-Request-Id`. Los errores tienen un formato único: `{ "error": { "code": "...", "message": "..." } }`. El detalle de cada endpoint está en [`openapi.yaml`](openapi.yaml).

---

## Cómo funciona la creación asíncrona

1. `POST /products` valida el nombre, hace un pre-chequeo de duplicados, guarda una **solicitud** `pending` y agenda un job para dentro de 5 s. Responde `202` con `Location: /product_requests/{id}`.
2. El worker toma el job a los ~5 s y, en una transacción, crea el producto y marca la solicitud `completed`. Si el nombre ya existe, la marca `failed` con `name_taken`.
3. El cliente consulta `GET /product_requests/{id}` (guiado por `Retry-After`) hasta ver un estado final.

Garantías: unicidad por índice en la base (no solo por el pre-chequeo), job idempotente, reintentos acotados y estado final siempre registrado. El detalle está en [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md#4-creación-asíncrona-y-sus-garantías).

---

## Decisiones de diseño y tradeoffs

- **Router propio sobre Rack**, sin frameworks.
- **Job agendado (`perform_in`), no `sleep`.** Tradeoff: "no antes de 5 s", corre entre 5 y ~6 s.
- **La unicidad la garantiza la base**; el pre-chequeo solo adelanta el `409`. Tradeoff: ante una carrera, el perdedor se entera por polling (`name_taken`).
- **Job idempotente** (`FOR UPDATE` + estado `pending`). Tradeoff: un bloqueo de fila por job.
- **Dual write: guardar y después encolar**; si falla, `failed` + `503`.
- **`400` estructura / `422` valores, body estricto.**
- **`404` (no `403`) para recursos ajenos**, filtrando por `user_id`.
- **JWT stateless de 1 h.** 
- **Login con mismo error y mismo tiempo** para usuario inexistente o contraseña mala. Tradeoff: un bcrypt extra.
- **Paginación limit/offset con `total`.** 
- **UUID v7.** para IDs.
- **`AUTHORS` público 24 h + ETag.
- **Rate limiting propio, *fail open*.** Tradeoff: ventana fija (hasta 2× en el borde).
- **Health con `degraded`** si el worker está caído. Tradeoff: endpoint público que expone qué componentes hay.
- **Una imagen, dos procesos** (`api` y `worker`), multi-stage, sin root.

---

## Variables de entorno

| Variable | Default | Uso |
|---|---|---|
| `RACK_ENV` | `development` | `development`, `test` o `production` |
| `PORT` | `9292` | Puerto de Puma |
| `PUMA_MAX_THREADS` / `WEB_CONCURRENCY` | `3` / `0` | Threads y procesos de Puma |
| `DATABASE_URL` | — (obligatoria) | Conexión a Postgres |
| `DB_POOL` / `DB_CONNECT_TIMEOUT` | `5` / `2` | Conexiones del pool (≥ threads) / segundos para conectar |
| `REDIS_URL` | — (obligatoria) | Conexión a Redis |
| `SIDEKIQ_CONCURRENCY` / `SIDEKIQ_POLL_INTERVAL` | `5` / `1` | Threads del worker / segundos entre revisiones de jobs agendados |
| `JWT_SECRET` | — (obligatoria, ≥ 32 bytes) | Firma de los tokens |
| `JWT_TTL_SECONDS` | `3600` | Vencimiento del token |
| `BCRYPT_COST` | `12` | Costo de bcrypt |
| `RATE_LIMIT_GENERAL` / `_LOGIN_IP` / `_LOGIN_USERNAME` / `_REGISTER_IP` | `300` / `10` / `5` / `10` | Límites (por minuto; registro por hora) |
| `RATE_LIMIT_STORE` | `redis` | `memory` solo para tests |
| `LOG_LEVEL` | `info` | Nivel de logs |
| `POSTGRES_USER` / `POSTGRES_PASSWORD` | `fudo` / — | Usuario del container de Postgres |

---

## Desarrollo local

Ruby en el host (probado en WSL2 con rbenv); Postgres y Redis en Docker.

```bash
rbenv install 4.0.7          # la versión está en .ruby-version
bundle install
cp .env.example .env         # completar como arriba (DATABASE_URL con la misma contraseña)
# .env.test con: DATABASE_URL=...fudo_test  y  BCRYPT_COST=4

docker compose up -d postgres redis
bundle exec rake db:migrate
RACK_ENV=test bundle exec rake db:migrate

bundle exec rerun -b -- puma                          # API con recarga automática
bundle exec rerun -b -- sidekiq -r ./config/worker.rb # worker con recarga automática

bundle exec rspec                                     # tests
bundle exec rubocop                                   # estilo
docker run --rm -v "$PWD":/spec redocly/cli lint openapi.yaml   # valida el OpenAPI
```

Un solo worker por Redis a la vez: si el `worker` de Docker está corriendo, frenarlo antes (`docker compose stop worker api`).

---

## Mejoras posibles

Fuera del alcance de esta entrega, con el diseño ya pensado:

- **Reconciliación de solicitudes trabadas:** una tarea periódica que vuelva a encolar las solicitudes `pending` de más de ~10 minutos (cubre la pérdida total de Redis; es segura porque el job es idempotente).
- **Migraciones automáticas en Docker:** un servicio `migrate` del que dependan `api` y `worker`.
- **Paginación keyset** (`?after=<id>`) para volúmenes grandes.
- **Notificación del resultado** (SSE o webhooks) en lugar de polling.
- **Esquemas declarativos** (`dry-schema`) si la API crece; **`rack-attack`** para reglas de rate limiting más ricas.
- **CI** (lint + tests en cada push) reutilizando el servicio `test`.
- **Patrón *outbox*** para eliminar el dual write.
- **Índice parcial en `product_requests`** (`user_id, lower(name) WHERE status = 'pending'`) para que el pre-chequeo de duplicados no recorra la tabla.
- **Link al producto en la solicitud completada** (`links.product`), para no armar la URL del lado del cliente.
- **Documentación navegable servida por la API** (Redoc o Swagger UI en `/docs`).
- **Testing de contrato** test que validen cada respuesta contra el esquema de openapi.yaml
- **Revisión de pendientes al POST de producto** Agregar un chequeo que verifique si hay un producto pendiente para ese mismo usuario 

---

## Autor

Ver [`AUTHORS`](AUTHORS).
