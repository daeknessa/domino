import 'package:flutter_test/flutter_test.dart';

import 'package:dominoes/main.dart';

void main() {
  testWidgets('Score tracker basic test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our counters start at 0. There should be two of them.
    expect(find.text('0'), findsNWidgets(2));
    expect(find.text('1'), findsNothing);

    // Verify "Reset" and "Rules" buttons exist.
    expect(find.text('Reset'), findsOneWidget);
    expect(find.text('Rules'), findsOneWidget);

    // Verify "Add" buttons exist.
    expect(find.text('Add'), findsNWidgets(2));
  });
}
