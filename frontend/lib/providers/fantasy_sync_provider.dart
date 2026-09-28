import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import '../models/fantasy_sync_status.dart';
import '../repositories/fantasy_repository.dart';

class FantasySyncProvider extends ChangeNotifier {
  FantasySyncProvider({required FantasyRepository fantasyRepository})
      : _fantasyRepository = fantasyRepository;

  final FantasyRepository _fantasyRepository;

  FantasySyncStatus? status;
  bool isLoading = false;

  /// True while an admin-triggered `forceSync()` is in flight; the cron doesn't go through Flutter.
  bool isForcingSync = false;

  /// Reason the last `forceSync()` failed, from `ApiClient.messageFromError`.
  String? forceSyncError;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    try {
      status = await _fantasyRepository.fetchSyncStatus();
    } catch (_) {
      // Best effort: on failure the dashboard just hides the sync line.
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Admin-only: runs the existing `/fantasy/sync` (the one the cron calls), then reloads the status from
  /// the backend whether it worked or not, so `status` always reflects what the backend recorded.
  /// Returns true if the sync request succeeded.
  Future<bool> forceSync() async {
    isForcingSync = true;
    forceSyncError = null;
    notifyListeners();
    var ok = false;
    try {
      await _fantasyRepository.triggerSync();
      ok = true;
    } catch (e) {
      forceSyncError = ApiClient.messageFromError(e);
    } finally {
      // Reload the status either way.
      await load();
      isForcingSync = false;
      notifyListeners();
    }
    return ok;
  }
}
