import 'package:flutter/services.dart'
    show AssetBundle, AssetManifest, rootBundle;

import '../../../core/utils/app_logger.dart';
import '../../../core/utils/string_case.dart';
import '../models/exercise_model.dart';

/// Phase 6 polish · which photograph sits behind a running exercise.
///
/// The redesigned workout screen is a full-bleed photograph with the set
/// counter over it, so every exercise needs one — and there are 138
/// exercises and no per-exercise photography. This resolves that in
/// three steps, each of which is allowed to fail:
///
///   1. **The exercise's own background**, if one has been bundled at
///      `photos/workout_backgrounds/<PascalCase>.webp`.
///   2. **Its category's photograph**, reusing the cinematic set already
///      shipping for the Antrenman dashboard modules. Every exercise
///      lands here today, so the screen looks finished before a single
///      new file exists.
///   3. Nothing, and the screen paints its gradient. Only reachable if
///      an asset declaration is deleted.
///
/// **Step 1 is deliberately not a list in this file.** It is a lookup
/// against the bundle's own asset manifest, so dropping
/// `WeightedSitUp.webp` into `photos/workout_backgrounds/` and building
/// is the entire procedure — no slug to remember, no code review, no
/// chance of a file that ships in the APK and is never drawn.
///
/// The neighbouring [ExerciseMediaRegistry] is the older pattern: a
/// hand-maintained `Set<String>` that has to be edited in lockstep with
/// the directory. Its doc comment already describes the two-step dance.
/// That registry is not touched here, but it is the same problem and
/// this is the shape of the answer.
///
/// See `WORKOUT_BACKGROUND_IMAGE_REQUESTS.md` for the 51 exercises
/// currently resolving to step 2 and the prompts to generate them.
class WorkoutBackgroundRegistry {
  const WorkoutBackgroundRegistry._();

  static const String backgroundDir = 'photos/workout_backgrounds/';

  /// Reused from the Antrenman dashboard modules — dark gym photography
  /// with neon rim light, which is the register the workout screen is
  /// designed in. One per [ExerciseCategory], so the map is total and
  /// [backgroundFor] can never return null for a real exercise.
  static const Map<ExerciseCategory, String> categoryFallback = {
    ExerciseCategory.core: 'photos/workouts/core_steel_abs.webp',
    ExerciseCategory.chest: 'photos/workouts/chest_activation_growth.webp',
    ExerciseCategory.legs: 'photos/workouts/legs_power_day.webp',
    ExerciseCategory.back: 'photos/workouts/back_v_taper.webp',
    ExerciseCategory.arms: 'photos/workouts/arms_steel.webp',
    ExerciseCategory.shoulders: 'photos/workouts/shoulders_giant.webp',
    ExerciseCategory.fullBody: 'photos/workouts/cardio_full_body_flow.webp',
  };

  static Set<String> _bundled = const {};
  static bool _loaded = false;

  /// True once [warmUp] has resolved. Before that, [backgroundFor]
  /// answers with the category photograph — a real image, so there is
  /// no empty frame to flash through.
  static bool get isWarm => _loaded;

  /// Reads the asset manifest once. Safe to call repeatedly; safe to
  /// never call, since every failure mode degrades to the category
  /// photograph rather than to a blank screen.
  static Future<void> warmUp({AssetBundle? bundle}) async {
    if (_loaded) return;
    try {
      final manifest =
          await AssetManifest.loadFromAssetBundle(bundle ?? rootBundle);
      _bundled = manifest
          .listAssets()
          .where((a) => a.startsWith(backgroundDir))
          .toSet();
      _loaded = true;
      AppLogger.info(
        'workout backgrounds: ${_bundled.length} bundled',
        category: 'workout',
      );
    } catch (e) {
      // A manifest that will not parse is not worth failing a workout
      // over. Leaving `_loaded` false means a later attempt can retry.
      AppLogger.warning(
        'workout background manifest unreadable — using category art',
        category: 'workout',
        data: {'error': e.toString()},
      );
    }
  }

  /// The asset path for [exercise]'s background. Never null: an unknown
  /// category is not representable, and the map covers every value.
  static String backgroundFor(Exercise exercise) =>
      ownBackgroundFor(exercise.id) ?? categoryFallback[exercise.category]!;

  /// The exercise's *own* background, or null when none is bundled.
  /// Split out from [backgroundFor] so the request document can be
  /// generated, and so a test can assert the gap without asserting the
  /// fallback.
  static String? ownBackgroundFor(String slug) {
    final path = '$backgroundDir${StringCase.snakeToPascal(slug)}.webp';
    return _bundled.contains(path) ? path : null;
  }

  /// Test seam. Production reads the manifest; tests state the contents
  /// directly rather than building a bundle.
  static void debugSeed(Set<String> assets) {
    _bundled = assets;
    _loaded = true;
  }

  static void debugReset() {
    _bundled = const {};
    _loaded = false;
  }
}
