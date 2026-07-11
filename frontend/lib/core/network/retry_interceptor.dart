import 'package:dio/dio.dart';
import 'package:klass_app/core/config/api_config.dart';
import 'package:klass_app/core/utils/api_debug_info.dart';

class RetryInterceptor extends Interceptor {
  final Dio Function()? _dioFactory;

  RetryInterceptor({Dio Function()? dioFactory}) : _dioFactory = dioFactory;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.requestOptions.method != 'GET' || !_shouldRetry(err)) {
      return handler.next(err);
    }

    final retries = err.requestOptions.extra['retries'] as int? ?? 0;
    if (retries >= ApiConfig.maxRetries) {
      return handler.next(err);
    }

    final delay = ApiConfig.retryDelayMs * (retries + 1);
    await Future.delayed(Duration(milliseconds: delay));

    err.requestOptions.extra['retries'] = retries + 1;

    try {
      final dio = _dioFactory != null ? _dioFactory() : Dio(BaseOptions(baseUrl: err.requestOptions.baseUrl));
      final response = await dio.fetch(err.requestOptions);
      return handler.resolve(response);
    } catch (retryError) {
      final error = retryError is DioException ? retryError : err;
      return handler.next(_enrichError(error, err.requestOptions));
    }
  }

  DioException _enrichError(DioException error, RequestOptions originalOptions) {
    return DioException(
      requestOptions: error.requestOptions,
      response: error.response,
      type: error.type,
      error: error.error,
      stackTrace: error.stackTrace,
      message: ApiDebugInfo.build(
        error,
        operation: ApiDebugOperation.networkRequestFailed,
        endpoint: originalOptions.path,
      ),
    );
  }

  bool _shouldRetry(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError ||
        (e.type == DioExceptionType.unknown && e.response == null);
  }
}
