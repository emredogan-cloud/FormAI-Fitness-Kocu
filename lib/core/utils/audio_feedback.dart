import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_tts/flutter_tts.dart';

import 'app_logger.dart';

/// Speech priority — used by [AudioFeedback.speak] to order pending
/// phrases and decide whether a new utterance can pre-empt the one
/// currently playing.
///
/// Higher index = higher priority. A new phrase whose priority strictly
/// exceeds the currently-playing phrase's priority will interrupt it;
/// otherwise it lands in the queue and waits.
///
/// Mapping (audit Tier-A R7):
///   • [warning]       — form / safety corrections. Must reach the user.
///   • [cue]           — mid-rep phase coaching (e.g. burpee step transition).
///   • [milestone]     — rep / set / session-level achievements + lifecycle
///                       announcements (intro, rest start, completion).
///   • [encouragement] — motivational beats during active work.
///   • [ambient]       — rest-phase and mid-set heartbeats. Lowest priority,
///                       always yields to anything more urgent.
enum SpeechPriority {
  ambient,
  encouragement,
  milestone,
  cue,
  warning,
}

class _PendingSpeech {
  _PendingSpeech(this.phrase, this.priority, this.queuedAt);
  final String phrase;
  final SpeechPriority priority;
  final DateTime queuedAt;
}

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
  bool _initInFlight = false;
  String? _activeLanguage;

  // Tier-A audit R7 · serialised speech pipeline. Previously every
  // `speak()` called `_tts.stop()` first, which meant a form warning
  // could cut off a milestone (and vice versa) — the user heard half
  // sentences. We now keep one playing utterance + a small priority
  // queue. Pre-emption is allowed ONLY when a higher-priority phrase
  // arrives mid-utterance, so a `warning` can still interrupt an
  // `ambient` heartbeat but a `milestone` can't truncate a `warning`.
  bool _isSpeaking = false;
  SpeechPriority? _currentPriority;
  final List<_PendingSpeech> _queue = <_PendingSpeech>[];
  static const int _maxQueueDepth = 3;

  /// Per-phrase deduplication ledger. Keyed by exact phrase string so a
  /// rotating coach (which speaks different lines on each tick) is not
  /// affected, but a stuck warning ("Kalçanı düz tut!") doesn't repeat
  /// inside the cooldown window.
  final Map<String, DateTime> _phraseLastSpoken = <String, DateTime>{};

  bool _muted = false;

  /// Roadmap Phase 3b · the voice coach's mute switch.
  ///
  /// Gating here rather than at each call site is deliberate: the coach
  /// speaks from a dozen places (rep milestones, pacing, form warnings,
  /// rest checkpoints, tutorial guidance) and a mute that each of them
  /// had to remember to honour is a mute that leaks. One gate in
  /// [speak] cannot leak.
  bool get muted => _muted;

  set muted(bool value) {
    if (_muted == value) return;
    _muted = value;
    if (value) {
      // Silence must be immediate. Leaving a queued burst to drain after
      // the user hits mute is precisely the failure the toggle exists to
      // prevent — they pressed it because someone walked in.
      _queue.clear();
      unawaited(_stopQuietly());
    }
  }

  Future<void> _stopQuietly() async {
    try {
      await _tts.stop();
    } catch (e, st) {
      AppLogger.warning(
        'AudioFeedback: stop() on mute failed',
        category: 'tts',
        data: {'error': e.toString(), 'stack': st.toString()},
      );
    }
  }

  Future<void> init() async {
    if (_ready) return;
    if (_initInFlight) {
      // Coalesce concurrent init() callers — they all wait on the same
      // platform handshake and only the first one should drive it.
      while (_initInFlight && !_ready) {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      return;
    }
    _initInFlight = true;
    try {
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
        // Critical for the queue: `awaitSpeakCompletion(true)` makes
        // _tts.speak()'s Future resolve only when speech actually ends.
        // Without this the queue would race ahead and back-to-back
        // utterances would overlap.
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
    } finally {
      _initInFlight = false;
    }
  }

  /// Speaks [phrase] at the given [priority]. Returns immediately if
  /// the same phrase fired within [cooldown]. If something is already
  /// playing, the new phrase either pre-empts it (when priority is
  /// strictly higher) or enters the queue (otherwise). The queue is
  /// capped at [_maxQueueDepth] and same-phrase duplicates are
  /// dropped on enqueue.
  ///
  /// All call sites are fire-and-forget — the returned Future resolves
  /// once the phrase has either started speaking, been queued, or been
  /// dropped by dedupe. It does NOT wait for speech to finish.
  Future<void> speak(
    String phrase, {
    SpeechPriority priority = SpeechPriority.milestone,
    Duration cooldown = const Duration(seconds: 3),
  }) async {
    if (phrase.isEmpty) return;
    // Checked before init() so a muted user never pays the TTS engine
    // handshake — and, more importantly, so muting can never be
    // defeated by a call site that speaks before the engine is ready.
    if (_muted) return;
    if (!_ready) await init();

    final now = DateTime.now();

    // Phrase-level dedupe — global, across priorities. Keeps a stuck
    // analyzer warning from re-queueing every analyzer frame.
    final lastSpoken = _phraseLastSpoken[phrase];
    if (lastSpoken != null && now.difference(lastSpoken) < cooldown) {
      return;
    }

    if (_isSpeaking) {
      final current = _currentPriority!;
      if (priority.index > current.index) {
        // Pre-empt: stop the current utterance, push this phrase to
        // the front of the queue. The currently-awaiting `speak` call
        // will return from `_tts.stop()`, hit its `finally`, and
        // drain the queue — which will now play this phrase first.
        try {
          await _tts.stop();
        } catch (e, st) {
          AppLogger.warning(
            'AudioFeedback: stop() during pre-empt failed',
            category: 'tts',
            data: {'error': e.toString(), 'stack': st.toString()},
          );
        }
        _enqueue(_PendingSpeech(phrase, priority, now), atFront: true);
        return;
      }
      // Lower-or-equal priority: queue it.
      _enqueue(_PendingSpeech(phrase, priority, now));
      return;
    }

    // Idle path — speak immediately.
    await _speakNow(phrase, priority);
  }

  void _enqueue(_PendingSpeech entry, {bool atFront = false}) {
    // Drop exact-phrase duplicates already pending.
    if (_queue.any((q) => q.phrase == entry.phrase)) return;
    if (atFront) {
      _queue.insert(0, entry);
    } else {
      _queue.add(entry);
      // Highest-priority at the front; ties resolved by FIFO insertion order.
      _queue.sort((a, b) => b.priority.index.compareTo(a.priority.index));
    }
    // Soft cap: drop lowest-priority tail entries past the cap so a
    // burst of ambient cues can't crowd out an incoming warning.
    while (_queue.length > _maxQueueDepth) {
      _queue.removeLast();
    }
  }

  Future<void> _speakNow(String phrase, SpeechPriority priority) async {
    _isSpeaking = true;
    _currentPriority = priority;
    _phraseLastSpoken[phrase] = DateTime.now();
    try {
      await _tts.setVolume(1.0);
      await _tts.speak(phrase);
    } catch (e, st) {
      AppLogger.error(
        'AudioFeedback: speak failed (lang=$_activeLanguage)',
        e,
        stackTrace: st,
        category: 'tts',
        data: {'phrase': phrase, 'priority': priority.name},
      );
    } finally {
      _isSpeaking = false;
      _currentPriority = null;
      // Drain the next-highest-priority queued phrase. Fire-and-forget
      // so the speak() caller above doesn't pile up await chains.
      if (_queue.isNotEmpty) {
        final next = _queue.removeAt(0);
        // Use zero cooldown — dedupe was already enforced at enqueue.
        unawaited(speak(
          next.phrase,
          priority: next.priority,
          cooldown: Duration.zero,
        ));
      }
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
      // Bypass the queue for the smoke test — we want an unconditional
      // utterance regardless of pending coaching state.
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
    _queue.clear();
    _isSpeaking = false;
    _currentPriority = null;
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
