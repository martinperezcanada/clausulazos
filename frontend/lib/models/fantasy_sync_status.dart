/// Sync health from `GET /fantasy/sync/status`, backed by the row the backend updates on each run of
/// the `/fantasy/sync` cron. `lastSuccessfulSyncAt` only moves on runs that complete, so during an
/// outage it keeps showing the last good sync.
class FantasySyncStatus {
  const FantasySyncStatus({
    this.lastSuccessfulSyncAt,
    this.lastAttemptAt,
    this.lastStatus,
  });

  final DateTime? lastSuccessfulSyncAt;
  final DateTime? lastAttemptAt;
  final String? lastStatus;

  factory FantasySyncStatus.fromJson(Map<String, dynamic> json) {
    return FantasySyncStatus(
      lastSuccessfulSyncAt: json['lastSuccessfulSyncAt'] != null
          ? DateTime.parse(json['lastSuccessfulSyncAt'] as String).toLocal()
          : null,
      lastAttemptAt: json['lastAttemptAt'] != null
          ? DateTime.parse(json['lastAttemptAt'] as String).toLocal()
          : null,
      lastStatus: json['lastStatus'] as String?,
    );
  }
}
