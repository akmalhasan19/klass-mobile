import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/feature_flags.dart';
import '../utils/api_debug_info.dart';
import 'api_service.dart';

enum MediaGenerationViewState {
  idle,
  loading,
  inProgress,
  success,
  error,
}

class MediaGenerationService extends ChangeNotifier {
  static const Duration pollingInterval = Duration(seconds: 4);

  static final MediaGenerationService _instance = MediaGenerationService._internal();

  factory MediaGenerationService() {
    return _instance;
  }

  MediaGenerationService._internal();

  final ApiService _apiService = ApiService();

  Timer? _pollingTimer;
  bool _isPollingRequestInFlight = false;
  MediaGenerationViewState _state = MediaGenerationViewState.idle;
  Map<String, dynamic>? _resource;
  String? _generationId;
  String? _submittedPrompt;
  String? _errorMessage;

  MediaGenerationViewState get state => _state;
  Map<String, dynamic>? get resource => _resource == null ? null : Map<String, dynamic>.unmodifiable(_resource!);
  String? get generationId => _generationId;
  String? get submittedPrompt => _submittedPrompt;
  String? get errorMessage => _errorMessage;
  String? get currentStatus => _stringAt(_resource, ['status']);
  bool get isLoading => _state == MediaGenerationViewState.loading;
  bool get isInProgress => _state == MediaGenerationViewState.inProgress;
  bool get isSuccess => _state == MediaGenerationViewState.success;
  bool get isError => _state == MediaGenerationViewState.error;
  bool get hasVisibleState => _state != MediaGenerationViewState.idle;
  bool get isPollingActive => _pollingTimer?.isActive ?? false;
  bool get isTerminal => _boolAt(_resource, ['status_meta', 'is_terminal']) ?? _isTerminalStatus(currentStatus);
  bool get canRefreshStatus => _generationId != null;
  Map<String, dynamic>? get deliveryPayload => _mapAt(_resource, ['delivery_payload']);
  Map<String, dynamic>? get artifact => _mapAt(_resource, ['artifact']);
  Map<String, dynamic>? get publication => _mapAt(_resource, ['publication']);

  Future<bool> submitPrompt({
    required String prompt,
    String preferredOutputType = 'auto',
    int? subjectId,
    int? subSubjectId,
  }) async {
    final normalizedPrompt = prompt.trim();

    if (normalizedPrompt.isEmpty) {
      _setError('Prompt cannot be empty.');
      return false;
    }

    if (!FeatureFlags.useApiData || !FeatureFlags.enableAIFeatures) {
      _setError('AI generation is currently unavailable.');
      return false;
    }

    stopPolling();
    _resource = null;
    _generationId = null;
    _submittedPrompt = normalizedPrompt;
    _errorMessage = null;
    _state = MediaGenerationViewState.loading;
    notifyListeners();

    final payload = <String, dynamic>{
      'prompt': normalizedPrompt,
      'preferred_output_type': preferredOutputType,
    };

    if (subjectId != null) {
      payload['subject_id'] = subjectId;
    }

    if (subSubjectId != null) {
      payload['sub_subject_id'] = subSubjectId;
    }

    try {
      final response = await _apiService.dio.post('/media-generations', data: payload);
      final resource = _extractResource(response.data);

      if (resource == null) {
        throw Exception(
          ApiService.buildDebugInfo(
            'Invalid response format. Expected data as Object.',
            operation: ApiDebugOperation.networkRequestFailed,
            endpoint: '/media-generations',
          ),
        );
      }

      _applyResource(resource);

      if (_state == MediaGenerationViewState.inProgress) {
        _startPolling(immediate: false);
      }

      return true;
    } on DioException catch (error) {
      _setError(_resolveDioErrorMessage(error, endpoint: '/media-generations'));
      return false;
    } catch (error) {
      _setError(
        ApiService.buildDebugInfo(
          error,
          operation: ApiDebugOperation.networkRequestFailed,
          endpoint: '/media-generations',
        ),
      );
      return false;
    }
  }

  Future<void> pollNow() async {
    if (_generationId == null || _isPollingRequestInFlight) {
      return;
    }

    _isPollingRequestInFlight = true;

    try {
      final response = await _apiService.dio.get('/media-generations/$_generationId');
      final resource = _extractResource(response.data);

      if (resource == null) {
        throw Exception(
          ApiService.buildDebugInfo(
            'Invalid response format. Expected data as Object.',
            operation: ApiDebugOperation.networkRequestFailed,
            endpoint: '/media-generations/$_generationId',
          ),
        );
      }

      _applyResource(resource);

      if (_state == MediaGenerationViewState.inProgress && !isPollingActive) {
        _startPolling(immediate: false);
      }
    } on DioException catch (error) {
      _setError(
        _resolveDioErrorMessage(error, endpoint: '/media-generations/$_generationId'),
      );
    } catch (error) {
      _setError(
        ApiService.buildDebugInfo(
          error,
          operation: ApiDebugOperation.networkRequestFailed,
          endpoint: '/media-generations/$_generationId',
        ),
      );
    } finally {
      _isPollingRequestInFlight = false;
    }
  }

  void resumePollingIfNeeded() {
    if (_generationId == null || _state != MediaGenerationViewState.inProgress) {
      return;
    }

    _startPolling(immediate: true);
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void reset({bool notify = true}) {
    stopPolling();
    _isPollingRequestInFlight = false;
    _state = MediaGenerationViewState.idle;
    _resource = null;
    _generationId = null;
    _submittedPrompt = null;
    _errorMessage = null;

    if (notify) {
      notifyListeners();
    }
  }

  void _startPolling({required bool immediate}) {
    stopPolling();

    if (immediate) {
      unawaited(pollNow());
    }

    _pollingTimer = Timer.periodic(pollingInterval, (_) {
      unawaited(pollNow());
    });
  }

  void _applyResource(Map<String, dynamic> resource) {
    _resource = resource;
    _generationId = _stringAt(resource, ['id']) ?? _generationId;

    final status = _stringAt(resource, ['status']);
    final terminal = _boolAt(resource, ['status_meta', 'is_terminal']) ?? _isTerminalStatus(status);
    final resourceError = _mapAt(resource, ['error']);

    if (!terminal) {
      _errorMessage = null;
      _state = MediaGenerationViewState.inProgress;
      notifyListeners();
      return;
    }

    stopPolling();

    if (status == 'completed') {
      _errorMessage = null;
      _state = MediaGenerationViewState.success;
      notifyListeners();
      return;
    }

    _errorMessage = _stringAt(resourceError, ['message']) ?? _errorMessage ?? 'Media generation failed.';
    _state = MediaGenerationViewState.error;
    notifyListeners();
  }

  void _setError(String message) {
    stopPolling();
    _errorMessage = message;
    _state = MediaGenerationViewState.error;
    notifyListeners();
  }

  String _resolveDioErrorMessage(DioException error, {required String endpoint}) {
    final responseData = error.response?.data;
    final responseMap = _asMap(responseData);

    final structuredErrorMessage = _stringAt(responseMap, ['error', 'message']);
    if (structuredErrorMessage != null && structuredErrorMessage.isNotEmpty) {
      return structuredErrorMessage;
    }

    final topLevelMessage = _stringAt(responseMap, ['message']);
    if (topLevelMessage != null && topLevelMessage.isNotEmpty) {
      return topLevelMessage;
    }

    return ApiService.buildDebugInfo(
      error,
      operation: ApiDebugOperation.networkRequestFailed,
      endpoint: endpoint,
    );
  }

  Map<String, dynamic>? _extractResource(dynamic payload) {
    final payloadMap = _asMap(payload);
    if (payloadMap == null) {
      return null;
    }

    final data = payloadMap['data'];
    final dataMap = _asMap(data);
    if (dataMap != null) {
      return dataMap;
    }

    if (payloadMap.containsKey('id') && payloadMap.containsKey('status')) {
      return payloadMap;
    }

    return null;
  }

  bool _isTerminalStatus(String? status) {
    return status == 'completed' || status == 'failed' || status == 'cancelled';
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }

    return null;
  }

  Map<String, dynamic>? _mapAt(Map<String, dynamic>? source, List<String> path) {
    dynamic current = source;

    for (final segment in path) {
      if (current is Map<String, dynamic>) {
        current = current[segment];
        continue;
      }

      if (current is Map) {
        current = current[segment];
        continue;
      }

      return null;
    }

    return _asMap(current);
  }

  String? _stringAt(Map<String, dynamic>? source, List<String> path) {
    dynamic current = source;

    for (final segment in path) {
      if (current is Map<String, dynamic>) {
        current = current[segment];
        continue;
      }

      if (current is Map) {
        current = current[segment];
        continue;
      }

      return null;
    }

    if (current == null) {
      return null;
    }

    final value = current.toString().trim();

    return value.isEmpty ? null : value;
  }

  bool? _boolAt(Map<String, dynamic>? source, List<String> path) {
    dynamic current = source;

    for (final segment in path) {
      if (current is Map<String, dynamic>) {
        current = current[segment];
        continue;
      }

      if (current is Map) {
        current = current[segment];
        continue;
      }

      return null;
    }

    if (current is bool) {
      return current;
    }

    return null;
  }
}