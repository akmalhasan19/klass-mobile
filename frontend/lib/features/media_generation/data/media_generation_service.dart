import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:klass_app/core/config/api_config.dart';
import 'package:klass_app/core/config/feature_flags.dart';
import 'package:klass_app/core/network/connectivity_service.dart';
import 'package:klass_app/core/utils/api_debug_info.dart';
import 'package:klass_app/core/network/api_data_normalizer.dart';

enum MediaGenerationViewState {
  idle,
  loading,
  inProgress,
  success,
  error,
}

class MediaGenerationService extends ChangeNotifier {
  static const Duration _baseBackoffInterval = Duration(seconds: 2);
  static const Duration _maxBackoffInterval = Duration(seconds: 30);

  static final MediaGenerationService _instance = MediaGenerationService._internal();

  factory MediaGenerationService(Dio dio) {
    _instance._dio = dio;
    _instance._connectivityService = ConnectivityService();
    _instance._connectivityService.initialize();
    _instance._setupConnectivityListener();
    return _instance;
  }

  MediaGenerationService._internal();

  late Dio _dio;
  late ConnectivityService _connectivityService;

  Timer? _pollingTimer;
  Duration _currentBackoffInterval = _baseBackoffInterval;
  bool _isPollingRequestInFlight = false;
  MediaGenerationViewState _state = MediaGenerationViewState.idle;
  Map<String, dynamic>? _resource;
  String? _generationId;
  String? _submittedPrompt;
  String? _errorMessage;
  String? _presignedDownloadUrl;

  _PendingPromptRequest? _pendingRequest;
  StreamSubscription<bool>? _connectivitySubscription;

  MediaGenerationViewState get state => _state;
  Map<String, dynamic>? get resource => _resource == null ? null : Map<String, dynamic>.unmodifiable(_resource!);
  String? get generationId => _generationId;
  String? get submittedPrompt => _submittedPrompt;
  String? get errorMessage => _errorMessage;
  String? get errorCode => _stringAt(_resource, ['error_code']);
  String? get presignedDownloadUrl => _presignedDownloadUrl;
  String? get currentStatus => _stringAt(_resource, ['status']);
  bool get isLoading => _state == MediaGenerationViewState.loading;
  bool get isInProgress => _state == MediaGenerationViewState.inProgress;
  bool get isSuccess => _state == MediaGenerationViewState.success;
  bool get isError => _state == MediaGenerationViewState.error;
  bool get hasVisibleState => _state != MediaGenerationViewState.idle;
  bool get isPollingActive => _pollingTimer?.isActive ?? false;
  bool get isTerminal => _boolAt(_resource, ['status_meta', 'is_terminal']) ?? _isTerminalStatus(currentStatus);
  bool get canRefreshStatus => _generationId != null;
  bool get isOffline => !_connectivityService.isConnected;
  bool get hasQueuedRequest => _pendingRequest != null;
  bool get isRetryable => _boolAt(_resource, ['error', 'retryable']) ?? false;
  Duration get currentPollingInterval => _currentBackoffInterval;
  Map<String, dynamic>? get deliveryPayload => _mapAt(_resource, ['delivery_payload']);
  Map<String, dynamic>? get artifact => _mapAt(_resource, ['artifact']);
  Map<String, dynamic>? get publication => _mapAt(_resource, ['publication']);

  /// Signed URL for the HTML preview artifact (marp preview).
  /// Populated when the artifact format is pptx or pdf and the sidecar is
  /// available.  The URL points to a self-contained HTML file served via
  /// ``GET /v1/artifacts/download``.
  String? get previewUrl {
    final delivery = deliveryPayload;
    // Try the delivery_payload.preview_url first (newer proto-based contract).
    final fromDelivery = _stringAt(delivery, ['preview_url']);
    if (fromDelivery != null) return fromDelivery;
    // Fallback: artifact_metadata.preview_url
    final resource = _resource;
    return _stringAt(resource, ['artifact_metadata', 'preview_url']);
  }

  Future<bool> submitPrompt({
    required String prompt,
    String preferredOutputType = 'auto',
    int? subjectId,
    int? subSubjectId,
    CancelToken? cancelToken,
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

    if (isOffline) {
      _pendingRequest = _PendingPromptRequest(
        prompt: normalizedPrompt,
        preferredOutputType: preferredOutputType,
        subjectId: subjectId,
        subSubjectId: subSubjectId,
        cancelToken: cancelToken,
      );
      _state = MediaGenerationViewState.loading;
      _errorMessage = null;
      notifyListeners();
      return true;
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
      final response = await _dio.post(ApiConfig.v('/media-generations'), data: payload, cancelToken: cancelToken);
      final resource = _extractResource(response.data);

      if (resource == null) {
        throw Exception(
          ApiDataNormalizer.buildDebugInfo(
            'Invalid response format. Expected data as Object.',
            operation: ApiDebugOperation.networkRequestFailed,
            endpoint: ApiConfig.v('/media-generations'),
          ),
        );
      }

      _applyResource(resource);

      if (_state == MediaGenerationViewState.inProgress) {
        _resetBackoff();
        _startPolling(immediate: false);
      }

      return true;
    } on DioException catch (error) {
      _setError(_resolveDioErrorMessage(error, endpoint: ApiConfig.v('/media-generations')));
      return false;
    } catch (error) {
      _setError(
        ApiDataNormalizer.buildDebugInfo(
          error,
          operation: ApiDebugOperation.networkRequestFailed,
          endpoint: ApiConfig.v('/media-generations'),
        ),
      );
      return false;
    }
  }

  Future<void> pollNow({CancelToken? cancelToken}) async {
    if (_generationId == null || _isPollingRequestInFlight) {
      return;
    }

    _isPollingRequestInFlight = true;

    try {
      final response = await _dio.get(
        ApiConfig.v('/media-generations/$_generationId/job-status'),
        cancelToken: cancelToken,
        options: Options(extra: {'forceRefresh': true}),
      );
      final resource = _extractResource(response.data);

      if (resource == null) {
        throw Exception(
          ApiDataNormalizer.buildDebugInfo(
            'Invalid response format. Expected data as Object.',
            operation: ApiDebugOperation.networkRequestFailed,
            endpoint: ApiConfig.v('/media-generations/$_generationId/job-status'),
          ),
        );
      }

      _applyResource(resource);
    } on DioException catch (error) {
      _setError(
        _resolveDioErrorMessage(error, endpoint: ApiConfig.v('/media-generations/$_generationId/job-status')),
      );
    } catch (error) {
      _setError(
        ApiDataNormalizer.buildDebugInfo(
          error,
          operation: ApiDebugOperation.networkRequestFailed,
          endpoint: '/media-generations/$_generationId/job-status',
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

    _resetBackoff();
    _startPolling(immediate: true);
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> cancelGeneration({CancelToken? cancelToken}) async {
    if (_generationId == null) return;

    stopPolling();

    try {
      await _dio.delete(
        ApiConfig.v('/media-generations/$_generationId'),
        cancelToken: cancelToken,
      );
    } catch (_) {
      // Backend may not support DELETE — proceed with client-side cancel
    }

    _errorMessage = null;
    _state = MediaGenerationViewState.error;
    _resource = {
      ...?_resource,
      'status': 'cancelled',
      'status_meta': {'is_terminal': true},
    };
    notifyListeners();
  }

  void reset({bool notify = true}) {
    stopPolling();
    _isPollingRequestInFlight = false;
    _currentBackoffInterval = _baseBackoffInterval;
    _state = MediaGenerationViewState.idle;
    _resource = null;
    _generationId = null;
    _submittedPrompt = null;
    _errorMessage = null;
    _presignedDownloadUrl = null;
    _pendingRequest = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;

    if (notify) {
      notifyListeners();
    }
  }

  Future<bool> regenerateWithPrompt(String parentId, String additionalPrompt, {CancelToken? cancelToken}) async {
    final normalizedPrompt = additionalPrompt.trim();
    if (normalizedPrompt.isEmpty) {
      _setError('Prompt tambahan tidak boleh kosong.');
      return false;
    }

    stopPolling();
    _state = MediaGenerationViewState.loading;
    notifyListeners();

    try {
      final response = await _dio.post(
        ApiConfig.v('/media-generations/$parentId/regenerate'),
        data: {'additional_prompt': normalizedPrompt},
        cancelToken: cancelToken,
      );
      
      final resource = _extractResource(response.data);
      if (resource != null) {
        _applyResource(resource);
        if (_state == MediaGenerationViewState.inProgress) {
          _resetBackoff();
          _startPolling(immediate: false);
        }
        return true;
      }
      return false;
    } on DioException catch (error) {
      _setError(_resolveDioErrorMessage(error, endpoint: ApiConfig.v('/media-generations/$parentId/regenerate')));
      return false;
    } catch (error) {
      _setError('Failed to regenerate: $error');
      return false;
    }
  }

  Future<List<FreelancerSuggestion>> suggestFreelancers(String generationId, {CancelToken? cancelToken}) async {
    try {
      final response = await _dio.post(
        ApiConfig.v('/media-generations/$generationId/suggest-freelancers'),
        cancelToken: cancelToken,
      );
      
      final data = response.data['data'] as List?;
      if (data == null) {
        return [];
      }
      return data.map((json) => FreelancerSuggestion.fromJson(json)).toList();
    } on DioException catch (error) {
      final message = _resolveDioErrorMessage(error, endpoint: ApiConfig.v('/media-generations/$generationId/suggest-freelancers'));
      throw Exception(message);
    } catch (error) {
      debugPrint('Error suggesting freelancers: $error');
      throw Exception('Failed to suggest freelancers: $error');
    }
  }

  Future<Map<String, dynamic>?> hireFreelancer(
    String generationId, {
    required String mode,
    required String refinementDescription,
    int? selectedFreelancerId,
    CancelToken? cancelToken,
  }) async {
    try {
      final payload = <String, dynamic>{
        'mode': mode,
        'refinement_description': refinementDescription,
      };
      if (selectedFreelancerId != null) {
        payload['selected_freelancer_id'] = selectedFreelancerId;
      }
      
      final response = await _dio.post(
        ApiConfig.v('/media-generations/$generationId/hire-freelancer'),
        data: payload,
        cancelToken: cancelToken,
      );
      return response.data['data'] as Map<String, dynamic>?;
    } catch (error) {
      debugPrint('Error hiring freelancer: $error');
      rethrow;
    }
  }

  void _startPolling({required bool immediate}) {
    stopPolling();

    if (immediate) {
      _currentBackoffInterval = _baseBackoffInterval;
      unawaited(_pollAndReschedule());
    } else {
      _scheduleNextPoll();
    }
  }

  void _scheduleNextPoll() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer(_currentBackoffInterval, () {
      unawaited(_pollAndReschedule());
    });
  }

  Future<void> _pollAndReschedule() async {
    await pollNow();

    if (_state == MediaGenerationViewState.inProgress && !_isPollingRequestInFlight) {
      _advanceBackoff();
      _scheduleNextPoll();
    }
  }

  void _advanceBackoff() {
    final nextMs = (_currentBackoffInterval.inMilliseconds * 2)
        .clamp(0, _maxBackoffInterval.inMilliseconds);
    _currentBackoffInterval = Duration(milliseconds: nextMs);
  }

  void _resetBackoff() {
    _currentBackoffInterval = _baseBackoffInterval;
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = _connectivityService.onConnectionChange.listen(
      (isConnected) {
        if (isConnected && _pendingRequest != null) {
          _retryPendingRequest();
        }
      },
    );
  }

  Future<void> _retryPendingRequest() async {
    final pending = _pendingRequest;
    if (pending == null) return;

    _pendingRequest = null;
    notifyListeners();

    await submitPrompt(
      prompt: pending.prompt,
      preferredOutputType: pending.preferredOutputType,
      subjectId: pending.subjectId,
      subSubjectId: pending.subSubjectId,
      cancelToken: pending.cancelToken,
    );
  }

  void _applyResource(Map<String, dynamic> resource) {
    if (_resource == null) {
      _resource = resource;
    } else {
      _resource = Map<String, dynamic>.from(_resource!)..addAll(resource);
    }

    final currentResource = _resource!;

    _generationId = _stringAt(currentResource, ['id']) ?? _stringAt(currentResource, ['generation_id']) ?? _generationId;

    final status = _stringAt(currentResource, ['status']);
    final terminal = _boolAt(currentResource, ['status_meta', 'is_terminal']) ?? _isTerminalStatus(status);
    final resourceError = _mapAt(currentResource, ['error']);

    _presignedDownloadUrl = _stringAt(currentResource, ['presigned_download_url']) ?? _presignedDownloadUrl;

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

    return ApiDataNormalizer.buildDebugInfo(
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

class FreelancerSuggestion {
  final int id;
  final String name;
  final double rating;
  final double matchScore;
  final double successRate;

  FreelancerSuggestion({
    required this.id,
    required this.name,
    required this.rating,
    required this.matchScore,
    required this.successRate,
  });

  factory FreelancerSuggestion.fromJson(Map<String, dynamic> json) {
    final freelancer = json['freelancer'] ?? {};
    return FreelancerSuggestion(
      id: freelancer['id'] ?? 0,
      name: freelancer['name'] ?? 'Unknown',
      rating: (freelancer['rating'] ?? 0.0).toDouble(),
      matchScore: (json['match_score'] ?? 0.0).toDouble(),
      successRate: (json['success_rate'] ?? 0.0).toDouble(),
    );
  }
}

class _PendingPromptRequest {
  final String prompt;
  final String preferredOutputType;
  final int? subjectId;
  final int? subSubjectId;
  final CancelToken? cancelToken;

  _PendingPromptRequest({
    required this.prompt,
    required this.preferredOutputType,
    this.subjectId,
    this.subSubjectId,
    this.cancelToken,
  });
}