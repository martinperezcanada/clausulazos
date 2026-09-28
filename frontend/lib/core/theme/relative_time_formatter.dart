import 'package:intl/intl.dart';

/// Short relative label for a past timestamp: "Hace 18 min", "Hace 2 h", "Ayer 21:40" or a short date.
class RelativeTimeFormatter {
  RelativeTimeFormatter._();

  static final _timeFormat = DateFormat('HH:mm');
  static final _dateFormat = DateFormat("d MMM", 'es');

  static String describe(DateTime dateTime, {DateTime? now}) {
    final nowTime = now ?? DateTime.now();
    final diff = nowTime.difference(dateTime);

    if (diff.isNegative || diff.inSeconds < 60) return 'Justo ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24 && _isSameDay(dateTime, nowTime))
      return 'Hace ${diff.inHours} h';

    final yesterday = nowTime.subtract(const Duration(days: 1));
    if (_isSameDay(dateTime, yesterday))
      return 'Ayer ${_timeFormat.format(dateTime)}';

    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';

    return _dateFormat.format(dateTime);
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
