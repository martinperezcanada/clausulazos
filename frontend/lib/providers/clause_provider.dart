import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import '../models/clause.dart';
import '../models/user.dart';
import '../repositories/clause_repository.dart';

class ClauseProvider extends ChangeNotifier {
  ClauseProvider({required ClauseRepository clauseRepository})
      : _clauseRepository = clauseRepository;

  final ClauseRepository _clauseRepository;

  List<Clause> history = [];
  bool isLoading = false;
  String? errorMessage;

  /// Ids of clauses being confirmed, for a per-card loading state.
  final Set<String> confirmingIds = {};

  /// Ids of clauses sending a reminder, for a per-card loading state.
  final Set<String> remindingIds = {};

  bool isCreating = false;

  /// Creates a clausulazo against `toUserId`. Returns true on success (the clause is prepended to
  /// `history`); on failure `errorMessage` has the backend's reason (e.g. limit reached).
  Future<bool> createClause(String toUserId) async {
    isCreating = true;
    errorMessage = null;
    notifyListeners();
    try {
      final created = await _clauseRepository.create(toUserId);
      history = [created, ...history];
      return true;
    } catch (e) {
      errorMessage = ApiClient.messageFromError(e);
      return false;
    } finally {
      isCreating = false;
      notifyListeners();
    }
  }

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

  /// Records the current user's vote on a PENDING movement. Returns true on success; refresh
  /// history/stats afterwards, since slot counts may change.
  Future<bool> confirmClassification(
      String clauseId, String classification) async {
    confirmingIds.add(clauseId);
    errorMessage = null;
    notifyListeners();
    try {
      final updated = await _clauseRepository.confirmClassification(
          clauseId, classification);
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

  /// League rule: a manager with every slot taken can't be part of another clausulazo on that side
  /// (performed slots for a movement they made, received slots for one made on them). For them such a
  /// movement can only be "pactado". `stats` are the manager's own slot figures (`/users/me/stats`).
  static bool mustBeAgreed(Clause clause, String userId, UserStats stats) =>
      clause.fromUserId == userId
          ? stats.performed.isComplete
          : stats.received.isComplete;

  /// Votes "pactado" for `userId` on every movement still waiting for them that `mustBeAgreed`, so they
  /// are never asked to choose. Call it with stats that have just been loaded.
  Future<void> agreeMovementsAtLimit(String userId, UserStats stats) async {
    final atLimit = history
        .where((c) =>
            c.needsConfirmationFrom(userId) &&
            !confirmingIds.contains(c.id) &&
            mustBeAgreed(c, userId, stats))
        .toList();
    for (final clause in atLimit) {
      await confirmClassification(clause.id, 'AGREED');
    }
  }

  /// Sends an "avisar a..." reminder to the participant who hasn't confirmed. Returns the push result (see
  /// `ClauseRepository.remindParticipant`) when the call succeeds, or null if the request failed (see
  /// `errorMessage`).
  Future<({String message, bool success, String? reason})?> remindParticipant(
      String clauseId) async {
    remindingIds.add(clauseId);
    errorMessage = null;
    notifyListeners();
    try {
      return await _clauseRepository.remindParticipant(clauseId);
    } catch (e) {
      errorMessage = ApiClient.messageFromError(e);
      return null;
    } finally {
      remindingIds.remove(clauseId);
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

  /// Admin-only: on success removes the movement from `history` locally, so the card disappears without
  /// a reload; a later `loadHistory()` confirms it server-side.
  Future<bool> adminDeleteClause(String clauseId) async {
    try {
      await _clauseRepository.adminCancel(clauseId);
      history = history.where((c) => c.id != clauseId).toList();
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = ApiClient.messageFromError(e);
      notifyListeners();
      return false;
    }
  }
}
