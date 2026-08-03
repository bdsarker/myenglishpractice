import 'package:dio/dio.dart';
import '../../../core/constants/app_constants.dart';

class DatamuseApi {
  final Dio _dio;

  DatamuseApi({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ));

  Future<List<String>> getSynonyms(String word) async {
    try {
      final response = await _dio.get(
        'https://api.datamuse.com/words',
        queryParameters: {
          'rel_syn': word,
          'max': AppConstants.synonymLimit,
        },
      );
      final data = response.data as List<dynamic>;
      return data
          .map((e) => (e as Map<String, dynamic>)['word'] as String)
          .toList();
    } on DioException {
      return [];
    }
  }
}
