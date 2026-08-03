import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:myenglishpractice/data/datasources/remote/dictionary_api.dart';

class _MockDio extends Mock implements Dio {}

final _requestOptions = RequestOptions(path: '/');

Response<dynamic> _response(int status, Object? body) => Response<dynamic>(
      requestOptions: _requestOptions,
      statusCode: status,
      data: body,
    );

DioException _serverError() => DioException.badResponse(
      statusCode: 502,
      requestOptions: _requestOptions,
      response: _response(502, 'error code: 502'),
    );

/// One real entry, shaped like the live API.
const _antPayload = [
  {
    'word': 'ant',
    'phonetic': '/ænt/',
    'meanings': [
      {
        'partOfSpeech': 'noun',
        'definitions': [
          {'definition': 'An insect of the family Formicidae.'},
        ],
      },
    ],
  },
];

void main() {
  late _MockDio dio;
  late DictionaryApi api;

  setUp(() {
    dio = _MockDio();
    api = DictionaryApi(dio: dio);
  });

  void answerWith(List<Object> responses) {
    var call = 0;
    when(() => dio.get<dynamic>(any())).thenAnswer((_) async {
      final next = responses[call.clamp(0, responses.length - 1)];
      call++;
      if (next is DioException) throw next;
      return next as Response<dynamic>;
    });
  }

  test('parses a successful lookup', () async {
    answerWith([_response(200, _antPayload)]);

    final result = await api.lookup('ant');

    expect(result, isNotNull);
    expect(result!.definition, 'An insect of the family Formicidae.');
    expect(result.phonetic, '/ænt/');
    expect(result.partOfSpeech, 'noun');
  });

  test('returns null only when the word truly has no entry', () async {
    answerWith([
      _response(404, {'title': 'No Definitions Found'}),
    ]);

    expect(await api.lookup('zzzqqqxyz'), isNull);
  });

  test('retries past a burst of server errors', () async {
    // The live API returns 502 in bursts; a valid word must still resolve.
    answerWith([_serverError(), _serverError(), _response(200, _antPayload)]);

    final result = await api.lookup('ant');

    expect(result?.definition, 'An insect of the family Formicidae.');
    verify(() => dio.get<dynamic>(any())).called(3);
  });

  test('throws instead of reporting a valid word as unknown', () async {
    answerWith([_serverError()]);

    // Returning null here is what made "ant" show the not-found page.
    await expectLater(
      api.lookup('ant'),
      throwsA(isA<DictionaryUnavailableException>()),
    );
  });

  test('handles an error body that arrives as plain text', () async {
    answerWith([_response(200, 'error code: 502')]);

    expect(await api.lookup('ant'), isNull);
  });

  test('decodes a JSON body that arrives as a string', () async {
    answerWith([
      _response(
        200,
        '[{"word":"ant","phonetic":"/ænt/","meanings":'
            '[{"partOfSpeech":"noun","definitions":[{"definition":"An insect."}]}]}]',
      ),
    ]);

    expect((await api.lookup('ant'))?.definition, 'An insect.');
  });
}
