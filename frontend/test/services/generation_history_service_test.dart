import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klass_app/services/api_service.dart';
import 'package:klass_app/services/generation_history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _HistoryAdapter implements HttpClientAdapter {
  bool failOnDetails = false;
  bool failOnList = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // Mock GET /media-generations/:id
    if (options.method == 'GET' && options.path.contains('/media-generations/') && !options.path.endsWith('/media-generations')) {
      if (failOnDetails) {
        return _jsonResponse({
          'success': false,
          'message': 'Generation not found',
        }, 404);
      }

      final id = options.path.split('/').last;
      String? parentId;
      if (id == 'child-1') {
        parentId = 'parent-1';
      }

      return _jsonResponse({
        'success': true,
        'data': {
          'id': id,
          'generated_from_id': parentId,
        },
      });
    }

    // Mock GET /media-generations?parent_id=:id
    if (options.method == 'GET' && options.path.endsWith('/media-generations')) {
      if (failOnList) {
        return _jsonResponse({
          'success': false,
          'error': {'message': 'Database error'},
        }, 500);
      }

      return _jsonResponse({
        'success': true,
        'data': [
          {
            'id': 'parent-1',
            'created_at': '2026-04-16T10:00:00Z',
            'prompt': 'Original prompt',
            'is_regeneration': false,
          },
          {
            'id': 'child-1',
            'created_at': '2026-04-16T11:00:00Z',
            'prompt': 'Additional prompt',
            'is_regeneration': true,
            'generated_from_id': 'parent-1',
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
  late GenerationHistoryService service;
  late _HistoryAdapter adapter;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = GenerationHistoryService();
    adapter = _HistoryAdapter();
    ApiService().dio.httpClientAdapter = adapter;
  });

  test('fetchParentChainHistory success updates state and sorts history', () async {
    await service.fetchParentChainHistory('parent-1');

    expect(service.viewState, HistoryViewState.success);
    expect(service.generationHistory.length, 2);
    expect(service.generationHistory[0]['id'], 'parent-1');
    expect(service.generationHistory[1]['id'], 'child-1');
  });

  test('fetchParentChainHistory error sets error state', () async {
    adapter.failOnList = true;

    try {
      await service.fetchParentChainHistory('parent-1');
    } catch (_) {}

    expect(service.viewState, HistoryViewState.error);
    expect(service.errorMessage, 'Database error');
  });

  test('getHistoryForGeneration handles child and fetches parent chain', () async {
    await service.getHistoryForGeneration('child-1');

    expect(service.viewState, HistoryViewState.success);
    expect(service.generationHistory.length, 2);
    expect(service.generationHistory[0]['id'], 'parent-1');
  });

  test('getHistoryForGeneration handles parent and fetches itself', () async {
    await service.getHistoryForGeneration('parent-1');

    expect(service.viewState, HistoryViewState.success);
    expect(service.generationHistory.length, 2);
    expect(service.generationHistory[0]['id'], 'parent-1');
  });

  test('refreshHistory reloads data', () async {
    await service.fetchParentChainHistory('parent-1');
    expect(service.generationHistory.length, 2);

    await service.refreshHistory();
    expect(service.viewState, HistoryViewState.success);
    expect(service.generationHistory.length, 2);
  });
}
