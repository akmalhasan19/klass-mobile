import 'package:flutter_test/flutter_test.dart';
import 'package:klass_app/main.dart';

void main() {
  testWidgets('App renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const KlassApp());
    expect(find.text('Klass'), findsWidgets);
  });
}
