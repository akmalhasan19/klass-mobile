import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klass_app/features/bookmark/screens/bookmark_screen.dart';
import 'package:klass_app/core/providers/dio_provider.dart';
import 'package:klass_app/core/providers/secure_token_store_provider.dart';
import 'package:klass_app/core/storage/secure_token_store.dart';
import 'package:klass_app/core/config/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/in_memory_secure_storage.dart';

class _TopicsEmptyAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.contains('/topics')) {
      return ResponseBody.fromString('{"success":true,"data":[]}', 200, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });
    }

    return ResponseBody.fromString('{"success":true,"data":[]}', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Dio _createTestDio() {
  return Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(milliseconds: ApiConfig.connectTimeout),
    receiveTimeout: const Duration(milliseconds: ApiConfig.receiveTimeout),
    sendTimeout: const Duration(milliseconds: ApiConfig.sendTimeout),
  ));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('My Teaching Materials shows create-project empty state when no data exists', (tester) async {
    final dio = _createTestDio();
    dio.httpClientAdapter = _TopicsEmptyAdapter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(dio),
          secureTokenStoreProvider.overrideWithValue(
            SecureTokenStore(storage: InMemorySecureStorage()),
          ),
        ],
        child: const MaterialApp(
          home: BookmarkScreen(),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('My Teaching Materials'), findsOneWidget);
    expect(find.text('Belum ada material untuk ditampilkan'), findsOneWidget);
    expect(find.textContaining('Buat project terlebih dahulu'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Buat Project Pertama'), findsOneWidget);
  });

  testWidgets('Buat Project Pertama CTA triggers create callback when user is authenticated', (tester) async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'test-token',
      'user_data': '{"role":"teacher"}',
    });

    final dio = _createTestDio();
    dio.httpClientAdapter = _TopicsEmptyAdapter();

    final secureStorage = InMemorySecureStorage();
    await secureStorage.write('auth_token', 'test-token');
    await secureStorage.write('user_data', '{"role":"teacher"}');

    var createCallbackCalled = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(dio),
          secureTokenStoreProvider.overrideWithValue(
            SecureTokenStore(storage: secureStorage),
          ),
        ],
        child: MaterialApp(
          home: BookmarkScreen(
            onCreateNewModule: () {
              createCallbackCalled = true;
            },
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    final ctaFinder = find.widgetWithText(ElevatedButton, 'Buat Project Pertama');
    expect(ctaFinder, findsOneWidget);

    await tester.tap(ctaFinder);
    await tester.pumpAndSettle();

    expect(createCallbackCalled, isTrue);
  });
}
