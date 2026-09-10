import '../core/network/api_client.dart';
import '../core/storage/token_storage.dart';
import '../models/user.dart';

class AuthResult {
  AuthResult({required this.token, required this.user});
  final String token;
  final AppUser user;
}

class AuthRepository {
  AuthRepository({required ApiClient apiClient, required TokenStorage tokenStorage})
      : _apiClient = apiClient,
        _tokenStorage = tokenStorage;

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    final response = await _apiClient.dio.post('/auth/register', data: {
      'name': name,
      'email': email,
      'password': password,
      'confirmPassword': confirmPassword,
    });
    return _handleAuthResponse(response.data as Map<String, dynamic>);
  }

  Future<AuthResult> login({required String email, required String password}) async {
    final response = await _apiClient.dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return _handleAuthResponse(response.data as Map<String, dynamic>);
  }

  Future<AppUser?> fetchCurrentUser() async {
    final token = await _tokenStorage.readToken();
    if (token == null) return null;
    final response = await _apiClient.dio.get('/auth/me');
    return AppUser.fromJson(response.data as Map<String, dynamic>);
  }

  Future<bool> hasSession() async {
    final token = await _tokenStorage.readToken();
    return token != null;
  }

  Future<void> logout() => _tokenStorage.clearToken();

  Future<AuthResult> _handleAuthResponse(Map<String, dynamic> data) async {
    final token = data['accessToken'] as String;
    await _tokenStorage.saveToken(token);
    final user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
    return AuthResult(token: token, user: user);
  }
}
