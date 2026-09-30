import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Remembers on this device which plain IMPORTANTE alerts were swiped away in Inicio, so they stay
/// hidden after the app is closed and reopened. A storage failure is not an error for the caller: the
/// dismissals then only last for the session.
class DismissedAlertsStorage {
  DismissedAlertsStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _key = 'clausulazos_dismissed_alerts';

  Future<Set<String>> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return <String>{};
      return (jsonDecode(raw) as List).cast<String>().toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> write(Set<String> alerts) async {
    try {
      await _storage.write(key: _key, value: jsonEncode(alerts.toList()));
    } catch (_) {}
  }
}
