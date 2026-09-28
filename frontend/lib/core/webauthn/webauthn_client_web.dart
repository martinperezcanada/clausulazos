import 'dart:convert';
import 'dart:js_interop';

@JS('clausulazosWebAuthn.isSupported')
external JSBoolean _isSupported();

@JS('clausulazosWebAuthn.isPlatformAuthenticatorAvailable')
external JSPromise<JSBoolean> _isPlatformAuthenticatorAvailable();

@JS('clausulazosWebAuthn.register')
external JSPromise<JSString> _register(JSString optionsJson);

@JS('clausulazosWebAuthn.authenticate')
external JSPromise<JSString> _authenticate(JSString optionsJson);

/// Thrown when a passkey operation can't be completed: unsupported browser, cancelled dialog or a failed
/// ceremony. The message is safe to show in the UI.
class WebAuthnUnavailableException implements Exception {
  WebAuthnUnavailableException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Thin bridge to the browser's WebAuthn API (see `web/webauthn.js`). Methods take and return plain
/// JSON, so the rest of the app never deals with ArrayBuffers or base64url. Web only: Face ID on iPhone
/// is reached through Safari's WebAuthn implementation.
class WebAuthnClient {
  const WebAuthnClient();

  /// Whether the browser exposes the WebAuthn APIs at all (false on very old browsers or non-HTTPS
  /// contexts). If not, the passkey option is hidden and email + password is used.
  bool get isSupported {
    try {
      return _isSupported().toDart;
    } catch (_) {
      return false;
    }
  }

  /// Whether a platform authenticator (Face ID, Touch ID, Windows Hello, Android biometrics) is
  /// available, as opposed to only security keys. Only used to choose the button copy ("Continuar con
  /// Face ID" vs "Continuar con Passkey").
  Future<bool> isPlatformAuthenticatorAvailable() async {
    if (!isSupported) return false;
    try {
      final result = await _isPlatformAuthenticatorAvailable().toDart;
      return result.toDart;
    } catch (_) {
      return false;
    }
  }

  /// Runs `navigator.credentials.create()` with the options from `POST /auth/passkeys/registration/options`
  /// and returns the JSON for `POST /auth/passkeys/registration/verify`.
  Future<Map<String, dynamic>> register(Map<String, dynamic> options) {
    return _run(() => _register(jsonEncode(options).toJS));
  }

  /// Runs `navigator.credentials.get()` with the options from `POST /auth/passkeys/authentication/options`
  /// and returns the JSON for `POST /auth/passkeys/authentication/verify`.
  Future<Map<String, dynamic>> authenticate(Map<String, dynamic> options) {
    return _run(() => _authenticate(jsonEncode(options).toJS));
  }

  Future<Map<String, dynamic>> _run(JSPromise<JSString> Function() call) async {
    if (!isSupported) {
      throw WebAuthnUnavailableException(
          'Este navegador no admite Passkeys/Face ID.');
    }
    try {
      final resultJson = await call().toDart;
      return jsonDecode(resultJson.toDart) as Map<String, dynamic>;
    } catch (e) {
      throw WebAuthnUnavailableException(_friendlyMessage(e));
    }
  }

  String _friendlyMessage(Object e) {
    final text = e.toString();
    if (text.contains('NotAllowedError') ||
        text.toLowerCase().contains('cancel')) {
      return 'Operación cancelada.';
    }
    if (text.contains('InvalidStateError')) {
      return 'Esta passkey ya está registrada en este dispositivo.';
    }
    return 'No se ha podido completar la operación con Face ID/Passkey.';
  }
}
