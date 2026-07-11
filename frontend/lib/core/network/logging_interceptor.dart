import 'dart:developer';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:klass_app/core/config/feature_flags.dart';
import 'package:klass_app/core/network/monitoring_service.dart';

class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (FeatureFlags.enableVerboseApiLogging) {
      final logData = {
        'type': 'REQUEST',
        'method': options.method,
        'url': options.uri.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
      log(jsonEncode(logData), name: 'API_LOGGER');
    }
    return handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (FeatureFlags.enableErrorRateMonitoring) {
      MonitoringService().logSuccess(
        response.requestOptions.uri.toString(),
        response.statusCode,
      );
    }

    if (FeatureFlags.enableVerboseApiLogging) {
      final logData = {
        'type': 'RESPONSE',
        'method': response.requestOptions.method,
        'url': response.requestOptions.uri.toString(),
        'status': response.statusCode,
        'timestamp': DateTime.now().toIso8601String(),
      };
      log(jsonEncode(logData), name: 'API_LOGGER');
    }
    return handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    MonitoringService().logError(
      err.requestOptions.uri.toString(),
      err.response?.statusCode,
      err.message ?? 'Unknown Error',
      err.response?.data,
    );

    if (FeatureFlags.enableVerboseApiLogging) {
      final logData = {
        'type': 'ERROR',
        'method': err.requestOptions.method,
        'url': err.requestOptions.uri.toString(),
        'status': err.response?.statusCode,
        'error': err.message,
        'dio_type': err.type.name,
        'timestamp': DateTime.now().toIso8601String(),
      };
      log(jsonEncode(logData), name: 'API_LOGGER');
    }
    return handler.next(err);
  }
}
