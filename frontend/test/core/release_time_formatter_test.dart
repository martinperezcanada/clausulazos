import 'package:flutter_test/flutter_test.dart';
import 'package:clausulazos/core/theme/release_time_formatter.dart';

void main() {
  group('ReleaseTimeFormatter.describe', () {
    test('"Se libera hoy a las HH:mm" cuando es el mismo día', () {
      final now = DateTime(2026, 9, 8, 10, 0);
      final releaseAt = DateTime(2026, 9, 8, 18, 0);
      expect(ReleaseTimeFormatter.describe(releaseAt, now: now), 'Se libera hoy a las 18:00');
    });

    test('"Se libera mañana a las HH:mm" cuando es al día siguiente', () {
      final now = DateTime(2026, 9, 8, 23, 0);
      final releaseAt = DateTime(2026, 9, 9, 12, 0);
      expect(ReleaseTimeFormatter.describe(releaseAt, now: now), 'Se libera mañana a las 12:00');
    });

    test('"Se libera en N días" para fechas más lejanas', () {
      final now = DateTime(2026, 9, 1, 18, 0);
      final releaseAt = DateTime(2026, 9, 7, 12, 0);
      expect(ReleaseTimeFormatter.describe(releaseAt, now: now), 'Se libera en 6 días');
    });

    test('"Disponible" cuando la fecha de liberación ya pasó', () {
      final now = DateTime(2026, 9, 8, 18, 1);
      final releaseAt = DateTime(2026, 9, 8, 18, 0);
      expect(ReleaseTimeFormatter.describe(releaseAt, now: now), 'Disponible');
    });
  });
}
