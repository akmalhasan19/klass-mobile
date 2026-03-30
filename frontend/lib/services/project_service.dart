import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'api_service.dart';

class ProjectService extends ChangeNotifier {
  static final ProjectService _instance = ProjectService._internal();
  factory ProjectService() => _instance;
  ProjectService._internal();

  final ApiService _apiService = ApiService();

  List<Map<String, dynamic>> _addedProjects = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get addedProjects => List.unmodifiable(_addedProjects);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchProjects() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.dio.get('/topics');
      if (response.statusCode == 200) {
        final data = response.data['data'] as List?;
        if (data != null) {
          _addedProjects = data.cast<Map<String, dynamic>>();
        }
      }
    } on DioException catch (e) {
      _error = e.response?.data['message'] ?? 'Failed to load materials';
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addProject(Map<String, dynamic> projectData) async {
    try {
      final response = await _apiService.dio.post('/topics', data: projectData);
      if (response.statusCode == 200 || response.statusCode == 201) {
        fetchProjects(); // refresh list
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
