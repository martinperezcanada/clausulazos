import '../core/network/api_client.dart';

/// Talks to GET /fantasy/standings, which proxies LALIGA Fantasy's own
/// standings data as-is. We deliberately don't force it into a rigid
/// model: the exact fields LALIGA returns aren't something we control or
/// have been able to fully pin down, so the screen reads this generically
/// and shows whatever's actually there instead of assuming a fixed shape.
class FantasyRepository {
  FantasyRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<dynamic> fetchStandings() async {
    final response = await _apiClient.dio.get('/fantasy/standings');
    return response.data;
  }
}
