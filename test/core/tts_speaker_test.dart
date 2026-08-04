import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:myenglishpractice/core/services/speech_service.dart';

class _MockTts extends Mock implements FlutterTts {}

void main() {
  late _MockTts tts;
  late TtsSpeaker speaker;

  setUp(() {
    tts = _MockTts();
    when(() => tts.setLanguage(any())).thenAnswer((_) async => 1);
    when(() => tts.setSpeechRate(any())).thenAnswer((_) async => 1);
    when(() => tts.setPitch(any())).thenAnswer((_) async => 1);
    when(() => tts.setVolume(any())).thenAnswer((_) async => 1);
    when(() => tts.speak(any())).thenAnswer((_) async => 1);
    when(() => tts.stop()).thenAnswer((_) async => 1);
    speaker = TtsSpeaker(tts: tts);
  });

  test('speaks at the rate that means natural on both platforms', () async {
    await speaker.speak('apple');

    // 0.5, not 1.0: flutter_tts doubles the Android value on the way through so
    // that one number means normal speed everywhere. A platform conditional
    // here would make Android twice as fast as intended.
    verify(() => tts.setSpeechRate(0.5)).called(1);
    verify(() => tts.setLanguage('en-US')).called(1);
  });

  test('stops before every speak', () async {
    await speaker.speak('apple');

    // iOS queues utterances where Android flushes, so without the stop a second
    // tap plays both sentences back to back on iPhone.
    verifyInOrder([() => tts.stop(), () => tts.speak('apple')]);
  });

  test('interrupts the previous utterance rather than queueing it', () async {
    await speaker.speak('one');
    await speaker.speak('two');

    verifyInOrder([
      () => tts.stop(),
      () => tts.speak('one'),
      () => tts.stop(),
      () => tts.speak('two'),
    ]);
  });

  test('configures the engine once, however many times it speaks', () async {
    await speaker.speak('one');
    await speaker.speak('two');
    await speaker.speak('three');

    verify(() => tts.setLanguage(any())).called(1);
    verify(() => tts.setSpeechRate(any())).called(1);
  });

  test('concurrent first taps do not configure it twice', () async {
    // Both calls hit the memoised init before either finishes.
    await Future.wait([speaker.speak('one'), speaker.speak('two')]);

    verify(() => tts.setLanguage(any())).called(1);
  });

  test('stopping before anything played never touches the engine', () async {
    await speaker.stop();

    // Nothing can be playing if the engine was never configured, and reaching
    // for it would spin up a TTS session just to silence it.
    verifyNever(() => tts.stop());
  });

  test('reports finishing, cancelling and failing all as finished', () async {
    var finished = 0;
    speaker.onFinished(() => finished++);
    await speaker.speak('apple');

    // Whatever the engine calls, the UI only needs to know it went quiet.
    verify(() => tts.setCompletionHandler(captureAny())).captured.single();
    verify(() => tts.setCancelHandler(captureAny())).captured.single();
    (verify(() => tts.setErrorHandler(captureAny())).captured.single
        as Function)('some engine error');

    expect(finished, 3);
  });
}
