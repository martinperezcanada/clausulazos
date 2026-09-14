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

/// Thrown when a Passkey/WebAuthn operation can't be completed — either
/// because the browser doesn't support it, the user cancelled the
/// prompt, or the ceremony otherwise failed. Always carries a message
/// that's already safe to show directly in the UI.
class WebAuthnUnavailableException implements Exception {
  WebAuthnUnavailableException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Thin bridge to the browser's native WebAuthn API (see
/// `web/webauthn.js`). Every method here works with plain JSON
/// (`Map<String, dynamic>`), so the rest of the app never has to think
/// about ArrayBuffers, base64url encoding, or JS interop directly — it
/// just passes the options it got from the backend straight through, and
/// sends the result straight back.
///
/// This only works on Flutter Web (the app's only target — see
/// PROJECT_CONTEXT.md), since Face ID on iPhone is reached here through
/// Safari's WebAuthn implementation, not a native iOS API.
class WebAuthnClient {
  const WebAuthnClient();

  /// Whether this browser exposes the WebAuthn APIs at all. False on very
  /// old browsers or non-secure (non-HTTPS) contexts — the app should fall
  /// back to email + password without even showing the Passkey option.
  bool get isSupported {
    try {
      return _isSupported().toDart;
    } catch (_) {
      return false;
    }
  }

  /// Whether a *platform* authenticator (Face ID, Touch ID, Windows Hello,
  /// Android biometrics...) is available — as opposed to only external
  /// security keys. Used purely to tailor the button copy ("Continuar con
  /// Face ID" vs a more generic "Continuar con Passkey").
  Future<bool> isPlatformAuthenticatorAvailable() async {
    if (!isSupported) return false;
    try {
      final result = await _isPlatformAuthenticatorAvailable().toDart;
      return result.toDart;
    } catch (_) {
      return false;
    }
  }

  /// Runs `navigator.credentials.create()` with the registration options
  /// returned by `POST /auth/passkeys/registration/options`, and returns
  /// the response JSON ready to send straight to
  /// `POST /auth/passkeys/registration/verify`.
  Future<Map<String, dynamic>> register(Map<String, dynamic> options) {
    return _run(() => _register(jsonEncode(options).toJS));
  }

  /// Runs `navigator.credentials.get()` with the authentication options
  /// returned by `POST /auth/passkeys/authentication/options`, and
  /// returns the response JSON ready to send straight to
  /// `POST /auth/passkeys/authentication/verify`.
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
