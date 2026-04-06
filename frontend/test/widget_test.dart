import 'package:flutter_test/flutter_test.dart';
import 'package:klass_app/main.dart';
import 'package:flutter/material.dart';

void main() {
  test('KlassApp can be instantiated', () {
    const app = KlassApp();
    expect(app, isA<KlassApp>());
  });

  testWidgets('KlassApp exposes localization delegates and supported locales', (tester) async {
    await tester.pumpWidget(
      const KlassApp(
        homeOverride: SizedBox.shrink(),
      ),
    );

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(materialApp.localizationsDelegates, isNotNull);
    expect(materialApp.supportedLocales, equals(KlassApp.supportedLocales));
    expect(materialApp.locale, isNull);
  });
}
