import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klass_app/core/config/api_config.dart';
import 'package:klass_app/core/network/retry_interceptor.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Step {
  final DioExceptionType? errorType;
  final int? statusCode;

  const _Step.error(this.errorType) : statusCode = null;
  const _Step.success(this.statusCode) : errorType = null;
}

class _QueuedAdapter implements HttpClientAdapter {
  _QueuedAdapter(this.steps);

  final List<_Step> steps;
  int fetchCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    fetchCount += 1;

    if (steps.isEmpty) {
      return ResponseBody.fromString('{"ok":true}', 200, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });
    }

    final step = steps.removeAt(0);
    if (step.errorType != null) {
      throw DioException(
        requestOptions: options,
        type: step.errorType!,
        error: 'Simulated network failure',
      );
    }

    return ResponseBody.fromString('{"ok":true}', step.statusCode ?? 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Dio _createTestDio() {
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
  dio.interceptors.add(RetryInterceptor(dioFactory: () => dio));
  return dio;
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('GET retries on transient connection failure and then succeeds', () async {
    final dio = _createTestDio();
    final adapter = _QueuedAdapter([
      const _Step.error(DioExceptionType.connectionError),
      const _Step.success(200),
    ]);
    dio.httpClientAdapter = adapter;

    final response = await dio.get('/retry-once-success');

    expect(response.statusCode, 200);
    expect(adapter.fetchCount, 2);
  });

  test('GET stops after max retries on repeated timeout', () async {
    final dio = _createTestDio();
    final adapter = _QueuedAdapter([
      const _Step.error(DioExceptionType.connectionTimeout),
      const _Step.error(DioExceptionType.connectionTimeout),
      const _Step.error(DioExceptionType.connectionTimeout),
      const _Step.success(200),
    ]);
    dio.httpClientAdapter = adapter;

    await expectLater(
      () => dio.get('/retry-max-timeout'),
      throwsA(isA<DioException>()),
    );

    expect(adapter.fetchCount, ApiConfig.maxRetries + 1);
  });

  test('POST does not retry on connection error', () async {
    final dio = _createTestDio();
    final adapter = _QueuedAdapter([
      const _Step.error(DioExceptionType.connectionError),
      const _Step.success(200),
    ]);
    dio.httpClientAdapter = adapter;

    await expectLater(
      () => dio.post('/no-retry-post', data: {'name': 'test'}),
      throwsA(isA<DioException>()),
    );

    expect(adapter.fetchCount, 1);
  });
}
