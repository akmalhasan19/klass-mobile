class Env {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.18.6:8000/api',
  );

  static const String hfSpaceUrl = String.fromEnvironment(
    'HF_SPACE_URL',
    defaultValue: '',
  );

  static const bool isProd = bool.fromEnvironment(
    'IS_PROD',
    defaultValue: false,
  );

  static const bool enableVerboseLogging = bool.fromEnvironment(
    'ENABLE_VERBOSE_LOGGING',
    defaultValue: true,
  );
}
