import 'dart:convert';
import '../../core/constants/app_constants.dart';
import '../../core/utils/connectivity.dart';
import '../datasources/local/word_db.dart';
import '../datasources/remote/dictionary_api.dart';
import '../datasources/remote/datamuse_api.dart';
import '../datasources/remote/sentence_api.dart';
import '../datasources/remote/translate_api.dart';
import '../models/word_entry_model.dart';

class WordRepository {
  final WordDb _db;
  final DictionaryApi _dictionary;
  final DatamuseApi _datamuse;
  final TranslateApi _translate;
  final SentenceApi _sentences;
  final ConnectivityUtil _connectivity;

  WordRepository({
    WordDb? db,
    DictionaryApi? dictionary,
    DatamuseApi? datamuse,
    TranslateApi? translate,
    SentenceApi? sentences,
    ConnectivityUtil? connectivity,
  })  : _db = db ?? WordDb(),
        _dictionary = dictionary ?? DictionaryApi(),
        _datamuse = datamuse ?? DatamuseApi(),
        _translate = translate ?? TranslateApi(),
        _sentences = sentences ?? SentenceApi(),
        _connectivity = connectivity ?? ConnectivityUtil();

  Future<WordEntryModel> getWordEntry(String word) async {
    final cached = await _db.getCachedWord(word);
    if (cached != null) {
      final isFav = await _db.isFavorite(word);
      return WordEntryModel(
        word: word,
        banglaDefinition: cached['bangla_meaning'] as String?,
        synonyms: (jsonDecode(cached['synonyms_json'] as String? ?? '[]') as List<dynamic>).cast<String>(),
        sentences: (jsonDecode(cached['sentences_json'] as String? ?? '[]') as List<dynamic>).cast<String>(),
        isFavorite: isFav,
      );
    }

    // Every source below swallows its own network errors and returns a null or
    // empty result, which is indistinguishable from "no such word". Fail loudly
    // here instead, so being offline never gets reported as a bad spelling.
    await _connectivity.checkConnectivity();

    final results = await Future.wait([
      _dictionary.lookup(word),
      _datamuse.getSynonyms(word),
      _translate.translateToBangla(word),
      _sentences.getExampleSentences(word),
    ]);

    final dictResult = results[0] as DictionaryResult?;
    final synonyms = results[1] as List<String>;
    final bangla = results[2] as String;
    final corpusSentences = results[3] as List<String>;
    final isFav = await _db.isFavorite(word);

    // No dictionary entry does not mean the word is worthless — the dictionary
    // misses ordinary words like "norwegian" that the corpus covers well. What
    // it does mean is that nothing corroborates the spelling, so the sentences
    // have to earn their place by actually containing the word.
    final found = dictResult != null;

    final entry = WordEntryModel(
      word: word,
      phonetic: dictResult?.phonetic,
      partOfSpeech: dictResult?.partOfSpeech,
      englishDefinition: dictResult?.definition,
      banglaDefinition: bangla.isEmpty ? null : bangla,
      synonyms: synonyms,
      sentences: found
          ? _pool(corpusSentences, dictResult.examples)
          : _pool(_mentioning(word, corpusSentences), const []),
      isFavorite: isFav,
      found: found,
    );

    // Misses stay out of the cache: the lookup also returns null on a timeout
    // or a transient 5xx, and caching that would pin a real word as unknown
    // for the next 24 hours.
    if (found) {
      await _db.cacheWord(entry);
    }
    return entry;
  }

  /// The subset of [sentences] that actually contains [word].
  ///
  /// Only used when the dictionary has no entry. Tatoeba's search is fuzzy, not
  /// exact — it answers "definately" with "Define evolution." — so without an
  /// entry to corroborate the spelling, an unfiltered corpus hit is how a typo
  /// ends up illustrated by a sentence about a different word entirely.
  ///
  /// Matched at a word boundary but without one at the end, so inflections
  /// count: "norwegian" still matches "Are you Norwegians?".
  List<String> _mentioning(String word, List<String> sentences) {
    final mention = RegExp(r'\b' + RegExp.escape(word), caseSensitive: false);
    return sentences.where(mention.hasMatch).toList();
  }

  /// The whole pool the detail screen shuffles through, corpus sentences first.
  ///
  /// Cached in full rather than trimmed to what fits on screen, so re-opening a
  /// word within the cache window can still draw a different five.
  List<String> _pool(List<String> corpus, List<String> dictionary) {
    final seen = <String>{};
    final pool = <String>[];

    for (final sentence in [...corpus, ...dictionary]) {
      if (!seen.add(sentence.toLowerCase())) continue;
      pool.add(sentence);
      if (pool.length == AppConstants.sentencePoolLimit) break;
    }

    return pool;
  }
}
