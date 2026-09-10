/// Centralized environment configuration. Nothing else in the app should
/// hardcode the API base URL — everything reads it from here, so switching
/// between development and production is a one-line change.
enum AppEnvironment { development, production }

class AppConfig {
  AppConfig._();

  /// Change this single line to switch environments.
  static const AppEnvironment environment = AppEnvironment.development;

  static String get apiBaseUrl {
    switch (environment) {
      case AppEnvironment.development:
        // 10.0.2.2 is how the Android emulator reaches the host machine's
        // localhost. If you're running on iOS simulator or a physical
        // device on the same network, replace this accordingly (e.g.
        // http://localhost:3000 for iOS simulator, or your machine's LAN
        // IP for a physical device).
        return 'http://10.0.2.2:3000';
      case AppEnvironment.production:
        return 'https://api.clausulazos.example.com';
    }
  }

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);

  static const int maxActiveClauses = 2;
  static const int clauseDurationDays = 7;
}
