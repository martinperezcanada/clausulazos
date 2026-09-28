import 'package:flutter/foundation.dart';

/// Environment configuration; the API base URL is read from here only.
enum AppEnvironment { development, production }

class AppConfig {
  AppConfig._();

  /// Change this line to switch environments. Keep it as `production` on the real project;
  /// `development` is only for local testing.
  static const AppEnvironment environment = AppEnvironment.development;
  static String get apiBaseUrl {
    switch (environment) {
      case AppEnvironment.development:
        // Web and the iOS simulator reach the host as `localhost`; the Android emulator needs 10.0.2.2.
        // For a physical device, use your machine's LAN IP.
        return kIsWeb ? 'http://localhost:3000' : 'http://10.0.2.2:3000';
      case AppEnvironment.production:
        return 'https://clausulazos.onrender.com';
    }
  }

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);

  static const int maxActiveClauses = 2;
  static const int clauseDurationDays = 7;

  // Splash session check (see AuthProvider.checkSession): a few quick retries first for brief network
  // blips, then, if the backend is still unreachable (e.g. a sleeping Render instance waking up), a
  // slower background retry loop until it responds or a 401 arrives. Only a 401 clears the stored JWT.
  static const int sessionCheckMaxQuickAttempts = 3;
  static const Duration sessionCheckQuickRetryDelay = Duration(seconds: 3);
  static const Duration sessionCheckBackgroundRetryInterval =
      Duration(seconds: 6);
}
