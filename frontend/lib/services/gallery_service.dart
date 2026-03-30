import 'api_service.dart';

class GalleryService {
  final ApiService _apiService = ApiService();

  Future<List<Map<String, dynamic>>> fetchGallery({String? search, String? category}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (category != null && category.isNotEmpty) queryParams['category'] = category;

      final response = await _apiService.dio.get('/gallery', queryParameters: queryParams);
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
