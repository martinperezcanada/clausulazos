import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

const _tag = '[NotificationService]';

/// Background isolate entry point for pushes received while the app is backgrounded or terminated.
/// Must be a top-level function annotated with `@pragma('vm:entry-point')` so tree-shaking keeps it in
/// release builds. The isolate shares no state with the app, so it initializes Firebase itself. It
/// doesn't call our backend.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint(
      '$_tag FCM background message received: id=${message.messageId} data=${message.data}');
}

// Log only a token prefix.
String _maskToken(String token) => token.length <= 8
    ? '****'
    : '${token.substring(0, 4)}…${token.substring(token.length - 4)}';

/// Firebase Cloud Messaging setup: permissions, the device token, the three ways a push can reach the
/// app (foreground, tapped from background, tapped from a cold start) and, after [attachBackend],
/// registering the token with `POST /notifications/devices` for the logged-in user.
///
/// Every step is guarded: failures are caught and logged, and never block login, navigation or startup.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  bool _initialized = false;

  /// Debug-only access to the token; never logged in full, see [_maskToken].
  String? _lastKnownToken;
  String? get lastKnownToken => _lastKnownToken;

  // Set by `attachBackend()` once ApiClient/AuthProvider exist. Plain closures keep this file a pure
  // Firebase Messaging wrapper.
  Future<void> Function(String token, String platform)? _registerDevice;
  bool Function()? _isAuthenticated;

  // Avoids re-sending the same (token, user) pair on every AuthProvider notification. Cleared when the
  // session ends, so the next login registers again.
  String? _lastRegisteredKey;

  // Set by `attachNavigation()` once the GoRouter exists (after `initialize()` has started from
  // `main()`). A closure keeps go_router out of this file.
  void Function(String route)? _navigateTo;

  // A tap resolved by `getInitialMessage()` (cold start) before `attachNavigation()` ran; replayed once
  // it does.
  RemoteMessage? _pendingOpenedMessage;

  // Avoids navigating twice for the same tap if a message comes through both `getInitialMessage()` and
  // `onMessageOpenedApp`.
  String? _lastHandledMessageId;

  /// Call once after `Firebase.initializeApp()` and before `runApp`, but don't await it there: the
  /// permission request and token fetch can be slow (on Web without a VAPID key) and aren't needed for the
  /// first frame.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    debugPrint('$_tag initialize() starting');

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _requestPermission();
    await getToken();

    _messaging.onTokenRefresh.listen(
      _handleTokenRefresh,
      onError: (Object error) =>
          debugPrint('$_tag onTokenRefresh error: $error'),
    );

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // App launched by tapping a notification while terminated; handled like a tap from background.
    try {
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }
    } catch (error) {
      debugPrint('$_tag getInitialMessage error: $error');
    }

    debugPrint('$_tag initialize() finished');
  }

  /// Connects the service to the backend and the session state. Called once from `main.dart` after
  /// ApiClient/AuthProvider exist. Safe to call before a token or session exists, or more than once
  /// (e.g. on hot restart).
  void attachBackend({
    required Future<void> Function(String token, String platform)
        registerDevice,
    required bool Function() isAuthenticated,
  }) {
    _registerDevice = registerDevice;
    _isAuthenticated = isAuthenticated;
    unawaited(_maybeRegisterDevice());
  }

  /// Connects the service to the app's GoRouter. Called from `_ClausulazosAppState.initState()` right
  /// after the router is built, which is after `initialize()` started, so a tap at cold start may have
  /// resolved with nowhere to go. Replays that pending tap.
  void attachNavigation(void Function(String route) navigateTo) {
    _navigateTo = navigateTo;

    final pending = _pendingOpenedMessage;
    if (pending == null) return;
    _pendingOpenedMessage = null;

    final route = _routeFor(pending);
    if (route != null) navigateTo(route);
  }

  /// Call whenever the auth state changes. Does nothing without a session or a token; a pending token
  /// stays in [_lastKnownToken] and is registered on the next run after a session exists.
  void notifyAuthStateChanged() {
    if (_isAuthenticated?.call() != true) {
      // Logged out: forget the last registration so the next login, even with the same device token
      // (another account on this device), sends it again.
      _lastRegisteredKey = null;
      return;
    }
    unawaited(_maybeRegisterDevice());
  }

  Future<void> _maybeRegisterDevice() async {
    final token = _lastKnownToken;
    final register = _registerDevice;
    if (token == null || register == null) return;
    if (_isAuthenticated?.call() != true) return;

    final platform = _platformName();
    final key = '$token|$platform';
    if (_lastRegisteredKey == key) return;

    try {
      await register(token, platform);
      _lastRegisteredKey = key;
      debugPrint(
          '$_tag Device token registered with backend (platform=$platform, token=${_maskToken(token)})');
    } catch (error) {
      // Not shown to the user: a failed registration mustn't block login or navigation.
      debugPrint('$_tag Failed to register device token with backend: $error');
    }
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'other';
    }
  }

  Future<void> _requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
          alert: true, badge: true, sound: true);
      debugPrint(
          '$_tag Notification permission status: ${settings.authorizationStatus}');
    } catch (error) {
      debugPrint('$_tag requestPermission error: $error');
    }
  }

  /// Reads the current FCM token. On Web it needs a VAPID key (Firebase Console > Project Settings >
  /// Cloud Messaging > Web Push certificates), which isn't configured yet, so `null` is expected there.
  Future<String?> getToken() async {
    try {
      final token = await _messaging.getToken();
      _lastKnownToken = token;
      if (token != null) {
        debugPrint('$_tag FCM token obtained: ${_maskToken(token)}');
        unawaited(_maybeRegisterDevice());
      } else {
        debugPrint(
            '$_tag FCM token unavailable (expected on Web until a real VAPID key is configured)');
      }
      return token;
    } catch (error) {
      debugPrint('$_tag getToken error: $error');
      return null;
    }
  }

  void _handleTokenRefresh(String token) {
    _lastKnownToken = token;
    debugPrint('$_tag FCM token refreshed: ${_maskToken(token)}');
    unawaited(_maybeRegisterDevice());
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint(
      '$_tag FCM foreground message received: id=${message.messageId} '
      'title=${message.notification?.title} body=${message.notification?.body} data=${message.data}',
    );
    // No in-app banner yet; Activity already shows pending movements.
  }

  /// Fired when the user taps a notification (from background, or once
  /// up front from `getInitialMessage()` on a cold start).
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint(
        '$_tag FCM notification opened app: id=${message.messageId} data=${message.data}');

    final messageId = message.messageId;
    if (messageId != null && messageId == _lastHandledMessageId) {
      // This tap was already handled.
      return;
    }
    _lastHandledMessageId = messageId;

    final route = _routeFor(message);
    if (route == null) return;

    final navigateTo = _navigateTo;
    if (navigateTo != null) {
      navigateTo(route);
    } else {
      // Router not attached yet (this runs from `initialize()` in `main()`); replayed once it is.
      _pendingOpenedMessage = message;
    }
  }

  /// Route a tapped notification opens: the backend's `data.route` (sent by `POST /clauses/:id/remind`),
  /// falling back to `/activity` for a `pending_confirmation` push.
  String? _routeFor(RemoteMessage message) {
    final route = message.data['route'] as String?;
    if (route != null && route.isNotEmpty) return route;
    if (message.data['type'] == 'pending_confirmation') return '/activity';
    return null;
  }
}
