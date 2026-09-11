// Basic smoke test for the Attendance app.
//
// Builds MyApp with a route and verifies it renders without crashing.

import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_app/main.dart';

void main() {
  testWidgets('App builds smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(initialRoute: '/login'));
    await tester.pump();

    expect(find.byType(MyApp), findsOneWidget);
  });
}
