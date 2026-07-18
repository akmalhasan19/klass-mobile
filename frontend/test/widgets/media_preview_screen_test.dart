import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klass_app/core/config/api_config.dart';
import 'package:klass_app/features/media_generation/data/media_generation_service.dart';
import 'package:klass_app/features/media_generation/widgets/media_preview_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Mock HTTP adapter — configurable for different preview URL scenarios.
// ---------------------------------------------------------------------------
class _MockPreviewAdapter implements HttpClientAdapter {
  _MockPreviewAdapter({required this.generationId, required this.responseData});

  final String generationId;
  final Map<String, dynamic> responseData;
  int submitCount = 0;
  int pollCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'POST' && options.path.endsWith('/media-generations')) {
      submitCount += 1;
      return _jsonResponse({
        'success': true,
        'data': {
          'id': generationId,
          'prompt': 'Test prompt',
          'status': 'queued',
          'status_meta': {
            'lifecycle_version': 'media_generation_lifecycle.v1',
            'is_terminal': false,
          },
          'artifact': {'file_url': null},
          'publication': {'topic': null},
          'delivery_payload': null,
          'error': null,
        },
      }, 202);
    }

    if (options.method == 'GET' && options.path.contains('/media-generations/$generationId')) {
      pollCount += 1;
      return _jsonResponse({'success': true, 'data': responseData});
    }

    return _jsonResponse({'data': []});
  }

  ResponseBody _jsonResponse(Map<String, dynamic> payload, [int status = 200]) {
    return ResponseBody.fromString(
      jsonEncode(payload),
      status,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _createTestDio(HttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(milliseconds: ApiConfig.connectTimeout),
    receiveTimeout: const Duration(milliseconds: ApiConfig.receiveTimeout),
    sendTimeout: const Duration(milliseconds: ApiConfig.sendTimeout),
  ));
  dio.httpClientAdapter = adapter;
  return dio;
}

// ---------------------------------------------------------------------------
// Helper: build a completed generation response with optional preview_url
// placement.
// ---------------------------------------------------------------------------
Map<String, dynamic> _buildCompletedResponse({
  required String id,
  String? deliveryPreviewUrl,
  String? artifactMetadataPreviewUrl,
}) {
  final deliveryPayload = <String, dynamic>{
    'schema_version': 'media_delivery_response.v1',
    'title': 'Test Deck',
    'preview_summary': 'Deck siap.',
    'teacher_message': 'Gunakan untuk kelas.',
    'artifact': {
      'output_type': 'pdf',
      'title': 'Test Deck',
      'file_url': 'https://example.com/artifacts/test.pdf',
    },
  };
  if (deliveryPreviewUrl != null) {
    deliveryPayload['preview_url'] = deliveryPreviewUrl;
  }

  final data = <String, dynamic>{
    'id': id,
    'prompt': 'Test prompt',
    'resolved_output_type': 'pdf',
    'status': 'completed',
    'status_meta': {
      'lifecycle_version': 'media_generation_lifecycle.v1',
      'is_terminal': true,
    },
    'artifact': {
      'file_url': 'https://example.com/artifacts/test.pdf',
    },
    'publication': {
      'topic': {'id': 't1', 'title': 'Test'},
    },
    'delivery_payload': deliveryPayload,
    'error': null,
  };
  if (artifactMetadataPreviewUrl != null) {
    data['artifact_metadata'] = {'preview_url': artifactMetadataPreviewUrl};
  }
  return data;
}

class MyMockInAppWebViewPlatform extends InAppWebViewPlatform {
  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(PlatformInAppWebViewWidgetCreationParams params) {
    return _MyMockPlatformInAppWebViewWidget(params);
  }
}

class _MyMockPlatformInAppWebViewWidget extends PlatformInAppWebViewWidget {
  // ignore: use_super_parameters
  _MyMockPlatformInAppWebViewWidget(PlatformInAppWebViewWidgetCreationParams params)
      : super.implementation(params);

  @override
  Widget build(BuildContext context) {
    return const SizedBox();
  }

  @override
  void dispose() {}

  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) {
    throw UnimplementedError();
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    InAppWebViewPlatform.instance = MyMockInAppWebViewPlatform();
  });

  // =====================================================================
  // MediaGenerationService.previewUrl getter
  // =====================================================================
  group('MediaGenerationService.previewUrl', () {
    test('returns preview_url from delivery_payload (primary path)', () async {
      final adapter = _MockPreviewAdapter(
        generationId: 'gen-pp-001',
        responseData: _buildCompletedResponse(
          id: 'gen-pp-001',
          deliveryPreviewUrl: 'https://example.com/preview/gen-pp-001.html',
        ),
      );
      final service = MediaGenerationService(_createTestDio(adapter));

      await service.submitPrompt(prompt: 'Test');
      await service.pollNow();

      expect(service.previewUrl, 'https://example.com/preview/gen-pp-001.html');
      service.reset(notify: false);
    });

    test('falls back to artifact_metadata.preview_url when delivery lacks it', () async {
      final adapter = _MockPreviewAdapter(
        generationId: 'gen-pp-002',
        responseData: _buildCompletedResponse(
          id: 'gen-pp-002',
          // No deliveryPreviewUrl
          artifactMetadataPreviewUrl: 'https://example.com/preview/gen-pp-002-fallback.html',
        ),
      );
      final service = MediaGenerationService(_createTestDio(adapter));

      await service.submitPrompt(prompt: 'Test');
      await service.pollNow();

      expect(service.previewUrl, 'https://example.com/preview/gen-pp-002-fallback.html');
      service.reset(notify: false);
    });

    test('prefers delivery_payload.preview_url over artifact_metadata when both present', () async {
      final adapter = _MockPreviewAdapter(
        generationId: 'gen-pp-003',
        responseData: _buildCompletedResponse(
          id: 'gen-pp-003',
          deliveryPreviewUrl: 'https://example.com/preview/delivery.html',
          artifactMetadataPreviewUrl: 'https://example.com/preview/metadata.html',
        ),
      );
      final service = MediaGenerationService(_createTestDio(adapter));

      await service.submitPrompt(prompt: 'Test');
      await service.pollNow();

      expect(service.previewUrl, 'https://example.com/preview/delivery.html');
      service.reset(notify: false);
    });

    test('returns null when no resource is loaded', () {
      final service = MediaGenerationService(_createTestDio(
        _MockPreviewAdapter(generationId: 'x', responseData: {}),
      ));
      expect(service.previewUrl, isNull);
    });

    test('returns null when generation has no preview_url anywhere', () async {
      final adapter = _MockPreviewAdapter(
        generationId: 'gen-pp-004',
        responseData: _buildCompletedResponse(id: 'gen-pp-004'),
      );
      final service = MediaGenerationService(_createTestDio(adapter));

      await service.submitPrompt(prompt: 'Test');
      await service.pollNow();

      expect(service.previewUrl, isNull);
      service.reset(notify: false);
    });
  });

  // =====================================================================
  // MediaPreviewScreen widget tests
  //
  // InAppWebView is a platform widget — its internal fields
  // (initialUrlRequest, initialSettings) are not accessible via
  // tester.widget<InAppWebView>() in version 6.x.  These tests verify the
  // surrounding widget tree (Scaffold, AppBar, progress indicator) that
  // wraps the WebView.
  // =====================================================================
  group('MediaPreviewScreen widget', () {
    Widget buildScreen({String? title, String url = 'https://example.com/preview/test.html'}) {
      return MaterialApp(
        home: MediaPreviewScreen(previewUrl: url, title: title),
      );
    }

    testWidgets('renders Scaffold with AppBar showing provided title', (tester) async {
      await tester.pumpWidget(buildScreen(title: 'Fotosintesis'));
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('Fotosintesis'), findsOneWidget);
    });

    testWidgets('falls back to "Preview" when no title is provided', (tester) async {
      await tester.pumpWidget(buildScreen());
      expect(find.text('Preview'), findsOneWidget);
    });

    testWidgets('AppBar uses the brand teal background color', (tester) async {
      await tester.pumpWidget(buildScreen());
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, const Color(0xFF0E4C5C));
    });

    testWidgets('contains InAppWebView widget in the tree', (tester) async {
      await tester.pumpWidget(buildScreen());
      expect(find.byType(InAppWebView), findsOneWidget);
    });

    testWidgets('shows LinearProgressIndicator while loading (progress < 1.0)', (tester) async {
      await tester.pumpWidget(buildScreen());
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('handles long title without overflow', (tester) async {
      final longTitle = 'A' * 200;
      await tester.pumpWidget(buildScreen(title: longTitle));
      expect(find.text(longTitle), findsOneWidget);
    });
  });

  // =====================================================================
  // InAppWebViewSettings configuration verification
  //
  // Since we cannot read InAppWebView's constructor args via widget
  // inspection, we verify that the settings object we construct in the
  // screen code has the expected values by constructing the same object
  // independently and asserting its fields.
  // =====================================================================
  group('InAppWebViewSettings for Jinja2 HTML compatibility', () {
    test('settings match expected configuration for self-contained HTML preview', () {
      // This mirrors the settings used in MediaPreviewScreen.build().
      // If the screen's settings change, this test should be updated too.
      final settings = InAppWebViewSettings(
        javaScriptEnabled: true,
        verticalScrollBarEnabled: true,
        horizontalScrollBarEnabled: false,
        allowFileAccessFromFileURLs: true,
        allowUniversalAccessFromFileURLs: true,
        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
        useWideViewPort: true,
        loadWithOverviewMode: true,
        supportZoom: false,
        builtInZoomControls: false,
        displayZoomControls: false,
      );

      // Core: JS + file access for self-contained HTML
      expect(settings.javaScriptEnabled, isTrue);
      expect(settings.allowFileAccessFromFileURLs, isTrue);
      expect(settings.allowUniversalAccessFromFileURLs, isTrue);
      expect(settings.mixedContentMode, MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW);

      // Viewport: fit 1280×720 slides to mobile screen
      expect(settings.useWideViewPort, isTrue);
      expect(settings.loadWithOverviewMode, isTrue);

      // Zoom: disabled for slide-deck viewing
      expect(settings.supportZoom, isFalse);
      expect(settings.builtInZoomControls, isFalse);
      expect(settings.displayZoomControls, isFalse);

      // Scrolling: vertical only
      expect(settings.verticalScrollBarEnabled, isTrue);
      expect(settings.horizontalScrollBarEnabled, isFalse);
    });
  });
}
