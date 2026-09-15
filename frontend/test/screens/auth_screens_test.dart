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

// Widget tests run on the Dart VM (not a real browser), so real
// dart:js_interop calls to navigator.credentials aren't available here —
// force "unsupported" so LoginScreen renders its normal email/password
// form instead of the Face ID option, exactly like a real unsupported
// browser would.
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
}
