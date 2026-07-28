import 'package:dio/dio.dart';
import 'package:klass_app/core/config/api_config.dart';
import 'package:klass_app/core/config/feature_flags.dart';

class FreelancerService {
  final Dio _dio;

  FreelancerService(this._dio);

  /// Fetch freelancer detail profile from backend.
  /// Falls back to returning the basic data if the endpoint is unavailable.
  Future<Map<String, dynamic>> fetchFreelancerProfile({
    required String userId,
    CancelToken? cancelToken,
  }) async {
    if (!FeatureFlags.useApiData) {
      throw Exception('API data is disabled');
    }

    try {
      final response = await _dio.get(
        ApiConfig.v('/freelancers/$userId/profile'),
        cancelToken: cancelToken,
        options: Options(extra: {'forceRefresh': true}),
      );
      if (response.statusCode == 200) {
        final payload = response.data;
        if (payload is Map<String, dynamic> && payload['data'] is Map<String, dynamic>) {
          return payload['data'] as Map<String, dynamic>;
        }
      }
      throw Exception('Invalid response format');
    } on DioException {
      rethrow;
    }
  }

  /// Fetch basic profile info (lighter endpoint, no portfolio).
  Future<Map<String, dynamic>> fetchFreelancerProfileBasic({
    required String userId,
    CancelToken? cancelToken,
  }) async {
    if (!FeatureFlags.useApiData) {
      throw Exception('API data is disabled');
    }

    try {
      final response = await _dio.get(
        ApiConfig.v('/freelancers/$userId/profile/basic'),
        cancelToken: cancelToken,
        options: Options(extra: {'forceRefresh': true}),
      );
      if (response.statusCode == 200) {
        final payload = response.data;
        if (payload is Map<String, dynamic> && payload['data'] is Map<String, dynamic>) {
          return payload['data'] as Map<String, dynamic>;
        }
      }
      throw Exception('Invalid response format');
    } on DioException {
      rethrow;
    }
  }
}
