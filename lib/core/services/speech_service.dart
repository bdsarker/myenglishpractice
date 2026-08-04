import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Reads text aloud.
///
/// An interface rather than [TtsSpeaker] directly, because flutter_tts talks
/// over a MethodChannel that does not exist under `flutter test` — widget tests
/// substitute a fake through `speakerProvider`.
abstract class Speaker {
  /// Speaks [text], replacing anything already playing.
  Future<void> speak(String text);

  Future<void> stop();

  /// Called when speech ends on its own — finished, cancelled or failed.
  ///
  /// Not called for a [stop] this app initiated: Android does not reliably fire
  /// the cancel handler for a programmatic stop, so callers clear their own
  /// state there instead of waiting for a callback that may never arrive.
  void onFinished(VoidCallback callback);

  void dispose();
}

class TtsSpeaker implements Speaker {
  /// Natural speed on both platforms.
  ///
  /// The usual advice is that Android's normal rate is 1.0 and iOS's is 0.5,
  /// which would need a platform check. It doesn't: flutter_tts multiplies the
  /// Android value by 2.0 precisely so that 0.5 means normal everywhere, and on
  /// iOS 0.5 is AVSpeechUtteranceDefaultSpeechRate.
  static const _naturalRate = 0.5;

  static const _language = 'en-US';

  final FlutterTts _tts;
  VoidCallback? _onFinished;

  /// Memoised so concurrent first taps configure the engine once, not twice.
  Future<void>? _ready;

  TtsSpeaker({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  @override
  void onFinished(VoidCallback callback) => _onFinished = callback;

  Future<void> _configure() async {
    // Every path back to idle, however it got there.
    void finished([dynamic _, dynamic __]) => _onFinished?.call();

    _tts.setCompletionHandler(finished);
    _tts.setCancelHandler(finished);
    _tts.setErrorHandler(finished);

    if (!kIsWeb && Platform.isIOS) {
      await _tts.setSharedInstance(true);
      // playback, not the README's `ambient`: ambient is silenced by the
      // hardware mute switch, so a learner with the ringer off would tap the
      // button and hear nothing with no explanation. mixWithOthers and
      // duckOthers keep it polite over whatever else is playing.
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          IosTextToSpeechAudioCategoryOptions.duckOthers,
        ],
        IosTextToSpeechAudioMode.voicePrompt,
      );
    }

    await _tts.setLanguage(_language);
    await _tts.setSpeechRate(_naturalRate);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
  }

  @override
  Future<void> speak(String text) async {
    await (_ready ??= _configure());
    // iOS queues utterances (AVSpeechSynthesizer.speak appends) while Android
    // flushes, so without this a second tap plays both back to back on iPhone
    // and only the second on Android.
    await _tts.stop();
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    // Nothing can be playing if the engine was never configured.
    if (_ready == null) return;
    await _tts.stop();
  }

  @override
  void dispose() {
    _onFinished = null;
    _tts.stop();
  }
}
