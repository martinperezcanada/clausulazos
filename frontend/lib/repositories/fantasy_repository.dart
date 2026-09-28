import '../core/network/api_client.dart';
import '../models/fantasy_debt.dart';
import '../models/fantasy_sync_status.dart';

/// Talks to GET /fantasy/standings, which proxies LALIGA Fantasy's standings as-is. The response isn't
/// forced into a fixed model because LALIGA's fields aren't under our control, so the screen reads it
/// generically.
class FantasyRepository {
  FantasyRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<dynamic> fetchStandings() async {
    final response = await _apiClient.dio.get('/fantasy/standings');
    return response.data;
  }

  /// Accumulated debt per manager, plus the jornadas still missing a finished match that were excluded
  /// (`GET /fantasy/debts`, computed server-side by `FantasySyncService.getLeagueDebts()`).
  Future<FantasyDebtsSnapshot> fetchDebts() async {
    final response = await _apiClient.dio.get('/fantasy/debts');
    final data = response.data;
    if (data is! Map)
      return const FantasyDebtsSnapshot(managers: [], pendingWeeks: []);
    return FantasyDebtsSnapshot.fromJson(Map<String, dynamic>.from(data));
  }

  /// Feeds the chart under "Tabla general" (`GET /fantasy/debts/history`), computed with the same scan and
  /// rule as `fetchDebts()`.
  Future<FantasyDebtHistory> fetchDebtsHistory() async {
    final response = await _apiClient.dio.get('/fantasy/debts/history');
    final data = response.data;
    if (data is! Map)
      return const FantasyDebtHistory(pendingWeeks: [], points: []);
    return FantasyDebtHistory.fromJson(Map<String, dynamic>.from(data));
  }

  /// Status of the "Fantasy Sync" cron, from the backend's persisted `FantasySyncStatus` row.
  Future<FantasySyncStatus> fetchSyncStatus() async {
    final response = await _apiClient.dio.get('/fantasy/sync/status');
    return FantasySyncStatus.fromJson(response.data as Map<String, dynamic>);
  }

  /// Admin-only: triggers one run of `GET /fantasy/sync`, the same endpoint the cron calls every 10
  /// minutes. It is reachable without a JWT on purpose (the cron has none); the UI control is only shown
  /// in Modo Admin.
  Future<void> triggerSync() async {
    await _apiClient.dio.get('/fantasy/sync');
  }
}
