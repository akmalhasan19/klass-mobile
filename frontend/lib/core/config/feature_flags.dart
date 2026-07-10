/// FeatureFlags — Centralized feature flag management for safe rollback.
///
/// Usage:
///   if (FeatureFlags.useApiData) { ... fetch from API ... }
///   else { ... use fallback/cached data ... }
///
/// In a production setup, these flags would be fetched from a remote
/// configuration service (Firebase Remote Config, LaunchDarkly, etc.)
/// For now, they are compile-time constants for simplicity.
class FeatureFlags {
  // ─── Data Source Flags ─────────────────────────────────────

  /// Master toggle: when false, services fall back to cached/local data
  /// instead of making API calls. Use for emergency rollback.
  static const bool useApiData = true;

  /// When true, the gallery screen fetches from API.
  /// When false, shows an empty state with a maintenance message.
  static const bool enableGalleryApi = true;

  /// When true, bookmark operations sync with the server.
  /// When false, bookmarks are stored locally only.
  static const bool enableBookmarkSync = true;

  /// When true, search queries are sent to the backend.
  /// When false, search is disabled with a "coming soon" message.
  static const bool enableServerSearch = true;

  // ─── Feature Flags ────────────────────────────────────────

  /// Enables AI-powered features (prompt generation, etc.)
  static const bool enableAIFeatures = true;

  /// Enables gallery image caching for faster reloads.
  static const bool enableGalleryCache = true;

  /// Enables the new experimental checkout flow.
  static const bool enableNewCheckoutFlow = false;

  // ─── Observability Flags ──────────────────────────────────

  /// When true, detailed API request/response logs are emitted.
  /// Disable in production for performance.
  static const bool enableVerboseApiLogging = true;

  /// When true, monitoring service tracks error rates per endpoint.
  static const bool enableErrorRateMonitoring = true;

  // ─── Helpers ──────────────────────────────────────────────

  /// Conditionally execute code based on a feature flag.
  static void runIf(bool flag, Function action) {
    if (flag) {
      action();
    }
  }

  /// Returns the value of a flag by name (for dynamic lookup).
  /// Returns null if the flag name is not recognized.
  static bool? getFlagByName(String name) {
    switch (name) {
      case 'useApiData':
        return useApiData;
      case 'enableGalleryApi':
        return enableGalleryApi;
      case 'enableBookmarkSync':
        return enableBookmarkSync;
      case 'enableServerSearch':
        return enableServerSearch;
      case 'enableAIFeatures':
        return enableAIFeatures;
      case 'enableGalleryCache':
        return enableGalleryCache;
      case 'enableVerboseApiLogging':
        return enableVerboseApiLogging;
      case 'enableErrorRateMonitoring':
        return enableErrorRateMonitoring;
      default:
        return null;
    }
  }
}
