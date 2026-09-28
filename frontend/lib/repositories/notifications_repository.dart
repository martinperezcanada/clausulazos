import '../core/network/api_client.dart';

/// Device registration endpoint. `ApiClient` attaches the JWT, so the backend picks the owner itself
/// and no userId is sent.
class NotificationsRepository {
  NotificationsRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<void> registerDevice(
      {required String token, required String platform}) async {
    await _apiClient.dio.post('/notifications/devices', data: {
      'token': token,
      'platform': platform,
    });
  }
}
