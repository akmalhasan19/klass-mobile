import 'package:dio/dio.dart';
import 'package:klass_app/core/config/api_config.dart';
import 'package:klass_app/core/storage/secure_token_store.dart';

class AuthInterceptor extends Interceptor {
  final SecureTokenStore _tokenStore;
  final void Function()? _onUnauthenticated;

  AuthInterceptor({
    SecureTokenStore? tokenStore,
    void Function()? onUnauthenticated,
  }) : _tokenStore = tokenStore ?? SecureTokenStore(),
       _onUnauthenticated = onUnauthenticated;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _tokenStore.read();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    if (err.requestOptions.extra['isRetry'] == true) {
      await _tokenStore.clearAll();
      _onUnauthenticated?.call();
      return handler.next(err);
    }

    try {
      final token = await _tokenStore.read();
      if (token == null) {
        _onUnauthenticated?.call();
        return handler.next(err);
      }

      final refreshDio = Dio(BaseOptions(
        baseUrl: err.requestOptions.baseUrl,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ));

      final response = await refreshDio.post(ApiConfig.v('/auth/refresh'));

      final newToken = _extractToken(response.data);
      if (newToken == null) {
        throw Exception('No token in refresh response');
      }

      await _tokenStore.write(newToken);

      err.requestOptions.extra['isRetry'] = true;
      err.requestOptions.headers['Authorization'] = 'Bearer $newToken';

      final retryDio = Dio(BaseOptions(baseUrl: err.requestOptions.baseUrl));
      final retryResponse = await retryDio.fetch(err.requestOptions);
      return handler.resolve(retryResponse);
    } catch (_) {
      // Refresh or retry failed
    }

    await _tokenStore.clearAll();
    _onUnauthenticated?.call();
    return handler.next(err);
  }

  String? _extractToken(dynamic responseData) {
    if (responseData is! Map) return null;
    final data = (responseData['data'] as Map?)?.cast<String, dynamic>() ?? responseData;
    return data['token'] ?? data['access_token'];
  }
}
