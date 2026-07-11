import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:klass_app/core/config/api_config.dart';
import 'package:klass_app/core/network/api_data_normalizer.dart';
import 'package:klass_app/core/utils/api_debug_info.dart';

class ProjectService extends ChangeNotifier {
  static final ProjectService _instance = ProjectService._internal();
  factory ProjectService(Dio dio) {
    _instance._dio = dio;
    return _instance;
  }
  ProjectService._internal();

  late Dio _dio;

  List<Map<String, dynamic>> _addedProjects = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get addedProjects => List.unmodifiable(_addedProjects);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchProjects({bool forceRefresh = false, CancelToken? cancelToken}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _dio.get(
        ApiConfig.v('/topics'),
        cancelToken: cancelToken,
        options: Options(extra: {'forceRefresh': forceRefresh}),
        queryParameters: const {
          'include_contents': false,
          'per_page': 50,
        },
      );
      if (response.statusCode == 200) {
        final payload = response.data;
        if (payload is Map<String, dynamic> && payload['data'] is List) {
          final data = payload['data'] as List;
          _addedProjects = ApiDataNormalizer.normalizeTopicCollection(data);
        } else {
          _error = ApiDataNormalizer.buildDebugInfo(
            'Invalid response format. Expected data as List.',
            operation: ApiDebugOperation.workspaceMaterialsLoadFailed,
            endpoint: ApiConfig.v('/topics'),
          );
        }
      }
    } on DioException catch (e) {
      _error = ApiDataNormalizer.buildDebugInfo(
        e,
        operation: ApiDebugOperation.workspaceMaterialsLoadFailed,
        endpoint: ApiConfig.v('/topics'),
      );
    } catch (e) {
      _error = ApiDataNormalizer.buildDebugInfo(
        e,
        operation: ApiDebugOperation.workspaceMaterialsLoadFailed,
        endpoint: ApiConfig.v('/topics'),
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addProject(Map<String, dynamic> projectData, {CancelToken? cancelToken}) async {
    try {
      final response = await _dio.post(ApiConfig.v('/topics'), data: projectData, cancelToken: cancelToken);
      if (response.statusCode == 200 || response.statusCode == 201) {
        fetchProjects(forceRefresh: true); // refresh list and bypass cache
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
