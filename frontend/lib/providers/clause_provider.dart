import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import '../models/clause.dart';
import '../repositories/clause_repository.dart';

class ClauseProvider extends ChangeNotifier {
  ClauseProvider({required ClauseRepository clauseRepository}) : _clauseRepository = clauseRepository;

  final ClauseRepository _clauseRepository;

  List<Clause> history = [];
  bool isLoading = false;
  bool isSubmitting = false;
  String? errorMessage;

  Future<void> loadHistory() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      history = await _clauseRepository.fetchAll();
    } catch (e) {
      errorMessage = ApiClient.messageFromError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Returns the created Clause on success, or null (with [errorMessage]
  /// set) if the backend rejected the operation — e.g. because the
  /// destination just filled their last slot in a race with someone else.
  Future<Clause?> makeClause(String toUserId) async {
    isSubmitting = true;
    errorMessage = null;
    notifyListeners();
    try {
      final clause = await _clauseRepository.createClause(toUserId);
      return clause;
    } catch (e) {
      errorMessage = ApiClient.messageFromError(e);
      return null;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> cancelClause(String clauseId) async {
    try {
      await _clauseRepository.cancel(clauseId);
      return true;
    } catch (e) {
      errorMessage = ApiClient.messageFromError(e);
      notifyListeners();
      return false;
    }
  }
}
