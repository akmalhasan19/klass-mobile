import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:klass_app/main.dart';
import 'package:klass_app/screens/freelancer_home_screen.dart';
import 'package:klass_app/screens/home_screen.dart';
import 'package:klass_app/screens/settings_screen.dart';
import 'package:klass_app/services/api_service.dart';
import 'package:klass_app/services/locale_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LanguageSettingsAdapter implements HttpClientAdapter {
  _LanguageSettingsAdapter({this.user});

  final Map<String, dynamic>? user;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.contains('/auth/me')) {
      if (user == null) {
        return _jsonResponse({'message': 'Unauthorized'}, statusCode: 401);
      }

      return _jsonResponse({'success': true, 'data': user});
    }

    if (options.path.contains('/auth/logout')) {
      return _jsonResponse({'success': true});
    }

    if (options.path.contains('/homepage-sections')) {
      return _jsonResponse({'data': []});
    }

    if (options.path.contains('/homepage-recommendations')) {
      return _jsonResponse({
        'data': [],
        'meta': {'total': 0},
      });
    }

    if (options.path.contains('/marketplace-tasks')) {
      return _jsonResponse({
        'success': true,
        'data': [],
        'meta': {'total': 0},
      });
    }

    return _jsonResponse({'data': []});
  }

  ResponseBody _jsonResponse(
    Map<String, dynamic> payload, {
    int statusCode = 200,
  }) {
    return ResponseBody.fromString(
      jsonEncode(payload),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object> _prefsForSession({
  Map<String, dynamic>? user,
  String localeCode = 'en',
}) {
  return <String, Object>{
    LocalePreferencesService.localePreferenceKey: localeCode,
    if (user != null) 'auth_token': 'test-token',
    if (user != null) 'user_data': jsonEncode(user),
  };
}

Future<void> _pumpBootstrappedApp(
  WidgetTester tester, {
  Map<String, dynamic>? user,
  String localeCode = 'en',
}) async {
  SharedPreferences.setMockInitialValues(
    _prefsForSession(user: user, localeCode: localeCode),
  );

  await _renderBootstrappedApp(tester, user: user);
}

Future<void> _renderBootstrappedApp(
  WidgetTester tester, {
  Map<String, dynamic>? user,
}) async {
  ApiService().dio.httpClientAdapter = _LanguageSettingsAdapter(user: user);
  final appState = await loadInitialAppState();

  await tester.pumpWidget(
    KlassApp(
      initialRole: appState.role,
      initialIsGuest: appState.isGuest,
      initialLocale: appState.locale,
    ),
  );

  await _settleShell(tester);
}

Future<void> _settleShell(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 1200));
}

Future<void> _openSettings(
  WidgetTester tester, {
  required Finder settingsButton,
}) async {
  await tester.ensureVisible(settingsButton);
  await tester.tap(settingsButton);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1200));

  expect(find.byKey(SettingsScreen.screenKey), findsOneWidget);
}

Future<void> _switchToIndonesian(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(SettingsScreen.languageBahasaIndonesiaOptionKey));
  await tester.tap(find.byKey(SettingsScreen.languageBahasaIndonesiaOptionKey));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));

  final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
  final prefs = await SharedPreferences.getInstance();
  final currentValue = tester.widget<Text>(
    find.byKey(SettingsScreen.languageCurrentValueKey),
  );

  expect(materialApp.locale, const Locale('id'));
  expect(currentValue.data, 'Bahasa Indonesia');
  expect(
    prefs.getString(LocalePreferencesService.localePreferenceKey),
    'id',
  );
  expect(find.text('Pengaturan'), findsOneWidget);
}

Future<void> _restartApp(
  WidgetTester tester, {
  Map<String, dynamic>? user,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();

  await _renderBootstrappedApp(tester, user: user);
}

Future<void> _closeSettings(WidgetTester tester) async {
  final context = tester.element(find.byKey(SettingsScreen.screenKey));
  Navigator.of(context).maybePop();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1200));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('guest can switch language from settings and keep it after restart', (tester) async {
    await _pumpBootstrappedApp(tester, localeCode: 'en');

    expect(find.byKey(HomeScreen.settingsButtonKey), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    await _openSettings(
      tester,
      settingsButton: find.byKey(HomeScreen.settingsButtonKey),
    );
    await _switchToIndonesian(tester);

    await _closeSettings(tester);

    expect(find.text('Beranda'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);

    await _restartApp(tester);

    expect(find.byKey(HomeScreen.settingsButtonKey), findsOneWidget);
    expect(find.text('Beranda'), findsOneWidget);

    await _openSettings(
      tester,
      settingsButton: find.byKey(HomeScreen.settingsButtonKey),
    );

    final currentValue = tester.widget<Text>(
      find.byKey(SettingsScreen.languageCurrentValueKey),
    );
    expect(currentValue.data, 'Bahasa Indonesia');
    expect(find.text('Pengaturan'), findsOneWidget);
  });

  testWidgets('teacher keeps localized UI after restart and logout', (tester) async {
    const teacherUser = <String, dynamic>{
      'id': 1,
      'name': 'Sarah Jenkins',
      'email': 'sarah@klass.id',
      'role': 'teacher',
    };

    await _pumpBootstrappedApp(
      tester,
      user: teacherUser,
      localeCode: 'en',
    );

    expect(find.byKey(HomeScreen.settingsButtonKey), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Workspace'), findsOneWidget);

    await _openSettings(
      tester,
      settingsButton: find.byKey(HomeScreen.settingsButtonKey),
    );
    await _switchToIndonesian(tester);

    await _closeSettings(tester);

    expect(find.text('Pencarian'), findsOneWidget);
    expect(find.text('Ruang Kerja'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);

    await _restartApp(tester, user: teacherUser);

    expect(find.text('Pencarian'), findsOneWidget);
    expect(find.text('Ruang Kerja'), findsOneWidget);

    await tester.tap(find.text('Profil'));
    await _settleShell(tester);

    expect(find.text('GURU'), findsOneWidget);
    expect(find.text('Sarah Jenkins'), findsOneWidget);

    final logoutAction = find.widgetWithText(InkWell, 'Keluar');
    await tester.scrollUntilVisible(
      logoutAction,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    tester.widget<InkWell>(logoutAction).onTap?.call();
    await tester.pump();
    await _settleShell(tester);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_token'), isNull);
    expect(
      prefs.getString(LocalePreferencesService.localePreferenceKey),
      'id',
    );

    expect(find.byKey(HomeScreen.settingsButtonKey), findsOneWidget);
    expect(find.text('Beranda'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);

    await _openSettings(
      tester,
      settingsButton: find.byKey(HomeScreen.settingsButtonKey),
    );

    final currentValue = tester.widget<Text>(
      find.byKey(SettingsScreen.languageCurrentValueKey),
    );
    expect(currentValue.data, 'Bahasa Indonesia');
  });

  testWidgets('freelancer can switch language from settings and keep it after restart', (tester) async {
    const freelancerUser = <String, dynamic>{
      'id': 3,
      'name': 'Rina Freelancer',
      'email': 'rina@klass.id',
      'role': 'freelancer',
    };

    await _pumpBootstrappedApp(
      tester,
      user: freelancerUser,
      localeCode: 'en',
    );

    expect(find.byKey(FreelancerHomeScreen.settingsButtonKey), findsOneWidget);
    expect(find.text('Jobs'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    await _openSettings(
      tester,
      settingsButton: find.byKey(FreelancerHomeScreen.settingsButtonKey),
    );
    await _switchToIndonesian(tester);

    await _closeSettings(tester);

    expect(find.text('Pekerjaan'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);

    await _restartApp(tester, user: freelancerUser);

    expect(find.byKey(FreelancerHomeScreen.settingsButtonKey), findsOneWidget);
    expect(find.text('Pekerjaan'), findsOneWidget);

    await _openSettings(
      tester,
      settingsButton: find.byKey(FreelancerHomeScreen.settingsButtonKey),
    );

    final currentValue = tester.widget<Text>(
      find.byKey(SettingsScreen.languageCurrentValueKey),
    );
    expect(currentValue.data, 'Bahasa Indonesia');
    expect(find.text('Pengaturan'), findsOneWidget);
  });
}