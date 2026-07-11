class RouteCachePolicy {
  static const Duration defaultMaxStale = Duration(minutes: 5);

  static const Map<String, Duration> _endpointTtl = {
    '/v1/auth/me': Duration.zero,
    '/v1/media-generations': Duration.zero,
  };

  static const Map<String, List<String>> _invalidationRules = {
    '/v1/topics': ['/v1/topics'],
    '/v1/user/avatar': ['/v1/auth/me'],
  };

  static Duration? maxStaleFor(String path) {
    if (_endpointTtl.containsKey(path)) {
      final ttl = _endpointTtl[path]!;
      return ttl == Duration.zero ? null : ttl;
    }
    for (final entry in _endpointTtl.entries) {
      if (path.startsWith(entry.key)) {
        return entry.value == Duration.zero ? null : entry.value;
      }
    }
    return defaultMaxStale;
  }

  static bool shouldCache(String path) => maxStaleFor(path) != null;

  static List<String> getInvalidationKeys(String path) {
    if (_invalidationRules.containsKey(path)) {
      return List.from(_invalidationRules[path]!);
    }
    for (final entry in _invalidationRules.entries) {
      if (path.startsWith(entry.key)) {
        return List.from(entry.value);
      }
    }
    return [];
  }
}
