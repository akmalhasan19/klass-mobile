import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klass_app/main.dart';
import 'package:klass_app/services/locale_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
}
