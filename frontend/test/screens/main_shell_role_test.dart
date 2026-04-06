import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klass_app/main.dart';
import 'package:klass_app/screens/freelancer_home_screen.dart';
import 'package:klass_app/screens/home_screen.dart';
import 'package:klass_app/screens/settings_screen.dart';
import 'package:klass_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MainShellAdapter implements HttpClientAdapter {
  _MainShellAdapter({this.user, this.meDelay = Duration.zero});

  final Map<String, dynamic>? user;
  final Duration meDelay;
  int meRequestCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.contains('/auth/me')) {
      meRequestCount += 1;
      if (meDelay > Duration.zero) {
        await Future<void>.delayed(meDelay);
      }

      if (user == null) {
        return _jsonResponse({'message': 'Unauthorized'}, statusCode: 401);
      }

      return _jsonResponse({'data': user});
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

Future<_MainShellAdapter> _pumpMainShell(
  WidgetTester tester, {
  Map<String, dynamic>? user,
  Map<String, Object>? prefsData,
  MainShell shell = const MainShell(),
  Duration meDelay = Duration.zero,
  Locale locale = const Locale('en'),
}) async {
  SharedPreferences.setMockInitialValues(
    prefsData ??
        {
          if (user != null) 'auth_token': 'test-token',
          if (user != null) 'user_data': jsonEncode(user),
        },
  );

  final api = ApiService();
  final adapter = _MainShellAdapter(user: user, meDelay: meDelay);
  api.dio.httpClientAdapter = adapter;

  await tester.pumpWidget(
    KlassApp(
      initialLocale: locale,
      homeOverride: shell,
    ),
  );

  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 1200));

  return adapter;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('MainShell shows freelancer navigation and freelancer profile UI', (tester) async {
    await _pumpMainShell(
      tester,
      user: {
        'id': 3,
        'name': 'Rina Freelancer',
        'email': 'rina@klass.id',
        'role': 'freelancer',
      },
      locale: const Locale('id'),
    );

    expect(find.text('Pekerjaan'), findsOneWidget);
    expect(find.text('Pencarian'), findsNothing);

    await tester.tap(find.text('Profil'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('FREELANCER'), findsOneWidget);
    expect(find.text('Rina Freelancer'), findsOneWidget);
  });

  testWidgets('MainShell keeps teacher navigation and teacher profile UI intact', (tester) async {
    await _pumpMainShell(
      tester,
      user: {
        'id': 1,
        'name': 'Sarah Jenkins',
        'email': 'sarah@klass.id',
        'role': 'teacher',
      },
      locale: const Locale('id'),
    );

    expect(find.text('Pencarian'), findsOneWidget);
    expect(find.text('Ruang Kerja'), findsOneWidget);
    expect(find.text('Pekerjaan'), findsNothing);

    await tester.tap(find.text('Profil'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('GURU'), findsOneWidget);
    expect(find.text('Sarah Jenkins'), findsOneWidget);
  });

  testWidgets('Guest profile restores header and prompt UI immediately without loading or account settings', (tester) async {
    final adapter = await _pumpMainShell(
      tester,
      shell: const MainShell(
        initialRole: 'teacher',
        initialIsGuest: true,
      ),
      prefsData: const {},
      meDelay: const Duration(seconds: 2),
    );

    await tester.tap(find.text('Profile'));
    await tester.pump();

    expect(find.text('Join as Teacher'), findsOneWidget);
    expect(find.text('Join as Freelancer'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Guest User'), findsWidgets);
    expect(find.text('You are currently browsing as a guest'), findsOneWidget);
    expect(find.text('Return to your journey'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);
    expect(find.text('Account Settings'), findsNothing);
    expect(adapter.meRequestCount, 0);

    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Join as Teacher'), findsOneWidget);
    expect(find.text('Join as Freelancer'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Guest User'), findsWidgets);
    expect(find.text('You are currently browsing as a guest'), findsOneWidget);
    expect(find.text('Return to your journey'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);
    expect(find.text('Account Settings'), findsNothing);
  });

  testWidgets('Teacher home settings entry opens shared SettingsScreen through MainShell', (tester) async {
    await _pumpMainShell(
      tester,
      user: {
        'id': 1,
        'name': 'Sarah Jenkins',
        'email': 'sarah@klass.id',
        'role': 'teacher',
      },
    );

    expect(find.byKey(HomeScreen.settingsButtonKey), findsOneWidget);
    expect(find.byKey(FreelancerHomeScreen.settingsButtonKey), findsNothing);
    expect(find.byKey(SettingsScreen.screenKey), findsNothing);

    await tester.tap(find.byKey(HomeScreen.settingsButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.byKey(SettingsScreen.screenKey), findsOneWidget);
    expect(find.byKey(SettingsScreen.languageControlKey), findsOneWidget);
  });

  testWidgets('Freelancer home settings entry opens shared SettingsScreen through MainShell', (tester) async {
    await _pumpMainShell(
      tester,
      user: {
        'id': 3,
        'name': 'Rina Freelancer',
        'email': 'rina@klass.id',
        'role': 'freelancer',
      },
    );

    expect(find.byKey(FreelancerHomeScreen.settingsButtonKey), findsOneWidget);
    expect(find.byKey(HomeScreen.settingsButtonKey), findsNothing);
    expect(find.byKey(SettingsScreen.screenKey), findsNothing);

    await tester.tap(find.byKey(FreelancerHomeScreen.settingsButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.byKey(SettingsScreen.screenKey), findsOneWidget);
    expect(find.byKey(SettingsScreen.languageControlKey), findsOneWidget);
  });

  testWidgets('Guest home settings entry opens the shared SettingsScreen with the language selector', (tester) async {
    await _pumpMainShell(
      tester,
      shell: const MainShell(
        initialRole: 'teacher',
        initialIsGuest: true,
      ),
      prefsData: const {},
      locale: const Locale('id'),
    );

    expect(find.byKey(HomeScreen.settingsButtonKey), findsOneWidget);

    await tester.tap(find.byKey(HomeScreen.settingsButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.byKey(SettingsScreen.screenKey), findsOneWidget);
    expect(find.text('Pengaturan'), findsOneWidget);
    expect(find.byKey(SettingsScreen.languageControlKey), findsOneWidget);
  });
}