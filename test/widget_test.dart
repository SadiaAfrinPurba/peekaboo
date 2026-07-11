// Basic smoke test for Peekaboo.

import 'package:flutter_test/flutter_test.dart';

import 'package:peekaboo/app.dart';

void main() {
  testWidgets('App boots to the gallery with an empty state',
      (WidgetTester tester) async {
    await tester.pumpWidget(const PeekabooApp());
    await tester.pumpAndSettle();

    expect(find.text('Peekaboo'), findsOneWidget);
    expect(find.text('Your vault is empty'), findsOneWidget);
  });
}
