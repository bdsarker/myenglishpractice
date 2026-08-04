import 'package:flutter/foundation.dart';
import 'package:myenglishpractice/core/services/speech_service.dart';

/// A [Speaker] that records an ordered log instead of making noise.
///
/// Ordered, because which call came first is the interesting part of the
/// interrupt behaviour — not just that both happened.
class FakeSpeaker implements Speaker {
  final List<String> log = [];
  VoidCallback? _onFinished;

  /// Pretend the engine reached the end of an utterance on its own.
  void finish() => _onFinished?.call();

  @override
  Future<void> speak(String text) async => log.add('speak:$text');

  @override
  Future<void> stop() async => log.add('stop');

  @override
  void onFinished(VoidCallback callback) => _onFinished = callback;

  @override
  void dispose() => log.add('dispose');
}
