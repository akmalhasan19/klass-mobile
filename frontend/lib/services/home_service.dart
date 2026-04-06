import 'api_service.dart';
import '../config/feature_flags.dart';
import 'package:dio/dio.dart';
import '../utils/api_debug_info.dart';

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
          ApiService.buildDebugInfo(
            'Invalid response format. Expected data as List.',
            operation: ApiDebugOperation.homeProjectsLoadFailed,
            endpoint: '/homepage-recommendations',
          ),
        );
      }
      return [];
    } on DioException catch (e) {
      throw Exception(
        ApiService.buildDebugInfo(
          e,
          operation: ApiDebugOperation.homeProjectsLoadFailed,
          endpoint: '/homepage-recommendations',
        ),
      );
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception(
        ApiService.buildDebugInfo(
          e,
          operation: ApiDebugOperation.homeProjectsLoadFailed,
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
          ApiService.buildDebugInfo(
            'Invalid response format. Expected data as List.',
            operation: ApiDebugOperation.homeFreelancersLoadFailed,
            endpoint: '/marketplace-tasks',
          ),
        );
      }
      return [];
    } on DioException catch (e) {
      throw Exception(
        ApiService.buildDebugInfo(
          e,
          operation: ApiDebugOperation.homeFreelancersLoadFailed,
          endpoint: '/marketplace-tasks',
        ),
      );
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception(
        ApiService.buildDebugInfo(
          e,
          operation: ApiDebugOperation.homeFreelancersLoadFailed,
          endpoint: '/marketplace-tasks',
        ),
      );
    }
  }
}
