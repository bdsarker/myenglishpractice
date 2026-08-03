import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:myenglishpractice/core/utils/connectivity.dart';
import 'package:myenglishpractice/data/datasources/local/word_db.dart';
import 'package:myenglishpractice/data/datasources/remote/datamuse_api.dart';
import 'package:myenglishpractice/data/datasources/remote/dictionary_api.dart';
import 'package:myenglishpractice/data/datasources/remote/translate_api.dart';
import 'package:myenglishpractice/data/datasources/remote/wordnik_api.dart';
import 'package:myenglishpractice/data/models/word_entry_model.dart';
import 'package:myenglishpractice/data/repositories/word_repository.dart';

class _MockDb extends Mock implements WordDb {}

class _MockDictionary extends Mock implements DictionaryApi {}

class _MockDatamuse extends Mock implements DatamuseApi {}

class _MockTranslate extends Mock implements TranslateApi {}

class _MockWordnik extends Mock implements WordnikApi {}

class _MockConnectivity extends Mock implements ConnectivityUtil {}

/// Wordnik hands these back for any word, real or not.
const _fillerSentences = [
  'She used the word "asdfgh" perfectly in her essay.',
  'Learning to use "asdfgh" correctly will improve your writing.',
];

void main() {
  late _MockDb db;
  late _MockDictionary dictionary;
  late _MockDatamuse datamuse;
  late _MockTranslate translate;
  late _MockWordnik wordnik;
  late _MockConnectivity connectivity;
  late WordRepository repository;

  setUpAll(() => registerFallbackValue(const WordEntryModel(word: '')));

  setUp(() {
    db = _MockDb();
    dictionary = _MockDictionary();
    datamuse = _MockDatamuse();
    translate = _MockTranslate();
    wordnik = _MockWordnik();
    connectivity = _MockConnectivity();

    repository = WordRepository(
      db: db,
      dictionary: dictionary,
      datamuse: datamuse,
      translate: translate,
      wordnik: wordnik,
      connectivity: connectivity,
    );

    when(() => connectivity.checkConnectivity()).thenAnswer((_) async {});
    when(() => db.getCachedWord(any())).thenAnswer((_) async => null);
    when(() => db.isFavorite(any())).thenAnswer((_) async => false);
    when(() => db.cacheWord(any())).thenAnswer((_) async {});
    when(() => datamuse.getSynonyms(any())).thenAnswer((_) async => []);
    when(() => translate.translateToBangla(any())).thenAnswer((_) async => 'অনুবাদ');
    when(() => wordnik.getExampleSentences(any()))
        .thenAnswer((_) async => _fillerSentences);
  });

  test('marks a word found and caches it when the dictionary has an entry',
      () async {
    when(() => dictionary.lookup('apple')).thenAnswer(
      (_) async => const DictionaryResult(definition: 'A round fruit.'),
    );

    final entry = await repository.getWordEntry('apple');

    expect(entry.found, isTrue);
    expect(entry.englishDefinition, 'A round fruit.');
    expect(entry.sentences, _fillerSentences);
    verify(() => db.cacheWord(any())).called(1);
  });

  test('marks a word not found and drops the invented example sentences',
      () async {
    when(() => dictionary.lookup('asdfgh')).thenAnswer((_) async => null);

    final entry = await repository.getWordEntry('asdfgh');

    expect(entry.found, isFalse);
    expect(entry.sentences, isEmpty);
  });

  test('does not cache a miss, so a transient failure is retried', () async {
    when(() => dictionary.lookup('asdfgh')).thenAnswer((_) async => null);

    await repository.getWordEntry('asdfgh');

    verifyNever(() => db.cacheWord(any()));
  });

  test('surfaces a dictionary outage instead of calling the word unknown',
      () async {
    // Regression: the API 502s in bursts, and every failure used to come back
    // as "no definition found" for a perfectly ordinary word.
    when(() => dictionary.lookup('ant'))
        .thenAnswer((_) async => throw DictionaryUnavailableException());

    await expectLater(
      repository.getWordEntry('ant'),
      throwsA(isA<DictionaryUnavailableException>()),
    );
    verifyNever(() => db.cacheWord(any()));
  });

  test('reports being offline instead of calling the word unknown', () async {
    when(() => connectivity.checkConnectivity())
        .thenAnswer((_) async => throw NoInternetException());

    await expectLater(
      repository.getWordEntry('apple'),
      throwsA(isA<NoInternetException>()),
    );
    verifyNever(() => dictionary.lookup(any()));
  });

  test('serves a cached word without touching the network', () async {
    when(() => db.getCachedWord('apple')).thenAnswer((_) async => {
          'word': 'apple',
          'synonyms_json': '["fruit"]',
          'sentences_json': '["An apple a day."]',
          'bangla_meaning': 'আপেল',
          'cached_at': DateTime.now().millisecondsSinceEpoch,
        });

    final entry = await repository.getWordEntry('apple');

    expect(entry.found, isTrue);
    expect(entry.synonyms, ['fruit']);
    verifyNever(() => connectivity.checkConnectivity());
    verifyNever(() => dictionary.lookup(any()));
  });
}
