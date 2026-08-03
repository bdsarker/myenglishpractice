import 'dart:convert';
import 'package:dio/dio.dart';

class DictionaryResult {
  final String? phonetic;
  final String? partOfSpeech;
  final String? definition;

  const DictionaryResult({this.phonetic, this.partOfSpeech, this.definition});
}

/// The dictionary could not be reached, or answered with a server error.
///
/// Distinct from a null lookup result, which means the word genuinely has no
/// entry. Conflating the two makes ordinary words look like typos.
class DictionaryUnavailableException implements Exception {
  @override
  String toString() =>
      'Could not reach the dictionary right now. Please try again.';
}

class DictionaryApi {
  /// api.dictionaryapi.dev returns 5xx in bursts, so a single failed request
  /// says nothing about the word.
  static const _maxAttempts = 4;

  final Dio _dio;

  DictionaryApi({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
                // 404 is how this API says "no such word", so accept it as a
                // normal response and reserve exceptions for real failures.
                validateStatus: (status) => status != null && status < 500,
              ),
            );

  /// Returns null when the word has no dictionary entry.
  ///
  /// Throws [DictionaryUnavailableException] when the service itself failed.
  Future<DictionaryResult?> lookup(String word) async {
    final response = await _get(word);
    if (response.statusCode == 404) return null;

    // Errors come back as text/plain, which Dio leaves as a raw String.
    final data = _decode(response.data);
    if (data is! List || data.isEmpty) return null;

    final entry = data.first;
    if (entry is! Map<String, dynamic>) return null;
    final phonetic = entry['phonetic'] as String?;

    final meanings = entry['meanings'] as List<dynamic>?;
    if (meanings == null || meanings.isEmpty) {
      return DictionaryResult(phonetic: phonetic);
    }

    final meaning = meanings.first as Map<String, dynamic>;
    final partOfSpeech = meaning['partOfSpeech'] as String?;
    final defs = meaning['definitions'] as List<dynamic>?;
    final definition = defs != null && defs.isNotEmpty
        ? (defs.first as Map<String, dynamic>)['definition'] as String?
        : null;

    return DictionaryResult(
      phonetic: phonetic,
      partOfSpeech: partOfSpeech,
      definition: definition,
    );
  }

  Future<Response<dynamic>> _get(String word) async {
    for (var attempt = 1;; attempt++) {
      try {
        return await _dio.get(
          'https://api.dictionaryapi.dev/api/v2/entries/en/$word',
        );
      } on DioException {
        if (attempt >= _maxAttempts) throw DictionaryUnavailableException();
        await Future<void>.delayed(Duration(milliseconds: 300 * attempt));
      }
    }
  }

  Object? _decode(Object? body) {
    if (body is! String) return body;
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }
}
