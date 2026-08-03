import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myenglishpractice/data/datasources/local/word_list_asset.dart';
import 'package:myenglishpractice/domain/usecases/get_suggestions.dart';
import 'package:myenglishpractice/presentation/providers/search_provider.dart';
import 'package:myenglishpractice/presentation/screens/home/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Frequency-ordered, and chosen so each prefix has a distinct result set:
///   'a'     -> and, apple, about, another, answer, analysis
///   'an'    -> and, another, answer, analysis   (no 'apple')
///   'anoth' -> another
const _words = ['and', 'apple', 'about', 'another', 'answer', 'analysis', 'banana'];

Future<void> _pumpHome(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});

  final asset = WordListAsset(loader: (key) async => jsonEncode(_words));
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/word/:word',
        builder: (context, state) =>
            Scaffold(body: Text('detail:${state.pathParameters['word']}')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        wordListAssetProvider.overrideWithValue(asset),
        getSuggestionsProvider.overrideWithValue(GetSuggestions(asset: asset)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  // The debounce is a bare Timer, which pumpAndSettle does not wait for.
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('suggests on the very first character', (tester) async {
    await _pumpHome(tester);

    await _type(tester, 'a');

    // Regression: the callback used to return the previous query's results, so
    // the first character produced the initial empty list and showed nothing.
    expect(find.text('apple'), findsOneWidget);
    expect(find.text('and'), findsOneWidget);
  });

  testWidgets('narrows to the current prefix, not the previous one', (tester) async {
    await _pumpHome(tester);

    await _type(tester, 'a');
    await _type(tester, 'an');

    // Regression: results lagged one keystroke, so 'an' still showed the
    // matches for 'a' — 'apple' among them.
    expect(find.text('apple'), findsNothing);
    expect(find.text('another'), findsOneWidget);
    expect(find.text('analysis'), findsOneWidget);

    await _type(tester, 'anoth');

    expect(find.text('another'), findsOneWidget);
    expect(find.text('answer'), findsNothing);
  });

  testWidgets('opens the word when the keyboard search key is pressed',
      (tester) async {
    await _pumpHome(tester);

    await _type(tester, 'another');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('detail:another'), findsOneWidget);
  });

  testWidgets('search key opens a word that has no suggestion', (tester) async {
    await _pumpHome(tester);

    await _type(tester, 'ubiquitous');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('detail:ubiquitous'), findsOneWidget);
  });

  testWidgets('offers a search row when nothing matches', (tester) async {
    await _pumpHome(tester);

    await _type(tester, 'ub');
    expect(find.textContaining('Search for'), findsNothing,
        reason: 'too short to offer, and it would flash on every keystroke');

    await _type(tester, 'ubiq');
    await tester.tap(find.text('Search for "ubiq"'));
    await tester.pumpAndSettle();

    expect(find.text('detail:ubiq'), findsOneWidget);
  });

  testWidgets('tapping a suggestion opens that word', (tester) async {
    await _pumpHome(tester);

    await _type(tester, 'appl');
    await tester.tap(find.text('apple'));
    await tester.pumpAndSettle();

    expect(find.text('detail:apple'), findsOneWidget);
  });

  testWidgets('normalizes the query before opening and saving it',
      (tester) async {
    await _pumpHome(tester);

    await _type(tester, '  Apple ');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('detail:apple'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('recent_searches'), ['apple']);
  });

  testWidgets('ignores a blank submission', (tester) async {
    await _pumpHome(tester);

    await _type(tester, '   ');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.textContaining('detail:'), findsNothing);
  });
}
