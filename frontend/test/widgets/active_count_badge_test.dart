import 'package:clausulazos/models/clause.dart';
import 'package:clausulazos/models/user.dart';
import 'package:clausulazos/widgets/dashboard/active_count_badge.dart';
import 'package:clausulazos/widgets/dashboard/executed_clause_card.dart';
import 'package:clausulazos/widgets/dashboard/received_clause_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

SlotStats _slots(int active) =>
    SlotStats(active: active, limit: 2, available: (2 - active).clamp(0, 2));

Clause _clause(String id) {
  final now = DateTime.now();
  return Clause(
    id: id,
    fromUserId: 'a',
    toUserId: 'b',
    createdAt: now.subtract(const Duration(days: 1)),
    expiresAt: now.add(const Duration(days: 6)),
    status: ClauseStatus.active,
    fromUser: const AppUser(id: 'a', name: 'Alex', email: 'a@test.local'),
    toUser: const AppUser(id: 'b', name: 'Bea', email: 'b@test.local'),
  );
}

List<Clause> _clauses(int n) => [for (var i = 0; i < n; i++) _clause('c$i')];

/// Both Inicio cards, as Home builds them: the counts come from the manager's `SlotStats` (the same
/// figures Managers shows), the listed slots from the clause history.
Widget _home(
        {required SlotStats? performed,
        required SlotStats? received,
        int listedPerformed = 0,
        int listedReceived = 0}) =>
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(children: [
            ExecutedClauseCard(
                activeClauses: _clauses(listedPerformed), stats: performed),
            ReceivedClauseCard(
                activeClauses: _clauses(listedReceived), stats: received),
          ]),
        ),
      ),
    );

/// The "x/y" of each card's badge, in order (executed, received). Received shows a "BLINDADO" pill
/// instead when full, so it may be missing.
List<String> _badgeCounts(WidgetTester tester) => tester
    .widgetList<ActiveCountBadge>(find.byType(ActiveCountBadge))
    .map((b) => '${b.active}/${b.limit}')
    .toList();

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('0/2 executed and 0/2 received', (tester) async {
    await tester.pumpWidget(_home(performed: _slots(0), received: _slots(0)));
    expect(_badgeCounts(tester), ['0/2', '0/2']);
    expect(find.text('0/2 Activas'), findsNWidgets(2));
  });

  testWidgets('1/2 on either card', (tester) async {
    await tester.pumpWidget(_home(
        performed: _slots(1),
        received: _slots(1),
        listedPerformed: 1,
        listedReceived: 1));
    expect(_badgeCounts(tester), ['1/2', '1/2']);
  });

  testWidgets('2/2: executed shows 2/2 Activas, received turns BLINDADO (2/2)',
      (tester) async {
    await tester.pumpWidget(_home(
        performed: _slots(2),
        received: _slots(2),
        listedPerformed: 2,
        listedReceived: 2));
    expect(_badgeCounts(tester), ['2/2']);
    expect(find.text('2/2 Activas'), findsOneWidget);
    expect(find.text('BLINDADO (2/2)'), findsOneWidget);
  });

  testWidgets('executed and received use their own counters', (tester) async {
    await tester.pumpWidget(_home(
        performed: _slots(0),
        received: _slots(1),
        listedPerformed: 0,
        listedReceived: 1));
    expect(_badgeCounts(tester), ['0/2', '1/2']);
  });

  testWidgets('the count is the Managers figure, not a count of listed slots',
      (tester) async {
    // Stats say 1 performed even though no clause is listed (e.g. history still loading).
    await tester.pumpWidget(_home(performed: _slots(1), received: _slots(0)));
    expect(_badgeCounts(tester), ['1/2', '0/2']);
  });

  testWidgets('updates when the stats change', (tester) async {
    await tester.pumpWidget(_home(performed: _slots(0), received: _slots(0)));
    expect(_badgeCounts(tester), ['0/2', '0/2']);

    // e.g. after confirming a PENDING movement as CLAUSE, Home refreshes `myStats`.
    await tester.pumpWidget(
        _home(performed: _slots(1), received: _slots(0), listedPerformed: 1));
    expect(_badgeCounts(tester), ['1/2', '0/2']);
  });

  testWidgets('before stats load, falls back to the listed clauses',
      (tester) async {
    await tester
        .pumpWidget(_home(performed: null, received: null, listedPerformed: 1));
    expect(_badgeCounts(tester), ['1/2', '0/2']);
  });
}
