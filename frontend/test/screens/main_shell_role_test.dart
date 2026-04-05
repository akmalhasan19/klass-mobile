import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klass_app/main.dart';
import 'package:klass_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MainShellAdapter implements HttpClientAdapter {
  _MainShellAdapter({required this.user});

  final Map<String, dynamic> user;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.contains('/auth/me')) {
      return _jsonResponse({'data': user});
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

Future<void> _pumpMainShell(
  WidgetTester tester, {
  required Map<String, dynamic> user,
}) async {
  SharedPreferences.setMockInitialValues({
    'auth_token': 'test-token',
    'user_data': jsonEncode(user),
  });

  final api = ApiService();
  api.dio.httpClientAdapter = _MainShellAdapter(user: user);

  await tester.pumpWidget(
    const MaterialApp(
      home: MainShell(),
    ),
  );

  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 1200));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('MainShell shows freelancer navigation and freelancer profile UI', (tester) async {
    await _pumpMainShell(
      tester,
      user: {
        'id': 3,
        'name': 'Rina Freelancer',
        'email': 'rina@klass.id',
        'role': 'freelancer',
      },
    );

    expect(find.text('Jobs'), findsOneWidget);
    expect(find.text('Search'), findsNothing);

    await tester.tap(find.text('Profile'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('FREELANCER'), findsOneWidget);
    expect(find.text('Rina Freelancer'), findsOneWidget);
  });

  testWidgets('MainShell keeps teacher navigation and teacher profile UI intact', (tester) async {
    await _pumpMainShell(
      tester,
      user: {
        'id': 1,
        'name': 'Sarah Jenkins',
        'email': 'sarah@klass.id',
        'role': 'teacher',
      },
    );

    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Workspace'), findsOneWidget);
    expect(find.text('Jobs'), findsNothing);

    await tester.tap(find.text('Profile'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('TEACHER'), findsOneWidget);
    expect(find.text('Sarah Jenkins'), findsOneWidget);
  });
}