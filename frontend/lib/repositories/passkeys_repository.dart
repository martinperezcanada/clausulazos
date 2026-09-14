import '../core/network/api_client.dart';
import '../models/passkey.dart';
import '../models/user.dart';
import 'auth_repository.dart';

class PasskeysRepository {
  PasskeysRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  // ---- Registering a new passkey (must already be logged in) ----

  Future<Map<String, dynamic>> getRegistrationOptions() async {
    final response = await _apiClient.dio.post('/auth/passkeys/registration/options');
    return response.data as Map<String, dynamic>;
  }

  Future<void> verifyRegistration(Map<String, dynamic> credentialResponse, {String? name}) async {
    await _apiClient.dio.post('/auth/passkeys/registration/verify', data: {
      'response': credentialResponse,
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
    });
  }

  // ---- Logging in with a passkey (no session yet) ----

  Future<Map<String, dynamic>> getAuthenticationOptions({String? email}) async {
    final response = await _apiClient.dio.post('/auth/passkeys/authentication/options', data: {
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
    });
    return response.data as Map<String, dynamic>;
  }

  Future<AuthResult> verifyAuthentication(Map<String, dynamic> credentialResponse) async {
    final response = await _apiClient.dio.post('/auth/passkeys/authentication/verify', data: {
      'response': credentialResponse,
    });
    final data = response.data as Map<String, dynamic>;
    return AuthResult(
      token: data['accessToken'] as String,
      user: AppUser.fromJson(data['user'] as Map<String, dynamic>),
    );
  }

  // ---- Managing passkeys from the profile screen ----

  Future<List<PasskeyInfo>> list() async {
    final response = await _apiClient.dio.get('/auth/passkeys');
    return (response.data as List).map((e) => PasskeyInfo.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> delete(String id) async {
    await _apiClient.dio.delete('/auth/passkeys/$id');
  }
}
