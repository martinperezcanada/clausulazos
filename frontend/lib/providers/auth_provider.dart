import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthProvider({required AuthRepository authRepository}) : _authRepository = authRepository;

  final AuthRepository _authRepository;

  AuthStatus status = AuthStatus.unknown;
  AppUser? currentUser;
  String? errorMessage;
  bool isLoading = false;

  /// Called by ApiClient when the backend responds 401 to any request.
  void forceLogout() {
    currentUser = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> checkSession() async {
    final hasSession = await _authRepository.hasSession();
    if (!hasSession) {
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    try {
      final user = await _authRepository.fetchCurrentUser();
      currentUser = user;
      status = user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    } catch (_) {
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
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

  Future<bool> _runAuthAction(Future<AuthResult> Function() action) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await action();
      currentUser = result.user;
      status = AuthStatus.authenticated;
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
