import 'exercise_model.dart';

/// A discoverable, region-tagged collection of exercises (e.g. "Çelik Gibi
/// Karın", "Evde Göğüs Pompası"). Distinct from [WorkoutDay], which is one
/// slot in the linear 30-day program — plans are thematic and selectable
/// from the dashboard's regional filter strip.
class WorkoutPlan {
  const WorkoutPlan({
    required this.id,
    required this.title,
    required this.category,
    required this.level,
    required this.durationMinutes,
    required this.exercises,
    this.image,
    this.premiumExercises = const [],
  });

  final String id;
  final String title;
  final ExerciseCategory category;

  /// Human-readable difficulty label: 'Başlangıç' / 'Orta düzey' / 'İleri'.
  final String level;
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

  String get summary => '$level · $durationMinutes Dk';

  bool get isComingSoon => exercises.isEmpty;

  /// True when the plan ships an advanced tier, i.e. when `premiumExercises`
  /// has at least one resolved entry. The plan-detail screen reads this to
  /// decide between the legacy single-CTA layout (false) and the Phase 98
  /// two-button layout (true).
  bool get hasPremiumTier => premiumExercises.isNotEmpty;
}
