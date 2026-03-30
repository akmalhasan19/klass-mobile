import 'api_service.dart';
import '../config/feature_flags.dart';

class HomeService {
  final ApiService _apiService = ApiService();

  Future<List<Map<String, dynamic>>> fetchProjects() async {
    if (!FeatureFlags.useApiData) {
      return []; // Fallback: return empty when API is disabled
    }

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
      throw Exception('Failed to load projects: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchFreelancers() async {
    if (!FeatureFlags.useApiData) {
      return []; // Fallback: return empty when API is disabled
    }

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
