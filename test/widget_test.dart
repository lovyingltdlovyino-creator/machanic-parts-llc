// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:mechanic_part/main.dart';

void main() {
  testWidgets('Splash screen renders title', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MechanicPartApp());

    // Allow splash animations to settle.
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Verify that the splash screen title renders.
    expect(find.text('Mechanic Part'), findsOneWidget);
  });
}
