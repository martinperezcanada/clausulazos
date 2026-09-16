import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import '../core/webauthn/webauthn_client.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';
import '../repositories/passkeys_repository.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Real, observable phases of [AuthProvider.checkSession] — used only so
/// the Splash screen can show genuine progress instead of a fake timer.
enum SessionCheckStage { idle, checkingSession, validatingAccess, done }

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

  /// Whether this browser can even attempt Face ID/Passkeys — checked
  /// once and cached, so the login screen can hide the button entirely
  /// instead of showing something that will just fail.
  bool get passkeysSupported => _webAuthnClient.isSupported;

  /// Called by ApiClient when the backend responds 401 to any request.
  void forceLogout() {
    currentUser = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  // The Splash screen must stay visible at least this long, so its
  // progress bar has time to be seen even when the real check is instant.
  static const _minimumSplashDuration = Duration(seconds: 3);

  Future<void> checkSession() async {
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
    AuthStatus resolvedStatus;
    try {
      final user = await _authRepository.fetchCurrentUser();
      currentUser = user;
      resolvedStatus = user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    } catch (_) {
      resolvedStatus = AuthStatus.unauthenticated;
    }
    await _waitForMinimumSplashDuration(stopwatch);
    status = resolvedStatus;
    sessionCheckStage = SessionCheckStage.done;
    notifyListeners();
  }

  Future<void> _waitForMinimumSplashDuration(Stopwatch stopwatch) async {
    final remaining = _minimumSplashDuration - stopwatch.elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
  }

  Future<bool> login({required String email, required String password}) {
    return _runAuthAction(() => _authRepository.login(email: email, password: password));
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

  /// Full passkey login ceremony: fetch options from the backend, run
  /// `navigator.credentials.get()` in the browser, then send the signed
  /// assertion back to be verified. On success this produces exactly the
  /// same session (JWT + user) as email+password login.
  Future<bool> loginWithPasskey({String? email}) {
    return _runAuthAction(() async {
      final options = await _passkeysRepository.getAuthenticationOptions(email: email);
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

  Future<bool> changePassword({required String currentPassword, required String newPassword}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _authRepository.changePassword(currentPassword: currentPassword, newPassword: newPassword);
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
    await _authRepository.logout();
    currentUser = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
