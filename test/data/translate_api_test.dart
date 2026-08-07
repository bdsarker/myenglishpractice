import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:myenglishpractice/data/datasources/remote/translate_api.dart';

class _MockDio extends Mock implements Dio {}

final _requestOptions = RequestOptions(path: '/');

Response<dynamic> _translated(String text) => Response<dynamic>(
      requestOptions: _requestOptions,
      statusCode: 200,
      data: {
        'responseData': {'translatedText': text},
      },
    );

void main() {
  late _MockDio dio;
  late TranslateApi api;

  setUp(() {
    dio = _MockDio();
    api = TranslateApi(dio: dio);
  });

  void answerWith(Object response) {
    when(() => dio.get<dynamic>(any(), queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async {
      if (response is DioException) throw response;
      return response as Response<dynamic>;
    });
  }

  test('returns an ordinary translation untouched', () async {
    answerWith(_translated('নরওয়িয়ান'));

    expect(await api.translateToBangla('norwegian'), 'নরওয়িয়ান');
  });

  test('strips the note MyMemory appends to the translation itself', () async {
    // Live response for "petersburg". The commentary is inside translatedText,
    // not a sibling field, so it renders as part of the Bangla meaning.
    answerWith(_translated(
      'পিটার্সবার্গCity name (optional, probably does not need a translation)',
    ));

    expect(await api.translateToBangla('petersburg'), 'পিটার্সবার্গ');
  });

  test('reports no translation when the word comes back verbatim', () async {
    // What MyMemory does with a word it cannot translate. Echoing the input
    // back at the user as a "meaning" invents a definition for a typo.
    answerWith(_translated('aplle'));

    expect(await api.translateToBangla('aplle'), '');
  });

  test('ignores case and surrounding space when detecting the echo', () async {
    answerWith(_translated('Aplle'));

    expect(await api.translateToBangla('  aplle '), '');
  });

  test('swallows a network failure rather than blanking the whole entry',
      () async {
    // The fan-out in WordRepository is a single Future.wait: a throw here would
    // take the definition and the sentences down with it.
    answerWith(DioException.connectionTimeout(
      timeout: const Duration(seconds: 10),
      requestOptions: _requestOptions,
    ));

    expect(await api.translateToBangla('apple'), '');
  });
}
