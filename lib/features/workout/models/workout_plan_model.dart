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

  String get summary => '$level · $durationMinutes Dk';

  bool get isComingSoon => exercises.isEmpty;
}
