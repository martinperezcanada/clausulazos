import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import '../models/clause.dart';
import '../repositories/clause_repository.dart';

class ClauseProvider extends ChangeNotifier {
  ClauseProvider({required ClauseRepository clauseRepository}) : _clauseRepository = clauseRepository;

  final ClauseRepository _clauseRepository;

  List<Clause> history = [];
  bool isLoading = false;
  String? errorMessage;

  /// Ids of clauses currently being confirmed, so the UI can show a
  /// per-card loading state instead of blocking the whole screen.
  final Set<String> confirmingIds = {};

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

  /// Records the current user's vote on what a PENDING movement was.
  /// Returns true on success — the caller should refresh history/stats
  /// afterwards, since this may also change the requester's slot counts.
  Future<bool> confirmClassification(String clauseId, String classification) async {
    confirmingIds.add(clauseId);
    errorMessage = null;
    notifyListeners();
    try {
      final updated = await _clauseRepository.confirmClassification(clauseId, classification);
      final index = history.indexWhere((c) => c.id == clauseId);
      if (index != -1) {
        history[index] = updated;
      }
      return true;
    } catch (e) {
      errorMessage = ApiClient.messageFromError(e);
      return false;
    } finally {
      confirmingIds.remove(clauseId);
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
