import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klass_app/screens/home_screen.dart';
import 'package:klass_app/services/api_service.dart';
import 'package:klass_app/services/media_generation_service.dart';
import 'package:klass_app/widgets/prompt_input_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MediaFlowAdapter implements HttpClientAdapter {
  int homepageRecommendationRequests = 0;
  int topicsRequests = 0;
  int generationSubmitRequests = 0;
  int generationPollRequests = 0;

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
      homepageRecommendationRequests += 1;

      return _jsonResponse({
        'data': homepageRecommendationRequests == 1
            ? [
                {
                  'id': 'seed-project',
                  'title': 'Seed Recommendation',
                  'description': 'Seed recommendation',
                  'thumbnail_url': null,
                  'ratio': '16:9',
                  'project_type': 'mobile',
                  'tags': ['Seed'],
                  'modules': ['Seed'],
                  'source_type': 'admin_upload',
                  'display_priority': 100,
                },
              ]
            : [
                {
                  'id': 'generated-project',
                  'title': 'Deck Termodinamika Kelas 11',
                  'description': 'Generated recommendation',
                  'thumbnail_url': 'https://example.com/gallery/thermodynamics-deck.svg',
                  'ratio': '16:9',
                  'project_type': 'learning_material',
                  'tags': ['Science'],
                  'modules': ['Konsep Dasar'],
                  'source_type': 'ai_generated',
                  'display_priority': 120,
                },
              ],
        'meta': {
          'total': 1,
        },
      });
    }

    if (options.path.contains('/marketplace-tasks')) {
      return _jsonResponse({
        'success': true,
        'data': const [],
        'meta': {'total': 0},
      });
    }

    if (options.method == 'POST' && options.path.endsWith('/media-generations')) {
      generationSubmitRequests += 1;

      return _jsonResponse({
        'success': true,
        'data': {
          'id': 'gen-flow-123',
          'prompt': 'Buatkan deck termodinamika untuk kelas 11.',
          'preferred_output_type': 'auto',
          'resolved_output_type': null,
          'status': 'queued',
          'status_meta': {
            'lifecycle_version': 'media_generation_lifecycle.v1',
            'is_terminal': false,
            'retry_behavior': null,
          },
          'artifact': {
            'storage_path': null,
            'file_url': null,
            'thumbnail_url': null,
            'mime_type': null,
          },
          'publication': {
            'topic': null,
            'content': null,
            'recommended_project': null,
          },
          'delivery_payload': null,
          'error': null,
        },
      }, 202);
    }

    if (options.method == 'GET' && options.path.contains('/media-generations/gen-flow-123')) {
      generationPollRequests += 1;

      return _jsonResponse({
        'success': true,
        'data': {
          'id': 'gen-flow-123',
          'prompt': 'Buatkan deck termodinamika untuk kelas 11.',
          'preferred_output_type': 'auto',
          'resolved_output_type': 'pptx',
          'status': 'completed',
          'status_meta': {
            'lifecycle_version': 'media_generation_lifecycle.v1',
            'is_terminal': true,
            'retry_behavior': null,
          },
          'artifact': {
            'storage_path': 'materials/generated/thermodynamics-deck.pptx',
            'file_url': 'https://example.com/materials/thermodynamics-deck.pptx',
            'thumbnail_url': 'https://example.com/gallery/thermodynamics-deck.svg',
            'mime_type': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
          },
          'publication': {
            'topic': {
              'id': 'topic-123',
              'title': 'Deck Termodinamika Kelas 11',
            },
            'content': {
              'id': 'content-123',
              'title': 'Deck Termodinamika Kelas 11',
              'type': 'brief',
              'media_url': 'https://example.com/materials/thermodynamics-deck.pptx',
            },
            'recommended_project': {
              'id': 'project-123',
              'title': 'Deck Termodinamika Kelas 11',
              'source_type': 'ai_generated',
              'project_file_url': 'https://example.com/materials/thermodynamics-deck.pptx',
            },
          },
          'delivery_payload': {
            'schema_version': 'media_delivery_response.v1',
            'title': 'Deck Termodinamika Kelas 11 siap digunakan',
            'preview_summary': 'Deck sudah dipublikasikan dan siap dipakai untuk pembuka diskusi kelas.',
            'teacher_message': 'Gunakan deck ini untuk membuka konsep kalor lalu lanjutkan dengan latihan cepat.',
            'recommended_next_steps': [
              'Buka slide pembuka sebelum kelas dimulai.',
              'Bagikan file ke siswa jika dibutuhkan.',
            ],
            'classroom_tips': ['Gunakan contoh kalor sehari-hari.'],
            'artifact': {
              'output_type': 'pptx',
              'title': 'Deck Termodinamika Kelas 11',
              'file_url': 'https://example.com/materials/thermodynamics-deck.pptx',
              'thumbnail_url': 'https://example.com/gallery/thermodynamics-deck.svg',
              'mime_type': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
              'filename': 'thermodynamics-deck.pptx',
            },
            'publication': {
              'topic': {
                'id': 'topic-123',
                'title': 'Deck Termodinamika Kelas 11',
              },
              'content': {
                'id': 'content-123',
                'title': 'Deck Termodinamika Kelas 11',
                'type': 'brief',
                'media_url': 'https://example.com/materials/thermodynamics-deck.pptx',
              },
              'recommended_project': {
                'id': 'project-123',
                'title': 'Deck Termodinamika Kelas 11',
                'project_file_url': 'https://example.com/materials/thermodynamics-deck.pptx',
              },
            },
            'response_meta': {
              'generated_at': '2026-04-07T12:00:00Z',
              'llm_used': true,
              'provider': 'llm-gateway',
              'model': 'gpt-5.4',
            },
            'fallback': {
              'triggered': false,
              'reason_code': null,
              'action': null,
            },
          },
          'error': null,
        },
      });
    }

    if (options.path.contains('/topics')) {
      topicsRequests += 1;

      return _jsonResponse({
        'data': [
          {
            'id': 'topic-123',
            'title': 'Deck Termodinamika Kelas 11',
            'thumbnail_url': 'https://example.com/gallery/thermodynamics-deck.svg',
            'media_url': 'https://example.com/materials/thermodynamics-deck.pptx',
          },
        ],
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
    SharedPreferences.setMockInitialValues({
      'auth_token': 'teacher-token',
      'user_data': jsonEncode({'id': 1, 'role': 'teacher'}),
    });
    MediaGenerationService().reset(notify: false);
  });

  tearDown(() {
    MediaGenerationService().reset(notify: false);
  });

  testWidgets('HomeScreen shows success actions and refreshes workspace plus homepage after generation completes', (tester) async {
    final adapter = _MediaFlowAdapter();
    ApiService().dio.httpClientAdapter = adapter;

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HomeScreen(role: 'teacher'),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(adapter.homepageRecommendationRequests, 1);

    await tester.enterText(find.byType(TextField).first, 'Buatkan deck termodinamika untuk kelas 11.');
    await tester.pump();

    final promptWidget = tester.widget<PromptInputWidget>(find.byType(PromptInputWidget));
    promptWidget.onSubmit?.call('Buatkan deck termodinamika untuk kelas 11.');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(adapter.generationSubmitRequests, 1);
    expect(find.text('Understanding your prompt'), findsWidgets);

    await tester.pump(MediaGenerationService.pollingInterval);
    await tester.pumpAndSettle();

    expect(adapter.generationPollRequests, 1);
    expect(adapter.topicsRequests, 1);
    expect(adapter.homepageRecommendationRequests, 2);

    expect(find.text('Deck Termodinamika Kelas 11 siap digunakan'), findsOneWidget);
    expect(find.text('Download File'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
  });
}