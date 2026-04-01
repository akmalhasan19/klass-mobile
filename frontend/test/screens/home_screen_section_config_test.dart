import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klass_app/screens/home_screen.dart';
import 'package:klass_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _HomeScreenAdapter implements HttpClientAdapter {
  _HomeScreenAdapter({
    required this.sections,
    this.failSections = false,
  });

  final List<Map<String, dynamic>> sections;
  final bool failSections;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.contains('/homepage-sections')) {
      if (failSections) {
        return _jsonResponse({
          'unexpected': true,
        });
      }

      return _jsonResponse({
        'data': sections,
      });
    }

    if (options.path.contains('/topics') || options.path.contains('/marketplace-tasks')) {
      return _jsonResponse({
        'success': true,
        'data': [],
      });
    }

    return _jsonResponse({
      'data': [],
    });
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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('HomeScreen renders backend-configured section labels in configured order', (tester) async {
    final api = ApiService();
    api.dio.httpClientAdapter = _HomeScreenAdapter(
      sections: [
        {
          'id': 'section-2',
          'key': 'top_freelancers',
          'label': 'Mentor Pilihan',
          'position': 1,
          'is_enabled': true,
          'data_source': 'marketplace_tasks',
        },
        {
          'id': 'section-1',
          'key': 'project_recommendations',
          'label': 'Belajar Minggu Ini',
          'position': 2,
          'is_enabled': true,
          'data_source': 'topics',
        },
        {
          'id': 'section-3',
          'key': 'projects',
          'label': 'Hidden Section',
          'position': 3,
          'is_enabled': false,
          'data_source': 'topics',
        },
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HomeScreen(),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));

    final freelancerSection = find.text('Mentor Pilihan');
    final projectSection = find.text('Belajar Minggu Ini');

    expect(freelancerSection, findsOneWidget);
    expect(projectSection, findsOneWidget);
    expect(find.text('Hidden Section'), findsNothing);

    final freelancerOffset = tester.getTopLeft(freelancerSection);
    final projectOffset = tester.getTopLeft(projectSection);

    expect(freelancerOffset.dy, lessThan(projectOffset.dy));
  });

  testWidgets('HomeScreen falls back to default labels when section config fetch fails', (tester) async {
    final api = ApiService();
    api.dio.httpClientAdapter = _HomeScreenAdapter(
      sections: const [],
      failSections: true,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HomeScreen(),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Project Recommendations'), findsOneWidget);
    expect(find.text('Top Freelancers'), findsOneWidget);
  });
}