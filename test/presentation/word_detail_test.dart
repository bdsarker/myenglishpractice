import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:myenglishpractice/core/constants/app_constants.dart';
import 'package:myenglishpractice/data/models/word_entry_model.dart';
import 'package:myenglishpractice/domain/usecases/get_all_favorites.dart';
import 'package:myenglishpractice/domain/usecases/toggle_favorite.dart';
import 'package:myenglishpractice/presentation/providers/favorites_provider.dart';
import 'package:myenglishpractice/presentation/providers/speech_provider.dart';
import 'package:myenglishpractice/presentation/providers/word_detail_provider.dart';
import 'package:myenglishpractice/presentation/screens/word_detail/word_detail_screen.dart';

import '../support/fake_speaker.dart';

class _MockGetAllFavorites extends Mock implements GetAllFavorites {}

class _MockToggleFavorite extends Mock implements ToggleFavorite {}

/// Both set by [_pumpDetail] so tests can read back what was spoken and saved.
late FakeSpeaker _speaker;
late _MockToggleFavorite _toggleFavorite;

/// A pool bigger than what the screen shows, so shuffle has somewhere to go.
final _pool = [
  for (var i = 0; i < AppConstants.sentencePoolLimit; i++)
    'Example sentence number $i.',
];

Future<void> _pumpDetail(WidgetTester tester, WordEntryModel entry) async {
  // The detail body watches favourites, which otherwise reaches for sqflite.
  final getAllFavorites = _MockGetAllFavorites();
  when(getAllFavorites.call).thenAnswer((_) async => <WordEntryModel>[]);

  _toggleFavorite = _MockToggleFavorite();
  when(() => _toggleFavorite.call(any())).thenAnswer((_) async => true);

  // And the speak buttons would otherwise reach for a MethodChannel that no
  // test host provides.
  _speaker = FakeSpeaker();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        wordDetailProvider(entry.word).overrideWith((ref) async => entry),
        favoritesProvider.overrideWith(
          (ref) => FavoritesNotifier(getAllFavorites, _toggleFavorite),
        ),
        speakerProvider.overrideWithValue(_speaker),
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

/// The speak button belonging to one sentence — scoped to its own row, since
/// every row has an identical one.
Finder _speakButtonFor(String sentence) => find.descendant(
      of: find.ancestor(
        of: find.text(sentence),
        matching: find.byType(ListTile),
      ),
      matching: find.byIcon(Icons.volume_up_rounded),
    );

/// The pronunciation and part-of-speech pills, found by their oval shape.
Iterable<Container> _tags(WidgetTester tester) =>
    tester.widgetList<Container>(find.byType(Container)).where((c) {
      final decoration = c.decoration;
      return decoration is ShapeDecoration && decoration.shape is StadiumBorder;
    });

void main() {
  setUpAll(() => registerFallbackValue(const WordEntryModel(word: '')));

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

  testWidgets('pronounces the word from the button beside it', (tester) async {
    await _pumpDetail(tester, const WordEntryModel(word: 'apple'));

    await tester.tap(find.byIcon(Icons.volume_up_rounded));
    await tester.pumpAndSettle();

    expect(_speaker.log, ['speak:apple']);
  });

  testWidgets('gives every sentence its own button', (tester) async {
    await _pumpDetail(
      tester,
      WordEntryModel(word: 'apple', sentences: _pool),
    );

    // One per sentence, plus the word's own.
    expect(
      find.byIcon(Icons.volume_up_rounded),
      findsNWidgets(AppConstants.sentenceLimit + 1),
    );

    final third = _visibleSentences(tester)[2];
    await tester.tap(_speakButtonFor(third));
    await tester.pumpAndSettle();

    expect(_speaker.log, ['speak:$third']);
  });

  testWidgets('drops the decorative book icon the button replaced',
      (tester) async {
    await _pumpDetail(
      tester,
      WordEntryModel(word: 'apple', sentences: _pool),
    );

    expect(find.byIcon(Icons.book_outlined), findsNothing);
  });

  testWidgets('a second sentence interrupts the first', (tester) async {
    await _pumpDetail(
      tester,
      WordEntryModel(word: 'apple', sentences: _pool),
    );

    final shown = _visibleSentences(tester);
    await tester.tap(_speakButtonFor(shown.first));
    await tester.pumpAndSettle();
    await tester.tap(_speakButtonFor(shown[1]));
    await tester.pumpAndSettle();

    // No stop in between: the engine adapter issues that itself, so the two
    // never overlap. See tts_speaker_test.dart.
    expect(_speaker.log, ['speak:${shown.first}', 'speak:${shown[1]}']);
  });

  testWidgets('tapping the playing button stops instead of replaying',
      (tester) async {
    await _pumpDetail(tester, const WordEntryModel(word: 'apple'));

    await tester.tap(find.byIcon(Icons.volume_up_rounded));
    await tester.pumpAndSettle();
    // The same button, now showing stop.
    await tester.tap(find.byIcon(Icons.stop_rounded));
    await tester.pumpAndSettle();

    expect(_speaker.log, ['speak:apple', 'stop']);
  });

  testWidgets('only the playing button shows the stop icon', (tester) async {
    await _pumpDetail(
      tester,
      WordEntryModel(word: 'apple', sentences: _pool),
    );

    final total = AppConstants.sentenceLimit + 1;
    expect(find.byIcon(Icons.stop_rounded), findsNothing);

    await tester.tap(_speakButtonFor(_visibleSentences(tester).first));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_rounded), findsNWidgets(total - 1));

    // And it goes back when the engine reports it finished on its own.
    _speaker.finish();
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.stop_rounded), findsNothing);
    expect(find.byIcon(Icons.volume_up_rounded), findsNWidgets(total));
  });

  testWidgets('leaving the screen silences whatever is playing', (tester) async {
    await _pumpDetail(tester, const WordEntryModel(word: 'apple'));

    await tester.tap(find.byIcon(Icons.volume_up_rounded));
    await tester.pumpAndSettle();

    // Tear the screen down the way popping the route would.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(_speaker.log, ['speak:apple', 'stop']);
  });

  group('the favourite star', () {
    testWidgets('sits in the AppBar, not the body', (tester) async {
      await _pumpDetail(tester, const WordEntryModel(word: 'apple'));

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.star_outline_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byIcon(Icons.star_outline_rounded),
        ),
        findsNothing,
      );
    });

    testWidgets('still toggles', (tester) async {
      await _pumpDetail(tester, const WordEntryModel(word: 'apple'));

      await tester.tap(find.byIcon(Icons.star_outline_rounded));
      await tester.pumpAndSettle();

      verify(() => _toggleFavorite.call(any())).called(1);
    });

    testWidgets('is absent for a word with no entry', (tester) async {
      // Nothing to save, so no button that would appear to do nothing.
      await _pumpDetail(
        tester,
        const WordEntryModel(word: 'asdfghjkl', found: false),
      );

      expect(find.byIcon(Icons.star_outline_rounded), findsNothing);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
    });
  });

  group('a word the dictionary has no entry for', () {
    const notice =
        'No dictionary definition for this word. Here is what we could find.';

    /// The dictionary 404s on plenty of ordinary words that the corpus covers.
    const partial = WordEntryModel(
      word: 'norwegian',
      found: false,
      synonyms: ['norse'],
      sentences: ['Are you Norwegians?'],
      banglaDefinition: 'নরওয়িয়ান',
    );

    testWidgets('still renders what the other sources returned',
        (tester) async {
      await _pumpDetail(tester, partial);

      expect(find.text('Nothing found for "norwegian"'), findsNothing);
      expect(_inBody('Are you Norwegians?'), findsOneWidget);
      expect(_inBody('norse'), findsOneWidget);
      expect(_inBody('নরওয়িয়ান'), findsOneWidget);
    });

    testWidgets('says why there is no definition', (tester) async {
      await _pumpDetail(tester, partial);

      expect(find.text(notice), findsOneWidget);
    });

    testWidgets('can still be saved', (tester) async {
      // There is something worth coming back to, so the star has work to do.
      await _pumpDetail(tester, partial);

      expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);
    });

    testWidgets('falls back to the empty state when nothing came back at all',
        (tester) async {
      // "arrowsmith": no definition, no synonyms, no sentences anywhere.
      await _pumpDetail(
        tester,
        const WordEntryModel(word: 'arrowsmith', found: false),
      );

      expect(find.text('Nothing found for "arrowsmith"'), findsOneWidget);
      expect(find.text(notice), findsNothing);
    });

    testWidgets('leaves a defined word completely alone', (tester) async {
      await _pumpDetail(
        tester,
        WordEntryModel(
          word: 'apple',
          englishDefinition: 'A round fruit.',
          sentences: _pool,
        ),
      );

      expect(find.text(notice), findsNothing);
      expect(_inBody('A round fruit.'), findsOneWidget);
    });
  });
}
