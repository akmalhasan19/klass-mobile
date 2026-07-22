import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klass_app/l10n/generated/app_localizations.dart';
import 'package:klass_app/features/media_generation/models/clarification_gap.dart';
import 'package:klass_app/features/media_generation/widgets/clarification_question_card.dart';

Widget _buildTestableWidget(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: child,
      ),
    ),
  );
}

void main() {
  final testGap = ClarificationGap(
    fieldId: 'subject',
    question: 'Silakan tentukan mata pelajaran',
    priority: 'required',
    inputType: 'text_input',
    suggestions: [
      ClarificationGapSuggestion(label: 'Matematika', value: 'Matematika'),
      ClarificationGapSuggestion(label: 'Fisika', value: 'Fisika'),
    ],
  );

  testWidgets('renders ClarificationQuestionCard with text input and submit button', (tester) async {
    String? answeredText;

    await tester.pumpWidget(_buildTestableWidget(
      ClarificationQuestionCard(
        gap: testGap,
        onAnswer: (val) => answeredText = val,
      ),
    ));
    await tester.pumpAndSettle();

    // Verify question and submit button exist
    expect(find.text('Silakan tentukan mata pelajaran'), findsOneWidget);
    expect(find.byKey(const Key('clarification_submit_button')), findsOneWidget);

    // Enter text into TextField
    final textField = find.byType(TextField);
    expect(textField, findsOneWidget);
    await tester.enterText(textField, 'Biologi SMA');
    await tester.pumpAndSettle();

    // Tap the submit button
    final submitButton = find.byKey(const Key('clarification_submit_button'));
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    // Verify callback was triggered with the typed answer
    expect(answeredText, equals('Biologi SMA'));
  });

  testWidgets('chip selection triggers onAnswer callback immediately', (tester) async {
    String? answeredText;

    await tester.pumpWidget(_buildTestableWidget(
      ClarificationQuestionCard(
        gap: testGap,
        onAnswer: (val) => answeredText = val,
      ),
    ));
    await tester.pumpAndSettle();

    // Tap suggestion chip
    await tester.tap(find.text('Matematika'));
    await tester.pumpAndSettle();

    expect(answeredText, equals('Matematika'));
  });
}
