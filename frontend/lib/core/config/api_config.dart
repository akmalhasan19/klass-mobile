import 'package:klass_app/app/env.dart';

/// API Configuration — centralized timeout, retry, and base URL settings.
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
class ApiConfig {
  /// Base URL for the backend API, sourced from [Env].
  ///
  /// Override at build time:
  /// ```bash
  /// flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000/api/v1
  /// ```
  static String get baseUrl => Env.apiBaseUrl;

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