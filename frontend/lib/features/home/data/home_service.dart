import 'package:klass_app/core/network/api_data_normalizer.dart';
import 'package:klass_app/core/config/api_config.dart';
import 'package:klass_app/core/config/feature_flags.dart';
import 'package:dio/dio.dart';
import 'package:klass_app/core/utils/api_debug_info.dart';

class HomeService {
  final Dio _dio;

  HomeService(this._dio);

  Future<List<Map<String, dynamic>>> fetchProjects({bool forceRefresh = false, CancelToken? cancelToken}) async {
    if (!FeatureFlags.useApiData) {
      return []; // Fallback: return empty when API is disabled
    }

    try {
      final response = await _dio.get(
        ApiConfig.v('/homepage-recommendations'),
        cancelToken: cancelToken,
        options: Options(extra: {'forceRefresh': forceRefresh}),
        queryParameters: const {
          'limit': 10,
        },
      );
      if (response.statusCode == 200) {
        final payload = response.data;
        if (payload is Map<String, dynamic> && payload['data'] is List) {
          final data = payload['data'] as List;
          return ApiDataNormalizer.normalizeRecommendationCollection(data);
        }

        throw Exception(
          ApiDataNormalizer.buildDebugInfo(
            'Invalid response format. Expected data as List.',
            operation: ApiDebugOperation.homeProjectsLoadFailed,
            endpoint: ApiConfig.v('/homepage-recommendations'),
          ),
        );
      }
      return [];
    } on DioException catch (e) {
      throw Exception(
        ApiDataNormalizer.buildDebugInfo(
          e,
          operation: ApiDebugOperation.homeProjectsLoadFailed,
          endpoint: '/homepage-recommendations',
        ),
      );
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception(
        ApiDataNormalizer.buildDebugInfo(
          e,
          operation: ApiDebugOperation.homeProjectsLoadFailed,
          endpoint: '/homepage-recommendations',
        ),
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchHomepageSections({bool forceRefresh = false, CancelToken? cancelToken}) async {
    if (!FeatureFlags.useApiData) {
      return []; // Fallback
    }

    try {
      final response = await _dio.get(
        ApiConfig.v('/homepage-sections'),
        cancelToken: cancelToken,
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

  Future<List<Map<String, dynamic>>> fetchFreelancers({bool forceRefresh = false, CancelToken? cancelToken}) async {
    if (!FeatureFlags.useApiData) {
      return []; // Fallback: return empty when API is disabled
    }

    // Backend Rust saat ini belum memiliki endpoint khusus untuk GET /api/v1/freelancers
    // Endpoint /marketplace-tasks mengembalikan 'tasks' (pekerjaan), bukan profil user/freelancer.
    // Karenanya, kita bypass dan return empty list `[]` agar UI (home_screen.dart) 
    // melakukan fallback menggunakan data `kDummyFreelancers` (Agus, Susi, Ani, Budi).
    return [];
  }
}
