import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klass_app/services/api_service.dart';
import 'package:klass_app/services/media_generation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MediaGenerationAdapter implements HttpClientAdapter {
  _MediaGenerationAdapter({this.failOnPoll = false, this.failOnSuggest = false});

  final bool failOnPoll;
  final bool failOnSuggest;
  int submitCount = 0;
  int pollCount = 0;
  String? submitPath;
  String? pollPath;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'POST' && options.path.contains('/suggest-freelancers')) {
      if (failOnSuggest) {
        return _jsonErrorResponse({
          'error': {'message': 'System busy, try again later'}
        }, 503);
      }
      return _jsonResponse({
        'success': true,
        'data': [
          {
            'freelancer': {'id': 1, 'name': 'John Doe', 'rating': 4.5},
            'match_score': 0.85,
            'success_rate': 0.95,
          }
        ]
      });
    }

    if (options.method == 'POST' && options.path.endsWith('/media-generations')) {
      submitCount += 1;
      submitPath = options.path;

      return _jsonResponse({
        'success': true,
        'data': {
          'id': 'gen-123',
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

    if (options.method == 'GET' && options.path.contains('/media-generations/gen-123')) {
      pollCount += 1;
      pollPath = options.path;

      if (failOnPoll) {
        return _jsonResponse({
          'success': true,
          'data': {
            'id': 'gen-123',
            'prompt': 'Buatkan deck termodinamika untuk kelas 11.',
            'preferred_output_type': 'auto',
            'resolved_output_type': 'pptx',
            'status': 'failed',
            'status_meta': {
              'lifecycle_version': 'media_generation_lifecycle.v1',
              'is_terminal': true,
              'retry_behavior': 'restart_from_interpreting',
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
            'error': {
              'code': 'artifact_invalid',
              'message': 'File hasil generator tidak lolos validasi. Silakan coba lagi.',
              'retryable': true,
            },
          },
        });
      }

      return _jsonResponse({
        'success': true,
        'data': {
          'id': 'gen-123',
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

    return _jsonResponse({'data': []});
  }

  ResponseBody _jsonErrorResponse(Map<String, dynamic> payload, int statusCode) {
    return ResponseBody.fromString(
      jsonEncode(payload),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = MediaGenerationService();
    service.reset(notify: false);
  });

  tearDown(() {
    service.reset(notify: false);
  });

  test('submitPrompt stores generation id and hydrates final delivery payload after polling', () async {
    final adapter = _MediaGenerationAdapter();
    ApiService().dio.httpClientAdapter = adapter;

    final submitted = await service.submitPrompt(
      prompt: 'Buatkan deck termodinamika untuk kelas 11.',
    );

    expect(submitted, isTrue);
    expect(service.state, MediaGenerationViewState.inProgress);
    expect(service.generationId, 'gen-123');
    expect(service.currentStatus, 'queued');
    expect(adapter.submitCount, 1);
    expect(adapter.submitPath, '/media-generations');

    await service.pollNow();

    expect(adapter.pollCount, 1);
    expect(adapter.pollPath, '/media-generations/gen-123');
    expect(service.state, MediaGenerationViewState.success);
    expect(service.currentStatus, 'completed');
    expect(service.deliveryPayload?['title'], 'Deck Termodinamika Kelas 11 siap digunakan');
    expect(
      (service.deliveryPayload?['artifact'] as Map<String, dynamic>)['file_url'],
      'https://example.com/materials/thermodynamics-deck.pptx',
    );
  });

  test('pollNow transitions service into error state when backend returns failed generation', () async {
    final adapter = _MediaGenerationAdapter(failOnPoll: true);
    ApiService().dio.httpClientAdapter = adapter;

    final submitted = await service.submitPrompt(
      prompt: 'Buatkan deck termodinamika untuk kelas 11.',
    );

    expect(submitted, isTrue);
    expect(service.state, MediaGenerationViewState.inProgress);

    await service.pollNow();

    expect(adapter.pollCount, 1);
    expect(service.state, MediaGenerationViewState.error);
    expect(service.currentStatus, 'failed');
    expect(service.errorMessage, 'File hasil generator tidak lolos validasi. Silakan coba lagi.');
  });

  group('suggestFreelancers', () {
    test('returns list of suggestions on success', () async {
      final adapter = _MediaGenerationAdapter();
      ApiService().dio.httpClientAdapter = adapter;

      final suggestions = await service.suggestFreelancers('gen-123');

      expect(suggestions, isNotEmpty);
      expect(suggestions.first.name, 'John Doe');
      expect(suggestions.first.matchScore, 0.85);
    });

    test('throws Exception with resolved error message on DioException', () async {
      final adapter = _MediaGenerationAdapter(failOnSuggest: true);
      ApiService().dio.httpClientAdapter = adapter;

      expect(
        () => service.suggestFreelancers('gen-123'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('System busy'))),
      );
    });
  });
}