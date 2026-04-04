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
    this.projects = const [],
    this.freelancers = const [],
    this.failSections = false,
    this.failProjectsCount = 0,
  }) : remainingProjectFailures = failProjectsCount;

  final List<Map<String, dynamic>> sections;
  final List<Map<String, dynamic>> projects;
  final List<Map<String, dynamic>> freelancers;
  final bool failSections;
  final int failProjectsCount;
  int remainingProjectFailures;

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

    if (options.path.contains('/homepage-recommendations')) {
      if (remainingProjectFailures > 0) {
        remainingProjectFailures -= 1;

        throw DioException(
          requestOptions: options,
          response: Response(
            requestOptions: options,
            statusCode: 500,
            data: {
              'message': 'Simulated recommendation feed failure',
            },
          ),
          type: DioExceptionType.badResponse,
          message: 'Simulated recommendation feed failure',
        );
      }

      return _jsonResponse({
        'data': projects,
        'meta': {
          'total': projects.length,
        },
      });
    }

    if (options.path.contains('/marketplace-tasks')) {
      return _jsonResponse({
        'success': true,
        'data': freelancers,
        'meta': {
          'total': freelancers.length,
        },
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

Map<String, dynamic> _projectRecommendation({
  required String id,
  required String title,
  String sourceType = 'admin_upload',
}) {
  return {
    'id': id,
    'title': title,
    'description': 'Recommendation for $title',
    'thumbnail_url': null,
    'ratio': '16:9',
    'project_type': 'mobile',
    'tags': ['Flutter'],
    'modules': ['Auth'],
    'source_type': sourceType,
    'display_priority': 100,
  };
}

Future<void> _pumpHomeScreen(WidgetTester tester, _HomeScreenAdapter adapter) async {
  final api = ApiService();
  api.dio.httpClientAdapter = adapter;

  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: HomeScreen(),
      ),
    ),
  );

  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('HomeScreen renders backend-configured section labels in configured order', (tester) async {
    await _pumpHomeScreen(
      tester,
      _HomeScreenAdapter(
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
      projects: [
        _projectRecommendation(id: 'project-1', title: 'Admin Showcase'),
      ],
      freelancers: [
        {
          'id': 'freelancer-1',
          'name': 'Mentor QA',
        },
      ],
      ),
    );

    final freelancerSection = find.text('Mentor Pilihan');
    final projectSection = find.text('Belajar Minggu Ini');

    expect(freelancerSection, findsOneWidget);
    expect(projectSection, findsOneWidget);
    expect(find.text('Hidden Section'), findsNothing);
    expect(find.text('Admin Showcase'), findsOneWidget);
    expect(find.text('Klass Curated'), findsOneWidget);
    expect(find.text('★ Curated'), findsOneWidget);

    final freelancerOffset = tester.getTopLeft(freelancerSection);
    final projectOffset = tester.getTopLeft(projectSection);

    expect(freelancerOffset.dy, lessThan(projectOffset.dy));
  });

  testWidgets('HomeScreen falls back to default labels when section config fetch fails', (tester) async {
    await _pumpHomeScreen(
      tester,
      _HomeScreenAdapter(
        sections: const [],
        failSections: true,
      ),
    );

    expect(find.text('Project Recommendations'), findsOneWidget);
    expect(find.text('Top Freelancers'), findsOneWidget);
  });

  testWidgets('HomeScreen shows empty state when the recommendation feed is empty', (tester) async {
    await _pumpHomeScreen(
      tester,
      _HomeScreenAdapter(
        sections: [
          {
            'id': 'section-1',
            'key': 'project_recommendations',
            'label': 'Project Recommendations',
            'position': 1,
            'is_enabled': true,
            'data_source': 'recommended_projects',
          },
        ],
      ),
    );

    expect(find.text('Project Recommendations'), findsOneWidget);
    expect(find.text('Belum ada project'), findsOneWidget);
  });

  testWidgets('HomeScreen shows recommendation error state and can retry successfully', (tester) async {
    final adapter = _HomeScreenAdapter(
      sections: [
        {
          'id': 'section-1',
          'key': 'project_recommendations',
          'label': 'Project Recommendations',
          'position': 1,
          'is_enabled': true,
          'data_source': 'recommended_projects',
        },
      ],
      projects: [
        _projectRecommendation(id: 'project-2', title: 'Recovered Recommendation'),
      ],
      failProjectsCount: 1,
    );

    await _pumpHomeScreen(tester, adapter);

    expect(find.text('Copy Debug Info'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('/homepage-recommendations'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Recovered Recommendation'), findsOneWidget);
    expect(find.text('Copy Debug Info'), findsNothing);
  });
}