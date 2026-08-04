import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/speech_service.dart';

/// One engine for the whole app. Two [TtsSpeaker]s would each hold their own
/// iOS audio session and talk over each other.
final speakerProvider = Provider<Speaker>((ref) {
  final speaker = TtsSpeaker();
  ref.onDispose(speaker.dispose);
  return speaker;
});

/// The text currently being spoken, or null when silent.
///
/// Keyed on the text itself rather than an id: the word and every sentence are
/// already distinct strings, so there is nothing extra to plumb through.
class SpeechNotifier extends StateNotifier<String?> {
  final Speaker _speaker;

  SpeechNotifier(this._speaker) : super(null) {
    _speaker.onFinished(() {
      if (mounted) state = null;
    });
  }

  /// Play [text], or stop if it is already the one playing.
  Future<void> toggle(String text) async {
    if (state == text) return stop();

    // Set before awaiting so the button flips to its stop icon on the same
    // frame as the tap, rather than after the engine spins up.
    state = text;
    await _speaker.speak(text);
  }

  Future<void> stop() async {
    state = null;
    await _speaker.stop();
  }
}

final speechProvider = StateNotifierProvider<SpeechNotifier, String?>(
  (ref) => SpeechNotifier(ref.watch(speakerProvider)),
);
