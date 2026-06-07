import 'dart:convert';
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

  WordRepository({
    WordDb? db,
    DictionaryApi? dictionary,
    DatamuseApi? datamuse,
    TranslateApi? translate,
    WordnikApi? wordnik,
  })  : _db = db ?? WordDb(),
        _dictionary = dictionary ?? DictionaryApi(),
        _datamuse = datamuse ?? DatamuseApi(),
        _translate = translate ?? TranslateApi(),
        _wordnik = wordnik ?? WordnikApi();

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

    final entry = WordEntryModel(
      word: word,
      phonetic: dictResult?.phonetic,
      partOfSpeech: dictResult?.partOfSpeech,
      englishDefinition: dictResult?.definition,
      banglaDefinition: bangla.isEmpty ? null : bangla,
      synonyms: synonyms,
      sentences: sentences,
      isFavorite: isFav,
    );

    await _db.cacheWord(entry);
    return entry;
  }
}
