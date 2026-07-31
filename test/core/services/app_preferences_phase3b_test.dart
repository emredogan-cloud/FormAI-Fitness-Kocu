import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';

/// Roadmap Phase 3b · voice-coach mute + practice-rep persistence.
Future<AppPreferences> _prefs([Map<String, Object> seed = const {}]) async {
  SharedPreferences.setMockInitialValues(seed);
  final raw = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(raw)],
  );
  addTearDown(container.dispose);
  return container.read(appPreferencesProvider);
}

void main() {
  group('voiceCoachEnabled', () {
    test('defaults to ON — a silent coach on a fresh install reads as broken',
        () async {
      final prefs = await _prefs();
      expect(prefs.voiceCoachEnabled, isTrue);
    });

    test('turns off and back on, and survives a reread', () async {
      final prefs = await _prefs();

      await prefs.setVoiceCoachEnabled(false);
      expect(prefs.voiceCoachEnabled, isFalse);

      await prefs.setVoiceCoachEnabled(true);
      expect(prefs.voiceCoachEnabled, isTrue);
    });

    test('a stored false is honoured — the mute must outlive the session',
        () async {
      final prefs = await _prefs({'sixpack.voice_coach_enabled': false});
      expect(prefs.voiceCoachEnabled, isFalse);
    });
  });

  group('completedPracticeRep', () {
    test('defaults to false and latches once', () async {
      final prefs = await _prefs();
      expect(prefs.completedPracticeRep, isFalse);

      await prefs.markCompletedPracticeRep();
      expect(prefs.completedPracticeRep, isTrue);

      // Idempotent — the skip path and the completion path can both
      // reach it, and a second call must not toggle it back.
      await prefs.markCompletedPracticeRep();
      expect(prefs.completedPracticeRep, isTrue);
    });

    test('is independent of the camera-tutorial flag', () async {
      final prefs = await _prefs();

      await prefs.markCameraTutorialCompleted();
      // Replaying the setup guide must not force the movement drill
      // again, which is only true if these two flags are separate.
      expect(prefs.cameraTutorialCompleted, isTrue);
      expect(prefs.completedPracticeRep, isFalse);

      await prefs.markCompletedPracticeRep();
      expect(prefs.completedPracticeRep, isTrue);
    });

    test('an existing install that never saw the practice rep reads false',
        () async {
      // A user upgrading mid-programme has the tutorial flag but not the
      // practice one; they must not be treated as having done it.
      final prefs = await _prefs({'sixpack.camera_tutorial_completed': true});
      expect(prefs.cameraTutorialCompleted, isTrue);
      expect(prefs.completedPracticeRep, isFalse);
    });
  });

  group('seenInSessionTutorial', () {
    test('defaults false, latches, and is unrelated to the setup flags',
        () async {
      final prefs = await _prefs();
      expect(prefs.seenInSessionTutorial, isFalse);

      await prefs.markSeenInSessionTutorial();

      expect(prefs.seenInSessionTutorial, isTrue);
      expect(prefs.cameraTutorialCompleted, isFalse);
      expect(prefs.completedPracticeRep, isFalse);
    });
  });
}
