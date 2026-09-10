import '../core/network/api_client.dart';
import '../models/clause.dart';

class ClauseRepository {
  ClauseRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<Clause> createClause(String toUserId) async {
    final response = await _apiClient.dio.post('/clauses', data: {'toUserId': toUserId});
    return Clause.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<Clause>> fetchAll() async {
    final response = await _apiClient.dio.get('/clauses');
    return (response.data as List).map((e) => Clause.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Clause>> fetchMine() async {
    final response = await _apiClient.dio.get('/clauses/me');
    return (response.data as List).map((e) => Clause.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> cancel(String clauseId) async {
    await _apiClient.dio.delete('/clauses/$clauseId');
  }
}
