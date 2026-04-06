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

class _LoginFlowAdapter implements HttpClientAdapter {
  _LoginFlowAdapter({
    required this.loginUser,
    required this.meUser,
  });

  final Map<String, dynamic> loginUser;
  final Map<String, dynamic> meUser;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.contains('/auth/login')) {
      return _jsonResponse({
        'success': true,
        'data': {
          'token': 'test-token',
          'user': loginUser,
        },
      });
    }

    if (options.path.contains('/auth/me')) {
      return _jsonResponse({
        'success': true,
        'data': meUser,
      });
    }

    if (options.path.contains('/homepage-sections')) {
      return _jsonResponse({'data': []});
    }

    if (options.path.contains('/homepage-recommendations')) {
      return _jsonResponse({
        'data': [],
        'meta': {'total': 0},
      });
    }

    if (options.path.contains('/marketplace-tasks')) {
      return _jsonResponse({
        'success': true,
        'data': [],
        'meta': {'total': 0},
      });
    }

    return _jsonResponse({'data': []});
  }

  ResponseBody _jsonResponse(Map<String, dynamic> payload) {
    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<void> _pumpLoginFlow(
  WidgetTester tester, {
  required Map<String, dynamic> loginUser,
  required Map<String, dynamic> meUser,
}) async {
  SharedPreferences.setMockInitialValues({});

  final api = ApiService();
  api.dio.httpClientAdapter = _LoginFlowAdapter(
    loginUser: loginUser,
    meUser: meUser,
  );

  await tester.pumpWidget(
    MaterialApp(
      home: MainShell(key: KlassApp.mainShellKey),
    ),
  );

  await tester.pump(const Duration(milliseconds: 300));

  final context = KlassApp.mainShellKey.currentContext;
  if (context == null || !context.mounted) {
    fail('MainShell context is not available or not mounted');
  }

  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
  );

  await tester.pumpAndSettle();
}

Future<void> _login(WidgetTester tester) async {
  await tester.enterText(find.widgetWithText(TextField, 'Email Address'), 'demo@klass.id');
  await tester.enterText(find.widgetWithText(TextField, 'Password'), 'password123');
  await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('freelancer login follows auth me role and shows freelancer shell', (tester) async {
    await _pumpLoginFlow(
      tester,
      loginUser: {
        'id': 99,
        'name': 'Legacy Teacher Cache',
        'email': 'demo@klass.id',
        'role': 'teacher',
      },
      meUser: {
        'id': 3,
        'name': 'Rina Freelancer',
        'email': 'rina@klass.id',
        'role': 'freelancer',
      },
    );

    await _login(tester);

    expect(find.text('✅ Berhasil masuk sebagai Freelancer.'), findsOneWidget);
    expect(find.text('Jobs'), findsOneWidget);
    expect(find.text('Search'), findsNothing);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('FREELANCER'), findsOneWidget);
    expect(find.text('Rina Freelancer'), findsOneWidget);
  });

  testWidgets('teacher login remains on teacher shell after auth me refresh', (tester) async {
    await _pumpLoginFlow(
      tester,
      loginUser: {
        'id': 88,
        'name': 'Stale Freelancer Cache',
        'email': 'demo@klass.id',
        'role': 'freelancer',
      },
      meUser: {
        'id': 1,
        'name': 'Sarah Jenkins',
        'email': 'sarah@klass.id',
        'role': 'teacher',
      },
    );

    await _login(tester);

    expect(find.text('✅ Berhasil masuk.'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Workspace'), findsOneWidget);
    expect(find.text('Jobs'), findsNothing);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('TEACHER'), findsOneWidget);
    expect(find.text('Sarah Jenkins'), findsOneWidget);
  });
}