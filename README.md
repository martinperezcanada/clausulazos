# ⚽ Clausulazos

**Clausulazos** es una aplicación web para gestionar los **cláusulazos de una liga privada de Fantasy LaLiga**, evitando tener que controlar manualmente los movimientos mediante WhatsApp.

La aplicación permite registrar usuarios, gestionar cláusulas, controlar los límites de cada jugador y sincronizar automáticamente la actividad de **LaLiga Fantasy** con la liga de Clausulazos.

El objetivo es que el sistema sea completamente automático: los movimientos realizados en Fantasy se detectan y se incorporan a la aplicación sin necesidad de introducirlos manualmente.

---

## 📋 Índice

* [Descripción](#-descripción)
* [Reglas de los cláusulazos](#-reglas-de-los-cláusulazos)
* [Características](#-características)
* [Arquitectura](#-arquitectura)
* [Tecnologías](#-tecnologías)
* [Estructura del proyecto](#-estructura-del-proyecto)
* [Requisitos](#-requisitos)
* [Instalación local](#-instalación-local)
* [Variables de entorno](#-variables-de-entorno)
* [Base de datos](#-base-de-datos)
* [Prisma](#-prisma)
* [Backend](#-backend)
* [Frontend](#-frontend)
* [Integración con LaLiga Fantasy](#-integración-con-laliga-fantasy)
* [Autenticación automática de LaLiga](#-autenticación-automática-de-laliga)
* [Sincronización de actividad](#-sincronización-de-actividad)
* [GitHub Actions](#-github-actions)
* [Despliegue](#-despliegue)
* [Producción](#-producción)
* [Seguridad](#-seguridad)
* [Flujo completo del sistema](#-flujo-completo-del-sistema)
* [Desarrollo](#-desarrollo)
* [Estado actual](#-estado-actual)

---

# 🎯 Descripción

Clausulazos nace como una alternativa organizada a la gestión de cláusulas mediante grupos de WhatsApp.

Cada participante de la liga puede realizar cláusulas sobre otros jugadores, pero existen límites para evitar que una persona pueda realizar o recibir demasiadas cláusulas simultáneamente.

La aplicación mantiene automáticamente:

* usuarios;
* cláusulas realizadas;
* cláusulas recibidas;
* fechas de creación;
* fechas de expiración;
* estado de cada cláusula;
* límites disponibles;
* actividad importada desde LaLiga Fantasy.

Además, el sistema está preparado para detectar automáticamente los movimientos realizados en la liga Fantasy.

---

# 📜 Reglas de los cláusulazos

Cada usuario tiene dos límites independientes:

### Cláusulas realizadas

Un usuario puede tener como máximo:

**2 cláusulas activas realizadas.**

Cuando alcanza las 2:

> No puede realizar otra cláusula hasta que una de las anteriores expire o sea liberada.

### Cláusulas recibidas

Un usuario puede tener como máximo:

**2 cláusulas activas recibidas.**

Cuando alcanza las 2:

> No puede recibir otra cláusula hasta que una de las anteriores expire o sea liberada.

### Duración

Cada cláusula permanece activa durante exactamente:

**7 días / 7 × 24 horas**

Ejemplo:

```text
Cláusula recibida:
1 de septiembre

Segunda cláusula:
2 de septiembre

Primera liberación:
8 de septiembre

Segunda liberación:
9 de septiembre
```

Las liberaciones son independientes para cada cláusula y se calculan a partir de su propia fecha de creación.

---

# 🚀 Características

## Usuarios

* Registro.
* Inicio de sesión.
* Autenticación mediante JWT.
* Identificación de usuarios de la liga Fantasy.
* Asociación entre usuario de Clausulazos y usuario de LaLiga Fantasy.

## Gestión de cláusulas

* Crear cláusulas.
* Controlar cláusulas realizadas.
* Controlar cláusulas recibidas.
* Limitar a 2 activas por cada categoría.
* Fecha de creación.
* Fecha de expiración.
* Estados:

  * `ACTIVE`
  * `EXPIRED`
  * `CANCELLED`

## Estadísticas

El backend calcula:

* cláusulas realizadas activas;
* cláusulas recibidas activas;
* límite máximo;
* plazas disponibles;
* próxima liberación.

Ejemplo conceptual:

```json
{
  "performed": 1,
  "received": 2,
  "limit": 2,
  "available": 1,
  "nextReleaseAt": "2026-09-20T..."
}
```

## Integración Fantasy

La aplicación puede consultar la actividad de la liga de LaLiga Fantasy y detectar automáticamente nuevos cláusulazos.

## Automatización

La sincronización se ejecuta periódicamente mediante GitHub Actions.

El backend se encarga de obtener automáticamente los tokens necesarios para acceder a LaLiga Fantasy.

---

# 🏗️ Arquitectura

La aplicación utiliza una arquitectura separada entre frontend, backend y base de datos.

```text
                    ┌──────────────────────┐
                    │      Usuario         │
                    │   PC / móvil / web   │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │   Flutter Frontend   │
                    │       Vercel         │
                    └──────────┬───────────┘
                               │ HTTP
                               ▼
                    ┌──────────────────────┐
                    │    NestJS Backend    │
                    │       Render         │
                    └──────┬───────┬───────┘
                           │       │
                    Prisma │       │ API
                           │       │
                           ▼       ▼
                  ┌────────────┐  ┌─────────────────────┐
                  │ PostgreSQL │  │ LaLiga Fantasy API  │
                  │   Render   │  │ fantasy-api.llt...  │
                  └────────────┘  └─────────────────────┘
```

---

# 🧰 Tecnologías

## Frontend

* Flutter
* Dart
* Flutter Web
* Vercel

## Backend

* Node.js
* NestJS
* TypeScript
* Prisma ORM

## Base de datos

* PostgreSQL

## Integraciones

* LaLiga Fantasy API
* OAuth 2.0 / Azure AD B2C
* GitHub Actions

## Hosting

* **Frontend:** Vercel
* **Backend:** Render
* **Base de datos:** PostgreSQL en Render
* **Repositorio:** GitHub

---

# 📁 Estructura del proyecto

```text
clausulazos/
│
├── backend/
│   │
│   ├── prisma/
│   │   ├── migrations/
│   │   ├── schema.prisma
│   │   └── seed.ts
│   │
│   ├── src/
│   │   ├── auth/
│   │   ├── fantasy/
│   │   │   ├── fantasy.controller.ts
│   │   │   ├── fantasy.module.ts
│   │   │   ├── fantasy.service.ts
│   │   │   ├── fantasy-sync.service.ts
│   │   │   └── fantasy-auth.service.ts
│   │   │
│   │   ├── prisma/
│   │   ├── users/
│   │   └── ...
│   │
│   ├── .env
│   ├── .env.example
│   ├── package.json
│   └── tsconfig.json
│
├── frontend/
│   ├── lib/
│   │   ├── core/
│   │   ├── ...
│   │
│   ├── web/
│   │   ├── index.html
│   │   ├── manifest.json
│   │   └── icons/
│   │
│   └── pubspec.yaml
│
├── .gitignore
└── README.md
```

---

# 💻 Requisitos

Para desarrollo local se necesita:

* Node.js 20+ recomendado.
* npm.
* Flutter.
* Dart incluido con Flutter.
* PostgreSQL.
* Git.

El proyecto utiliza Prisma y el backend necesita acceso a PostgreSQL.

---

# 📦 Instalación local

## 1. Clonar el repositorio

```bash
git clone https://github.com/martinperezcanada/clausulazos.git
```

Entrar al proyecto:

```bash
cd clausulazos
```

---

# 🔧 Backend

Entrar:

```powershell
cd backend
```

Instalar dependencias:

```powershell
npm install
```

---

# 🔐 Variables de entorno

Crear:

```text
backend/.env
```

A partir de:

```text
backend/.env.example
```

El archivo `.env` **no debe subirse al repositorio**.

Variables utilizadas por el backend:

```env
DATABASE_URL=...

JWT_SECRET=...

LALIGA_REFRESH_TOKEN=...
```

### `DATABASE_URL`

Cadena de conexión de PostgreSQL.

### `JWT_SECRET`

Clave utilizada para firmar los JWT de autenticación de usuarios.

### `LALIGA_REFRESH_TOKEN`

Credencial privada utilizada para renovar automáticamente las sesiones de LaLiga Fantasy.

**Nunca debe publicarse ni introducirse directamente en el código fuente.**

---

# 🗄️ Base de datos

El backend utiliza PostgreSQL junto con Prisma.

En desarrollo local se utiliza una base de datos PostgreSQL denominada:

```text
clausulazos
```

El backend se conecta mediante:

```env
DATABASE_URL=...
```

---

# 🧬 Prisma

Generar Prisma Client:

```powershell
npm run prisma:generate
```

Crear una migración durante el desarrollo:

```powershell
npx prisma migrate dev --name nombre_de_la_migracion
```

Aplicar migraciones existentes:

```powershell
npm run prisma:deploy
```

Abrir Prisma Studio:

```powershell
npx prisma studio
```

---

# 🧱 Modelos principales

## User

Representa a un usuario de Clausulazos.

Incluye información como:

* `id`
* `name`
* `email`
* `password`
* `createdAt`
* `updatedAt`

También existe la asociación con el identificador del usuario correspondiente de LaLiga Fantasy.

---

## Clause

Representa una cláusula.

Contiene:

* usuario que realiza la cláusula;
* usuario que la recibe;
* fecha de creación;
* fecha de expiración;
* estado;
* fecha de cancelación.

Estados:

```text
ACTIVE
EXPIRED
CANCELLED
```

---

## FantasyAuthToken

Modelo utilizado para mantener la autenticación automática con LaLiga Fantasy.

```text
FantasyAuthToken
```

Incluye:

```text
id
refreshToken
accessToken
accessTokenExpiresAt
refreshTokenExpiresAt
updatedAt
```

La tabla utilizada en PostgreSQL es:

```text
fantasy_auth_tokens
```

El registro principal utiliza:

```text
id = laliga
```

Esto permite que el backend conserve la sesión de LaLiga sin depender de un access token introducido manualmente.

---

# ▶️ Ejecutar el backend

Desarrollo:

```powershell
npm run start:dev
```

Build:

```powershell
npm run build
```

Producción:

```powershell
npm run start:prod
```

En Render se utiliza:

```powershell
npm run start:render
```

El script de Render ejecuta primero:

```text
prisma migrate deploy
```

y después:

```text
node dist/main
```

Por tanto, las migraciones pendientes se aplican automáticamente al arrancar el backend.

---

# 🌐 Frontend

El frontend está desarrollado con Flutter.

Entrar:

```powershell
cd frontend
```

Instalar dependencias:

```powershell
flutter pub get
```

Ejecutar en desarrollo:

```powershell
flutter run
```

Para web:

```powershell
flutter run -d chrome
```

---

# 🌍 Configuración de entornos

El frontend dispone de configuración diferenciada para desarrollo y producción.

En:

```text
frontend/lib/core/config/app_config.dart
```

El entorno de desarrollo utiliza:

```text
http://10.0.2.2:3000
```

para poder acceder al backend local desde un emulador Android.

En producción se utiliza el backend desplegado en Render:

```text
https://clausulazos.onrender.com
```

---

# 📱 Flutter Web / PWA

La aplicación está preparada para utilizarse como aplicación web y puede instalarse en dispositivos compatibles.

La carpeta:

```text
frontend/web/
```

contiene:

* `index.html`
* `manifest.json`
* iconos PWA.

Los iconos principales incluyen:

```text
Icon-192.png
Icon-512.png
```

y variantes compatibles con iconos maskable.

El manifest está configurado para una experiencia de aplicación independiente:

```text
display: standalone
```

---

# ⚽ Integración con LaLiga Fantasy

Clausulazos se conecta con la API utilizada por LaLiga Fantasy.

Host:

```text
https://fantasy-api.llt-services.com
```

La liga configurada actualmente es:

```text
League ID:
017892931
```

Competición:

```text
Competition ID:
1
```

La actividad se consulta mediante:

```text
/api/v1/competition/1/leagues/017892931/activity/0?x-lang=es
```

El backend utiliza las cabeceras necesarias para identificarse como la aplicación Fantasy.

---

# 🔐 Autenticación automática con LaLiga

Uno de los puntos más importantes del proyecto es que **no se utiliza un access token permanente introducido manualmente**.

LaLiga utiliza OAuth 2.0 mediante Azure AD B2C.

El backend dispone de:

```text
fantasy-auth.service.ts
```

Este servicio se encarga de obtener y renovar los tokens.

---

## Access token

El access token tiene una duración limitada.

Actualmente LaLiga devuelve aproximadamente:

```text
86400 segundos
```

es decir:

**24 horas.**

Por tanto, guardar únicamente el access token no sería suficiente.

---

## Refresh token

La aplicación utiliza un refresh token para obtener nuevos access tokens.

El flujo es:

```text
Refresh Token
      ↓
OAuth token endpoint
      ↓
Nuevo Access Token
      ↓
LaLiga Fantasy API
```

El refresh token también tiene una duración limitada, pero permite renovar automáticamente los access tokens mientras siga siendo válido.

La respuesta de LaLiga puede proporcionar un nuevo refresh token.

Cuando esto ocurre, el backend sustituye el anterior por el nuevo.

---

# 🔄 Funcionamiento de `FantasyAuthService`

El servicio comprueba primero si existe un registro de autenticación:

```text
fantasy_auth_tokens
```

Si existe un access token válido, lo reutiliza.

Si está próximo a caducar o ya ha caducado:

```text
refreshAccessToken()
```

solicita uno nuevo.

El backend guarda:

```text
accessToken
accessTokenExpiresAt
refreshToken
refreshTokenExpiresAt
```

en PostgreSQL.

De esta forma, el resto del backend no necesita preocuparse por la renovación.

---

# 🛡️ Ventaja del sistema

Antes:

```text
Access Token
    ↓
.env
    ↓
API LaLiga
```

Cuando expiraba:

```text
❌ Capturar token manualmente
❌ Actualizar .env
❌ Reiniciar/desplegar
```

Ahora:

```text
Refresh Token
      ↓
PostgreSQL
      ↓
FantasyAuthService
      ↓
Nuevo Access Token
      ↓
LaLiga API
```

El proceso es automático.

---

# 🔄 Sincronización Fantasy

El servicio:

```text
fantasy-sync.service.ts
```

se encarga de consultar la actividad de la liga Fantasy y detectar cláusulas.

Antes de realizar la petición obtiene el token mediante:

```typescript
const token = await this.fantasyAuthService.getAccessToken();
```

Por tanto, ningún servicio de sincronización necesita manejar directamente el refresh token.

---

# ⏱️ Fecha de inicio de sincronización

Actualmente existe una fecha de inicio configurada para evitar importar actividad histórica anterior al comienzo del sistema:

```text
2026-09-13T19:50:00+02:00
```

Las actividades anteriores a esa fecha se ignoran.

Esto evita que movimientos antiguos de la liga Fantasy se conviertan accidentalmente en cláusulas de Clausulazos.

---

# 🧠 Detección de cláusulas

El sincronizador:

1. Consulta la actividad de LaLiga Fantasy.
2. Filtra los movimientos anteriores al inicio configurado.
3. Identifica operaciones relevantes.
4. Relaciona los usuarios de LaLiga con los usuarios de Clausulazos.
5. Comprueba los límites.
6. Comprueba si el movimiento ya existe.
7. Registra la cláusula correspondiente.
8. Evita duplicados.

La sincronización devuelve información como:

```text
totalActivities
detectedClauseTransfers
skippedBeforeStart
alreadyExists
created
skippedLimit
skippedUsers
```

---

# 🌐 Endpoint de sincronización

El endpoint principal es:

```http
GET /fantasy/sync
```

En producción:

```text
https://clausulazos.onrender.com/fantasy/sync
```

Este endpoint ejecuta la sincronización de la actividad de LaLiga Fantasy.

---

# 🤖 GitHub Actions

La sincronización está automatizada mediante GitHub Actions.

Workflow:

```text
.github/workflows/
```

El objetivo es ejecutar periódicamente:

```text
https://clausulazos.onrender.com/fantasy/sync
```

La configuración actual utiliza una ejecución cada 10 minutos:

```yaml
name: Fantasy Sync

on:
  schedule:
    - cron: "*/10 * * * *"
  workflow_dispatch:

jobs:
  sync:
    runs-on: ubuntu-latest

    steps:
      - name: Ejecutar sincronización
        run: |
          curl -f https://clausulazos.onrender.com/fantasy/sync
```

También puede ejecutarse manualmente mediante:

```text
workflow_dispatch
```

---

# ☁️ Despliegue

## GitHub

Repositorio:

```text
martinperezcanada/clausulazos
```

La rama principal es:

```text
main
```

Los cambios se desarrollan localmente y se suben manualmente:

```powershell
git add .
git commit -m "Descripción del cambio"
git push origin main
```

---

# 🖥️ Backend — Render

Backend:

```text
https://clausulazos.onrender.com
```

Render se conecta con el repositorio de GitHub.

Durante el despliegue se construye el backend y se ejecutan las migraciones de Prisma mediante:

```text
prisma migrate deploy
```

El arranque de producción utiliza:

```text
prisma migrate deploy && node dist/main
```

---

# 🗃️ PostgreSQL — Render

La base de datos de producción se encuentra en PostgreSQL proporcionado por Render.

El backend recibe la conexión mediante:

```env
DATABASE_URL
```

Las migraciones se ejecutan automáticamente al arrancar el backend.

---

# 🌐 Frontend — Vercel

El frontend está desplegado en Vercel.

El proyecto utiliza:

```text
frontend/
```

como directorio raíz del proyecto Flutter Web.

La aplicación web se conecta al backend desplegado en Render.

---

# 🔒 Seguridad

Los siguientes valores son secretos:

```text
DATABASE_URL
JWT_SECRET
LALIGA_REFRESH_TOKEN
```

Nunca deben incluirse en:

* GitHub;
* README;
* código fuente;
* commits;
* capturas de pantalla;
* logs;
* respuestas de API.

El archivo:

```text
backend/.env
```

debe permanecer fuera del repositorio.

El repositorio incluye:

```text
backend/.env.example
```

para documentar las variables necesarias sin incluir valores privados.

---

# 🚨 Tokens de LaLiga

No se utiliza:

```text
LALIGA_TOKEN
```

El sistema utiliza:

```text
LALIGA_REFRESH_TOKEN
```

como credencial inicial para crear la sesión automática.

Después, los tokens obtenidos se almacenan en:

```text
fantasy_auth_tokens
```

El access token se actualiza automáticamente cuando es necesario.

**No es necesario capturar manualmente un nuevo access token.**

---

# 🔁 Flujo completo de autenticación

```text
                    ┌──────────────────┐
                    │ LALIGA_REFRESH   │
                    │     _TOKEN       │
                    └────────┬─────────┘
                             │
                             ▼
                  ┌─────────────────────┐
                  │ FantasyAuthService  │
                  └─────────┬───────────┘
                            │
                            ▼
                OAuth 2.0 / Azure AD B2C
                            │
                            ▼
                    Nuevo access token
                            │
                            ▼
                  fantasy-api.llt-services
                            │
                            ▼
                    Datos de actividad
                            │
                            ▼
                  FantasySyncService
                            │
                            ▼
                       PostgreSQL
```

---

# 🔄 Flujo completo de sincronización

```text
GitHub Actions
      │
      │ cada 10 minutos
      ▼
GET /fantasy/sync
      │
      ▼
FantasySyncService
      │
      ▼
FantasyAuthService
      │
      ├── Access Token válido
      │       ↓
      │   reutilizar
      │
      └── Access Token caducado
              ↓
          Refresh Token
              ↓
          nuevo Access Token
      │
      ▼
LaLiga Fantasy API
      │
      ▼
Actividad de la liga
      │
      ▼
Detección de cláusulas
      │
      ▼
Comprobación de usuarios
      │
      ▼
Comprobación de límites
      │
      ▼
Comprobación de duplicados
      │
      ▼
PostgreSQL
      │
      ▼
Clausulazos actualizado
```

---

# 🧪 Comprobación de producción

El sistema se ha probado directamente contra Render utilizando:

```powershell
Invoke-WebRequest https://clausulazos.onrender.com/fantasy/sync
```

La respuesta actual es:

```text
HTTP 200 OK
```

Esto confirma que:

* Render está operativo.
* La migración de `FantasyAuthToken` está aplicada.
* PostgreSQL funciona.
* El refresh token es válido.
* El backend puede renovar el access token.
* La API de LaLiga responde correctamente.
* La sincronización funciona.
* No es necesario proporcionar manualmente un access token.

---

# 🛠️ Desarrollo habitual

## Iniciar backend

```powershell
cd C:\Proyectos\clausulazos\clausulazos\backend
npm run start:dev
```

## Compilar

```powershell
npm run build
```

## Ejecutar migraciones

```powershell
npx prisma migrate dev
```

## Abrir Prisma Studio

```powershell
npx prisma studio
```

## Iniciar Flutter

```powershell
cd C:\Proyectos\clausulazos\clausulazos\frontend
flutter pub get
flutter run -d chrome
```

---

# 🔍 Comprobaciones útiles

Comprobar referencias antiguas al sistema de token:

```powershell
cd C:\Proyectos\clausulazos\clausulazos

Get-ChildItem -Path backend\src -Recurse -File |
  Select-String -Pattern "LALIGA_TOKEN"
```

La búsqueda debería no devolver resultados.

Comprobar estado de Git:

```powershell
git status
```

Comprobar historial:

```powershell
git log --oneline
```

---

# 📌 Estado actual del proyecto

Actualmente el proyecto dispone de:

### Frontend

* [x] Flutter
* [x] Flutter Web
* [x] PWA
* [x] Manifest
* [x] Iconos de aplicación
* [x] Configuración de producción
* [x] Despliegue en Vercel

### Backend

* [x] NestJS
* [x] PostgreSQL
* [x] Prisma
* [x] Autenticación
* [x] Gestión de usuarios
* [x] Gestión de cláusulas
* [x] Límites de cláusulas
* [x] Integración con LaLiga Fantasy
* [x] Sincronización automática
* [x] Renovación automática de tokens
* [x] Despliegue en Render

### Automatización

* [x] GitHub Actions
* [x] Sincronización periódica
* [x] OAuth 2.0
* [x] Refresh token
* [x] Rotación automática del refresh token
* [x] Persistencia de tokens en PostgreSQL

### Producción

* [x] GitHub
* [x] Render
* [x] PostgreSQL
* [x] Vercel
* [x] API de LaLiga funcionando
* [x] Sincronización comprobada con HTTP 200

---

# 🏁 Resultado

Clausulazos funciona como una plataforma independiente para gestionar los cláusulazos de una liga privada de Fantasy LaLiga.

El sistema combina:

```text
Flutter
   +
NestJS
   +
PostgreSQL
   +
Prisma
   +
LaLiga Fantasy API
   +
OAuth 2.0
   +
GitHub Actions
```

La parte de autenticación con LaLiga está diseñada para funcionar de forma automática:

> **El usuario no necesita volver a capturar ni introducir manualmente el access token de LaLiga.**

El backend se encarga de renovarlo y almacenarlo automáticamente, mientras que GitHub Actions mantiene la sincronización periódica de la actividad Fantasy.

---

## 🌐 Producción

**Backend**

```text
https://clausulazos.onrender.com
```

**Repositorio**

```text
https://github.com/martinperezcanada/clausulazos
```

**Frontend**

Desplegado mediante Vercel.

---

## 📄 Licencia

Proyecto privado/personal.

La utilización, distribución o modificación del proyecto queda sujeta a las condiciones que establezca su propietario.
