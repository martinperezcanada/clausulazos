import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:clausulazos/core/theme/app_theme.dart';
import 'package:clausulazos/core/webauthn/webauthn_client.dart';
import 'package:clausulazos/providers/auth_provider.dart';
import 'package:clausulazos/repositories/auth_repository.dart';
import 'package:clausulazos/repositories/passkeys_repository.dart';
import 'package:clausulazos/screens/auth/login_screen.dart';
import 'package:clausulazos/screens/auth/register_screen.dart';
import 'package:clausulazos/widgets/gavel_logo.dart';
import 'package:clausulazos/core/network/api_client.dart';
import 'package:clausulazos/core/storage/token_storage.dart';

// A minimal fake so these widget tests don't touch a real network/storage.
class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository()
      : super(
          apiClient: ApiClient(tokenStorage: TokenStorage()),
          tokenStorage: TokenStorage(),
        );
}

class _FakePasskeysRepository extends PasskeysRepository {
  _FakePasskeysRepository()
      : super(
          apiClient: ApiClient(tokenStorage: TokenStorage()),
          tokenStorage: TokenStorage(),
        );
}

// Widget tests run on the Dart VM, where `dart:js_interop` calls to navigator.credentials aren't
// available; force "unsupported" so LoginScreen shows the email/password form.
class _FakeUnsupportedWebAuthnClient extends WebAuthnClient {
  const _FakeUnsupportedWebAuthnClient();
  @override
  bool get isSupported => false;
}

Widget _wrap(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(
          authRepository: _FakeAuthRepository(),
          passkeysRepository: _FakePasskeysRepository(),
          webAuthnClient: const _FakeUnsupportedWebAuthnClient(),
        ),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.dark,
      home: Builder(builder: (context) {
        return Router.withConfig(
          config:
              GoRouter(routes: [GoRoute(path: '/', builder: (_, __) => child)]),
        );
      }),
    ),
  );
}

void main() {
  group('LoginScreen', () {
    testWidgets('muestra errores de validación con campos vacíos',
        (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));
      await tester.tap(find.text('INICIAR SESIÓN'));
      await tester.pump();

      expect(find.text('Introduce un email válido'), findsOneWidget);
      expect(find.text('Introduce tu contraseña'), findsOneWidget);
    });
  });

  group('RegisterScreen', () {
    testWidgets('valida nombre, email, contraseña mínima y confirmación',
        (tester) async {
      await tester.pumpWidget(_wrap(const RegisterScreen()));

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Contraseña'), '123');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirmar contraseña'), '456');
      await tester.tap(find.text('CREAR CUENTA'));
      await tester.pump();

      expect(find.text('El nombre es obligatorio'), findsOneWidget);
      expect(find.text('Introduce un email válido'), findsOneWidget);
      expect(find.text('Mínimo 6 caracteres'), findsOneWidget);
      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
    });
  });

  testWidgets('LoginScreen: sin logo ni texto encima de "Bienvenido Mánager"',
      (tester) async {
    await tester.pumpWidget(_wrap(const LoginScreen()));

    expect(find.text('CLAUSULAZOS'), findsNothing);
    expect(find.byType(GavelLogo), findsNothing);
    expect(find.text('Bienvenido Mánager'), findsOneWidget);
  });

  testWidgets(
      'LoginScreen: halo que respira detrás del formulario, sin tapar nada y liberado al salir',
      (tester) async {
    await tester.pumpWidget(_wrap(const LoginScreen()));

    final glow = find.byKey(const Key('login-form-glow'));
    expect(glow, findsOneWidget);

    // Behind the form card: in the same Stack, painted before it, and it never takes touches.
    final stack = find.ancestor(of: glow, matching: find.byType(Stack)).first;
    final layers = tester.widget<Stack>(stack).children;
    expect(layers.first, isA<Positioned>());
    expect(find.ancestor(of: glow, matching: find.byType(IgnorePointer)),
        findsWidgets);

    // Breathes slowly between a faint minimum and a slightly brighter maximum, never off.
    double alpha() {
      final box = tester.widget<DecoratedBox>(glow);
      final gradient = (box.decoration as BoxDecoration).gradient!;
      return gradient.colors.first.a;
    }

    final samples = <double>[];
    for (var i = 0; i < 26; i++) {
      samples.add(alpha());
      await tester.pump(const Duration(milliseconds: 200));
    }
    final lo = samples.reduce((a, b) => a < b ? a : b);
    final hi = samples.reduce((a, b) => a > b ? a : b);
    expect(lo, greaterThan(0.04));
    expect(hi, lessThan(0.09));
    expect(hi - lo, greaterThan(0.02)); // it does breathe
    // Smooth: no jump between consecutive frames 200 ms apart.
    for (var i = 1; i < samples.length; i++) {
      expect((samples[i] - samples[i - 1]).abs(), lessThan(0.005));
    }

    // Leaving the screen disposes the controller (a running ticker here would fail the test).
    await tester.pumpWidget(const SizedBox());
  });
}
