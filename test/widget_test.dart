import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myenglishpractice/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Without this the theme's fonts are fetched over HTTP, which leaves timers
    // pending after the widget tree is torn down.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('App starts without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: EnglishBuddyApp()));
    await tester.pumpAndSettle();

    expect(find.byType(EnglishBuddyApp), findsOneWidget);
    expect(find.text('Type a word to get started'), findsOneWidget);
  });
}
