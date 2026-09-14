import 'package:intl/intl.dart';

/// Formats a slot's release instant the way the spec describes:
/// "Se libera en 6 días", "Se libera mañana", "Se libera hoy a las 18:42"...
class ReleaseTimeFormatter {
  ReleaseTimeFormatter._();

  static final _timeFormat = DateFormat('HH:mm');
  static final _dateTimeFormat = DateFormat("d 'de' MMMM · HH:mm", 'es');

  static String describe(DateTime releaseAt, {DateTime? now}) {
    final nowTime = now ?? DateTime.now();
    if (releaseAt.isBefore(nowTime)) {
      return 'Disponible';
    }
    final today = DateTime(nowTime.year, nowTime.month, nowTime.day);
    final releaseDay = DateTime(releaseAt.year, releaseAt.month, releaseAt.day);
    final dayDiff = releaseDay.difference(today).inDays;

    if (dayDiff == 0) {
      return 'Se libera hoy a las ${_timeFormat.format(releaseAt)}';
    }
    if (dayDiff == 1) {
      return 'Se libera mañana a las ${_timeFormat.format(releaseAt)}';
    }
    return 'Se libera en $dayDiff días';
  }

  static String fullDateTime(DateTime dateTime) => _dateTimeFormat.format(dateTime);

  /// Compact "Hoy · 18:32" / "Mañana · 18:32" / "d de MMMM · 18:32" label,
  /// for tight dashboard cards (see HomeScreen "Próxima liberación").
  static String dayAndTime(DateTime dateTime, {DateTime? now}) {
    final nowTime = now ?? DateTime.now();
    final today = DateTime(nowTime.year, nowTime.month, nowTime.day);
    final day = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final dayDiff = day.difference(today).inDays;

    if (dayDiff == 0) return 'Hoy · ${_timeFormat.format(dateTime)}';
    if (dayDiff == 1) return 'Mañana · ${_timeFormat.format(dateTime)}';
    return fullDateTime(dateTime);
  }
}
