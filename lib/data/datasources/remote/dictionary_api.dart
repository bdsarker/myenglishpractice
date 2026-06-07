import 'package:dio/dio.dart';

class DictionaryResult {
  final String? phonetic;
  final String? partOfSpeech;
  final String? definition;

  const DictionaryResult({this.phonetic, this.partOfSpeech, this.definition});
}

class DictionaryApi {
  final Dio _dio;

  DictionaryApi({Dio? dio}) : _dio = dio ?? Dio();

  Future<DictionaryResult?> lookup(String word) async {
    try {
      final response = await _dio.get(
        'https://api.dictionaryapi.dev/api/v2/entries/en/$word',
      );
      final data = response.data as List<dynamic>;
      if (data.isEmpty) return null;

      final entry = data[0] as Map<String, dynamic>;
      final phonetic = entry['phonetic'] as String?;

      final meanings = entry['meanings'] as List<dynamic>?;
      if (meanings == null || meanings.isEmpty) {
        return DictionaryResult(phonetic: phonetic);
      }

      final meaning = meanings[0] as Map<String, dynamic>;
      final partOfSpeech = meaning['partOfSpeech'] as String?;
      final defs = meaning['definitions'] as List<dynamic>?;
      final definition = defs != null && defs.isNotEmpty
          ? (defs[0] as Map<String, dynamic>)['definition'] as String?
          : null;

      return DictionaryResult(
        phonetic: phonetic,
        partOfSpeech: partOfSpeech,
        definition: definition,
      );
    } on DioException {
      return null;
    }
  }
}
