import 'package:clausulazos/core/theme/app_theme.dart';
import 'package:clausulazos/models/clause.dart';
import 'package:clausulazos/models/user.dart';
import 'package:clausulazos/widgets/dashboard/executed_clause_card.dart';
import 'package:clausulazos/widgets/dashboard/occupied_clause_slot.dart';
import 'package:clausulazos/widgets/dashboard/received_clause_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Clause _clause() {
  final now = DateTime.now();
  return Clause(
    id: 'c1',
    fromUserId: 'pablo',
    toUserId: 'martin',
    createdAt: now.subtract(const Duration(days: 2)),
    expiresAt: now.add(const Duration(days: 5)),
    status: ClauseStatus.active,
    fromUser: const AppUser(id: 'pablo', name: 'Pablo', email: 'p@test.local'),
    toUser: const AppUser(id: 'martin', name: 'Martin', email: 'm@test.local'),
    playerName: 'Lamine Yamal',
  );
}

const _oneOfTwo = SlotStats(active: 1, limit: 2, available: 1);

Future<void> _pump(WidgetTester tester, Widget card) => tester.pumpWidget(
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: card))));

Text _textOf(WidgetTester tester, String data) =>
    tester.widget<Text>(find.text(data));

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('executed slot keeps "En enfriamiento" in green', (tester) async {
    await _pump(tester,
        ExecutedClauseCard(activeClauses: [_clause()], stats: _oneOfTwo));

    expect(find.byType(OccupiedClauseSlot), findsOneWidget);
    expect(_textOf(tester, 'En enfriamiento').style?.color,
        AppColors.primaryGreen);
  });

  testWidgets('received slot: same slot, "Protección activa" in cyan',
      (tester) async {
    await _pump(tester,
        ReceivedClauseCard(activeClauses: [_clause()], stats: _oneOfTwo));

    expect(find.byType(OccupiedClauseSlot), findsOneWidget);
    expect(find.text('En enfriamiento'), findsNothing);
    expect(
        _textOf(tester, 'Protección activa').style?.color, AppColors.infoBlue);
    expect(find.text('Lamine Yamal'), findsOneWidget);
  });
}
