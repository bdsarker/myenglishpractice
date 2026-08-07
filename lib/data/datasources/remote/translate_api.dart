import 'package:dio/dio.dart';

class TranslateApi {
  final Dio _dio;

  TranslateApi({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ));

  /// MyMemory sometimes appends a translator's note to the translation itself,
  /// e.g. "পিটার্সবার্গCity name (optional, probably does not need a
  /// translation)". Anything from the first ASCII-parenthesised aside onwards is
  /// commentary, not Bangla.
  static final _trailingNote = RegExp(r'[A-Za-z][^()]*\([^)]*\)\s*$');

  Future<String> translateToBangla(String text) async {
    try {
      final response = await _dio.get(
        'https://api.mymemory.translated.net/get',
        queryParameters: {'q': text, 'langpair': 'en|bn'},
      );
      final data = response.data as Map<String, dynamic>;
      final raw =
          (data['responseData'] as Map<String, dynamic>)['translatedText'] as String? ?? '';

      final cleaned = raw.replaceFirst(_trailingNote, '').trim();

      // A word it cannot translate comes back verbatim ("aplle" -> "aplle").
      // That is not a meaning, and showing it as one invents a definition for
      // whatever the user typed.
      if (cleaned.toLowerCase() == text.trim().toLowerCase()) return '';

      return cleaned;
    } on DioException {
      return '';
    }
  }
}
