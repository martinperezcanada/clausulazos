import '../core/network/api_client.dart';
import '../models/clause.dart';

class ClauseRepository {
  ClauseRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<Clause>> fetchAll() async {
    final response = await _apiClient.dio.get('/clauses');
    return (response.data as List).map((e) => Clause.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Clause>> fetchMine() async {
    final response = await _apiClient.dio.get('/clauses/me');
    return (response.data as List).map((e) => Clause.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// `classification` must be 'CLAUSE' or 'AGREED' — the backend rejects
  /// anything else and re-checks that the caller is actually a participant.
  Future<Clause> confirmClassification(String clauseId, String classification) async {
    final response = await _apiClient.dio.patch(
      '/clauses/$clauseId/classification',
      data: {'classification': classification},
    );
    return Clause.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> cancel(String clauseId) async {
    await _apiClient.dio.delete('/clauses/$clauseId');
  }
}
