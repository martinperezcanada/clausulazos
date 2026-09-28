import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/webauthn/webauthn_client.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';
import '../repositories/passkeys_repository.dart';

// `backendUnreachable`: a JWT is stored but the last validation attempts failed for connectivity
// reasons (no response at all, never a 401). Different from `unauthenticated`: the token is kept and
// the app keeps retrying instead of logging out.
enum AuthStatus { unknown, authenticated, unauthenticated, backendUnreachable }

/// Phases of [AuthProvider.checkSession].
enum SessionCheckStage {
  idle,
  checkingSession,
  validatingAccess,
  reconnecting,
  done
}

/// Outcome of one attempt to validate the stored JWT; internal to `checkSession()` and its retry loop.
enum _ValidateOutcome { success, invalidSession, unreachable }

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required AuthRepository authRepository,
    required PasskeysRepository passkeysRepository,
    WebAuthnClient? webAuthnClient,
  })  : _authRepository = authRepository,
        _passkeysRepository = passkeysRepository,
        _webAuthnClient = webAuthnClient ?? const WebAuthnClient();

  final AuthRepository _authRepository;
  final PasskeysRepository _passkeysRepository;
  final WebAuthnClient _webAuthnClient;

  AuthStatus status = AuthStatus.unknown;
  SessionCheckStage sessionCheckStage = SessionCheckStage.idle;
  AppUser? currentUser;
  String? errorMessage;
  bool isLoading = false;

  Timer? _reconnectTimer;

  /// Whether this browser can attempt Face ID/passkeys. Checked once and cached, so the login screen can
  /// hide the button.
  bool get passkeysSupported => _webAuthnClient.isSupported;

  /// Called by ApiClient on a 401, the one signal that the stored JWT is invalid (the interceptor has
  /// already cleared it).
  void forceLogout() {
    _reconnectTimer?.cancel();
    currentUser = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  // The splash stays visible at least this long, so it doesn't just flash when the check is instant.
  static const _minimumSplashDuration = Duration(seconds: 3);

  Future<void> checkSession() async {
    _reconnectTimer?.cancel();

    final stopwatch = Stopwatch()..start();
    sessionCheckStage = SessionCheckStage.checkingSession;
    notifyListeners();
    final hasSession = await _authRepository.hasSession();
    if (!hasSession) {
      await _waitForMinimumSplashDuration(stopwatch);
      status = AuthStatus.unauthenticated;
      sessionCheckStage = SessionCheckStage.done;
      notifyListeners();
      return;
    }

    sessionCheckStage = SessionCheckStage.validatingAccess;
    notifyListeners();

    var outcome = await _attemptValidateSession();
    var attempt = 1;
    while (outcome == _ValidateOutcome.unreachable &&
        attempt < AppConfig.sessionCheckMaxQuickAttempts) {
      attempt++;
      sessionCheckStage = SessionCheckStage.reconnecting;
      notifyListeners();
      await Future.delayed(AppConfig.sessionCheckQuickRetryDelay);
      outcome = await _attemptValidateSession();
    }

    await _waitForMinimumSplashDuration(stopwatch);
    _applyValidateOutcome(outcome, scheduleBackgroundRetry: true);
  }

  /// One attempt to validate the stored JWT. Tells a real 401 (already cleared from storage by
  /// ApiClient's interceptor) apart from not reaching the backend at all (timeout, connection refused,
  /// DNS, a sleeping Render instance), which must never count as a logout.
  Future<_ValidateOutcome> _attemptValidateSession() async {
    try {
      final user = await _authRepository.fetchCurrentUser();
      if (user == null) return _ValidateOutcome.invalidSession;
      currentUser = user;
      return _ValidateOutcome.success;
    } on DioException catch (e) {
      return e.response?.statusCode == 401
          ? _ValidateOutcome.invalidSession
          : _ValidateOutcome.unreachable;
    } catch (_) {
      return _ValidateOutcome.unreachable;
    }
  }

  void _applyValidateOutcome(_ValidateOutcome outcome,
      {required bool scheduleBackgroundRetry}) {
    switch (outcome) {
      case _ValidateOutcome.success:
        status = AuthStatus.authenticated;
        sessionCheckStage = SessionCheckStage.done;
      case _ValidateOutcome.invalidSession:
        currentUser = null;
        status = AuthStatus.unauthenticated;
        sessionCheckStage = SessionCheckStage.done;
      case _ValidateOutcome.unreachable:
        // Keep the JWT: this is a connectivity problem, not an invalid session. Stay on Splash (see
        // AppRouter) and keep retrying in the background.
        status = AuthStatus.backendUnreachable;
        sessionCheckStage = SessionCheckStage.reconnecting;
        if (scheduleBackgroundRetry) _scheduleBackgroundRetry();
    }
    notifyListeners();
  }

  void _scheduleBackgroundRetry() {
    _reconnectTimer?.cancel();
    _reconnectTimer =
        Timer(AppConfig.sessionCheckBackgroundRetryInterval, () async {
      // Superseded by a login, logout or new checkSession() in the meantime.
      if (status != AuthStatus.backendUnreachable) return;
      final outcome = await _attemptValidateSession();
      _applyValidateOutcome(outcome, scheduleBackgroundRetry: true);
    });
  }

  Future<void> _waitForMinimumSplashDuration(Stopwatch stopwatch) async {
    final remaining = _minimumSplashDuration - stopwatch.elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
  }

  Future<bool> login({required String email, required String password}) {
    return _runAuthAction(
        () => _authRepository.login(email: email, password: password));
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) {
    return _runAuthAction(
      () => _authRepository.register(
        name: name,
        email: email,
        password: password,
        confirmPassword: confirmPassword,
      ),
    );
  }

  /// Passkey login: fetch options from the backend, run `navigator.credentials.get()` in the browser and
  /// send the signed assertion back. Produces the same session as email + password login.
  Future<bool> loginWithPasskey({String? email}) {
    return _runAuthAction(() async {
      final options =
          await _passkeysRepository.getAuthenticationOptions(email: email);
      final credentialResponse = await _webAuthnClient.authenticate(options);
      return _passkeysRepository.verifyAuthentication(credentialResponse);
    });
  }

  Future<bool> _runAuthAction(Future<AuthResult> Function() action) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await action();
      currentUser = result.user;
      status = AuthStatus.authenticated;
      return true;
    } on WebAuthnUnavailableException catch (e) {
      errorMessage = e.message;
      return false;
    } catch (e) {
      errorMessage = ApiClient.messageFromError(e);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> changePassword(
      {required String currentPassword, required String newPassword}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _authRepository.changePassword(
          currentPassword: currentPassword, newPassword: newPassword);
      return true;
    } catch (e) {
      errorMessage = ApiClient.messageFromError(e);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _reconnectTimer?.cancel();
    await _authRepository.logout();
    currentUser = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    super.dispose();
  }
}
