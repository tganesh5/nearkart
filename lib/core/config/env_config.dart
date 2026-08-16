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

  static String get razorpayKey {
    switch (_environment) {
      case Environment.dev:
        return const String.fromEnvironment('RAZORPAY_KEY_DEV', defaultValue: '');
      case Environment.staging:
        return const String.fromEnvironment('RAZORPAY_KEY_STAGING', defaultValue: '');
      case Environment.prod:
        return const String.fromEnvironment('RAZORPAY_KEY_PROD', defaultValue: '');
    }
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
