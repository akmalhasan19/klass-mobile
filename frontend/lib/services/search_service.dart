import 'api_service.dart';
import '../config/feature_flags.dart';
import 'package:dio/dio.dart';

class SearchService {
  final ApiService _apiService = ApiService();

  Future<List<Map<String, dynamic>>> searchTopics({String? q, String? category, bool forceRefresh = false}) async {
    if (!FeatureFlags.useApiData || !FeatureFlags.enableServerSearch) {
      return []; // Fallback: return empty when API/search is disabled
    }

    try {
       final queryParams = <String, dynamic>{};
       queryParams['include_contents'] = false;
       if (q != null && q.isNotEmpty) queryParams['search'] = q;
       if (category != null && category.isNotEmpty && category != 'All') queryParams['category'] = category;

       final response = await _apiService.dio.get(
         '/topics',
         options: Options(extra: {'forceRefresh': forceRefresh}),
         queryParameters: queryParams,
       );
       if (response.statusCode == 200) {
         final data = response.data['data'] as List?;
         if (data != null) {
           return ApiService.normalizeTopicCollection(data);
         }
       }
       return [];
    } catch (_) {
      rethrow;
    }
  }
}
