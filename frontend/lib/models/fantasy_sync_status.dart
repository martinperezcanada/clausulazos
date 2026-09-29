/// Sync health from `GET /fantasy/sync/status`, backed by the row the backend updates on each run of
/// the `/fantasy/sync` cron. `lastSuccessfulSyncAt` only moves on runs that complete, so during an
/// outage it keeps showing the last good sync.
class FantasySyncStatus {
  const FantasySyncStatus({
    this.lastSuccessfulSyncAt,
    this.lastAttemptAt,
    this.lastStatus,
    this.lastChangeCount = 0,
  });

  final DateTime? lastSuccessfulSyncAt;
  final DateTime? lastAttemptAt;
  final String? lastStatus;

  /// Clauses the last successful sync created, completed or reconciled; 0 when it changed nothing.
  final int lastChangeCount;

  factory FantasySyncStatus.fromJson(Map<String, dynamic> json) {
    return FantasySyncStatus(
      lastSuccessfulSyncAt: json['lastSuccessfulSyncAt'] != null
          ? DateTime.parse(json['lastSuccessfulSyncAt'] as String).toLocal()
          : null,
      lastAttemptAt: json['lastAttemptAt'] != null
          ? DateTime.parse(json['lastAttemptAt'] as String).toLocal()
          : null,
      lastStatus: json['lastStatus'] as String?,
      lastChangeCount: (json['lastChangeCount'] as num?)?.toInt() ?? 0,
    );
  }
}
