import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../repositories/user_repository.dart';

class UserProvider extends ChangeNotifier {
  UserProvider({required UserRepository userRepository}) : _userRepository = userRepository;

  final UserRepository _userRepository;

  List<AppUser> players = [];
  UserStats? myStats;
  AppUser? me;
  bool isLoading = false;
  String? errorMessage;

  /// Refreshes everything Home/Players need. Call this whenever the app
  /// comes back to foreground or the user pulls to refresh — a slot may
  /// have expired while the app was in the background (rule #35).
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
}
