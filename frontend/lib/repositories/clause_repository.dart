import '../core/network/api_client.dart';
import '../models/clause.dart';

class ClauseRepository {
  ClauseRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// Creates a clausulazo against `toUserId` (`fromUserId` comes from the JWT). The backend enforces the
  /// 2/2 limits atomically, so this can fail with a validation error if a side is full.
  Future<Clause> create(String toUserId) async {
    final response =
        await _apiClient.dio.post('/clauses', data: {'toUserId': toUserId});
    return Clause.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<Clause>> fetchAll() async {
    final response = await _apiClient.dio.get('/clauses');
    return (response.data as List)
        .map((e) => Clause.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Clause>> fetchMine() async {
    final response = await _apiClient.dio.get('/clauses/me');
    return (response.data as List)
        .map((e) => Clause.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `classification` must be 'CLAUSE' or 'AGREED'; the backend rejects anything else and checks the
  /// caller is a participant.
  Future<Clause> confirmClassification(
      String clauseId, String classification) async {
    final response = await _apiClient.dio.patch(
      '/clauses/$clauseId/classification',
      data: {'classification': classification},
    );
    return Clause.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> cancel(String clauseId) async {
    await _apiClient.dio.delete('/clauses/$clauseId');
  }

  /// Admin-only removal of any movement, through a separate `AdminGuard`-protected route (the backend
  /// checks the real user's email).
  Future<void> adminCancel(String clauseId) async {
    await _apiClient.dio.delete('/clauses/$clauseId/admin');
  }

  /// "Avisar a...": asks the backend to remind the participant who hasn't confirmed a PENDING movement
  /// and to push an FCM notification if they have a registered device
  /// (`ClausesController.remindParticipant`). `success`/`reason` describe the push outcome (`reason` is
  /// `NO_DEVICE`, `NOT_CONFIGURED` or `SEND_FAILED` when `success` is false); the reminder is recorded
  /// either way.
  Future<({String message, bool success, String? reason})> remindParticipant(
      String clauseId) async {
    final response = await _apiClient.dio.post('/clauses/$clauseId/remind');
    final data = response.data as Map<String, dynamic>;
    return (
      message: data['message'] as String,
      success: data['success'] as bool? ?? false,
      reason: data['reason'] as String?,
    );
  }
}
