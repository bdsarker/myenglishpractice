import 'dart:convert';
import '../../core/utils/connectivity.dart';
import '../datasources/local/word_db.dart';
import '../datasources/remote/dictionary_api.dart';
import '../datasources/remote/datamuse_api.dart';
import '../datasources/remote/translate_api.dart';
import '../datasources/remote/wordnik_api.dart';
import '../models/word_entry_model.dart';

class WordRepository {
  final WordDb _db;
  final DictionaryApi _dictionary;
  final DatamuseApi _datamuse;
  final TranslateApi _translate;
  final WordnikApi _wordnik;
  final ConnectivityUtil _connectivity;

  WordRepository({
    WordDb? db,
    DictionaryApi? dictionary,
    DatamuseApi? datamuse,
    TranslateApi? translate,
    WordnikApi? wordnik,
    ConnectivityUtil? connectivity,
  })  : _db = db ?? WordDb(),
        _dictionary = dictionary ?? DictionaryApi(),
        _datamuse = datamuse ?? DatamuseApi(),
        _translate = translate ?? TranslateApi(),
        _wordnik = wordnik ?? WordnikApi(),
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
      _wordnik.getExampleSentences(word),
    ]);

    final dictResult = results[0] as DictionaryResult?;
    final synonyms = results[1] as List<String>;
    final bangla = results[2] as String;
    final sentences = results[3] as List<String>;
    final isFav = await _db.isFavorite(word);

    // No dictionary entry means the word does not exist. Wordnik hands back
    // generic filler sentences in that case, so drop them rather than show
    // invented examples for a word nobody can define.
    final found = dictResult != null;

    final entry = WordEntryModel(
      word: word,
      phonetic: dictResult?.phonetic,
      partOfSpeech: dictResult?.partOfSpeech,
      englishDefinition: dictResult?.definition,
      banglaDefinition: bangla.isEmpty ? null : bangla,
      synonyms: synonyms,
      sentences: found ? sentences : const [],
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
}
