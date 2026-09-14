class WebAuthnUnavailableException implements Exception {
  WebAuthnUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WebAuthnClient {
  const WebAuthnClient();

  bool get isSupported => false;

  Future<bool> isPlatformAuthenticatorAvailable() async => false;

  Future<Map<String, dynamic>> register(
    Map<String, dynamic> options,
  ) async {
    throw WebAuthnUnavailableException(
      'Passkeys no están disponibles en esta plataforma.',
    );
  }

  Future<Map<String, dynamic>> authenticate(
    Map<String, dynamic> options,
  ) async {
    throw WebAuthnUnavailableException(
      'Passkeys no están disponibles en esta plataforma.',
    );
  }
}
