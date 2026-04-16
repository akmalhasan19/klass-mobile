import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klass_app/controllers/freelancer_hiring_flow_controller.dart';
import 'package:klass_app/screens/hiring/freelancer_suggestions_screen.dart';
import 'package:klass_app/services/api_service.dart';
import 'package:klass_app/services/media_generation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAdapter implements HttpClientAdapter {
  _MockAdapter({this.fail = false});
  final bool fail;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (fail) {
      return _jsonResponse({
        'error': {'message': 'Server is down'}
      }, 500);
    }

    return _jsonResponse({
      'success': true,
      'data': [
        {
          'freelancer': {'id': 1, 'name': 'John Doe', 'rating': 4.8},
          'match_score': 0.9,
          'success_rate': 0.95,
        }
      ]
    });
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
    return MaterialApp(home: child);
  }

  testWidgets('FreelancerSuggestionsScreen shows error state and retry works', (tester) async {
    final service = MediaGenerationService();
    ApiService().dio.httpClientAdapter = _MockAdapter(fail: true);

    final controller = FreelancerHiringFlowController(
      apiService: service,
      generationId: 'gen-123',
    );

    await tester.pumpWidget(buildTestHarness(FreelancerSuggestionsScreen(controller: controller)));
    
    // Initial state is loading, then error
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('Gagal Memuat Saran'), findsOneWidget);
    expect(find.text('Server is down'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);

    // Test Retry
    ApiService().dio.httpClientAdapter = _MockAdapter(fail: false);
    await tester.tap(find.text('Coba Lagi'));
    await tester.pump();
    
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    
    expect(find.text('John Doe'), findsOneWidget);
    expect(find.text('90% Cocok'), findsOneWidget);
  });
}
