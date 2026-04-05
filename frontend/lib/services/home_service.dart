import 'api_service.dart';
import '../config/feature_flags.dart';
import 'package:dio/dio.dart';

class HomeService {
  final ApiService _apiService = ApiService();

  Future<List<Map<String, dynamic>>> fetchProjects({bool forceRefresh = false}) async {
    if (!FeatureFlags.useApiData) {
      return []; // Fallback: return empty when API is disabled
    }

    try {
      final response = await _apiService.dio.get(
        '/homepage-recommendations',
        options: Options(extra: {'forceRefresh': forceRefresh}),
        queryParameters: const {
          'limit': 10,
        },
      );
      if (response.statusCode == 200) {
        final payload = response.data;
        if (payload is Map<String, dynamic> && payload['data'] is List) {
          final data = payload['data'] as List;
          return ApiService.normalizeRecommendationCollection(data);
        }

        throw Exception(
          'Gagal memuat projects\n'
          'Endpoint: /homepage-recommendations\n'
          'Error: Invalid response format. Expected data as List.',
        );
      }
      return [];
    } on DioException catch (e) {
      throw Exception(
        ApiService.buildDebugInfo(
          e,
          operation: 'Gagal memuat projects',
          endpoint: '/homepage-recommendations',
        ),
      );
    } catch (e) {
      throw Exception(
        ApiService.buildDebugInfo(
          e,
          operation: 'Gagal memuat projects',
          endpoint: '/homepage-recommendations',
        ),
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchHomepageSections({bool forceRefresh = false}) async {
    if (!FeatureFlags.useApiData) {
      return []; // Fallback
    }

    try {
      final response = await _apiService.dio.get(
        '/homepage-sections',
        options: Options(extra: {'forceRefresh': forceRefresh}),
      );
      if (response.statusCode == 200) {
        final payload = response.data;
        if (payload is Map<String, dynamic> && payload['data'] is List) {
          final data = payload['data'] as List;
          return data.cast<Map<String, dynamic>>();
        }
      }
      return [];
    } catch (e) {
      return []; // Silently fallback to static defaults if config fetch fails
    }
  }

  Future<List<Map<String, dynamic>>> fetchFreelancers({bool forceRefresh = false}) async {
    if (!FeatureFlags.useApiData) {
      return []; // Fallback: return empty when API is disabled
    }

    try {
      final response = await _apiService.dio.get(
        '/marketplace-tasks',
        options: Options(extra: {'forceRefresh': forceRefresh}),
      );
      if (response.statusCode == 200) {
        final payload = response.data;
        if (payload is Map<String, dynamic> && payload['data'] is List) {
          final data = payload['data'] as List;
          return data.cast<Map<String, dynamic>>();
        }

        throw Exception(
          'Gagal memuat freelancers\n'
          'Endpoint: /marketplace-tasks\n'
          'Error: Invalid response format. Expected data as List.',
        );
      }
      return [];
    } on DioException catch (e) {
      throw Exception(
        ApiService.buildDebugInfo(
          e,
          operation: 'Gagal memuat freelancers',
          endpoint: '/marketplace-tasks',
        ),
      );
    } catch (e) {
      throw Exception(
        ApiService.buildDebugInfo(
          e,
          operation: 'Gagal memuat freelancers',
          endpoint: '/marketplace-tasks',
        ),
      );
    }
  }
}
