import 'package:flutter_test/flutter_test.dart';
import 'package:split_easy_app/main.dart';

void main() {
  testWidgets('app loads the login screen', (tester) async {
    await initializeApp();
    await tester.pumpWidget(const SplitEasyApp());

    expect(find.text('SplitEasy'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });
}
