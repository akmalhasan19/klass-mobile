import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:klass_app/app/env.dart';
import 'package:klass_app/core/config/api_config.dart';
import 'package:klass_app/core/network/auth_interceptor.dart';
import 'package:klass_app/core/network/cache_interceptor.dart';
import 'package:klass_app/core/network/logging_interceptor.dart';
import 'package:klass_app/core/network/retry_interceptor.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(milliseconds: ApiConfig.connectTimeout),
    receiveTimeout: const Duration(milliseconds: ApiConfig.receiveTimeout),
    sendTimeout: const Duration(milliseconds: ApiConfig.sendTimeout),
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
  ));

  dio.interceptors.addAll([
    AuthInterceptor(
      onUnauthenticated: () async {
        final prefs = await SharedPreferences.getInstance();
        final keys = prefs.getKeys().toList();
        for (final key in keys) {
          if (key.startsWith('api_cache_')) {
            await prefs.remove(key);
          }
        }
      },
    ),
    CacheInterceptor(),
    RetryInterceptor(dioFactory: () => dio),
    if (!Env.isProd) LoggingInterceptor(),
  ]);

  return dio;
});
