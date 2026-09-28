import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../repositories/user_repository.dart';

class UserProvider extends ChangeNotifier {
  UserProvider({required UserRepository userRepository})
      : _userRepository = userRepository;

  final UserRepository _userRepository;

  List<AppUser> players = [];
  UserStats? myStats;
  AppUser? me;
  bool isLoading = false;
  String? errorMessage;

  /// Admin-only: accounts awaiting approval (see `loadPendingUsers()`). Empty for regular users.
  List<AppUser> pendingUsers = [];
  bool isLoadingPending = false;

  /// Refreshes everything Home/Players need. Call it when the app returns to the foreground or on pull to
  /// refresh: a slot may have expired in the meantime.
  Future<void> refreshAll() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _userRepository.fetchMe(),
        _userRepository.fetchMyStats(),
        _userRepository.fetchOtherPlayers(),
      ]);
      me = results[0] as AppUser;
      myStats = results[1] as UserStats;
      players = results[2] as List<AppUser>;
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshStatsOnly() async {
    try {
      myStats = await _userRepository.fetchMyStats();
      notifyListeners();
    } catch (_) {
      // best-effort; a full refreshAll() will surface errors properly
    }
  }

  /// Admin-only: loads accounts awaiting approval. For a non-admin the backend answers 403 and this fails
  /// silently, like `refreshStatsOnly()`; Managers only calls it in admin mode.
  Future<void> loadPendingUsers() async {
    isLoadingPending = true;
    notifyListeners();
    try {
      pendingUsers = await _userRepository.fetchPendingUsers();
    } catch (_) {
      pendingUsers = [];
    } finally {
      isLoadingPending = false;
      notifyListeners();
    }
  }

  /// Returns true on success; call `refreshAll()` afterwards so the approved manager shows up.
  Future<bool> approveUser(String id) async {
    try {
      await _userRepository.approveUser(id);
      pendingUsers = pendingUsers.where((u) => u.id != id).toList();
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectUser(String id) async {
    try {
      await _userRepository.rejectUser(id);
      pendingUsers = pendingUsers.where((u) => u.id != id).toList();
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
