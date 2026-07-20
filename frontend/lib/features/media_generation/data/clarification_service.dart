import 'dart:async';

import 'package:dio/dio.dart';
import 'package:klass_app/core/config/api_config.dart';
import 'package:klass_app/core/utils/api_debug_info.dart';
import 'package:klass_app/core/network/api_data_normalizer.dart';

import '../models/clarification_response.dart';

class ClarificationService {
  final Dio _dio;

  ClarificationService(this._dio);

  /// Analyze prompt and return clarification questions.
  ///
  /// Calls `POST /media-generations/preflight` to detect gaps
  /// and return questions that need answering before generation.
  Future<ClarificationResponse> preflight({
    required String rawPrompt,
    String preferredOutputType = 'auto',
    int? subjectId,
    int? subSubjectId,
    CancelToken? cancelToken,
  }) async {
    final payload = <String, dynamic>{
      'raw_prompt': rawPrompt.trim(),
      'preferred_output_type': preferredOutputType,
    };

    if (subjectId != null) {
      payload['subject_id'] = subjectId;
    }

    if (subSubjectId != null) {
      payload['sub_subject_id'] = subSubjectId;
    }

    try {
      final response = await _dio.post(
        ApiConfig.v('/media-generations/preflight'),
        data: payload,
        cancelToken: cancelToken,
      );

      final data = response.data;
      final dataMap = data is Map<String, dynamic> ? data : null;

      if (dataMap == null) {
        throw Exception(
          ApiDataNormalizer.buildDebugInfo(
            'Invalid response format. Expected data as Object.',
            operation: ApiDebugOperation.networkRequestFailed,
            endpoint: ApiConfig.v('/media-generations/preflight'),
          ),
        );
      }

      final innerData = dataMap['data'];
      if (innerData == null || innerData is! Map<String, dynamic>) {
        throw Exception(
          ApiDataNormalizer.buildDebugInfo(
            'Invalid response format. Expected data.data as Object.',
            operation: ApiDebugOperation.networkRequestFailed,
            endpoint: ApiConfig.v('/media-generations/preflight'),
          ),
        );
      }

      return ClarificationResponse.fromJson(innerData);
    } on DioException catch (error) {
      final message = _resolveDioErrorMessage(error, endpoint: ApiConfig.v('/media-generations/preflight'));
      throw Exception(message);
    } catch (error) {
      throw Exception(
        ApiDataNormalizer.buildDebugInfo(
          error,
          operation: ApiDebugOperation.networkRequestFailed,
          endpoint: ApiConfig.v('/media-generations/preflight'),
        ),
      );
    }
  }

  /// Submit enriched prompt to start generation after clarification.
  ///
  /// Calls `POST /media-generations/confirm` with the generation_id,
  /// enriched prompt, and the answers map from the clarification flow.
  Future<Map<String, dynamic>> confirmGeneration({
    required String generationId,
    required String enrichedPrompt,
    required Map<String, String> answers,
    int? subjectId,
    int? subSubjectId,
    CancelToken? cancelToken,
  }) async {
    final payload = <String, dynamic>{
      'generation_id': generationId,
      'enriched_prompt': enrichedPrompt,
      'answers': answers,
    };

    if (subjectId != null) {
      payload['subject_id'] = subjectId;
    }

    if (subSubjectId != null) {
      payload['sub_subject_id'] = subSubjectId;
    }

    try {
      final response = await _dio.post(
        ApiConfig.v('/media-generations/confirm'),
        data: payload,
        cancelToken: cancelToken,
      );

      final data = response.data;
      final dataMap = data is Map<String, dynamic> ? data : null;

      if (dataMap == null) {
        throw Exception(
          ApiDataNormalizer.buildDebugInfo(
            'Invalid response format. Expected data as Object.',
            operation: ApiDebugOperation.networkRequestFailed,
            endpoint: ApiConfig.v('/media-generations/confirm'),
          ),
        );
      }

      final innerData = dataMap['data'];
      if (innerData == null || innerData is! Map<String, dynamic>) {
        throw Exception(
          ApiDataNormalizer.buildDebugInfo(
            'Invalid response format. Expected data.data as Object.',
            operation: ApiDebugOperation.networkRequestFailed,
            endpoint: ApiConfig.v('/media-generations/confirm'),
          ),
        );
      }

      return innerData;
    } on DioException catch (error) {
      final message = _resolveDioErrorMessage(error, endpoint: ApiConfig.v('/media-generations/confirm'));
      throw Exception(message);
    } catch (error) {
      throw Exception(
        ApiDataNormalizer.buildDebugInfo(
          error,
          operation: ApiDebugOperation.networkRequestFailed,
          endpoint: ApiConfig.v('/media-generations/confirm'),
        ),
      );
    }
  }

  /// Skip all clarification questions and generate with enriched prompt.
  ///
  /// Calls `POST /media-generations/{id}/skip-clarification`.
  /// The enriched prompt is the suggested_prompt from preflight response.
  Future<Map<String, dynamic>> skipClarification({
    required String generationId,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.v('/media-generations/$generationId/skip-clarification'),
        cancelToken: cancelToken,
      );

      final data = response.data;
      final dataMap = data is Map<String, dynamic> ? data : null;

      if (dataMap == null) {
        throw Exception(
          ApiDataNormalizer.buildDebugInfo(
            'Invalid response format. Expected data as Object.',
            operation: ApiDebugOperation.networkRequestFailed,
            endpoint: ApiConfig.v('/media-generations/$generationId/skip-clarification'),
          ),
        );
      }

      final innerData = dataMap['data'];
      if (innerData == null || innerData is! Map<String, dynamic>) {
        throw Exception(
          ApiDataNormalizer.buildDebugInfo(
            'Invalid response format. Expected data.data as Object.',
            operation: ApiDebugOperation.networkRequestFailed,
            endpoint: ApiConfig.v('/media-generations/$generationId/skip-clarification'),
          ),
        );
      }

      return innerData;
    } on DioException catch (error) {
      final message = _resolveDioErrorMessage(
        error,
        endpoint: ApiConfig.v('/media-generations/$generationId/skip-clarification'),
      );
      throw Exception(message);
    } catch (error) {
      throw Exception(
        ApiDataNormalizer.buildDebugInfo(
          error,
          operation: ApiDebugOperation.networkRequestFailed,
          endpoint: ApiConfig.v('/media-generations/$generationId/skip-clarification'),
        ),
      );
    }
  }

  String _resolveDioErrorMessage(DioException error, {required String endpoint}) {
    final responseData = error.response?.data;
    final responseMap = _asMap(responseData);

    final structuredErrorMessage = _stringAt(responseMap, ['error', 'message']);
    final topLevelMessage = _stringAt(responseMap, ['message']);

    String detailedMessage = '';
    if (structuredErrorMessage != null && structuredErrorMessage.isNotEmpty) {
      detailedMessage = structuredErrorMessage;
    } else if (topLevelMessage != null && topLevelMessage.isNotEmpty) {
      detailedMessage = topLevelMessage;
    } else {
      detailedMessage = ApiDataNormalizer.buildDebugInfo(
        error,
        operation: ApiDebugOperation.networkRequestFailed,
        endpoint: endpoint,
      );
    }

    return detailedMessage;
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((key, item) => MapEntry(key.toString(), item));
    return null;
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
    if (current == null) return null;
    final value = current.toString().trim();
    return value.isEmpty ? null : value;
  }
}
