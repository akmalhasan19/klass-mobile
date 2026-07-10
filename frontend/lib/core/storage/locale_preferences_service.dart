import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalePreferencesService {
  const LocalePreferencesService();

  static const String localePreferenceKey = 'app_locale_code';
  static const List<Locale> defaultSupportedLocales = <Locale>[
    Locale('en'),
    Locale('id'),
  ];

  Future<Locale?> loadSavedLocale({
    List<Locale> supportedLocales = defaultSupportedLocales,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return parseStoredLocale(
      prefs.getString(localePreferenceKey),
      supportedLocales: supportedLocales,
    );
  }

  Future<void> saveLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(localePreferenceKey, serializeLocale(locale));
  }

  Future<void> clearSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(localePreferenceKey);
  }

  static String serializeLocale(Locale locale) {
    final countryCode = locale.countryCode;
    if (countryCode == null || countryCode.isEmpty) {
      return locale.languageCode;
    }

    return '${locale.languageCode}_$countryCode';
  }

  static Locale? parseStoredLocale(
    String? value, {
    List<Locale> supportedLocales = defaultSupportedLocales,
  }) {
    if (value == null) {
      return null;
    }

    final normalized = value.trim().replaceAll('-', '_');
    if (normalized.isEmpty) {
      return null;
    }

    final parts = normalized.split('_');
    final candidate = parts.length > 1 && parts[1].isNotEmpty
        ? Locale(parts[0], parts[1])
        : Locale(parts[0]);

    return matchSupportedLocale(candidate, supportedLocales: supportedLocales);
  }

  static Locale? matchSupportedLocale(
    Locale locale, {
    List<Locale> supportedLocales = defaultSupportedLocales,
  }) {
    for (final supportedLocale in supportedLocales) {
      if (sameLocale(supportedLocale, locale)) {
        return supportedLocale;
      }

      if (supportedLocale.languageCode == locale.languageCode) {
        return supportedLocale;
      }
    }

    return null;
  }

  static bool sameLocale(Locale left, Locale right) {
    return left.languageCode == right.languageCode &&
        (left.countryCode ?? '') == (right.countryCode ?? '');
  }
}
