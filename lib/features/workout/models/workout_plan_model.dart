import '../../../core/utils/app_copy.dart';
import '../domain/workout_plan_titles.dart';
import 'exercise_model.dart';

/// A discoverable, region-tagged collection of exercises (e.g. "Çelik Gibi
/// Karın", "Evde Göğüs Pompası"). Distinct from [WorkoutDay], which is one
/// slot in the linear 30-day program — plans are thematic and selectable
/// from the dashboard's regional filter strip.
class WorkoutPlan {
  const WorkoutPlan({
    required this.id,
    required this.category,
    required this.levelToken,
    required this.durationMinutes,
    required this.exercises,
    this.image,
    this.premiumExercises = const [],
  });

  final String id;
  final ExerciseCategory category;

  /// Difficulty as a token. Was a Turkish label string, which is how an
  /// English reader ended up seeing "Orta düzey" on every plan card.
  final WorkoutLevel levelToken;
  final int durationMinutes;
  final List<Exercise> exercises;

  /// Either an http(s) URL or a bundled asset path. The dashboard's
  /// _resolveImage helper picks the right Image constructor at render time.
  final String? image;

  /// Phase 98 · advanced "Premium" tier curated for the same program.
  /// Empty for plans with no premium upgrade (regional bodyweight cards
  /// stay single-button); populated for the 7 equipment programs so the
  /// plan-detail screen can render a half-width "Premium Seviye" launcher
  /// alongside the existing "Lite Seviye" button. The premium list is a
  /// sibling — not a superset — of `exercises`: the standard button still
  /// launches `exercises` unchanged, the premium button launches these.
  final List<Exercise> premiumExercises;

  /// Card title in the reader's language.
  ///
  /// Resolved on read rather than stored, so switching language applies
  /// to the catalogue and not only to the chrome around it — the failure
  /// Phase 7 hit with recipes, where every ARB string flipped instantly
  /// and the content stayed in the old language until restart.
  ///
  /// [AppCopy] rather than a `BuildContext` because a plan is also
  /// composed into notifications, which have no tree. Falls back to the
  /// id, which is visible enough to notice and harmless enough to ship:
  /// every id in the catalogue has a title, and a test proves it.
  String get title => workoutPlanTitle(AppCopy.strings, id) ?? id;

  String get level => levelToken.label(AppCopy.strings);

  String get summary =>
      AppCopy.strings.minutesLevelLine(durationMinutes, level);

  bool get isComingSoon => exercises.isEmpty;

  /// True when the plan ships an advanced tier, i.e. when `premiumExercises`
  /// has at least one resolved entry. The plan-detail screen reads this to
  /// decide between the legacy single-CTA layout (false) and the Phase 98
  /// two-button layout (true).
  bool get hasPremiumTier => premiumExercises.isNotEmpty;
}
