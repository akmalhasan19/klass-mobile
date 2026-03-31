import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klass_app/screens/bookmark_screen.dart';
import 'package:klass_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('My Teaching Materials shows create-project empty state when no data exists', (tester) async {
    final api = ApiService();
    api.dio.httpClientAdapter = _TopicsEmptyAdapter();

    await tester.pumpWidget(
      const MaterialApp(
        home: BookmarkScreen(),
      ),
    );

    // Wait async fetch + listener updates.
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
    });

    final api = ApiService();
    api.dio.httpClientAdapter = _TopicsEmptyAdapter();

    var createCallbackCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: BookmarkScreen(
          onCreateNewModule: () {
            createCallbackCalled = true;
          },
        ),
      ),
    );

    // Wait async fetch + listener updates.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    final ctaFinder = find.widgetWithText(ElevatedButton, 'Buat Project Pertama');
    expect(ctaFinder, findsOneWidget);

    await tester.tap(ctaFinder);
    await tester.pumpAndSettle();

    expect(createCallbackCalled, isTrue);
  });
}
