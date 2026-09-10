import 'package:flutter_test/flutter_test.dart';
import 'package:clausulazos/models/clause.dart';

void main() {
  group('Clause.isActiveAt', () {
    test('un cláusulazo activo con expiresAt en el futuro cuenta como activo', () {
      final now = DateTime(2026, 9, 1, 12, 0);
      final clause = Clause(
        id: '1',
        fromUserId: 'a',
        toUserId: 'b',
        createdAt: now,
        expiresAt: now.add(const Duration(days: 7)),
        status: ClauseStatus.active,
      );
      expect(clause.isActiveAt(now.add(const Duration(days: 1))), isTrue);
    });

    test('un cláusulazo con expiresAt exactamente ahora ya NO cuenta como activo', () {
      final now = DateTime(2026, 9, 8, 18, 0);
      final createdAt = now.subtract(const Duration(days: 7));
      final clause = Clause(
        id: '2',
        fromUserId: 'a',
        toUserId: 'b',
        createdAt: createdAt,
        expiresAt: now, // expires exactly at `now`
        status: ClauseStatus.active,
      );
      expect(clause.isActiveAt(now), isFalse);
    });

    test('un cláusulazo cancelado nunca cuenta como activo, aunque no haya expirado', () {
      final now = DateTime(2026, 9, 1, 12, 0);
      final clause = Clause(
        id: '3',
        fromUserId: 'a',
        toUserId: 'b',
        createdAt: now,
        expiresAt: now.add(const Duration(days: 7)),
        status: ClauseStatus.cancelled,
      );
      expect(clause.isActiveAt(now), isFalse);
    });

    test('un cláusulazo expirado no cuenta como activo', () {
      final createdAt = DateTime(2026, 9, 1, 12, 0);
      final clause = Clause(
        id: '4',
        fromUserId: 'a',
        toUserId: 'b',
        createdAt: createdAt,
        expiresAt: createdAt.add(const Duration(days: 7)),
        status: ClauseStatus.active,
      );
      final tenDaysLater = createdAt.add(const Duration(days: 10));
      expect(clause.isActiveAt(tenDaysLater), isFalse);
    });
  });
}
