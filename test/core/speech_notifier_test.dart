import 'package:flutter_test/flutter_test.dart';
import 'package:myenglishpractice/presentation/providers/speech_provider.dart';

import '../support/fake_speaker.dart';

void main() {
  late FakeSpeaker speaker;
  late SpeechNotifier notifier;

  setUp(() {
    speaker = FakeSpeaker();
    notifier = SpeechNotifier(speaker);
  });

  // Guarded: one test disposes early on purpose, and StateNotifier throws on a
  // second dispose.
  tearDown(() {
    if (notifier.mounted) notifier.dispose();
  });

  test('starts silent', () {
    expect(notifier.state, isNull);
    expect(speaker.log, isEmpty);
  });

  test('speaks the text and holds it as the playing one', () async {
    await notifier.toggle('apple');

    expect(notifier.state, 'apple');
    expect(speaker.log, ['speak:apple']);
  });

  test('toggling the same text stops rather than replaying it', () async {
    await notifier.toggle('apple');
    await notifier.toggle('apple');

    expect(notifier.state, isNull);
    expect(speaker.log, ['speak:apple', 'stop']);
  });

  test('a different text replaces the first', () async {
    await notifier.toggle('apple');
    await notifier.toggle('An apple fell.');

    expect(notifier.state, 'An apple fell.');
    expect(speaker.log, ['speak:apple', 'speak:An apple fell.']);
  });

  test('goes silent when the engine reports it finished', () async {
    await notifier.toggle('apple');
    speaker.finish();

    expect(notifier.state, isNull);
    // Nothing extra asked of the engine — it stopped by itself.
    expect(speaker.log, ['speak:apple']);
  });

  test('a finish callback after disposal does not throw', () async {
    await notifier.toggle('apple');
    notifier.dispose();

    expect(speaker.finish, returnsNormally);
  });
}
