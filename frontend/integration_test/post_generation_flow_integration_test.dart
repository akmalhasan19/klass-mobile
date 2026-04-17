import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:klass_app/main.dart';
import 'package:klass_app/screens/login_screen.dart';
import 'package:klass_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FlowMockAdapter implements HttpClientAdapter {
  bool failFreelancers = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // Auth
    if (options.path.contains('/auth/login')) {
      return _jsonResponse({
        'success': true,
        'data': {
          'token': 'test-token',
          'user': {'id': 1, 'name': 'Sarah Teacher', 'role': 'teacher'},
        },
      });
    }
    if (options.path.contains('/auth/me')) {
      return _jsonResponse({
        'success': true,
        'data': {'id': 1, 'name': 'Sarah Teacher', 'role': 'teacher'},
      });
    }

    // Media Generations List (History)
    if (options.path.endsWith('/media-generations')) {
      return _jsonResponse({
        'success': true,
        'data': [
          {
            'id': 'parent-123',
            'created_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
            'status': 'completed',
            'prompt': 'Initial class material',
            'is_regeneration': false,
          },
          {
            'id': 'child-456',
            'created_at': DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String(),
            'status': 'completed',
            'prompt': 'Improved version',
            'is_regeneration': true,
            'generated_from_id': 'parent-123',
          }
        ]
      });
    }

    // Specific Generation Details (to find parent)
    if (options.path.contains('/media-generations/child-456')) {
      return _jsonResponse({
        'success': true,
        'data': {'id': 'child-456', 'generated_from_id': 'parent-123'}
      });
    }

    // Suggest Freelancers
    if (options.path.contains('/suggest-freelancers')) {
      if (failFreelancers) {
        return _jsonResponse({
          'error': {'message': 'Search engine unavailable'}
        }, 503);
      }
      return _jsonResponse({
        'success': true,
        'data': [
          {
            'freelancer': {'id': 1, 'name': 'Expert Editor', 'rating': 4.9},
            'match_score': 0.98,
            'success_rate': 0.99,
          }
        ]
      });
    }

    // Marketplace Tasks (empty for regression)
    if (options.path.contains('/marketplace-tasks') || options.path.contains('/homepage')) {
       return _jsonResponse({'data': []});
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
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late _FlowMockAdapter adapter;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    adapter = _FlowMockAdapter();
    ApiService().dio.httpClientAdapter = adapter;
  });

  Future<void> login(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: MainShell(key: KlassApp.mainShellKey)));
    await tester.pump(const Duration(milliseconds: 300));
    final context = KlassApp.mainShellKey.currentContext!;
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Email Address'), 'sarah@klass.id');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'password');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  testWidgets('Full post-generation actions flow: history and hiring error recovery', (tester) async {
    await login(tester);

    // 1. Simulate a success generation state manually via the service in HomeScreen
    // In a real E2E we'd type a prompt, but here we can shortcut to verify the UI.
    // For the sake of integration, we'll assume the MediaGenerationStatusCard is visible.
    // Since we don't have a triggered generation, we can't easily see the card unless we trigger it.
    
    // Let's trigger a generation
    await tester.enterText(find.byType(TextField).first, 'Create math lesson');
    await tester.tap(find.byIcon(Icons.auto_awesome_rounded));
    await tester.pump();
    
    // Wait for "completed" status (mocked in adapter)
    // The MediaGenerationService will poll. We need to wait.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // 2. Verify "View History" works
    expect(find.text('Lihat Riwayat Generasi'), findsOneWidget);
    await tester.tap(find.text('Lihat Riwayat Generasi'));
    await tester.pumpAndSettle();

    expect(find.text('Riwayat Generasi'), findsOneWidget);
    expect(find.text('Initial class material'), findsOneWidget);
    expect(find.text('Improved version'), findsOneWidget);
    expect(find.text('Regenerasi'), findsOneWidget);

    // Go back
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    // 3. Verify "Hire Freelancer" flow with error recovery
    await tester.tap(find.text('Sewa Freelancer'));
    await tester.pumpAndSettle();

    expect(find.text('Apa yang perlu diperbaiki?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Please fix the formatting of the equations.');
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    // Select Auto-Search
    await tester.tap(find.text('Cari Freelancer Otomatis'));
    await tester.pump();

    // Mock search failure
    adapter.failFreelancers = true;
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('Gagal Memuat Saran'), findsOneWidget);
    expect(find.text('Search engine unavailable'), findsOneWidget);

    // Retry search (Mock success now)
    adapter.failFreelancers = false;
    await tester.tap(find.text('Coba Lagi'));
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('Expert Editor'), findsOneWidget);
    expect(find.text('98% Cocok'), findsOneWidget);
    expect(find.text('Pilih & Tugaskan'), findsOneWidget);
  });
}
