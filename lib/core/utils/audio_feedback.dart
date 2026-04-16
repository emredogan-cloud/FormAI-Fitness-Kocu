import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class AudioFeedback {
  AudioFeedback({
    this.language = 'tr-TR',
    this.speechRate = 0.5,
    this.pitch = 1.0,
  });

  final String language;
  final double speechRate;
  final double pitch;

  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  String? _lastPhrase;
  DateTime? _lastSpokenAt;

  Future<void> init() async {
    if (_ready) return;
    try {
      await _tts.setLanguage(language);
    } catch (e, st) {
      debugPrint('AudioFeedback: setLanguage("$language") failed: $e\n$st');
      // Don't abort init — TTS engine will fall back to the device default.
    }
    try {
      await _tts.setSpeechRate(speechRate);
      await _tts.setPitch(pitch);
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(true);
    } catch (e, st) {
      debugPrint('AudioFeedback: init tuning failed: $e\n$st');
    }
    _ready = true;
  }

  /// Speaks [phrase] unless the same phrase was spoken within [cooldown].
  Future<void> speak(
    String phrase, {
    Duration cooldown = const Duration(seconds: 3),
  }) async {
    if (!_ready) await init();
    final now = DateTime.now();
    final lastAt = _lastSpokenAt;
    if (_lastPhrase == phrase &&
        lastAt != null &&
        now.difference(lastAt) < cooldown) {
      return;
    }
    _lastPhrase = phrase;
    _lastSpokenAt = now;
    try {
      await _tts.stop();
      await _tts.setVolume(1.0);
      await _tts.speak(phrase);
    } catch (e, st) {
      debugPrint('AudioFeedback: speak("$phrase") failed: $e\n$st');
    }
  }

  Future<void> dispose() async {
    try {
      await _tts.stop();
    } catch (e, st) {
      debugPrint('AudioFeedback: stop on dispose failed: $e\n$st');
    }
  }
}
