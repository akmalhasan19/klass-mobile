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
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  test('loadInitialAppState restores locale and role metadata from SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'persisted-token',
      'user_data': '{"role":"freelancer"}',
      LocalePreferencesService.localePreferenceKey: 'id',
    });

    final appState = await loadInitialAppState();

    expect(appState.role, 'freelancer');
    expect(appState.isGuest, isFalse);
    expect(appState.locale, const Locale('id'));
  });

  testWidgets('KlassApp applies the bootstrapped initial locale to MaterialApp', (tester) async {
    await tester.pumpWidget(
      const KlassApp(
        initialLocale: Locale('id'),
        homeOverride: SizedBox.shrink(),
      ),
    );

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.locale, const Locale('id'));
  });

  testWidgets('KlassApp updates MaterialApp locale through the root update path', (tester) async {
    late BuildContext appContext;

    await tester.pumpWidget(
      KlassApp(
        initialLocale: const Locale('en'),
        homeOverride: Builder(
          builder: (context) {
            appContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    await KlassApp.of(appContext).updateLocale(const Locale('id'));
    await tester.pump();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final prefs = await SharedPreferences.getInstance();

    expect(materialApp.locale, const Locale('id'));
    expect(
      prefs.getString(LocalePreferencesService.localePreferenceKey),
      'id',
    );
  });

  testWidgets('KlassApp restores the persisted locale on a cold start', (tester) async {
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

    await tester.pumpWidget(const SizedBox.shrink());

    final appState = await loadInitialAppState();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dioProvider.overrideWithValue(dio)],
        child: KlassApp(
          initialRole: appState.role,
          initialIsGuest: appState.isGuest,
          initialLocale: appState.locale,
          homeOverride: const SettingsScreen(),
        ),
      ),
    );

    await tester.ensureVisible(find.byKey(SettingsScreen.languageControlKey));
    await tester.pump(const Duration(milliseconds: 250));

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final currentValue = tester.widget<Text>(
      find.byKey(SettingsScreen.languageCurrentValueKey),
    );

    expect(appState.locale, const Locale('id'));
    expect(materialApp.locale, const Locale('id'));
    expect(find.text('Pengaturan'), findsOneWidget);
    expect(currentValue.data, 'Bahasa Indonesia');
  });
}
