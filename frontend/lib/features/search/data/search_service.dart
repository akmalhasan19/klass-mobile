import 'package:klass_app/core/network/api_data_normalizer.dart';
import 'package:klass_app/core/config/api_config.dart';
import 'package:klass_app/core/config/feature_flags.dart';
import 'package:dio/dio.dart';

class SearchService {
  final Dio _dio;

  SearchService(this._dio);

  Future<List<Map<String, dynamic>>> searchTopics({String? q, String? category, bool forceRefresh = false, CancelToken? cancelToken}) async {
    if (!FeatureFlags.useApiData || !FeatureFlags.enableServerSearch) {
      return []; // Fallback: return empty when API/search is disabled
    }

    try {
       final queryParams = <String, dynamic>{};
       queryParams['include_contents'] = false;
       if (q != null && q.isNotEmpty) queryParams['search'] = q;
       if (category != null && category.isNotEmpty && category != 'All') queryParams['category'] = category;

       final response = await _dio.get(
         ApiConfig.v('/topics'),
         cancelToken: cancelToken,
         options: Options(extra: {'forceRefresh': forceRefresh}),
         queryParameters: queryParams,
       );
       if (response.statusCode == 200) {
         final data = response.data['data'] as List?;
         if (data != null) {
           return ApiDataNormalizer.normalizeTopicCollection(data);
         }
       }
       return [];
    } catch (_) {
      rethrow;
    }
  }
}
