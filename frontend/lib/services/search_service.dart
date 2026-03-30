import 'api_service.dart';

class SearchService {
  final ApiService _apiService = ApiService();

  Future<List<Map<String, dynamic>>> searchTopics({String? q, String? category}) async {
    try {
       final queryParams = <String, dynamic>{};
       if (q != null && q.isNotEmpty) queryParams['search'] = q;
       if (category != null && category.isNotEmpty && category != 'All') queryParams['category'] = category;

       final response = await _apiService.dio.get('/topics', queryParameters: queryParams);
       if (response.statusCode == 200) {
         final data = response.data['data'] as List?;
         if (data != null) {
           return data.cast<Map<String, dynamic>>();
         }
       }
       return [];
    } catch (e) {
      throw Exception('Search failed: $e');
    }
  }
}
