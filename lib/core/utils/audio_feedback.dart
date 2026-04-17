import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class AudioFeedback {
  AudioFeedback({
    this.language = 'tr-TR',
    this.fallbackLanguage = 'en-US',
    this.speechRate = 0.5,
    this.pitch = 1.0,
  });

  final String language;
  final String fallbackLanguage;
  final double speechRate;
  final double pitch;

  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  String? _activeLanguage;
  String? _lastPhrase;
  DateTime? _lastSpokenAt;

  Future<void> init() async {
    if (_ready) return;

    // iOS: route TTS through the playback category so it isn't silenced by
    // the ringer switch and can mix with background media.
    if (Platform.isIOS) {
      try {
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          ],
          IosTextToSpeechAudioMode.voicePrompt,
        );
      } catch (e, st) {
        debugPrint('AudioFeedback: iOS audio category failed: $e\n$st');
      }
    }

    // Android (esp. Xiaomi/MIUI): many devices ship without Turkish voice
    // data, so probe the available set and fall back to en-US rather than
    // going silent.
    String chosen = language;
    try {
      final raw = await _tts.getLanguages;
      final available = (raw is List)
          ? raw.map((e) => e.toString().toLowerCase()).toList()
          : const <String>[];
      debugPrint('AudioFeedback: ${available.length} TTS languages available');
      if (!available.contains(language.toLowerCase())) {
        debugPrint(
          '⚠️ AudioFeedback: "$language" is NOT installed on this device. '
          'Falling back to "$fallbackLanguage". '
          'Install Turkish TTS via Settings → Language & input → '
          'Text-to-speech output for native playback.',
        );
        chosen = fallbackLanguage;
      }
    } catch (e, st) {
      debugPrint('AudioFeedback: getLanguages failed: $e\n$st');
    }

    try {
      await _tts.setLanguage(chosen);
      _activeLanguage = chosen;
    } catch (e, st) {
      debugPrint('AudioFeedback: setLanguage("$chosen") failed: $e\n$st');
      if (chosen != fallbackLanguage) {
        try {
          await _tts.setLanguage(fallbackLanguage);
          _activeLanguage = fallbackLanguage;
        } catch (e2, st2) {
          debugPrint(
            'AudioFeedback: fallback setLanguage("$fallbackLanguage") '
            'failed: $e2\n$st2',
          );
        }
      }
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
      debugPrint(
        'AudioFeedback: speak("$phrase", lang=$_activeLanguage) '
        'failed: $e\n$st',
      );
    }
  }

  /// Manual smoke test for the TTS pipeline — tap-to-invoke from dev UI.
  /// Forces the engine open, re-applies volume, and speaks a fixed phrase.
  Future<void> testAudio() async {
    debugPrint('🔊 TTS DEBUG: Starting audio test...');
    try {
      if (!_ready) {
        debugPrint('🔊 TTS DEBUG: engine not ready, running init() first.');
        await init();
      }
      debugPrint('🔊 TTS DEBUG: active language = $_activeLanguage');
      await _tts.stop();
      await _tts.setVolume(1.0);
      final result = await _tts.speak('Ses testi başarılı, sistem çalışıyor.');
      debugPrint('🔊 TTS DEBUG: speak() returned $result');
    } catch (e, st) {
      debugPrint('🔊 TTS ERROR: testAudio failed: $e\n$st');
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
