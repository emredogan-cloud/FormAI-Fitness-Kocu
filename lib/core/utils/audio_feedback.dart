import 'dart:io' show Platform;

import 'package:flutter_tts/flutter_tts.dart';

import 'app_logger.dart';

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
        AppLogger.error(
          'AudioFeedback: iOS audio category failed',
          e,
          stackTrace: st,
          category: 'tts',
        );
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
      AppLogger.info(
        'AudioFeedback: ${available.length} TTS languages available',
        category: 'tts',
      );
      if (!available.contains(language.toLowerCase())) {
        AppLogger.warning(
          'AudioFeedback: "$language" is NOT installed on this device. '
          'Falling back to "$fallbackLanguage".',
          category: 'tts',
        );
        chosen = fallbackLanguage;
      }
    } catch (e, st) {
      AppLogger.error(
        'AudioFeedback: getLanguages failed',
        e,
        stackTrace: st,
        category: 'tts',
      );
    }

    try {
      await _tts.setLanguage(chosen);
      _activeLanguage = chosen;
    } catch (e, st) {
      AppLogger.error(
        'AudioFeedback: setLanguage("$chosen") failed',
        e,
        stackTrace: st,
        category: 'tts',
      );
      if (chosen != fallbackLanguage) {
        try {
          await _tts.setLanguage(fallbackLanguage);
          _activeLanguage = fallbackLanguage;
        } catch (e2, st2) {
          AppLogger.error(
            'AudioFeedback: fallback setLanguage("$fallbackLanguage") failed',
            e2,
            stackTrace: st2,
            category: 'tts',
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
      AppLogger.error(
        'AudioFeedback: init tuning failed',
        e,
        stackTrace: st,
        category: 'tts',
      );
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
      AppLogger.error(
        'AudioFeedback: speak failed (lang=$_activeLanguage)',
        e,
        stackTrace: st,
        category: 'tts',
        data: {'phrase': phrase},
      );
    }
  }

  /// Manual smoke test for the TTS pipeline — tap-to-invoke from dev UI.
  /// Forces the engine open, re-applies volume, and speaks a fixed phrase.
  Future<void> testAudio() async {
    AppLogger.info('TTS smoke test: start', category: 'tts');
    try {
      if (!_ready) {
        AppLogger.info(
          'TTS smoke test: engine not ready, running init()',
          category: 'tts',
        );
        await init();
      }
      AppLogger.info(
        'TTS smoke test: active language = $_activeLanguage',
        category: 'tts',
      );
      await _tts.stop();
      await _tts.setVolume(1.0);
      final result = await _tts.speak('Ses testi başarılı, sistem çalışıyor.');
      AppLogger.info(
        'TTS smoke test: speak() returned $result',
        category: 'tts',
      );
    } catch (e, st) {
      AppLogger.error(
        'TTS smoke test failed',
        e,
        stackTrace: st,
        category: 'tts',
      );
    }
  }

  Future<void> dispose() async {
    try {
      await _tts.stop();
    } catch (e, st) {
      AppLogger.warning(
        'AudioFeedback: stop on dispose failed',
        category: 'tts',
        data: {'error': e.toString(), 'stack': st.toString()},
      );
    }
  }
}
