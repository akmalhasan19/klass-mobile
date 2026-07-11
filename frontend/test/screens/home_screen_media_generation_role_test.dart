import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klass_app/features/home/screens/home_screen.dart';
import 'package:klass_app/core/providers/dio_provider.dart';
import 'package:klass_app/core/config/api_config.dart';
import 'package:klass_app/features/media_generation/data/media_generation_service.dart';
import 'package:klass_app/features/media_generation/widgets/media_generation_status_card.dart';
import 'package:klass_app/features/home/widgets/prompt_input_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _HomeScreenRoleAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.contains('/homepage-sections')) {
      return _jsonResponse({
        'data': [
          {'key': 'project_recommendations', 'label': 'Projects', 'position': 1},
          {'key': 'freelancers', 'label': 'Freelancers', 'position': 2},
        ],
      });
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
        'data': const [],
        'meta': {'total': 0},
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
    SharedPreferences.setMockInitialValues({
      'auth_token': 'freelancer-token',
      'user_data': jsonEncode({'id': 3, 'role': 'freelancer'}),
    });
    MediaGenerationService(_createTestDio()).reset(notify: false);
  });

  tearDown(() {
    MediaGenerationService(_createTestDio()).reset(notify: false);
  });

  testWidgets('HomeScreen freelancer role keeps media generation hero prompt hidden', (tester) async {
    final dio = _createTestDio();
    dio.httpClientAdapter = _HomeScreenRoleAdapter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dioProvider.overrideWithValue(dio)],
        child: const MaterialApp(
          home: Scaffold(
            body: HomeScreen(role: 'freelancer'),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(PromptInputWidget), findsNothing);
    expect(find.byType(MediaGenerationStatusCard), findsNothing);
  });
}
