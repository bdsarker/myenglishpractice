import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myenglishpractice/main.dart';

void main() {
  testWidgets('App starts without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: EnglishBuddyApp()));
    expect(find.byType(EnglishBuddyApp), findsOneWidget);
  });
}
