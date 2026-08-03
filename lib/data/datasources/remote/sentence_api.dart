import 'package:dio/dio.dart';
import '../../../core/constants/app_constants.dart';

/// Example sentences from Tatoeba, a corpus written for language learners.
///
/// Sentences are CC BY 2.0 FR, so anything shown from here has to carry the
/// attribution rendered on the word detail screen.
class SentenceApi {
  static const _endpoint = 'https://tatoeba.org/en/api_v0/search';

  /// Short enough to stay readable on a phone, long enough to show real usage.
  static const _maxCharacters = 100;

  final Dio _dio;

  SentenceApi({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ));

  /// Returns up to [AppConstants.sentencePoolLimit] sentences using [word].
  ///
  /// Empty when the corpus has nothing — never filler. Inventing a sentence for
  /// a word is worse than showing none.
  Future<List<String>> getExampleSentences(String word) async {
    final Response<dynamic> response;
    try {
      response = await _dio.get(
        _endpoint,
        queryParameters: {
          // '=word' is an exact-word search: '=person' does not match 'personal'.
          'query': '=$word',
          'from': 'eng',
          // A different draw every time the cache expires.
          'sort': 'random',
          // Keeps the sentences simple: no fragments, no essays.
          'word_count_min': 4,
          'word_count_max': 14,
        },
      );
    } on DioException {
      return const [];
    }

    return _select(response.data, word);
  }

  /// Tatoeba is community-written and its API makes no schema promise, so every
  /// step here checks rather than casts.
  List<String> _select(Object? body, String word) {
    if (body is! Map) return const [];

    final results = body['results'];
    if (results is! List) return const [];

    final usesWord = RegExp(
      // Leading boundary only, so inflections survive: 'persons' for 'person'.
      '\\b${RegExp.escape(word)}',
      caseSensitive: false,
    );

    final seen = <String>{};
    final sentences = <String>[];

    for (final result in results) {
      if (result is! Map) continue;

      final text = result['text'];
      if (text is! String) continue;

      final sentence = text.trim();
      if (!_readsAsSentence(sentence)) continue;
      if (!usesWord.hasMatch(sentence)) continue;
      // The corpus carries many near-identical 'Tom is ...' variants.
      if (!seen.add(sentence.toLowerCase())) continue;

      sentences.add(sentence);
      if (sentences.length == AppConstants.sentencePoolLimit) break;
    }

    return sentences;
  }

  bool _readsAsSentence(String sentence) {
    if (sentence.isEmpty || sentence.length > _maxCharacters) return false;
    if (!RegExp(r'^[A-Z]').hasMatch(sentence)) return false;
    return RegExp(r'[.!?]$').hasMatch(sentence);
  }
}
