# CLAUSULAZOS

Aplicación privada para gestionar los cláusulazos de una liga Fantasy
entre amigos. Regla central: cada jugador tiene 2 plazas de "realizados"
y 2 de "recibidos", y **cada plaza se libera individualmente 7 × 24 horas
después de usarse** (no hay contadores permanentes ni reinicio semanal).

- [`backend/`](./backend) — NestJS + TypeScript + PostgreSQL + Prisma + JWT + bcrypt
- [`frontend/`](./frontend) — Flutter + Dart + Provider + go_router

Cada carpeta tiene su propio README con instrucciones de instalación,
ejecución y tests. Léelos — cada uno explica también una limitación
importante del entorno en el que se construyó este proyecto (ver más
abajo).

## Resumen para arrancar rápido

```bash
# 1. Backend
cd backend
npm install
cp .env.example .env
npx prisma generate
npx prisma migrate dev --name init
npm run seed
npm run start:dev        # http://localhost:3000

# 2. Frontend (en otra terminal)
cd frontend
flutter create . --platforms=android,ios
flutter pub get
flutter run
```

Usuarios de prueba (contraseña `clausulazo123` para todos):
`martin@example.com`, `juan@example.com`, `pedro@example.com`,
`antonio@example.com`, `carlos@example.com`, `dani@example.com`,
`pablo@example.com`, `miguel@example.com`.

## Nota sobre el entorno de construcción

Este proyecto se construyó dentro de un contenedor sandbox con acceso de
red restringido a un puñado de dominios (npm, PyPI, crates.io, GitHub,
repositorios de Ubuntu). Eso afectó a dos cosas concretas:

1. **`prisma generate`** necesita descargar un binario desde
   `binaries.prisma.sh`, un dominio no permitido en el sandbox → no pude
   ejecutar el backend "de verdad" aquí. En su lugar, instalé PostgreSQL
   localmente, **validé el algoritmo de bloqueo de concurrencia
   (`pg_advisory_xact_lock`) con un script standalone sobre `pg` en
   crudo** (dos peticiones simultáneas → una aceptada, una rechazada,
   nunca más de 2 activos), y comprobé con `tsc --noEmit` que todo el
   código del backend compila correctamente. En tu máquina, con acceso
   normal a internet, `npx prisma generate` funcionará sin más.
2. **Flutter** no está instalado en el sandbox y `pub.dev` tampoco es
   accesible, así que el frontend se escribió completo a mano pero no
   se pudo compilar/analizar/testear en este entorno.

Todo el código se entrega completo y lo más correcto posible dado lo
anterior; ambos READMEs detallan exactamente qué se pudo verificar y qué
queda por verificar en tu máquina.

## Qué se ha construido

1. Backend NestJS completo: auth (registro/login/JWT/bcrypt), usuarios,
   cláusulazos, regla de expiración a 7×24h, estadísticas, próxima
   liberación, cancelación con liberación inmediata.
2. Frontend Flutter completo: splash, welcome, login, registro, home con
   contadores animados, selección de jugador (bloqueando a quien tiene
   2/2 recibidos), confirmación, actividad/historial, jugadores, perfil,
   navegación inferior, tema oscuro deportivo.
3. Persistencia real: PostgreSQL vía Prisma, sin contadores permanentes —
   cada cláusulazo es un registro con su propio `createdAt`/`expiresAt`.
4. Autenticación JWT de extremo a extremo, con `fromUserId` derivado
   siempre del token (nunca aceptado del cliente).
5. Protección de concurrencia con locks de PostgreSQL dentro de
   transacciones Prisma, validada contra una base de datos real.
6. Tests: 14 escenarios de negocio + tests e2e en el backend; tests de
   modelo, formateo de fechas y widgets en el frontend.
7. Seed con los 8 jugadores de la liga.
8. Documentación completa en ambos READMEs.

## Estructura del proyecto

```
clausulazos/
  backend/
    src/{auth,users,clauses,prisma}/
    prisma/{schema.prisma,seed.ts}
    test/app.e2e-spec.ts
    README.md
  frontend/
    lib/{core,models,repositories,providers,screens,widgets}/
    test/
    README.md
  README.md   (este archivo)
```

## Decisiones técnicas importantes

- **Prisma 7 + driver adapter `pg`** en vez del motor de consultas nativo:
  estándar desde Prisma 6/7, no es un workaround.
- **UUID** como id de usuarios y cláusulazos (no enteros autoincrementales).
- **`status` (ACTIVE/EXPIRED/CANCELLED) + `expiresAt`** en la tabla
  `Clause`, en vez de solo la fecha: permite distinguir una cancelación
  explícita de una expiración natural sin perder el historial.
- **Advisory locks de PostgreSQL** (`pg_advisory_xact_lock`), ordenados
  por id de usuario para evitar interbloqueos, como mecanismo de
  concurrencia — más ligero que `SERIALIZABLE` + reintentos y con el
  mismo resultado: imposible superar el límite de 2 activos con
  peticiones simultáneas.
- **`ValidationPipe({ whitelist: true, forbidNonWhitelisted: true })`**
  global en NestJS: cualquier campo no declarado en el DTO (como un
  `fromUserId` inyectado desde el cliente) se rechaza con 400.
- **DI manual en Flutter** (sin `get_it` ni generadores de código): con 3
  repositorios y 3 providers, cablearlos a mano en `main.dart` es más
  simple y perfectamente mantenible.
