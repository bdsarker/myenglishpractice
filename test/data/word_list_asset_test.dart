import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myenglishpractice/core/constants/app_constants.dart';
import 'package:myenglishpractice/data/datasources/local/word_list_asset.dart';

/// Frequency-ordered, like the real asset.
const _sample = [
  'and', 'are', 'at', 'as', 'all', 'an', 'about', 'any', 'also', 'am', //
  'another', 'analysis', 'annual', 'anything', 'anyone', 'answer', 'animal',
  'apple', 'the', 'that',
];

WordListAsset _assetOf(List<String> words, {int? failTimes}) {
  var failuresLeft = failTimes ?? 0;
  return WordListAsset(loader: (key) async {
    if (failuresLeft > 0) {
      failuresLeft--;
      throw PlatformException(code: 'not-found', message: 'no asset');
    }
    return jsonEncode(words);
  });
}

void main() {
  group('getSuggestions', () {
    test('returns matches for a single character', () async {
      final asset = _assetOf(_sample);
      final result = await asset.getSuggestions('a');

      expect(result, isNotEmpty);
      expect(result.first, 'and');
    });

    test('keeps frequency order from the asset', () async {
      final asset = _assetOf(_sample);

      expect(
        await asset.getSuggestions('an'),
        ['an', 'and', 'any', 'another', 'analysis', 'annual', 'anything', 'anyone', 'answer', 'animal'],
      );
    });

    test('narrows as the prefix grows, matching only that prefix', () async {
      final asset = _assetOf(_sample);

      expect(await asset.getSuggestions('anoth'), ['another']);
      expect(await asset.getSuggestions('appl'), ['apple']);
      for (final word in await asset.getSuggestions('an')) {
        expect(word, startsWith('an'));
      }
    });

    test('promotes an exact match that ranks below the limit', () async {
      // 'zz' sits past the suggestion limit among its own prefix matches.
      final words = [
        for (var i = 0; i < AppConstants.suggestionLimit + 5; i++) 'zz$i',
        'zz',
      ];
      final result = await _assetOf(words).getSuggestions('zz');

      expect(result.first, 'zz');
      expect(result, hasLength(AppConstants.suggestionLimit));
    });

    test('caps results at the suggestion limit', () async {
      final words = [for (var i = 0; i < 50; i++) 'test$i'];

      expect(
        await _assetOf(words).getSuggestions('test'),
        hasLength(AppConstants.suggestionLimit),
      );
    });

    test('returns nothing for an empty or whitespace query', () async {
      final asset = _assetOf(_sample);

      expect(await asset.getSuggestions(''), isEmpty);
      expect(await asset.getSuggestions('   '), isEmpty);
    });

    test('is case insensitive and trims the query', () async {
      final asset = _assetOf(_sample);

      expect(await asset.getSuggestions('  ANOTH '), ['another']);
    });

    test('collapses duplicates in the asset', () async {
      final asset = _assetOf(['apple', 'apple', 'apply', 'Apple']);

      expect(await asset.getSuggestions('app'), ['apple', 'apply']);
    });
  });

  group('load', () {
    test('reads the asset only once across concurrent calls', () async {
      var reads = 0;
      final asset = WordListAsset(loader: (key) async {
        reads++;
        return jsonEncode(_sample);
      });

      await Future.wait([
        asset.getSuggestions('a'),
        asset.getSuggestions('b'),
        asset.load(),
      ]);

      expect(reads, 1);
    });

    test('does not cache a failed load, so a later call retries', () async {
      final asset = _assetOf(_sample, failTimes: 1);

      await expectLater(asset.getSuggestions('a'), throwsA(isA<PlatformException>()));
      expect(await asset.getSuggestions('a'), isNotEmpty);
    });
  });

  group('bundled asset', () {
    // The only test that touches the real bundle: proves the asset ships,
    // parses, and is still ordered by frequency.
    setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

    test('ships, parses and is ranked by frequency', () async {
      final raw = await rootBundle.loadString(WordListAsset.assetKey);
      final words = (jsonDecode(raw) as List<dynamic>).cast<String>();

      // A floor, not the exact count — but high enough that a regeneration
      // which silently drops a source fails here.
      expect(words.length, greaterThanOrEqualTo(20000));
      expect(words.toSet(), hasLength(words.length), reason: 'no duplicates');
      expect(
        words.every(RegExp(r'^[a-z]+$').hasMatch),
        isTrue,
        reason: 'lowercase letters only',
      );

      // Frequency order is what makes `take(n)` return the common words.
      // Sorting this file alphabetically would silently break suggestions.
      expect(words.indexOf('the'), lessThan(words.indexOf('theatre')));
      expect(words.indexOf('any'), lessThan(words.indexOf('analysis')));
    });

    test('covers the words the search box is expected to suggest', () async {
      final asset = WordListAsset();

      expect(await asset.getSuggestions('a'), isNotEmpty);
      expect(await asset.getSuggestions('an'), contains('another'));
      expect(await asset.getSuggestions('anoth'), ['another']);
      expect(await asset.getSuggestions('appl'), contains('apple'));
    });

    test('suggests mid-frequency vocabulary, not just the most common words',
        () async {
      // While the asset was the top 10,000 of a 20k source these produced no
      // suggestions at all.
      final asset = WordListAsset();

      for (final word in [
        'arrogant', 'arrogance', 'diligent', 'pragmatic', //
        'verbose', 'meticulous', 'eloquent',
      ]) {
        expect(
          await asset.getSuggestions(word),
          contains(word),
          reason: '"$word" should be suggested',
        );
      }
    });

    test('does not suggest words that lead nowhere', () async {
      // Regression: tapping a suggestion has to show something. None of these
      // has a definition, a synonym or an example sentence in any of the four
      // sources, so suggesting them can only produce an empty screen.
      // Abbreviations and proper nouns are the bulk of that class, which is
      // what the WordNet intersection in tool/generate_word_list.dart removes.
      final asset = WordListAsset();

      for (final word in [
        'arrowsmith', 'gld', 'spp', 'maris', //
        'findhorn', 'oligochaeta', 'mastopexy', 'inkster',
      ]) {
        expect(
          await asset.getSuggestions(word),
          isNot(contains(word)),
          reason: '"$word" has no content anywhere and should not be offered',
        );
      }
    });
  });
}
