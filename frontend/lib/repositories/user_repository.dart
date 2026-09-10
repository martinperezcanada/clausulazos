import '../core/network/api_client.dart';
import '../models/user.dart';

class UserRepository {
  UserRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<AppUser>> fetchOtherPlayers() async {
    final response = await _apiClient.dio.get('/users');
    return (response.data as List)
        .map((e) => AppUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AppUser> fetchMe() async {
    final response = await _apiClient.dio.get('/users/me');
    return AppUser.fromJson(response.data as Map<String, dynamic>);
  }

  Future<UserStats> fetchMyStats() async {
    final response = await _apiClient.dio.get('/users/me/stats');
    return UserStats.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AppUser> fetchUser(String id) async {
    final response = await _apiClient.dio.get('/users/$id');
    return AppUser.fromJson(response.data as Map<String, dynamic>);
  }
}
