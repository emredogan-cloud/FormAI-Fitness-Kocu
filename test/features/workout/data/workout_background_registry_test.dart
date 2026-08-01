import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/workout/data/workout_background_registry.dart';
import 'package:sixpack_ai/features/workout/models/exercise_model.dart';

Exercise _exercise({
  String id = 'weighted_sit_up',
  ExerciseCategory category = ExerciseCategory.core,
}) {
  return Exercise(
    id: id,
    name: 'Ağırlıklı Sit-up',
    type: ExerciseType.repBased,
    difficulty: 'intermediate',
    targetMuscle: 'core',
    isCardio: false,
    category: category,
  );
}

void main() {
  setUp(WorkoutBackgroundRegistry.debugReset);
  tearDown(WorkoutBackgroundRegistry.debugReset);

  test('an exercise with no background of its own gets its category art', () {
    // This is the state the app ships in: 51 of 138 exercises have no
    // photograph. None of them may render an empty frame.
    for (final category in ExerciseCategory.values) {
      final path = WorkoutBackgroundRegistry.backgroundFor(
          _exercise(category: category));
      expect(path, startsWith('photos/workouts/'));
      expect(path, endsWith('.webp'));
    }
  });

  test(
      'every category has art — the map is total, so the lookup cannot '
      'return null', () {
    expect(
      WorkoutBackgroundRegistry.categoryFallback.keys.toSet(),
      ExerciseCategory.values.toSet(),
    );
  });

  test('dropping a file in is the whole procedure — no list to edit', () {
    // The contract the founder was given: put WeightedSitUp.webp in
    // photos/workout_backgrounds/ and it is used. If this ever needs a
    // slug added somewhere, that promise has been broken.
    expect(
        WorkoutBackgroundRegistry.ownBackgroundFor('weighted_sit_up'), isNull);

    WorkoutBackgroundRegistry.debugSeed({
      'photos/workout_backgrounds/WeightedSitUp.webp',
    });

    expect(
      WorkoutBackgroundRegistry.backgroundFor(_exercise()),
      'photos/workout_backgrounds/WeightedSitUp.webp',
    );
    // A neighbouring exercise is unaffected and still gets category art.
    expect(
      WorkoutBackgroundRegistry.backgroundFor(_exercise(id: 'dead_bug')),
      startsWith('photos/workouts/'),
    );
  });

  test(
      'the slug is snake_case and the file is PascalCase, as everywhere '
      'else in this app', () {
    WorkoutBackgroundRegistry.debugSeed({
      'photos/workout_backgrounds/BulgarianSplitSquat.webp',
    });
    expect(
      WorkoutBackgroundRegistry.ownBackgroundFor('bulgarian_split_squat'),
      'photos/workout_backgrounds/BulgarianSplitSquat.webp',
    );
    // Not the snake_case name, and not a near miss.
    expect(
      WorkoutBackgroundRegistry.ownBackgroundFor('bulgarian_split_squats'),
      isNull,
    );
  });

  testWidgets(
      'an unreadable manifest degrades to category art rather than '
      'failing the workout', (tester) async {
    // A workout in progress is the worst possible moment to throw.
    await WorkoutBackgroundRegistry.warmUp(bundle: _BrokenBundle());
    expect(WorkoutBackgroundRegistry.isWarm, isFalse);
    expect(
      WorkoutBackgroundRegistry.backgroundFor(_exercise()),
      startsWith('photos/workouts/'),
    );
  });

  testWidgets(
      'the real bundle declares the directory, so a dropped file '
      'is actually shipped', (tester) async {
    // pubspec must declare photos/workout_backgrounds/ or a file placed
    // there never reaches the APK and the registry can never see it.
    // The directory holds a README today; its presence in the manifest is
    // what proves the declaration exists.
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    expect(
      manifest
          .listAssets()
          .where((a) => a.startsWith(WorkoutBackgroundRegistry.backgroundDir)),
      isNotEmpty,
      reason: 'pubspec.yaml no longer declares '
          '${WorkoutBackgroundRegistry.backgroundDir}',
    );
  });
}

class _BrokenBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => throw StateError('no bundle');
}
