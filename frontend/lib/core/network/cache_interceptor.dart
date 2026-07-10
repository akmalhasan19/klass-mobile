import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CacheInterceptor extends Interceptor {
  static const String _cachePrefix = 'api_cache_';
  
  // Cache validity duration, e.g., 5 minutes.
  // We use this to return from cache immediately.
  static const Duration _cacheDuration = Duration(minutes: 5);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Only cache GET requests
    if (options.method == 'GET') {
      final forceRefresh = options.extra['forceRefresh'] == true;
      final cacheKey = _getCacheKey(options);
      
      if (!forceRefresh) {
        final prefs = await SharedPreferences.getInstance();
        final cachedStr = prefs.getString(cacheKey);
        
        if (cachedStr != null) {
          try {
            final cachedData = jsonDecode(cachedStr);
            final timestamp = cachedData['timestamp'];
            final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
            
            // Return cached response if it's still valid (prevents reloading on navigation)
            if (DateTime.now().difference(cacheTime) < _cacheDuration) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  data: cachedData['data'],
                  statusCode: 200,
                  statusMessage: 'OK (Cached)',
                ),
                true, // resolve as normal
              );
            }
          } catch (e) {
            // Ignore error and proceed to network request
          }
        }
      }
    }
    
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    // Save successful GET responses to cache
    if (response.requestOptions.method == 'GET' && 
        response.statusCode != null && 
        response.statusCode! >= 200 && 
        response.statusCode! < 300) {
      
      final cacheKey = _getCacheKey(response.requestOptions);
      final cacheData = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'data': response.data,
      };
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(cacheData));
    }
    
    super.onResponse(response, handler);
  }

  String _getCacheKey(RequestOptions options) {
    // Include query parameters in the cache key
    final uri = options.uri;
    return '$_cachePrefix${uri.toString()}';
  }
}
