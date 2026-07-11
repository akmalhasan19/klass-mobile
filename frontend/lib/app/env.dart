/// Environment configuration — single source of truth for all
/// build-time overrides passed via `--dart-define`.
///
/// Usage:
/// ```bash
/// # Run on device with custom API
/// flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000/api/v1
///
/// # Run in production mode
/// flutter run --dart-define=IS_PROD=true
///
/// # Build release APK with custom URL
/// flutter build apk --dart-define=API_BASE_URL=https://myapp.hf.space/api/v1 \
///   --dart-define=IS_PROD=true --dart-define=ENABLE_VERBOSE_LOGGING=false
/// ```
///
/// All fields are `static const` so the compiler inlines them at build time
/// — zero runtime overhead compared to platform channels or config files.
class Env {
  /// Base URL for the Klass backend API (Laravel).
  ///
  /// Default targets local dev server at `/api/v1` prefix.
  /// Override for HF Space: flutter run --dart-define=API_BASE_URL=...
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.18.6:8000/api/v1',
  );

  /// Hugging Face Space URL (used for LLM / media generation services).
  ///
  /// Empty by default; set only when deploying to HF Space.
  static const String hfSpaceUrl = String.fromEnvironment(
    'HF_SPACE_URL',
    defaultValue: '',
  );

  /// Whether this build targets production.
  ///
  /// When true:
  ///   - Disables verbose API logging
  ///   - Enables certificate pinning (once implemented)
  ///   - Disables debug UI elements
  static const bool isProd = bool.fromEnvironment(
    'IS_PROD',
    defaultValue: false,
  );

  /// Convenience: inverse of [isProd] for use in feature-gating.
  static bool get isDev => !isProd;

  /// Enables verbose structured logging for all API requests/responses.
  ///
  /// Defaults to `true` in dev; set to `false` in production builds
  /// either via `--dart-define=ENABLE_VERBOSE_LOGGING=false` or by
  /// relying on [isProd] to disable it in the consuming code.
  static const bool enableVerboseLogging = bool.fromEnvironment(
    'ENABLE_VERBOSE_LOGGING',
    defaultValue: true,
  );
}