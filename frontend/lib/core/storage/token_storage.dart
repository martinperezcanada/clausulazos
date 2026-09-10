import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper around flutter_secure_storage so the rest of the app
/// never talks to the storage plugin directly.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _tokenKey = 'clausulazos_jwt';

  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> clearToken() => _storage.delete(key: _tokenKey);
}
