# Clausulazos — Frontend (Flutter)

App móvil (Material 3, tema oscuro/deportivo) que consume el backend de
Clausulazos.

## ⚠️ Nota sobre este entorno de construcción

Este código Dart se ha escrito completo y a mano siguiendo la arquitectura
pedida, pero **no ha podido compilarse ni analizarse** dentro del sandbox
usado para construir el proyecto: no hay Flutter SDK instalado y el acceso
de red a `pub.dev` (el registro de paquetes de Dart/Flutter) está
bloqueado por la política de red del contenedor. Por tanto, a diferencia
del backend (que sí se pudo `tsc --noEmit` y cuyo algoritmo de
concurrencia se validó contra Postgres real), este frontend no se ha
podido verificar en ejecución aquí.

En tu máquina, con Flutter instalado normalmente, el primer paso es:

```bash
cd frontend
flutter create . --platforms=android,ios   # genera android/, ios/, etc. que faltan en este entregable
flutter pub get
flutter run
```

(El comando `flutter create .` sobre un proyecto existente conserva
`lib/`, `pubspec.yaml`, etc. y solo rellena las carpetas de plataforma que
no se incluyen en este entregable porque requieren las herramientas
nativas de Flutter para generarse correctamente.)

## Stack

- Flutter + Dart, null safety
- Material 3
- `provider` para estado
- `go_router` para navegación (con redirect automático según sesión)
- `dio` para HTTP, con interceptor de JWT y manejo global de 401
- `flutter_secure_storage` para guardar el token

## Estructura

```
lib/
  main.dart                    # bootstrap: DI manual + MultiProvider + MaterialApp.router
  core/
    config/app_config.dart     # API_BASE_URL centralizada (dev/prod)
    theme/                     # tema oscuro + formateador de fechas de liberación
    network/api_client.dart    # Dio + interceptor JWT + manejo de 401
    routing/app_router.dart    # go_router + redirects según sesión
    storage/token_storage.dart # flutter_secure_storage
  models/                      # AppUser, UserStats, Clause
  repositories/                # Auth/User/Clause — únicos que hablan con la API
  providers/                   # AuthProvider, UserProvider, ClauseProvider
  screens/                     # splash, auth, home, clauses, activity, players, profile
  widgets/                     # StatCard, PlayerCard, ClauseCard, PrimaryButton, LockedButton
```

## Configuración de API_BASE_URL

Todo pasa por `lib/core/config/app_config.dart`. Por defecto apunta a
`http://10.0.2.2:3000` (cómo el emulador de Android accede al `localhost`
de tu máquina). Cambia `AppConfig.environment` a `production` y ajusta la
URL de producción cuando toque desplegar.

## Autenticación y sesión

- El JWT se guarda con `flutter_secure_storage` (nunca en texto plano ni
  en memoria compartida).
- `ApiClient` añade el header `Authorization: Bearer <token>` a toda
  petición automáticamente.
- Si el backend responde 401 en cualquier momento, `ApiClient` borra el
  token y notifica a `AuthProvider`, que fuerza la vuelta a Login gracias
  al `redirect` de `go_router` (que escucha `AuthProvider` vía
  `refreshListenable`).

## Refresco de datos (regla #35)

`HomeScreen`, `PlayersScreen` y `SelectPlayerScreen` vuelven a pedir datos
al backend:
- al entrar en la pantalla,
- con pull-to-refresh,
- y `HomeScreen` además observa `WidgetsBindingObserver` para refrescar
  automáticamente cuando la app vuelve a primer plano — así una plaza que
  ha expirado mientras la app estaba en segundo plano se refleja sin que
  el usuario tenga que hacer nada.

## Backend como autoridad (regla #9)

El backend es quien decide si un cláusulazo es válido. La UI muestra
candados/deshabilita botones como ayuda visual, pero el botón "CONFIRMAR
CLÁUSULAZO" siempre hace la petición real: si el backend la rechaza (por
ejemplo, por una condición de carrera resuelta a favor de otro jugador),
`ConfirmClauseScreen` muestra el error tal cual lo devuelve la API, no
un mensaje inventado en el cliente.

## Tests

```bash
flutter test
```

Cubren:
- Modelo `Clause.isActiveAt` (activo, expirado, cancelado, expiración exacta)
- `ReleaseTimeFormatter` (hoy / mañana / en N días / disponible)
- `StatCard` en 0/2, 1/2 y 2/2 (candado + "COMPLETO")
- `PrimaryButton` deshabilitado / cargando
- `PlayerCard` bloqueado vs. disponible (según plazas recibidas)
- Validación de formularios de Login y Registro

## Decisiones técnicas relevantes

- **DI manual sin paquete adicional** (`get_it`, etc.): con solo 3
  repositorios y 3 providers, construirlos a mano en `main.dart` y
  exponerlos con `MultiProvider` es más simple y igual de mantenible.
- **`go_router` con `refreshListenable: authProvider`**: centraliza toda
  la lógica de "a dónde puedo navegar según mi sesión" en un único sitio
  (`redirect`), en vez de repetir comprobaciones en cada pantalla.
- **`AppUser.stats` opcional dentro del propio modelo de usuario**: el
  backend ya devuelve las stats embebidas en `GET /users`, así que no
  hace falta una petición aparte por jugador para pintar `PlayersScreen`
  o `SelectPlayerScreen`.
