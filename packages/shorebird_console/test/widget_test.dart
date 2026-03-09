import 'package:flutter_test/flutter_test.dart';
import 'package:shorebird_console/app.dart';

void main() {
  testWidgets('App renders', (tester) async {
    await tester.pumpWidget(
      const App(apiBaseUrl: 'http://localhost:8080'),
    );
    expect(find.text('Shorebird Console'), findsOneWidget);
  });
}
