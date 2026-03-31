import 'dart:developer';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../config/feature_flags.dart';
import 'monitoring_service.dart';

class ApiService {
  late Dio _dio;
  
  static final ApiService _instance = ApiService._internal();

  factory ApiService() {
    return _instance;
  }

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(milliseconds: ApiConfig.connectTimeout),
      receiveTimeout: const Duration(milliseconds: ApiConfig.receiveTimeout),
      sendTimeout: const Duration(milliseconds: ApiConfig.sendTimeout),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        
        // Structured Logging for Priority Endpoints
        if (FeatureFlags.enableVerboseApiLogging) {
          final logData = {
            "type": "REQUEST",
            "method": options.method,
            "url": options.uri.toString(),
            "timestamp": DateTime.now().toIso8601String(),
          };
          log(jsonEncode(logData), name: 'API_LOGGER');
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        // Track success in MonitoringService
        if (FeatureFlags.enableErrorRateMonitoring) {
          MonitoringService().logSuccess(
            response.requestOptions.uri.toString(),
            response.statusCode,
          );
        }

        if (FeatureFlags.enableVerboseApiLogging) {
          final logData = {
            "type": "RESPONSE",
            "method": response.requestOptions.method,
            "url": response.requestOptions.uri.toString(),
            "status": response.statusCode,
            "timestamp": DateTime.now().toIso8601String(),
          };
          log(jsonEncode(logData), name: 'API_LOGGER');
        }
        return handler.next(response);
      },
      onError: (DioException e, handler) async {
        // Log Error to Monitoring Service (with error rate tracking)
        MonitoringService().logError(
          e.requestOptions.uri.toString(), 
          e.response?.statusCode, 
          e.message ?? 'Unknown Error',
          e.response?.data,
        );
        
        if (FeatureFlags.enableVerboseApiLogging) {
          final logData = {
            "type": "ERROR",
            "method": e.requestOptions.method,
            "url": e.requestOptions.uri.toString(),
            "status": e.response?.statusCode,
            "error": e.message,
            "dio_type": e.type.name,
            "timestamp": DateTime.now().toIso8601String(),
          };
          log(jsonEncode(logData), name: 'API_LOGGER');
        }

        // Client Retry Policy — only GET requests for transient failures
        if (e.requestOptions.method == 'GET' && _shouldRetry(e)) {
          int retries = e.requestOptions.extra['retries'] ?? 0;
          if (retries < ApiConfig.maxRetries) {
            final delay = ApiConfig.retryDelayMs * (retries + 1); // Linear backoff
            log(
              '🔄 Retrying request: ${e.requestOptions.uri} '
              '(Attempt ${retries + 1}/${ApiConfig.maxRetries}, '
              'delay: ${delay}ms)',
              name: 'API_RETRY',
            );

            await Future.delayed(Duration(milliseconds: delay));
            e.requestOptions.extra['retries'] = retries + 1;
            try {
              final response = await _dio.fetch(e.requestOptions);
              return handler.resolve(response);
            } catch (retryError) {
              return handler.next(retryError is DioException ? retryError : e);
            }
          }
        }
        
        // Handle global unauthenticated errors here if needed
        final enrichedError = DioException(
          requestOptions: e.requestOptions,
          response: e.response,
          type: e.type,
          error: e.error,
          stackTrace: e.stackTrace,
          message: buildDebugInfo(
            e,
            operation: 'Network request failed',
            endpoint: e.requestOptions.path,
          ),
        );

        return handler.next(enrichedError);
      },
    ));
  }

  bool _shouldRetry(DioException e) {
    return e.type == DioExceptionType.connectionTimeout || 
           e.type == DioExceptionType.receiveTimeout ||
           e.type == DioExceptionType.sendTimeout ||
           e.type == DioExceptionType.connectionError ||
           (e.type == DioExceptionType.unknown && e.response == null);
  }

  static String buildDebugInfo(
    Object error, {
    required String operation,
    required String endpoint,
  }) {
    if (error is DioException) {
      final req = error.requestOptions;
      final statusCode = error.response?.statusCode;
      final responseData = error.response?.data;

      String? backendMessage;
      String? responseSnippet;

      if (responseData is Map<String, dynamic>) {
        final message = responseData['message'];
        if (message is String && message.isNotEmpty) {
          backendMessage = message;
        }
        responseSnippet = jsonEncode(responseData);
      } else if (responseData != null) {
        responseSnippet = responseData.toString();
      }

      if (responseSnippet != null && responseSnippet.length > 300) {
        responseSnippet = '${responseSnippet.substring(0, 300)}...';
      }

      final technicalMessage = _extractTechnicalMessage(error.message);

      final lines = <String>[
        operation,
        'Endpoint: $endpoint',
        'Method: ${req.method}',
        'URL: ${req.uri}',
        'Status: ${statusCode ?? '-'}',
        'Dio Type: ${error.type.name}',
        'Error: $technicalMessage',
      ];

      if (backendMessage != null) {
        lines.add('Backend Message: $backendMessage');
      }

      if (responseSnippet != null && responseSnippet.isNotEmpty) {
        lines.add('Response: $responseSnippet');
      }

      return lines.join('\n');
    }

    return [
      operation,
      'Endpoint: $endpoint',
      'Error: ${error.toString()}',
    ].join('\n');
  }

  static String _extractTechnicalMessage(String? rawMessage) {
    if (rawMessage == null || rawMessage.trim().isEmpty) {
      return 'Unknown network error';
    }

    if (!rawMessage.contains('\n')) {
      return rawMessage;
    }

    final lines = rawMessage
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    for (final line in lines.reversed) {
      if (line.startsWith('Error: ')) {
        return line.substring('Error: '.length);
      }
    }

    return lines.last;
  }

  Dio get dio => _dio;
}
