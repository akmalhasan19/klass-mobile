import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klass_app/services/api_service.dart';
import 'package:klass_app/services/media_generation_service.dart';
import 'package:klass_app/widgets/media_generation_status_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _HistoryAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'POST' && options.path.endsWith('/media-generations')) {
      return _jsonResponse({
        'success': true,
        'data': {'id': 'gen-123', 'status': 'interpreting'},
      }, 202);
    }
    if (options.method == 'GET' && options.path.contains('/media-generations/gen-123')) {
      return _jsonResponse({
        'success': true,
        'data': {
          'id': 'gen-123',
          'status': 'completed',
          'artifact': {'file_url': 'https://example.com/file.pptx'},
          'delivery_payload': {'title': 'Ready'},
        },
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
  late MediaGenerationService service;

  Widget buildTestHarness(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = MediaGenerationService();
    service.reset(notify: false);
  });

  testWidgets('MediaGenerationStatusCard shows View History button when callback is provided', (tester) async {
    ApiService().dio.httpClientAdapter = _HistoryAdapter();
    var historyTapCount = 0;

    await tester.runAsync(() async {
      await service.submitPrompt(prompt: 'Test prompt');
      service.stopPolling();
      await service.pollNow();
      service.stopPolling();
    });

    await tester.pumpWidget(
      buildTestHarness(
        MediaGenerationStatusCard(
          service: service,
          onViewHistory: () => historyTapCount += 1,
        ),
      ),
    );
    await tester.pump();

    final historyButton = find.byIcon(Icons.history_rounded);
    expect(historyButton, findsOneWidget);

    await tester.ensureVisible(historyButton);
    await tester.tap(historyButton);
    await tester.pump();

    expect(historyTapCount, 1);
  });

  testWidgets('MediaGenerationStatusCard hides View History button when callback is null', (tester) async {
    ApiService().dio.httpClientAdapter = _HistoryAdapter();

    await tester.runAsync(() async {
      await service.submitPrompt(prompt: 'Test prompt');
      service.stopPolling();
      await service.pollNow();
      service.stopPolling();
    });

    await tester.pumpWidget(
      buildTestHarness(
        MediaGenerationStatusCard(
          service: service,
          onViewHistory: null,
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.history_rounded), findsNothing);
  });
}
