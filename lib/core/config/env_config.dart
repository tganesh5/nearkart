enum Environment { dev, staging, prod }

class EnvConfig {
  static Environment _environment = Environment.dev;

  static Environment get current => _environment;

  static void init(Environment env) {
    _environment = env;
  }

  static bool get isDev => _environment == Environment.dev;
  static bool get isStaging => _environment == Environment.staging;
  static bool get isProd => _environment == Environment.prod;

  /// Web OAuth client ID used as Google Sign-In's `serverClientId`.
  ///
  /// This is the public `client_type: 3` identifier already published in
  /// `android/app/google-services.json`. It is not a secret: Android apps
  /// prove themselves with package name + signing certificate, not this
  /// string. A `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` still wins so a
  /// different Firebase project can override it without a code change.
  static const _firebaseWebClientId =
      '861604428943-748kib25dslqbo91ievg9meiviraubhb.apps.googleusercontent.com';

  static String get googleServerClientId {
    const fromEnv = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
    final trimmed = fromEnv.trim();
    return trimmed.isEmpty ? _firebaseWebClientId : trimmed;
  }

  static String get apiBaseUrl {
    switch (_environment) {
      case Environment.dev:
        return 'http://localhost:8080/api/v1';
      case Environment.staging:
        return 'https://staging-api.nearkart.com/api/v1';
      case Environment.prod:
        return 'https://api.nearkart.com/api/v1';
    }
  }

  static double get defaultDeliveryRadiusKm {
    switch (_environment) {
      case Environment.dev:
        return 10.0;
      case Environment.staging:
      case Environment.prod:
        return 5.0;
    }
  }
}
