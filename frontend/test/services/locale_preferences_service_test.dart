import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klass_app/services/api_service.dart';
import 'package:klass_app/services/auth_service.dart';
import 'package:klass_app/services/locale_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LogoutAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"ok":true}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService().dio.httpClientAdapter = _LogoutAdapter();
  });

  test('LocalePreferencesService stores and restores a supported locale', () async {
    final service = const LocalePreferencesService();

    await service.saveLocale(const Locale('id'));
    final restored = await service.loadSavedLocale();
    final prefs = await SharedPreferences.getInstance();

    expect(restored, const Locale('id'));
    expect(
      prefs.getString(LocalePreferencesService.localePreferenceKey),
      'id',
    );
  });

  test('LocalePreferencesService ignores unsupported stored locales', () async {
    SharedPreferences.setMockInitialValues({
      LocalePreferencesService.localePreferenceKey: 'fr',
    });

    final restored = await const LocalePreferencesService().loadSavedLocale();

    expect(restored, isNull);
  });

  test('AuthService.logout preserves locale preference while clearing auth state', () async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'token',
      'user_data': '{"role":"teacher"}',
      'api_cache_me': '{"name":"Sarah"}',
      LocalePreferencesService.localePreferenceKey: 'id',
    });

    await AuthService().logout();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_token'), isNull);
    expect(prefs.getString('user_data'), isNull);
    expect(prefs.getString('api_cache_me'), isNull);
    expect(
      prefs.getString(LocalePreferencesService.localePreferenceKey),
      'id',
    );
  });
}
