import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clausulazos/models/user.dart';
import 'package:clausulazos/widgets/stat_card.dart';
import 'package:clausulazos/widgets/primary_button.dart';
import 'package:clausulazos/core/theme/app_theme.dart';

void main() {
  group('StatCard', () {
    testWidgets('muestra 0/2 y ambos puntos verdes cuando no hay activos', (tester) async {
      const stats = SlotStats(active: 0, limit: 2, available: 2, nextReleaseAt: null);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: StatCard(
            title: 'Recibidos',
            stats: stats,
            availableLabelBuilder: (n) => 'Puedes recibir $n más',
          ),
        ),
      ));

      expect(find.text('0 / 2'), findsOneWidget);
      expect(find.text('Puedes recibir 2 más'), findsOneWidget);
      expect(find.textContaining('COMPLETO'), findsNothing);
    });

    testWidgets('muestra 1/2 con un punto rojo y un punto verde', (tester) async {
      const stats = SlotStats(active: 1, limit: 2, available: 1, nextReleaseAt: null);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: StatCard(
            title: 'Realizados',
            stats: stats,
            availableLabelBuilder: (n) => 'Puedes hacer $n más',
          ),
        ),
      ));

      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text('Puedes hacer 1 más'), findsOneWidget);
    });

    testWidgets('muestra 2/2 con COMPLETO y candado cuando no hay disponibles', (tester) async {
      const stats = SlotStats(active: 2, limit: 2, available: 0, nextReleaseAt: null);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: StatCard(
            title: 'Realizados',
            stats: stats,
            availableLabelBuilder: (n) => 'Puedes hacer $n más',
          ),
        ),
      ));

      expect(find.text('2 / 2'), findsOneWidget);
      expect(find.text('COMPLETO'), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
    });
  });

  group('LockedButton', () {
    testWidgets('muestra el candado y el mensaje de plazas agotadas', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: LockedButton(
            title: 'Has utilizado tus 2 plazas.',
            subtitle: 'Primera plaza disponible: 8 septiembre 18:00',
          ),
        ),
      ));

      expect(find.text('Has utilizado tus 2 plazas.'), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
    });
  });

  group('PrimaryButton', () {
    testWidgets('el botón está deshabilitado cuando onPressed es null', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: PrimaryButton(label: 'HACER CLAUSULAZO', onPressed: null),
        ),
      ));

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('muestra el indicador de carga cuando isLoading es true', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: PrimaryButton(label: 'CONFIRMAR', onPressed: null, isLoading: true),
        ),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('CONFIRMAR'), findsNothing);
    });
  });
}
