import 'dart:developer';
import 'dart:convert';

/// MonitoringService — Application observability and error rate tracking.
///
/// Provides:
/// - Structured error logging with endpoint-level tracking
/// - Error rate monitoring with configurable thresholds
/// - Alert triggering when error rates exceed thresholds
/// - Event logging for custom application events
///
/// In production, this would integrate with Sentry, Firebase Crashlytics,
/// or Datadog. Currently logs to console with structured JSON format.
class MonitoringService {
  static final MonitoringService _instance = MonitoringService._internal();

  factory MonitoringService() {
    return _instance;
  }

  MonitoringService._internal();

  // --- Error Rate Tracking ---

  /// Sliding window size for error rate calculation (last N requests per endpoint)
  static const int _windowSize = 50;

  /// Error rate threshold (0.0 - 1.0). Alert when exceeded.
  static const double _errorRateThreshold = 0.3; // 30%

  /// Tracks the last N request outcomes per endpoint (true = error, false = success)
  final Map<String, List<bool>> _endpointHistory = {};

  /// Tracks total error counts per endpoint since app start
  final Map<String, int> _errorCounts = {};

  /// Tracks total request counts per endpoint since app start
  final Map<String, int> _requestCounts = {};

  /// Records a successful request for an endpoint
  void recordSuccess(String endpoint) {
    _recordOutcome(endpoint, isError: false);
  }

  /// Records a failed request for an endpoint
  void recordError(String endpoint) {
    _recordOutcome(endpoint, isError: true);
  }

  void _recordOutcome(String endpoint, {required bool isError}) {
    final normalized = _normalizeEndpoint(endpoint);

    // Update total counts
    _requestCounts[normalized] = (_requestCounts[normalized] ?? 0) + 1;
    if (isError) {
      _errorCounts[normalized] = (_errorCounts[normalized] ?? 0) + 1;
    }

    // Update sliding window
    _endpointHistory.putIfAbsent(normalized, () => []);
    final history = _endpointHistory[normalized]!;
    history.add(isError);
    if (history.length > _windowSize) {
      history.removeAt(0);
    }

    // Check threshold
    final rate = getErrorRate(normalized);
    if (rate > _errorRateThreshold && history.length >= 5) {
      _triggerErrorRateAlert(normalized, rate);
    }
  }

  /// Returns the current error rate for an endpoint (0.0 - 1.0)
  double getErrorRate(String endpoint) {
    final normalized = _normalizeEndpoint(endpoint);
    final history = _endpointHistory[normalized];
    if (history == null || history.isEmpty) return 0.0;

    final errorCount = history.where((e) => e).length;
    return errorCount / history.length;
  }

  /// Returns a summary of all endpoint error rates
  Map<String, Map<String, dynamic>> getHealthReport() {
    final report = <String, Map<String, dynamic>>{};

    for (final endpoint in _endpointHistory.keys) {
      final totalRequests = _requestCounts[endpoint] ?? 0;
      final totalErrors = _errorCounts[endpoint] ?? 0;
      final currentRate = getErrorRate(endpoint);

      report[endpoint] = {
        'total_requests': totalRequests,
        'total_errors': totalErrors,
        'current_error_rate': currentRate,
        'status': currentRate > _errorRateThreshold ? 'UNHEALTHY' : 'HEALTHY',
      };
    }

    return report;
  }

  void _triggerErrorRateAlert(String endpoint, double rate) {
    final alertData = {
      'timestamp': DateTime.now().toIso8601String(),
      'alert_type': 'ERROR_RATE_EXCEEDED',
      'endpoint': endpoint,
      'error_rate': '${(rate * 100).toStringAsFixed(1)}%',
      'threshold': '${(_errorRateThreshold * 100).toStringAsFixed(0)}%',
      'total_errors': _errorCounts[endpoint],
      'total_requests': _requestCounts[endpoint],
    };
    log(
      '🚨 [ALERT] Error rate threshold exceeded!\n${jsonEncode(alertData)}',
      name: 'MonitoringService',
    );
  }

  /// Normalizes full URLs to endpoint paths for consistent grouping
  String _normalizeEndpoint(String endpoint) {
    try {
      final uri = Uri.parse(endpoint);
      return uri.path;
    } catch (_) {
      return endpoint;
    }
  }

  // --- Structured Error Logging ---

  /// Logs an error with structured context for monitoring dashboards
  void logError(
    String endpoint,
    int? statusCode,
    String errorMessage, [
    dynamic data,
  ]) {
    recordError(endpoint);

    final logData = {
      'timestamp': DateTime.now().toIso8601String(),
      'endpoint': _normalizeEndpoint(endpoint),
      'status_code': statusCode,
      'error': errorMessage,
      'error_rate': '${(getErrorRate(_normalizeEndpoint(endpoint)) * 100).toStringAsFixed(1)}%',
    };

    if (data != null) {
      try {
        logData['response_data'] = data is String ? data : jsonEncode(data);
      } catch (_) {
        logData['response_data'] = data.toString();
      }
    }

    log(
      '🚨 [MONITORING] API Error:\n${jsonEncode(logData)}',
      name: 'MonitoringService',
    );
  }

  /// Logs a structured custom event
  void logEvent(String eventName, Map<String, dynamic> params) {
    final logData = {
      'timestamp': DateTime.now().toIso8601String(),
      'event': eventName,
      'params': params,
    };
    log(
      '📊 [MONITORING] Event:\n${jsonEncode(logData)}',
      name: 'MonitoringService',
    );
  }

  /// Logs a successful API response for tracking
  void logSuccess(String endpoint, int? statusCode) {
    recordSuccess(endpoint);
  }

  /// Resets all monitoring data (useful for testing)
  void reset() {
    _endpointHistory.clear();
    _errorCounts.clear();
    _requestCounts.clear();
  }
}
