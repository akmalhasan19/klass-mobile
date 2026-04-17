import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klass_app/screens/generation_history_screen.dart';
import 'package:klass_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAdapter implements HttpClientAdapter {
  _MockAdapter({this.fail = false, this.empty = false});
  final bool fail;
  final bool empty;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.contains('/media-generations/')) {
      return _jsonResponse({
        'success': true,
        'data': {'id': 'gen-123', 'generated_from_id': null}
      });
    }

    if (options.path.endsWith('/media-generations')) {
      if (fail) {
        return _jsonResponse({
          'success': false,
          'error': {'message': 'Connection timeout'}
        }, 500);
      }
      if (empty) {
        return _jsonResponse({'success': true, 'data': []});
      }

      return _jsonResponse({
        'success': true,
        'data': [
          {
            'id': 'parent-1',
            'created_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
            'status': 'completed',
            'prompt': 'Initial prompt',
            'is_regeneration': false,
          },
          {
            'id': 'child-1',
            'created_at': DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String(),
            'status': 'completed',
            'prompt': 'Regenerated with more detail',
            'is_regeneration': true,
            'generated_from_id': 'parent-1',
          }
        ]
      });
    }

    return _jsonResponse({'data': []});
  }

  ResponseBody _jsonResponse(Map<String, dynamic> payload, [int statusCode = 200]) {
    return ResponseBody.fromString(
      jsonEncode(payload),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestHarness(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  testWidgets('GenerationHistoryScreen shows loading then success state', (tester) async {
    ApiService().dio.httpClientAdapter = _MockAdapter();
    
    await tester.pumpWidget(buildTestHarness(const GenerationHistoryScreen(generationId: 'gen-123')));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Memuat riwayat generasi...'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Initial prompt'), findsOneWidget);
    expect(find.text('Regenerated with more detail'), findsOneWidget);
    expect(find.text('Regenerasi'), findsOneWidget);
    expect(find.text('Selesai'), findsNWidgets(2));
  });

  testWidgets('GenerationHistoryScreen shows error state with retry', (tester) async {
    ApiService().dio.httpClientAdapter = _MockAdapter(fail: true);

    await tester.pumpWidget(buildTestHarness(const GenerationHistoryScreen(generationId: 'gen-123')));
    await tester.pumpAndSettle();

    expect(find.text('Gagal memuat riwayat'), findsOneWidget);
    expect(find.text('Connection timeout'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);

    // Test Retry
    ApiService().dio.httpClientAdapter = _MockAdapter(fail: false);
    await tester.tap(find.text('Coba Lagi'));
    await tester.pump();
    
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Initial prompt'), findsOneWidget);
  });

  testWidgets('GenerationHistoryScreen shows empty state', (tester) async {
    ApiService().dio.httpClientAdapter = _MockAdapter(empty: true);

    await tester.pumpWidget(buildTestHarness(const GenerationHistoryScreen(generationId: 'gen-123')));
    await tester.pumpAndSettle();

    expect(find.text('Tidak ada riwayat generasi ditemukan.'), findsOneWidget);
  });
}
