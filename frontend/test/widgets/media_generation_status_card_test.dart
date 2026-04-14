import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klass_app/services/api_service.dart';
import 'package:klass_app/services/media_generation_service.dart';
import 'package:klass_app/widgets/media_generation_status_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MediaGenerationStatusAdapter implements HttpClientAdapter {
  _MediaGenerationStatusAdapter({this.failOnPoll = false});

  final bool failOnPoll;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'POST' && options.path.endsWith('/media-generations')) {
      return _jsonResponse({
        'success': true,
        'data': {
          'id': 'gen-status-123',
          'prompt': 'Buatkan deck termodinamika untuk kelas 11.',
          'preferred_output_type': 'auto',
          'resolved_output_type': null,
          'status': 'interpreting',
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

    if (options.method == 'GET' && options.path.contains('/media-generations/gen-status-123')) {
      if (failOnPoll) {
        return _jsonResponse({
          'success': true,
          'data': {
            'id': 'gen-status-123',
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
          'id': 'gen-status-123',
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
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = MediaGenerationService();
    service.reset(notify: false);
  });

  tearDown(() {
    service.reset(notify: false);
  });

  testWidgets('MediaGenerationStatusCard renders loading and progress states', (tester) async {
    ApiService().dio.httpClientAdapter = _MediaGenerationStatusAdapter();

    final submitted = await tester.runAsync(() async {
      final submitted = await service.submitPrompt(
        prompt: 'Buatkan deck termodinamika untuk kelas 11.',
      );
      service.stopPolling();

      return submitted;
    });

    expect(submitted, isTrue);

    await tester.pumpWidget(
      buildTestHarness(MediaGenerationStatusCard(service: service)),
    );
    await tester.pump();

    expect(find.text('Understanding your prompt'), findsOneWidget);
    expect(find.text('Understanding prompt'), findsWidgets);
    expect(find.text('Deciding format'), findsOneWidget);
    expect(find.text('Generating file'), findsOneWidget);
    expect(find.text('Publishing result'), findsWidgets);
  });

  testWidgets('MediaGenerationStatusCard renders success state and wires CTA callbacks', (tester) async {
    ApiService().dio.httpClientAdapter = _MediaGenerationStatusAdapter();
    var downloadTapCount = 0;
    var regenerateTapCount = 0;
    var hireFreelancerTapCount = 0;

    await tester.runAsync(() async {
      await service.submitPrompt(prompt: 'Buatkan deck termodinamika untuk kelas 11.');
      service.stopPolling();
      await service.pollNow();
      service.stopPolling();
    });

    await tester.pumpWidget(
      buildTestHarness(
        MediaGenerationStatusCard(
          service: service,
          onDownload: () async => downloadTapCount += 1,
          onRegenerate: () async => regenerateTapCount += 1,
          onHireFreelancer: () async => hireFreelancerTapCount += 1,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Deck Termodinamika Kelas 11 siap digunakan'), findsOneWidget);
    expect(find.text('Artifact published successfully'), findsOneWidget);
    expect(find.text('Download File'), findsOneWidget);
    expect(find.text('Regenerate'), findsOneWidget);
    expect(find.text('Hire Freelancer'), findsOneWidget);

    await tester.ensureVisible(find.text('Download File'));
    await tester.tap(find.text('Download File'));
    await tester.pump();
    await tester.ensureVisible(find.text('Regenerate'));
    await tester.tap(find.text('Regenerate'));
    await tester.pump();
    await tester.ensureVisible(find.text('Hire Freelancer'));
    await tester.tap(find.text('Hire Freelancer'));
    await tester.pump();

    expect(downloadTapCount, 1);
    expect(regenerateTapCount, 1);
    expect(hireFreelancerTapCount, 1);
  });

  testWidgets('MediaGenerationStatusCard renders terminal error state from failed generation', (tester) async {
    ApiService().dio.httpClientAdapter = _MediaGenerationStatusAdapter(failOnPoll: true);

    await tester.runAsync(() async {
      await service.submitPrompt(prompt: 'Buatkan deck termodinamika untuk kelas 11.');
      service.stopPolling();
      await service.pollNow();
      service.stopPolling();
    });

    await tester.pumpWidget(
      buildTestHarness(MediaGenerationStatusCard(service: service)),
    );
    await tester.pump();

    expect(find.text('Media generation needs attention'), findsOneWidget);
    expect(find.text('Generation did not finish successfully'), findsOneWidget);
    expect(find.text('File hasil generator tidak lolos validasi. Silakan coba lagi.'), findsOneWidget);
  });
}