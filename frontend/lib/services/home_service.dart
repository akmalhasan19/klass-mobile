import 'api_service.dart';

class HomeService {
  final ApiService _apiService = ApiService();

  Future<List<Map<String, dynamic>>> fetchProjects() async {
    try {
      final response = await _apiService.dio.get('/topics');
      if (response.statusCode == 200) {
        final data = response.data['data'] as List?;
        if (data != null) {
          return data.cast<Map<String, dynamic>>();
        }
      }
      return [];
    } catch (e) {
      // In a real app we might want to log this properly or throw
      throw Exception('Failed to load projects: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchFreelancers() async {
    try {
      final response = await _apiService.dio.get('/marketplace-tasks');
      if (response.statusCode == 200) {
        final data = response.data['data'] as List?;
        if (data != null) {
          return data.cast<Map<String, dynamic>>();
        }
      }
      return [];
    } catch (e) {
      throw Exception('Failed to load freelancers: $e');
    }
  }
}
