import 'package:dio/dio.dart';

class TranslateApi {
  final Dio _dio;

  TranslateApi({Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(connectTimeout: Duration(seconds: 10)));

  Future<String> translateToBangla(String text) async {
    try {
      final response = await _dio.get(
        'https://api.mymemory.translated.net/get',
        queryParameters: {'q': text, 'langpair': 'en|bn'},
      );
      final data = response.data as Map<String, dynamic>;
      return (data['responseData'] as Map<String, dynamic>)['translatedText'] as String? ?? '';
    } on DioException {
      return '';
    }
  }
}
