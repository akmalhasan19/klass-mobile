import 'package:klass_app/app/env.dart';

/// API Configuration — centralized timeout, retry, endpoint builder,
/// and base URL settings.
///
/// All network configuration constants live here so they can be
/// adjusted in one place for production vs development environments.
///
/// ## Base URL
///
/// The [baseUrl] delegates to [Env.apiBaseUrl], which is set via
/// `--dart-define=API_BASE_URL=...` at build time.  This eliminates
/// the old dual-source pattern where both `Env` and `ApiConfig` read
/// the same `String.fromEnvironment('API_BASE_URL')`.
///
/// ## Versioned Endpoints
///
/// Use [v()] for every API path — it automatically prepends the
/// active version from [Env.apiVersion], keeping version management
/// in a single location.
class ApiConfig {
  /// Base URL for the backend API, sourced from [Env].
  ///
  /// Does NOT include the version prefix — use [v()] for path building.
  ///
  /// Override at build time:
  /// ```bash
  /// flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000/api
  /// ```
  static String get baseUrl => Env.apiBaseUrl;

  /// Prepends the active API version to [path].
  ///
  /// Example: `ApiConfig.v('/auth/login')` → `'/v1/auth/login'`
  ///
  /// When the backend introduces a new version, change [Env.apiVersion]
  /// and all endpoints automatically adopt the new prefix.
  static String v(String path) => '/${Env.apiVersion}$path';

  // ─── Timeout Configuration (milliseconds) ─────────────────

  /// Time to wait for TCP connection to be established.
  static const int connectTimeout = 30000;

  /// Time to wait for the server to send data after connection is open.
  static const int receiveTimeout = 30000;

  /// Time to wait for the client to send data to the server.
  static const int sendTimeout = 30000;

  // ─── Retry Policy ─────────────────────────────────────────

  /// Maximum number of retry attempts for transient GET failures.
  static const int maxRetries = 2;

  /// Base delay between retries in milliseconds.
  /// Actual delay = retryDelayMs * attemptNumber (linear backoff).
  static const int retryDelayMs = 500;
}