import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klass_app/app/app.dart';
import 'package:klass_app/features/profile/screens/settings_screen.dart';
import 'package:klass_app/core/providers/dio_provider.dart';
import 'package:klass_app/core/config/api_config.dart';
import 'package:klass_app/core/storage/locale_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Dio _createTestDio() {
  return Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(milliseconds: ApiConfig.connectTimeout),
    receiveTimeout: const Duration(milliseconds: ApiConfig.receiveTimeout),
    sendTimeout: const Duration(milliseconds: ApiConfig.sendTimeout),
  ));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('SettingsScreen syncs the selector with the active locale on open', (tester) async {
    final dio = _createTestDio();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dioProvider.overrideWithValue(dio)],
        child: const KlassApp(
          initialLocale: Locale('id'),
          homeOverride: SettingsScreen(),
        ),
      ),
    );

    await tester.ensureVisible(find.byKey(SettingsScreen.languageControlKey));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byKey(SettingsScreen.languageControlKey), findsOneWidget);
    expect(find.byKey(SettingsScreen.languageEnglishOptionKey), findsOneWidget);
    expect(find.byKey(SettingsScreen.languageBahasaIndonesiaOptionKey), findsOneWidget);

    final currentValue = tester.widget<Text>(
      find.byKey(SettingsScreen.languageCurrentValueKey),
    );
    expect(currentValue.data, 'Bahasa Indonesia');
  });

  testWidgets('SettingsScreen saves the selected locale and updates MaterialApp immediately', (tester) async {
    final dio = _createTestDio();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dioProvider.overrideWithValue(dio)],
        child: const KlassApp(
          initialLocale: Locale('en'),
          homeOverride: SettingsScreen(),
        ),
      ),
    );

    await tester.ensureVisible(find.byKey(SettingsScreen.languageBahasaIndonesiaOptionKey));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(SettingsScreen.languageBahasaIndonesiaOptionKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final prefs = await SharedPreferences.getInstance();
    final currentValue = tester.widget<Text>(
      find.byKey(SettingsScreen.languageCurrentValueKey),
    );

    expect(materialApp.locale, const Locale('id'));
    expect(
      prefs.getString(LocalePreferencesService.localePreferenceKey),
      'id',
    );
    expect(currentValue.data, 'Bahasa Indonesia');
  });
}
