import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klass_app/main.dart';
import 'package:klass_app/screens/settings_screen.dart';
import 'package:klass_app/widgets/bottom_nav.dart';
import 'package:klass_app/widgets/feature_coming_soon.dart';
import 'package:klass_app/widgets/prompt_input_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('BottomNav renders localized Indonesian labels for teacher and freelancer roles', (tester) async {
    await tester.pumpWidget(
      KlassApp(
        initialLocale: const Locale('id'),
        homeOverride: Scaffold(
          body: Column(
            children: const [
              Expanded(child: SizedBox.shrink()),
              BottomNav(currentIndex: 0, onTap: _noop, role: 'teacher'),
              BottomNav(currentIndex: 0, onTap: _noop, role: 'freelancer'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Beranda'), findsNWidgets(2));
    expect(find.text('Pencarian'), findsOneWidget);
    expect(find.text('Ruang Kerja'), findsOneWidget);
    expect(find.text('Profil'), findsNWidgets(2));
    expect(find.text('Pekerjaan'), findsOneWidget);
    expect(find.text('Portofolio'), findsOneWidget);
  });

  testWidgets('SettingsScreen renders localized Indonesian shared chrome copy', (tester) async {
    await tester.pumpWidget(
      const KlassApp(
        initialLocale: Locale('id'),
        homeOverride: SettingsScreen(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 250));
    await tester.ensureVisible(find.byKey(SettingsScreen.languageControlKey));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Pengaturan'), findsOneWidget);
    expect(find.text('Preferensi AI'), findsOneWidget);
    expect(find.text('Antarmuka & Tema'), findsOneWidget);
    expect(find.text('Ruang Kerja & Data'), findsOneWidget);
    expect(find.text('Peralatan Kreator'), findsOneWidget);
    expect(find.text('Ajukan Klub Baru'), findsOneWidget);
    expect(find.text('Keluar'), findsOneWidget);
  });

  testWidgets('Shared reusable widgets render localized defaults', (tester) async {
    await tester.pumpWidget(
      KlassApp(
        initialLocale: const Locale('id'),
        homeOverride: Scaffold(
          body: ListView(
            children: const [
              PromptInputWidget(),
              SizedBox(height: 24),
              FeatureComingSoon(),
            ],
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Ketik topik yang ingin dipelajari...'), findsOneWidget);
    expect(find.text('Fitur Mendatang'), findsOneWidget);
    expect(find.text('SEGERA HADIR'), findsOneWidget);
    expect(find.text('Mengerti'), findsOneWidget);
  });
}

void _noop(int _) {}
