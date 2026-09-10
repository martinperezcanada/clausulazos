import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clausulazos/core/theme/app_theme.dart';
import 'package:clausulazos/models/user.dart';
import 'package:clausulazos/widgets/player_card.dart';

void main() {
  AppUser buildUser({required int receivedActive, required int receivedLimit}) {
    return AppUser(
      id: 'u1',
      name: 'Pedro',
      email: 'pedro@example.com',
      stats: UserStats(
        performed: const SlotStats(active: 0, limit: 2, available: 2),
        received: SlotStats(
          active: receivedActive,
          limit: receivedLimit,
          available: receivedLimit - receivedActive,
        ),
      ),
    );
  }

  testWidgets('un jugador con 2/2 recibidos aparece bloqueado y sin onTap', (tester) async {
    final user = buildUser(receivedActive: 2, receivedLimit: 2);
    var tapped = false;

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: PlayerCard(player: user, showReceivedOnly: true, onTap: () => tapped = true),
      ),
    ));

    expect(find.byIcon(Icons.lock), findsOneWidget);
    await tester.tap(find.byType(PlayerCard));
    expect(tapped, isFalse);
  });

  testWidgets('un jugador con 0/2 recibidos permite pulsar', (tester) async {
    final user = buildUser(receivedActive: 0, receivedLimit: 2);
    var tapped = false;

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: PlayerCard(player: user, showReceivedOnly: true, onTap: () => tapped = true),
      ),
    ));

    expect(find.byIcon(Icons.lock), findsNothing);
    await tester.tap(find.byType(PlayerCard));
    expect(tapped, isTrue);
  });
}
