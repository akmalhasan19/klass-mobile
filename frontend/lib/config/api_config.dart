import 'package:flutter/foundation.dart';

/// API Configuration — centralized timeout, retry, and base URL settings.
///
/// All network configuration constants live here so they can be
/// adjusted in one place for production vs development environments.
class ApiConfig {
  /// Optional override from build runtime args.
  ///
  /// Example:
  /// flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000/api
  static const String _overrideBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Base URL for the backend API.
  /// - Dev Server: 'http://192.168.200.158:8000/api'
  /// - Android emulator/iOS simulator defaults replaced with local dev IP.
  /// - Physical device:  use 'http://YOUR_IP:8000/api' atau IP di atas.
  static String get baseUrl {
    if (_overrideBaseUrl.isNotEmpty) {
      return _overrideBaseUrl;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return 'http://192.168.200.158:8000/api';
    }
  }

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
