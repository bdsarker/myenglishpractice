import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:myenglishpractice/core/constants/app_constants.dart';
import 'package:myenglishpractice/data/models/word_entry_model.dart';
import 'package:myenglishpractice/domain/usecases/get_all_favorites.dart';
import 'package:myenglishpractice/domain/usecases/toggle_favorite.dart';
import 'package:myenglishpractice/presentation/providers/favorites_provider.dart';
import 'package:myenglishpractice/presentation/providers/word_detail_provider.dart';
import 'package:myenglishpractice/presentation/screens/word_detail/word_detail_screen.dart';

class _MockGetAllFavorites extends Mock implements GetAllFavorites {}

class _MockToggleFavorite extends Mock implements ToggleFavorite {}

/// A pool bigger than what the screen shows, so shuffle has somewhere to go.
final _pool = [
  for (var i = 0; i < AppConstants.sentencePoolLimit; i++)
    'Example sentence number $i.',
];

Future<void> _pumpDetail(WidgetTester tester, WordEntryModel entry) async {
  // The detail body watches favourites, which otherwise reaches for sqflite.
  final getAllFavorites = _MockGetAllFavorites();
  when(getAllFavorites.call).thenAnswer((_) async => <WordEntryModel>[]);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        wordDetailProvider(entry.word).overrideWith((ref) async => entry),
        favoritesProvider.overrideWith(
          (ref) => FavoritesNotifier(getAllFavorites, _MockToggleFavorite()),
        ),
      ],
      child: MaterialApp(home: WordDetailScreen(word: entry.word)),
    ),
  );
  await tester.pumpAndSettle();
}

List<String> _visibleSentences(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .where(_pool.contains)
    .toList();

/// `Set ==` is identity in Dart, so comparing draws needs an explicit check.
bool _sameDraw(List<String> a, List<String> b) =>
    a.toSet().difference(b.toSet()).isEmpty && a.length == b.length;

/// Scoped to the scrolling body — the AppBar renders the word too.
Finder _inBody(String text) => find.descendant(
      of: find.byType(SingleChildScrollView),
      matching: find.text(text),
    );

/// The pronunciation and part-of-speech pills, found by their oval shape.
Iterable<Container> _tags(WidgetTester tester) =>
    tester.widgetList<Container>(find.byType(Container)).where((c) {
      final decoration = c.decoration;
      return decoration is ShapeDecoration && decoration.shape is StadiumBorder;
    });

void main() {
  testWidgets('sets the pronunciation and part of speech beside the word',
      (tester) async {
    await _pumpDetail(
      tester,
      const WordEntryModel(
        word: 'apple',
        phonetic: '/ˈæp.əl/',
        partOfSpeech: 'noun',
      ),
    );

    expect(_inBody('/ˈæp.əl/'), findsOneWidget);
    expect(_inBody('noun'), findsOneWidget);
    // Both are ovals, not just the part of speech.
    expect(_tags(tester), hasLength(2));

    // Laid out after the word, on the same line while it fits.
    final word = tester.getTopLeft(_inBody('apple'));
    final ipa = tester.getTopLeft(_inBody('/ˈæp.əl/'));
    final pos = tester.getTopLeft(_inBody('noun'));
    expect(ipa.dx, greaterThan(word.dx));
    expect(pos.dx, greaterThan(ipa.dx));
    expect(ipa.dy, closeTo(pos.dy, 1));
  });

  testWidgets('omits a pill the dictionary had no value for', (tester) async {
    await _pumpDetail(
      tester,
      const WordEntryModel(word: 'apple', partOfSpeech: 'noun'),
    );

    expect(_tags(tester), hasLength(1));
    expect(_inBody('noun'), findsOneWidget);
  });

  testWidgets('wraps the pills instead of overflowing a long word',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpDetail(
      tester,
      const WordEntryModel(
        word: 'antidisestablishmentarianism',
        phonetic: '/ˌæn.ti.dɪs.ɪˌstæb.lɪʃ.mənˈteə.ri.ə.nɪ.zəm/',
        partOfSpeech: 'noun',
      ),
    );

    expect(tester.takeException(), isNull);
    expect(_tags(tester), hasLength(2));
  });

  testWidgets('shows only the display limit, drawn from the cached pool',
      (tester) async {
    await _pumpDetail(
      tester,
      WordEntryModel(word: 'apple', sentences: _pool),
    );

    final shown = _visibleSentences(tester);
    expect(shown, hasLength(AppConstants.sentenceLimit));
    expect(shown.toSet(), hasLength(AppConstants.sentenceLimit));
  });

  testWidgets('shuffle draws a different five without a refetch',
      (tester) async {
    await _pumpDetail(
      tester,
      WordEntryModel(word: 'apple', sentences: _pool),
    );

    final before = _visibleSentences(tester);

    // A fair shuffle can redraw the same five, so retry until the draw actually
    // moves rather than asserting on a single press.
    var after = before;
    for (var attempt = 0; attempt < 20 && _sameDraw(after, before); attempt++) {
      await tester.tap(find.byIcon(Icons.shuffle_rounded));
      await tester.pumpAndSettle();
      after = _visibleSentences(tester);
    }

    expect(after, hasLength(AppConstants.sentenceLimit));
    expect(_sameDraw(after, before), isFalse);
    expect(_pool, containsAll(after));
  });

  testWidgets('hides shuffle when there is nothing else to show',
      (tester) async {
    final few = _pool.take(3).toList();

    await _pumpDetail(
      tester,
      WordEntryModel(word: 'ephemeral', sentences: few),
    );

    // Order is not asserted — a short pool is still drawn at random.
    expect(_visibleSentences(tester), unorderedEquals(few));
    expect(find.byIcon(Icons.shuffle_rounded), findsNothing);
  });

  testWidgets('renders no sentence section, and no filler, when the pool is empty',
      (tester) async {
    await _pumpDetail(
      tester,
      const WordEntryModel(word: 'apple', englishDefinition: 'A round fruit.'),
    );

    expect(find.text('Example Sentences'), findsNothing);
    expect(find.textContaining('perfectly in her essay'), findsNothing);
  });

  testWidgets('credits Tatoeba, as its licence requires', (tester) async {
    await _pumpDetail(
      tester,
      WordEntryModel(word: 'apple', sentences: _pool),
    );

    expect(find.textContaining('Tatoeba'), findsOneWidget);
  });
}
