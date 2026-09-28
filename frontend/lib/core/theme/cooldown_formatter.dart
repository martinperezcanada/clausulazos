/// Formats the remaining cooldown (`expiresAt` minus now) as "X días XX h XX min".
class CooldownFormatter {
  CooldownFormatter._();

  static String remaining(DateTime expiresAt, {DateTime? now}) {
    final nowTime = now ?? DateTime.now();
    final diff = expiresAt.difference(nowTime);

    if (diff.isNegative) return 'Liberado';

    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;

    if (days > 0) {
      return '$days día${days == 1 ? '' : 's'} $hours h $minutes min';
    }
    if (hours > 0) {
      return '$hours h $minutes min';
    }
    if (minutes > 0) {
      return '$minutes min';
    }
    return 'Menos de 1 min';
  }
}
