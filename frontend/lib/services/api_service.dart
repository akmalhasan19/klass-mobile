import 'dart:developer';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../config/feature_flags.dart';
import 'monitoring_service.dart';
import 'cache_interceptor.dart';
import '../utils/api_debug_info.dart';

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

    _dio.interceptors.add(CacheInterceptor());
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
            operation: ApiDebugOperation.networkRequestFailed,
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
    required ApiDebugOperation operation,
    required String endpoint,
  }) {
    return ApiDebugInfo.build(
      error,
      operation: operation,
      endpoint: endpoint,
    );
  }

  static List<Map<String, dynamic>> normalizeRecommendationCollection(List data) {
    return data
        .whereType<Map>()
        .map((item) => normalizeRecommendationItem(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Map<String, dynamic> normalizeRecommendationItem(Map<String, dynamic> recommendation) {
    final normalized = Map<String, dynamic>.from(recommendation);
    final thumbnailUrl = normalized['thumbnail_url'];
    
    if (thumbnailUrl is String && thumbnailUrl.isNotEmpty) {
      normalized['media_url'] = thumbnailUrl;
      normalized['image'] = thumbnailUrl;
      normalized['imagePath'] = thumbnailUrl;
    }

    if (normalized['modules'] == null) {
      normalized['modules'] = [];
    } else {
      final rawModules = normalized['modules'] as List;
      normalized['modules'] = rawModules.map((mod) {
        if (mod is String) {
          return {'title': mod};
        } else if (mod is Map) {
          return Map<String, dynamic>.from(mod);
        }
        return {'title': mod.toString()};
      }).toList();
    }
    
    if (normalized['tags'] == null) {
      normalized['tags'] = [];
    }

    return normalized;
  }

  static List<Map<String, dynamic>> normalizeTopicCollection(List data) {
    return data
        .whereType<Map>()
        .map((item) => normalizeTopicItem(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Map<String, dynamic> normalizeTopicItem(Map<String, dynamic> topic) {
    final normalized = Map<String, dynamic>.from(topic);
    final thumbnailUrl = normalized['thumbnail_url'];
    final mediaUrl = normalized['media_url'];

    if ((mediaUrl == null || mediaUrl.toString().isEmpty) &&
        thumbnailUrl is String &&
        thumbnailUrl.isNotEmpty) {
      normalized['media_url'] = thumbnailUrl;
      normalized['image'] = thumbnailUrl;
      normalized['imagePath'] = thumbnailUrl;
    }

    return normalized;
  }

  Dio get dio => _dio;
}
