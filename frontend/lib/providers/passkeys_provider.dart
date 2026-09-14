import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import '../core/webauthn/webauthn_client.dart';
import '../models/passkey.dart';
import '../repositories/passkeys_repository.dart';

class PasskeysProvider extends ChangeNotifier {
  PasskeysProvider({required PasskeysRepository passkeysRepository, WebAuthnClient? webAuthnClient})
      : _passkeysRepository = passkeysRepository,
        _webAuthnClient = webAuthnClient ?? const WebAuthnClient();

  final PasskeysRepository _passkeysRepository;
  final WebAuthnClient _webAuthnClient;

  List<PasskeyInfo> passkeys = [];
  bool isLoading = false;
  bool isRegistering = false;
  String? errorMessage;

  bool get isSupported => _webAuthnClient.isSupported;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      passkeys = await _passkeysRepository.list();
    } catch (e) {
      errorMessage = ApiClient.messageFromError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Full registration ceremony: fetch options, run
  /// `navigator.credentials.create()` in the browser (this is what
  /// triggers the Face ID prompt), then verify with the backend.
  /// [name] is an optional friendly label, e.g. "iPhone de Martín".
  Future<bool> registerPasskey({String? name}) async {
    if (!isSupported) {
      errorMessage = 'Este navegador no admite Passkeys/Face ID.';
      notifyListeners();
      return false;
    }

    isRegistering = true;
    errorMessage = null;
    notifyListeners();
    try {
      final options = await _passkeysRepository.getRegistrationOptions();
      final credentialResponse = await _webAuthnClient.register(options);
      await _passkeysRepository.verifyRegistration(credentialResponse, name: name);
      await load();
      return true;
    } on WebAuthnUnavailableException catch (e) {
      errorMessage = e.message;
      return false;
    } catch (e) {
      errorMessage = ApiClient.messageFromError(e);
      return false;
    } finally {
      isRegistering = false;
      notifyListeners();
    }
  }

  Future<bool> deletePasskey(String id) async {
    try {
      await _passkeysRepository.delete(id);
      passkeys = passkeys.where((p) => p.id != id).toList();
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = ApiClient.messageFromError(e);
      notifyListeners();
      return false;
    }
  }
}
