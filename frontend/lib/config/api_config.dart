/// API Configuration — centralized timeout, retry, and base URL settings.
///
/// All network configuration constants live here so they can be
/// adjusted in one place for production vs development environments.
class ApiConfig {
  /// Base URL for the backend API.
  /// - Android emulator: 'http://10.0.2.2:8000/api'
  /// - iOS simulator:    'http://127.0.0.1:8000/api'
  /// - Physical device:  use 'http://YOUR_IP:8000/api'
  static const String baseUrl = 'http://10.0.2.2:8000/api';

  // ─── Timeout Configuration (milliseconds) ─────────────────

  /// Time to wait for TCP connection to be established.
  static const int connectTimeout = 15000;

  /// Time to wait for the server to send data after connection is open.
  static const int receiveTimeout = 15000;

  /// Time to wait for the client to send data to the server.
  static const int sendTimeout = 15000;

  // ─── Retry Policy ─────────────────────────────────────────

  /// Maximum number of retry attempts for transient GET failures.
  static const int maxRetries = 2;

  /// Base delay between retries in milliseconds.
  /// Actual delay = retryDelayMs * attemptNumber (linear backoff).
  static const int retryDelayMs = 500;
}
