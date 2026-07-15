import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:klass_app/core/config/api_config.dart';
import 'package:klass_app/core/config/feature_flags.dart';
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
  static const Duration pollingInterval = Duration(seconds: 4);

  static final MediaGenerationService _instance = MediaGenerationService._internal();

  factory MediaGenerationService(Dio dio) {
    _instance._dio = dio;
    return _instance;
  }

  MediaGenerationService._internal();

  late Dio _dio;

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
        ApiConfig.v('/media-generations/$_generationId'),
        cancelToken: cancelToken,
        options: Options(extra: {'forceRefresh': true}),
      );
      final resource = _extractResource(response.data);

      if (resource == null) {
        throw Exception(
          ApiDataNormalizer.buildDebugInfo(
            'Invalid response format. Expected data as Object.',
            operation: ApiDebugOperation.networkRequestFailed,
            endpoint: ApiConfig.v('/media-generations/$_generationId'),
          ),
        );
      }

      _applyResource(resource);

      if (_state == MediaGenerationViewState.inProgress && !isPollingActive) {
        _startPolling(immediate: false);
      }
    } on DioException catch (error) {
      _setError(
        _resolveDioErrorMessage(error, endpoint: ApiConfig.v('/media-generations/$_generationId')),
      );
    } catch (error) {
      _setError(
        ApiDataNormalizer.buildDebugInfo(
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