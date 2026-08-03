import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:myenglishpractice/core/constants/app_constants.dart';
import 'package:myenglishpractice/core/utils/connectivity.dart';
import 'package:myenglishpractice/data/datasources/local/word_db.dart';
import 'package:myenglishpractice/data/datasources/remote/datamuse_api.dart';
import 'package:myenglishpractice/data/datasources/remote/dictionary_api.dart';
import 'package:myenglishpractice/data/datasources/remote/sentence_api.dart';
import 'package:myenglishpractice/data/datasources/remote/translate_api.dart';
import 'package:myenglishpractice/data/models/word_entry_model.dart';
import 'package:myenglishpractice/data/repositories/word_repository.dart';

class _MockDb extends Mock implements WordDb {}

class _MockDictionary extends Mock implements DictionaryApi {}

class _MockDatamuse extends Mock implements DatamuseApi {}

class _MockTranslate extends Mock implements TranslateApi {}

class _MockSentences extends Mock implements SentenceApi {}

class _MockConnectivity extends Mock implements ConnectivityUtil {}

const _corpusSentences = [
  'An apple fell from the tree.',
  'She ate the last apple.',
];

void main() {
  late _MockDb db;
  late _MockDictionary dictionary;
  late _MockDatamuse datamuse;
  late _MockTranslate translate;
  late _MockSentences sentences;
  late _MockConnectivity connectivity;
  late WordRepository repository;

  setUpAll(() => registerFallbackValue(const WordEntryModel(word: '')));

  setUp(() {
    db = _MockDb();
    dictionary = _MockDictionary();
    datamuse = _MockDatamuse();
    translate = _MockTranslate();
    sentences = _MockSentences();
    connectivity = _MockConnectivity();

    repository = WordRepository(
      db: db,
      dictionary: dictionary,
      datamuse: datamuse,
      translate: translate,
      sentences: sentences,
      connectivity: connectivity,
    );

    when(() => connectivity.checkConnectivity()).thenAnswer((_) async {});
    when(() => db.getCachedWord(any())).thenAnswer((_) async => null);
    when(() => db.isFavorite(any())).thenAnswer((_) async => false);
    when(() => db.cacheWord(any())).thenAnswer((_) async {});
    when(() => datamuse.getSynonyms(any())).thenAnswer((_) async => []);
    when(() => translate.translateToBangla(any())).thenAnswer((_) async => 'অনুবাদ');
    when(() => sentences.getExampleSentences(any()))
        .thenAnswer((_) async => _corpusSentences);
  });

  test('marks a word found and caches it when the dictionary has an entry',
      () async {
    when(() => dictionary.lookup('apple')).thenAnswer(
      (_) async => const DictionaryResult(definition: 'A round fruit.'),
    );

    final entry = await repository.getWordEntry('apple');

    expect(entry.found, isTrue);
    expect(entry.englishDefinition, 'A round fruit.');
    expect(entry.sentences, _corpusSentences);
    verify(() => db.cacheWord(any())).called(1);
  });

  test('tops the corpus pool up with the dictionary\'s own examples', () async {
    when(() => dictionary.lookup('apple')).thenAnswer(
      (_) async => const DictionaryResult(
        definition: 'A round fruit.',
        examples: [
          // Already in the corpus list, in a different case.
          'she ate the last apple.',
          'He packed an apple for lunch.',
        ],
      ),
    );

    final entry = await repository.getWordEntry('apple');

    expect(entry.sentences, [
      ..._corpusSentences,
      'He packed an apple for lunch.',
    ]);
  });

  test('caps the pool so a cached row cannot grow without bound', () async {
    when(() => sentences.getExampleSentences('apple')).thenAnswer(
      (_) async => [
        for (var i = 0; i < AppConstants.sentencePoolLimit + 4; i++)
          'Sentence number $i about an apple.',
      ],
    );
    when(() => dictionary.lookup('apple')).thenAnswer(
      (_) async => const DictionaryResult(
        definition: 'A round fruit.',
        examples: ['One more apple sentence.'],
      ),
    );

    final entry = await repository.getWordEntry('apple');

    expect(entry.sentences, hasLength(AppConstants.sentencePoolLimit));
    // The whole pool is cached, not just the five the screen shows, so a cache
    // hit can still shuffle.
    final cached = verify(() => db.cacheWord(captureAny())).captured.single
        as WordEntryModel;
    expect(cached.sentences, hasLength(AppConstants.sentencePoolLimit));
  });

  test('marks a word not found and drops the example sentences', () async {
    when(() => dictionary.lookup('asdfgh')).thenAnswer((_) async => null);

    final entry = await repository.getWordEntry('asdfgh');

    expect(entry.found, isFalse);
    // A corpus hit on a word the dictionary cannot define is a coincidence.
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
