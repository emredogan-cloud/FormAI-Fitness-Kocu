import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/features/workout/domain/workout_mode.dart';

/// Roadmap Phase 3 (C21) · workout mode + tutorial persistence.
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
  group('WorkoutMode tokens', () {
    test('tokens are stable — they are persisted and sent to analytics', () {
      expect(WorkoutMode.camera.token, 'camera');
      expect(WorkoutMode.manual.token, 'manual');
    });

    test('tokens are unique', () {
      final tokens = WorkoutMode.values.map((m) => m.token).toList();
      expect(tokens.toSet().length, tokens.length);
    });

    test('fromToken round-trips every value', () {
      for (final mode in WorkoutMode.values) {
        expect(WorkoutMode.fromToken(mode.token), mode);
      }
    });

    test(
        'an unknown or null token defaults to camera — a user with no '
        'stored preference has not opted out of anything', () {
      expect(WorkoutMode.fromToken(null), WorkoutMode.camera);
      expect(WorkoutMode.fromToken(''), WorkoutMode.camera);
      expect(WorkoutMode.fromToken('nonsense'), WorkoutMode.camera);
    });
  });

  group('persistence', () {
    test('a fresh install defaults to camera mode', () async {
      final prefs = await _prefs();
      expect(prefs.preferredWorkoutMode, WorkoutMode.camera);
    });

    test('the chosen mode round-trips', () async {
      final prefs = await _prefs();
      await prefs.setPreferredWorkoutMode(WorkoutMode.manual);
      expect(prefs.preferredWorkoutMode, WorkoutMode.manual);
      await prefs.setPreferredWorkoutMode(WorkoutMode.camera);
      expect(prefs.preferredWorkoutMode, WorkoutMode.camera);
    });

    test('a corrupt stored value degrades to camera rather than throwing',
        () async {
      final prefs = await _prefs({'sixpack.workout_mode': 'garbage'});
      expect(prefs.preferredWorkoutMode, WorkoutMode.camera);
    });

    test('the tutorial flag defaults false and flips once', () async {
      final prefs = await _prefs();
      expect(prefs.cameraTutorialCompleted, isFalse);
      await prefs.markCameraTutorialCompleted();
      expect(prefs.cameraTutorialCompleted, isTrue);
    });

    test('the in-session tutorial flag defaults false and flips once',
        () async {
      final prefs = await _prefs();
      expect(prefs.seenInSessionTutorial, isFalse);
      await prefs.markSeenInSessionTutorial();
      expect(prefs.seenInSessionTutorial, isTrue);
    });

    test(
        'completing the tutorial and choosing a mode are independent — '
        'a manual-mode user has still completed the tutorial', () async {
      final prefs = await _prefs();
      await prefs.markCameraTutorialCompleted();
      await prefs.setPreferredWorkoutMode(WorkoutMode.manual);
      expect(prefs.cameraTutorialCompleted, isTrue);
      expect(prefs.preferredWorkoutMode, WorkoutMode.manual);
    });
  });
}
