# Clausulazos — Backend (NestJS + Prisma + PostgreSQL)

API que gestiona los "cláusulazos" de una liga Fantasy entre amigos, con la
regla de **2 plazas activas** (realizados y recibidos) que se liberan
individualmente **7 × 24 horas** después de crearse cada cláusulazo.

## Stack

- NestJS + TypeScript
- PostgreSQL
- Prisma ORM (Prisma 7, con el *driver adapter* `@prisma/adapter-pg`, que
  habla con Postgres a través del driver `pg` en vez del motor nativo de
  Prisma)
- JWT (`@nestjs/jwt` + `passport-jwt`)
- bcrypt para contraseñas
- class-validator / class-transformer para DTOs

## ⚠️ Nota importante sobre este entorno de construcción

Este backend se ha escrito y su lógica de concurrencia se ha **validado
contra una instancia real de PostgreSQL** (ver sección de tests), pero el
propio comando `npx prisma generate` no ha podido ejecutarse dentro del
entorno sandbox usado para construir el proyecto, porque ese entorno
bloquea el acceso de red a `binaries.prisma.sh` (el CDN donde Prisma aloja
el *schema engine*), devolviendo `403 host_not_allowed`. No es una decisión
de diseño: es una restricción del contenedor de construcción.

**En tu máquina, con acceso normal a internet, esto no es un problema.**
Simplemente ejecuta `npm install` y `npx prisma generate` como el primer
paso (ver más abajo) y todo funcionará con normalidad.

Para no depender de ciegamente "confiar" en el código, el algoritmo de
bloqueo de concurrencia (la parte más delicada del sistema, la regla #10
del encargo) se extrajo a un script standalone usando el driver `pg` en
crudo y se ejecutó realmente contra un PostgreSQL local dentro del sandbox,
simulando dos peticiones simultáneas sobre el mismo jugador: el resultado
confirmado fue **1 petición aceptada, 1 rechazada, nunca más de 2 activos**.
La implementación de `ClausesService.create()` usa exactamente esa misma
técnica (`pg_advisory_xact_lock` dentro de una transacción Prisma).

## Instalación

```bash
cd backend
npm install
cp .env.example .env   # y ajusta DATABASE_URL / JWT_SECRET si hace falta
npx prisma generate
npx prisma migrate dev --name init
npm run seed
```

## Variables de entorno (`.env`)

```
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/clausulazos?schema=public"
JWT_SECRET="cambia_este_secreto_en_produccion"
PORT=3000
```

## Ejecutar el backend

```bash
npm run start:dev     # desarrollo, con recarga en caliente
npm run build && npm run start:prod   # producción
```

La API queda escuchando en `http://localhost:3000`.

## Base de datos

Dos tablas:

- **User**: `id, name, email (único), password (hash bcrypt), createdAt, updatedAt`
- **Clause**: `id, fromUserId, toUserId, createdAt, expiresAt, status (ACTIVE | EXPIRED | CANCELLED), cancelledAt`

`expiresAt` se calcula y se guarda explícitamente como `createdAt + 7 días`
en el momento de crear el cláusulazo. **No existen contadores
permanentes**: cada cláusulazo es un registro individual con su propio
reloj de expiración, tal y como pide el encargo. Un cláusulazo cuenta como
activo si y solo si `status = ACTIVE` **y** `expiresAt > now()`. Los
cláusulazos expirados o cancelados nunca se borran: quedan en el
historial.

## API

### Auth
- `POST /auth/register` — `{ name, email, password, confirmPassword }`
- `POST /auth/login` — `{ email, password }` → `{ accessToken, user }`
- `GET /auth/me` — usuario autenticado (requiere Bearer token)

### Users
- `GET /users` — todos los usuarios excepto el actual, con sus stats
- `GET /users/me`
- `GET /users/me/stats` — plazas activas/disponibles y próxima liberación
- `GET /users/:id`

### Clauses
- `POST /clauses` — `{ toUserId }` (el `fromUserId` **siempre** sale del JWT, nunca del body — regla #40)
- `GET /clauses` — historial completo
- `GET /clauses/me` — cláusulazos donde el usuario es origen o destino
- `DELETE /clauses/:id` — cancela un cláusulazo (solo quien lo realizó)

Ejemplo de respuesta de `GET /users/me/stats`:

```json
{
  "performed": { "active": 1, "limit": 2, "available": 1, "nextReleaseAt": "2026-09-08T18:00:00.000Z" },
  "received":  { "active": 2, "limit": 2, "available": 0, "nextReleaseAt": "2026-09-09T12:00:00.000Z" }
}
```

## Concurrencia (regla #10 del encargo)

`ClausesService.create()` corre dentro de una transacción Prisma
(`$transaction`). Antes de contar cláusulazos activos, toma un
**advisory lock de PostgreSQL** (`pg_advisory_xact_lock(hashtext(userId))`)
sobre el usuario origen y el usuario destino, **siempre en el mismo orden
(ordenados alfabéticamente por id)** para evitar interbloqueos. Cualquier
otra transacción que intente tocar las plazas de ese mismo usuario se
queda bloqueada hasta que la primera transacción termina (commit o
rollback). Esto hace que el patrón "contar y luego insertar" sea atómico
de verdad: dos peticiones simultáneas contra el mismo jugador nunca pueden
superar el límite de 2 activos.

## Tests

```bash
npm run test        # unit/integration tests (src/**/*.spec.ts)
npm run test:e2e     # tests end-to-end sobre la API HTTP completa
```

Los tests de `clauses.service.spec.ts` cubren los 14 escenarios pedidos
(tests 1–14 del encargo: límites de 2 activos, liberación a los 7 días,
auto-cláusula prohibida, `expiresAt = createdAt + 7d`, expiración exacta,
concurrencia, cancelación, historial). Requieren una base de datos
PostgreSQL real (usan transacciones y fechas reales), igual que el resto
de la app — no están mockeados.

## Seed

`npm run seed` crea 8 jugadores de prueba con la contraseña de desarrollo
**`clausulazo123`** para todos:

```
martin@example.com   juan@example.com    pedro@example.com   antonio@example.com
carlos@example.com   dani@example.com    pablo@example.com   miguel@example.com
```

## Decisiones técnicas relevantes

- **Prisma 7 + driver adapter `pg`**: en vez del motor de consultas nativo
  de Prisma, se usa el adaptador oficial sobre el driver `pg`, que es
  totalmente estándar y soportado — no es un workaround exclusivo del
  sandbox, es la forma recomendada por Prisma desde la v6/v7 y funciona
  igual de bien en cualquier entorno con acceso normal a internet.
- **IDs de usuario y cláusulazo como UUID** (`@default(uuid())`), en vez
  de enteros autoincrementales, para no filtrar información secuencial
  (p. ej. cuántos usuarios/cláusulazos existen) a través de la API.
- **`status` + `expiresAt`** en vez de solo `expiresAt`: permite distinguir
  una cancelación explícita (`CANCELLED`) de una expiración natural, sin
  perder el registro.
- **`ValidationPipe({ whitelist: true, forbidNonWhitelisted: true })`**
  global: cualquier campo no declarado en el DTO (como un `fromUserId`
  inyectado desde el cliente) se rechaza con 400, reforzando la regla #40.
