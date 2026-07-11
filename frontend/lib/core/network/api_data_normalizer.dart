import 'package:dio/dio.dart';
import 'package:klass_app/core/utils/api_debug_info.dart';

class ApiDataNormalizer {
  static String buildDebugInfo(
    Object error, {
    required ApiDebugOperation operation,
    required String endpoint,
  }) {
    return ApiDebugInfo.build(
      error,
      operation: operation,
      endpoint: endpoint,
    );
  }

  static List<Map<String, dynamic>> normalizeRecommendationCollection(List data) {
    return data
        .whereType<Map>()
        .map((item) => normalizeRecommendationItem(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Map<String, dynamic> normalizeRecommendationItem(Map<String, dynamic> recommendation) {
    final normalized = Map<String, dynamic>.from(recommendation);
    final thumbnailUrl = normalized['thumbnail_url'];

    if (thumbnailUrl is String && thumbnailUrl.isNotEmpty) {
      normalized['media_url'] = thumbnailUrl;
      normalized['image'] = thumbnailUrl;
      normalized['imagePath'] = thumbnailUrl;
    }

    if (normalized['modules'] == null) {
      normalized['modules'] = [];
    } else {
      final rawModules = normalized['modules'] as List;
      normalized['modules'] = rawModules.map((mod) {
        if (mod is String) {
          return {'title': mod};
        } else if (mod is Map) {
          return Map<String, dynamic>.from(mod);
        }
        return {'title': mod.toString()};
      }).toList();
    }

    if (normalized['tags'] == null) {
      normalized['tags'] = [];
    }

    return normalized;
  }

  static List<Map<String, dynamic>> normalizeTopicCollection(List data) {
    return data
        .whereType<Map>()
        .map((item) => normalizeTopicItem(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Map<String, dynamic> normalizeTopicItem(Map<String, dynamic> topic) {
    final normalized = Map<String, dynamic>.from(topic);
    final thumbnailUrl = normalized['thumbnail_url'];
    final mediaUrl = normalized['media_url'];

    if ((mediaUrl == null || mediaUrl.toString().isEmpty) &&
        thumbnailUrl is String &&
        thumbnailUrl.isNotEmpty) {
      normalized['media_url'] = thumbnailUrl;
      normalized['image'] = thumbnailUrl;
      normalized['imagePath'] = thumbnailUrl;
    }

    return normalized;
  }
}
