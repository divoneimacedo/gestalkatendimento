enum Environment {
  development,
  homolog,
  production,
}

class AppConfig {
  static const String _env = String.fromEnvironment(
    'ENV',
    defaultValue: 'development',
  );

  static const String appName = 'Gestalk Atendimento - Atendentes';
  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.3+1',
  );

  static const String defaultSlug = String.fromEnvironment(
    'GESTALK_DEFAULT_SLUG',
    defaultValue: 'gestalk',
  );

  // Endpoint opcional no backend para gerar token do VideoSDK.
  static const String videoSdkTokenEndpoint = '/videosdk/token';

  static Environment get environment {
    switch (_env) {
      case 'production':
        return Environment.production;
      case 'homolog':
        return Environment.homolog;
      default:
        return Environment.development;
    }
  }

  static String get apiUrl {
    switch (environment) {
      case Environment.production:
        return 'https://api.gestalkconecta.com.br';
      case Environment.homolog:
        return 'https://api-staging.gestalkconecta.com.br';
      case Environment.development:
        return 'http://localhost:5000';
    }
  }

  static String get socketUrl {
    switch (environment) {
      case Environment.production:
        return 'https://api.gestalkconecta.com.br';
      case Environment.homolog:
        return 'https://api-hml.gestalkconecta.com.br';
      case Environment.development:
        return 'http://localhost:3000';
    }
  }

  static bool get isDevelopment => environment == Environment.development;
  static bool get isHomolog => environment == Environment.homolog;
  static bool get isProduction => environment == Environment.production;
}
