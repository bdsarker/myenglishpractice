import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:myenglishpractice/core/constants/app_constants.dart';
import 'package:myenglishpractice/data/datasources/remote/sentence_api.dart';

class _MockDio extends Mock implements Dio {}

final _requestOptions = RequestOptions(path: '/');

Response<dynamic> _response(Object? body) => Response<dynamic>(
      requestOptions: _requestOptions,
      statusCode: 200,
      data: body,
    );

/// Tatoeba wraps the sentences in a `results` list, alongside paging metadata
/// and translations this app ignores.
Map<String, dynamic> _payload(List<String> texts) => {
      'paging': {
        'Sentences': {'count': texts.length}
      },
      'results': [
        for (final text in texts) {'id': 1, 'text': text, 'lang': 'eng'},
      ],
    };

void main() {
  late _MockDio dio;
  late SentenceApi api;

  setUp(() {
    dio = _MockDio();
    api = SentenceApi(dio: dio);
  });

  void answerWith(Object response) {
    when(() => dio.get<dynamic>(any(), queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async {
      if (response is DioException) throw response;
      return response as Response<dynamic>;
    });
  }

  test('parses sentences out of a Tatoeba payload', () async {
    answerWith(_response(_payload([
      'The ant is on the table.',
      'An ant bit me on the arm.',
    ])));

    expect(await api.getExampleSentences('ant'), [
      'The ant is on the table.',
      'An ant bit me on the arm.',
    ]);
  });

  test('searches for the exact word form', () async {
    answerWith(_response(_payload(['The ant is on the table.'])));

    await api.getExampleSentences('ant');

    final captured = verify(
      () => dio.get<dynamic>(any(),
          queryParameters: captureAny(named: 'queryParameters')),
    ).captured.single as Map<String, dynamic>;

    // Without the '=', a search for 'ant' also returns 'antique' and 'want'.
    expect(captured['query'], '=ant');
    expect(captured['from'], 'eng');
  });

  test('drops a sentence that does not use the word', () async {
    answerWith(_response(_payload([
      'The ant is on the table.',
      'She walked home in the rain.',
    ])));

    expect(await api.getExampleSentences('ant'), ['The ant is on the table.']);
  });

  test('keeps inflected forms of the word', () async {
    answerWith(_response(_payload([
      'Women are persons too.',
      'The person improved quickly.',
    ])));

    expect(await api.getExampleSentences('person'), hasLength(2));
  });

  test('collapses duplicates that differ only in case', () async {
    answerWith(_response(_payload([
      'The ant is on the table.',
      'THE ANT IS ON THE TABLE.',
    ])));

    expect(await api.getExampleSentences('ant'), hasLength(1));
  });

  test('drops fragments and sentences too long to read on a phone', () async {
    answerWith(_response(_payload([
      'The ant is on the table.',
      'the ant is lowercase', // no capital, no terminator
      'An ant ${'crawled slowly ' * 10}away.', // well past 100 characters
    ])));

    expect(await api.getExampleSentences('ant'), ['The ant is on the table.']);
  });

  test('caps the pool so the cached row stays small', () async {
    answerWith(_response(_payload([
      for (var i = 0; i < AppConstants.sentencePoolLimit + 5; i++)
        'The ant number $i walked away.',
    ])));

    expect(
      await api.getExampleSentences('ant'),
      hasLength(AppConstants.sentencePoolLimit),
    );
  });

  test('returns nothing rather than filler when the corpus is unreachable',
      () async {
    answerWith(DioException.connectionTimeout(
      timeout: const Duration(seconds: 10),
      requestOptions: _requestOptions,
    ));

    expect(await api.getExampleSentences('ant'), isEmpty);
  });

  test('survives a body that is not the shape the API documents', () async {
    answerWith(_response('error code: 502'));
    expect(await api.getExampleSentences('ant'), isEmpty);

    answerWith(_response({'results': 'unexpected'}));
    expect(await api.getExampleSentences('ant'), isEmpty);

    answerWith(_response({
      'results': [
        {'id': 1},
        'not a map',
      ]
    }));
    expect(await api.getExampleSentences('ant'), isEmpty);
  });

  test('escapes a word that would otherwise be a regex', () async {
    answerWith(_response(_payload(['The c++ compiler is fast.'])));

    // A raw '+' in the pattern would throw before it could match anything.
    expect(await api.getExampleSentences('c++'), ['The c++ compiler is fast.']);
  });
}
