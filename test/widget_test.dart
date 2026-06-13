// Basic smoke test for gdust_lite
import 'package:flutter_test/flutter_test.dart';
import 'package:gdust_lite/main.dart';

void main() {
  testWidgets('App launches without crash', (WidgetTester tester) async {
    await tester.pumpWidget(const GdustLiteApp());
    await tester.pumpAndSettle();
    // Should show the main page with AppBar
    expect(find.text('第 1 周'), findsOneWidget);
  });
}
