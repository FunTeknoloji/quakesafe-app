import 'package:flutter_test/flutter_test.dart';
import 'package:quakesafe_app/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Basic check that the app starts.
    // Since it depends on connectivity and permissions, we just check if it's there.
    expect(find.byType(MyApp), findsOneWidget);
  });
}
