import 'api_service.dart';
import '../config/feature_flags.dart';
import 'package:dio/dio.dart';

class GalleryService {
  final ApiService _apiService = ApiService();

  Future<List<Map<String, dynamic>>> fetchGallery({String? search, String? category, bool forceRefresh = false}) async {
    if (!FeatureFlags.useApiData || !FeatureFlags.enableGalleryApi) {
      return []; // Fallback: return empty when API/gallery is disabled
    }

    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (category != null && category.isNotEmpty) queryParams['category'] = category;

      final response = await _apiService.dio.get(
        '/gallery',
        options: Options(extra: {'forceRefresh': forceRefresh}),
        queryParameters: queryParams,
      );
      if (response.statusCode == 200) {
        final data = response.data['data'] as List?;
        if (data != null) {
          return data.cast<Map<String, dynamic>>();
        }
      }
      return [];
    } catch (e) {
      throw Exception('Failed to load gallery: $e');
    }
  }
}
