# CLAUSULAZOS — Estado de trabajo en `clausulazos-pruebas`

> Última actualización: sesión de implementación completa "Stitch en toda la app". Este archivo es solo de contexto de desarrollo — **no se ha hecho commit ni push de nada**.

Copia de trabajo: `C:\Proyectos\clausulazos\clausulazos-pruebas` (clon independiente del mismo repo que `clausulazos`, mismo remoto, rama `main`). **El proyecto real (`clausulazos`, sin `-pruebas`) no se ha tocado.**

---

## ESTADO ACTUAL (resumen)

Todas las pantallas principales han sido revisadas y actualizadas contra el diseño de Stitch (proyecto `Clausulazos Fantasy Manager`, `projectId 9807135412830436284`, design system "Pitch Velocity"). El sistema visual (Space Grotesk / Hanken Grotesk / JetBrains Mono, paleta verde/rojo/cian/ámbar sobre fondo oscuro, radios, tarjetas) ya estaba aplicado desde sesiones anteriores; esta sesión se centró en **estructura, componentes compartidos, cabecera consistente y datos reales** en todas las pantallas, no solo en el Dashboard.

### Componentes compartidos nuevos
- `widgets/app_top_bar.dart` — `AppTopBar`: cabecera fija reutilizada en **todas** las pantallas. En pantallas raíz de la barra inferior (Home, Actividad, Managers, Perfil) muestra marca + campana (con indicador real ligado a `needsConfirmationFrom`, nunca inventado) + avatar con iniciales. En pantallas empujadas (Clasificación, Detalle de Manager) muestra flecha atrás + título — igual que Stitch distingue ambos tipos de cabecera.
- `widgets/filter_pill.dart` — chip de filtro redondeado con contador, usado en Actividad y Managers (antes duplicado con `ChoiceChip` genérico).
- `core/theme/relative_time_formatter.dart` — "Hace 18 min" / "Ayer 21:40" / fecha corta, siempre a partir de un `createdAt` real.
- `core/theme/amount_formatter.dart` — formato "48.500.000 €" (ya existía desde el Dashboard, ahora reutilizado en `ClauseCard`).
- `widgets/dashboard/pulsing_dot.dart` — punto pulsante reutilizado fuera del Dashboard (Actividad, `AppTopBar`, `ClauseCard`).

### Pantallas revisadas esta sesión
| Pantalla | Qué se hizo |
|---|---|
| **Home / Dashboard** | Ya estaba al nivel Stitch (sesiones previas). Solo se migró su cabecera a `AppTopBar` compartido (antes tenía su propio `DashboardTopBar`, eliminado). |
| **Actividad** | Reescrita: cabecera fija, título "Actividad de Liga" + punto en vivo, subtítulo real, filtros en píldora con contador real, feed con `ClauseCard` rediseñado, separador "HISTORIAL CONFIRMADO" antes del primer movimiento no pendiente, estado vacío ilustrado ("Mercado hipervigilado" / "Sin movimientos en «X»"). **No se implementó** el "tribunal comunitario" de 6 votos que muestra Stitch — es una funcionalidad ficticia de la maqueta que no existe en las reglas reales (2 participantes confirman, no la liga entera); en su lugar se usa el flujo real de confirmación de 2 botones ya existente. |
| **Managers (Jugadores en Stitch)** | Cabecera fija, buscador, filtros en píldora reutilizada, `PlayerCard` con badge real BLINDADO/VULNERABLE (antes solo texto). El catálogo de jugadores de fútbol con puja de la pantalla "7. Jugadores" de Stitch **sigue sin implementarse a propósito** — no existe ese concepto en el proyecto real. |
| **Clasificación** | Cabecera con flecha atrás + título vía `AppTopBar`. Las 3 pestañas (Tabla General / Cupos / Récords) se mantienen intactas, ya eran reales y honestas (sin datos inventados). |
| **Detalle de Manager** | Cabecera con flecha atrás + nombre del manager vía `AppTopBar`. Resto intacto (stats reales, ejecutar cláusulazo, historial con `ClauseCard` rediseñado). |
| **Perfil** | Cabecera migrada a `AppTopBar`. Resto intacto (passkeys, cambiar contraseña, gobernanza, logout). |
| **Bienvenida (Welcome)** | Se añadió un hero card con titular/subtítulo inspirado en Stitch ("Adiós al caos de WhatsApp en tu liga…"), sin inventar datos de Fantasy ni el selector multi-liga de Stitch (no existe en el proyecto real). Las 3 tarjetas de reglas ya existían de una sesión anterior y coinciden bien con el "Reglamento Blindado" de Stitch. |
| **Login / Registro / Splash** | No se tocaron esta sesión — ya habían sido rediseñadas a fondo en una sesión previa y siguen estructuralmente alineadas con Stitch (hero, formulario, passkeys, medidor de fuerza de contraseña, reglas reales). Se revisaron contra el HTML de Stitch y no se detectaron huecos que justificaran reescribirlas. |

### `ClauseCard` — rediseño central (Actividad + Detalle de Manager)
Antes era una tarjeta genérica de texto plano. Ahora replica la tarjeta de transacción de Stitch: barra de etiqueta coloreada por tipo (PENDIENTE / CLÁUSULAZO CONFIRMADO / ACUERDO PACTADO / CANCELADO) con tiempo relativo real, jugador + ruta `de → a` + importe, y una cinta inferior contextual:
- Activo → "Blindaje activo" + `Libera en {countdown real}`.
- Liberado → fecha real de liberación.
- Acuerdo → "No computa para el límite de cláusulas" (regla real).
- Pendiente esperando al otro → texto real de espera.
- Pendiente y me toca confirmar → los mismos 2 botones reales (Cláusulazo / Acuerdo) con diálogo de confirmación que ya existían, solo reestilizados.

---

## LO QUE NO SE HA IMPLEMENTADO (a propósito, documentado)

Estas partes de Stitch representan funcionalidad que **no existe en las reglas reales del proyecto** y que sesiones anteriores ya decidieron no implementar. Esta sesión mantiene esa decisión:

1. **Multi-liga** (selector de "Liga Privada Activa" en Welcome) — el proyecto real trabaja sobre una única liga hardcodeada en el backend.
2. **Catálogo de jugadores de fútbol con puja** (pantalla "7. Jugadores" de Stitch) — el proyecto real es manager↔manager, no manager↔jugador de fútbol.
3. **"Tribunal comunitario" / votación de quórum (4/6 votos)** en Actividad — las reglas reales usan confirmación de los 2 participantes (`fromConfirmation`/`toConfirmation`), no votación de toda la liga. Implementarlo habría alterado las reglas de negocio reales, cosa que se pidió explícitamente no hacer.
4. **Fotos reales de jugadores/managers** — Stitch usa fotos de stock; el proyecto usa avatares con iniciales (equivalente visual más cercano sin inventar imágenes).
5. **Nombre de equipo Fantasy** ("Rayo Vallecano FC" en el saludo de Stitch) — no hay campo fiable para esto en el modelo `User` ni confirmado en el payload de LALIGA; se omite en vez de inventarlo (decisión ya tomada en la sesión del Dashboard).
6. **Clasificación y Liberaciones como accesos rápidos del Dashboard** — pospuesto explícitamente a una fase posterior, por instrucción directa.

---

## LALIGA FANTASY — sigue igual que antes

Sin cambios esta sesión. La sincronización automática (`FantasySyncStatus`, `GET /fantasy/sync/status`, GitHub Actions "Fantasy Sync" cada 10 min) ya se implementó por completo en la sesión del Dashboard y sigue funcionando igual — no se ha tocado backend ni Prisma en esta sesión. Lo que sigue sin confirmar (shape exacto de `standing`, nombre de jugador 100% fiable, puntos/presupuesto Fantasy) sigue igual de documentado que antes en las pantallas que lo usan (Clasificación, tarjetas de cláusula muestran "un jugador" cuando no hay nombre).

---

## ARCHIVOS MODIFICADOS/CREADOS ESTA SESIÓN

**Nuevos:**
- `frontend/lib/widgets/app_top_bar.dart`
- `frontend/lib/widgets/filter_pill.dart`
- `frontend/lib/core/theme/relative_time_formatter.dart`

**Eliminado:**
- `frontend/lib/widgets/dashboard/dashboard_top_bar.dart` (sustituido por `AppTopBar`, genérico y reutilizado en toda la app).

**Modificados:**
- `frontend/lib/screens/home/home_screen.dart` (usa `AppTopBar`)
- `frontend/lib/screens/activity/activity_screen.dart` (reescrita)
- `frontend/lib/screens/players/players_screen.dart` (reescrita)
- `frontend/lib/screens/standings/standings_screen.dart` (cabecera)
- `frontend/lib/screens/managers/manager_detail_screen.dart` (cabecera)
- `frontend/lib/screens/profile/profile_screen.dart` (cabecera)
- `frontend/lib/screens/auth/welcome_screen.dart` (hero card añadido)
- `frontend/lib/widgets/clause_card.dart` (rediseño completo)
- `frontend/lib/widgets/player_card.dart` (badge blindado/vulnerable)

**Backend / Prisma:** sin cambios esta sesión (todo lo necesario ya existía de la sesión anterior del Dashboard).

---

## VALIDACIÓN

**`flutter analyze`:** 0 errores, 0 warnings. Quedan los mismos `info` preexistentes de `deprecated_member_use` (`withOpacity`) que ya eran baseline aceptado del proyecto antes de esta sesión, ahora también presentes en los archivos nuevos por seguir el mismo patrón que el resto del código.

**`npm run build` (backend):** no ejecutado — no hubo cambios de backend ni de Prisma esta sesión, así que no aplica según la propia validación pedida ("si modificas backend/Prisma"). Un intento de build falló por un `EPERM` de Windows al bloquear el motor de Prisma porque el backend ya estaba corriendo en otro proceso (`npm run start:dev`) — no relacionado con ningún cambio de esta sesión.

**Verificación visual en navegador/emulador:** no realizada esta sesión (solo análisis estático). Sigue siendo el paso más importante pendiente, igual que tras la sesión del Dashboard.

---

## PRÓXIMO PASO

1. **Verificar visualmente** las pantallas rediseñadas esta sesión (Actividad, Managers, Clasificación, Detalle de Manager, Perfil, Welcome) en `flutter run -d chrome`, especialmente el nuevo `ClauseCard` en distintos estados (pendiente que me toca confirmar, pendiente esperando al otro, cláusulazo activo con cooldown, cláusulazo liberado, acuerdo, cancelado).
2. Si algo no convence visualmente, pasar pantalla por pantalla ajustando fidelidad fina (sombras, glow, algún detalle de Stitch no reproducido al 100%).
3. Decidir si merece la pena mostrar el nombre real de equipo Fantasy en el saludo del Dashboard, si en algún momento se confirma un campo fiable para ello.
4. Si se consigue un `LALIGA_TOKEN` real de prueba, seguir con lo ya documentado: confirmar shape de `standing` y nombre de jugador fiable.

---

## PROBLEMAS CONOCIDOS

1. `backend/.env` (no versionado) sigue necesitando `CORS_ORIGINS` actualizado al puerto real de Flutter Web si cambia entre sesiones.
2. El backend ya estaba corriendo en otro proceso durante esta sesión, lo que bloqueó un intento de `npm run build`; no se ha forzado el cierre de ese proceso para no interrumpir el entorno del usuario.
3. Todos los datos de Fantasy no confirmados (ver sección LALIGA FANTASY) siguen siendo la limitación externa principal — no es un bug, es información que no podemos obtener sin un token real de prueba.
