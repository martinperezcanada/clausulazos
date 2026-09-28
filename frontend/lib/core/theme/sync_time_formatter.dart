/// Formats a past sync timestamp as "Sincronizado hace X min". Pass `lastSuccessfulSyncAt`, or null when
/// there is no successful sync yet.
class SyncTimeFormatter {
  SyncTimeFormatter._();

  static String describe(DateTime? lastSuccessfulSyncAt, {DateTime? now}) {
    if (lastSuccessfulSyncAt == null) return 'Sin sincronizar todavía';

    final nowTime = now ?? DateTime.now();
    final diff = nowTime.difference(lastSuccessfulSyncAt);

    if (diff.isNegative || diff.inSeconds < 60) {
      return 'Sincronizado hace un momento';
    }
    if (diff.inMinutes < 60) {
      return 'Sincronizado hace ${diff.inMinutes} min';
    }
    if (diff.inHours < 24) {
      final minutes = diff.inMinutes % 60;
      return minutes == 0
          ? 'Sincronizado hace ${diff.inHours} h'
          : 'Sincronizado hace ${diff.inHours} h $minutes min';
    }
    final days = diff.inDays;
    return 'Sincronizado hace $days día${days == 1 ? '' : 's'}';
  }
}
