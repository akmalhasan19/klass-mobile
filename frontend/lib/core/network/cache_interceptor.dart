import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';

import 'package:klass_app/core/network/cache_policy.dart';

class CacheInterceptor extends Interceptor {
  final HiveCacheStore _store;

  CacheInterceptor()
      : _store = HiveCacheStore('${Directory.systemTemp.path}/klass_cache');

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.method != 'GET') {
      return handler.next(options);
    }

    final forceRefresh = options.extra['forceRefresh'] == true;
    final maxStale = RouteCachePolicy.maxStaleFor(options.path);

    if (maxStale == null || forceRefresh) {
      return handler.next(options);
    }

    final cacheKey = options.uri.toString();
    final cached = await _store.get(cacheKey);

    if (cached != null && !cached.isStaled()) {
      return handler.resolve(cached.toResponse(options));
    }

    return handler.next(options);
  }

  @override
  void onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    final options = response.requestOptions;
    final status = response.statusCode;

    if (options.method == 'GET' && status != null && status >= 200 && status < 300) {
      await _cacheResponse(response);
    }

    if (options.method != 'GET' && status != null && status >= 200 && status < 300) {
      await _invalidateOnMutation(options);
    }

    return handler.next(response);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Fallback to stale cache when network fails
    if (err.response == null && err.requestOptions.method == 'GET') {
      final cacheKey = err.requestOptions.uri.toString();
      final cached = await _store.get(cacheKey);
      if (cached != null) {
        return handler.resolve(cached.toResponse(err.requestOptions));
      }
    }

    return handler.next(err);
  }

  Future<void> _cacheResponse(Response response) async {
    final path = response.requestOptions.path;
    final maxStale = RouteCachePolicy.maxStaleFor(path);

    if (maxStale == null) return;
    final cacheKey = response.requestOptions.uri.toString();
    final cacheOptions = CacheOptions(
      store: _store,
      maxStale: maxStale,
      keyBuilder: (_) => cacheKey,
    );

    final cached = await CacheResponse.fromResponse(
      key: cacheKey,
      options: cacheOptions,
      response: response,
    );

    final toStore = await cached.writeContent(cacheOptions, response: response);
    await _store.set(toStore);
  }

  Future<void> _invalidateOnMutation(RequestOptions options) async {
    final keys = RouteCachePolicy.getInvalidationKeys(options.path);
    for (final key in keys) {
      await _store.deleteFromPath(RegExp(key));
    }
  }
}
