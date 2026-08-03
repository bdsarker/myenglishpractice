import 'package:dio/dio.dart';
import '../../../core/constants/api_keys.dart';
import '../../../core/constants/app_constants.dart';

class WordnikApi {
  final Dio _dio;

  WordnikApi({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ));

  Future<List<String>> getExampleSentences(String word) async {
    try {
      final response = await _dio.get(
        'https://api.wordnik.com/v4/word.json/$word/examples',
        queryParameters: {
          'limit': AppConstants.sentenceLimit,
          'api_key': ApiKeys.wordnik,
        },
      );
      final data = response.data as Map<String, dynamic>;
      final examples = data['examples'] as List<dynamic>?;
      if (examples == null || examples.isEmpty) {
        return _fallback(word);
      }
      return examples
          .map((e) => (e as Map<String, dynamic>)['text'] as String)
          .toList();
    } on DioException {
      return _fallback(word);
    }
  }

  List<String> _fallback(String word) => [
        'She used the word "$word" perfectly in her essay.',
        'Learning to use "$word" correctly will improve your writing.',
        'Can you give me an example sentence using "$word"?',
      ];
}
