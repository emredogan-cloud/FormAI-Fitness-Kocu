enum ExerciseType { repBased, timeBased }

enum ExerciseCategory { core, chest, legs, back, arms, shoulders, fullBody }

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.type,
    required this.difficulty,
    required this.targetMuscle,
    required this.isCardio,
    this.targetReps,
    this.targetDurationInSeconds,
    this.videoUrl,
    this.sets = 1,
    this.restDurationInSeconds = 30,
    this.category = ExerciseCategory.core,
    this.description = '',
    this.shortTip = '',
  });

  final String id;
  final String name;
  final ExerciseType type;
  final int? targetReps;
  final int? targetDurationInSeconds;
  final String? videoUrl;
  final int sets;
  final int restDurationInSeconds;
  final ExerciseCategory category;

  /// Long-form Turkish instructions shown on the "HAZIRLAN!" overlay and
  /// spoken by the voice coach at exercise start. Empty by default so
  /// pre-Phase-26 callers compile; populated for every shipped exercise.
  final String description;

  /// 4-6 word tactical reminder rendered as a translucent pill above the
  /// camera control panel for the duration of the active set.
  final String shortTip;

  /// Coarse difficulty bucket used by the personalised-plan generator.
  /// Expected values: `beginner`, `intermediate`, `advanced`. Kept as a
  /// plain string (not an enum) so new tiers can be added without forcing
  /// a schema migration on every serialised exercise.
  final String difficulty;

  /// Which body region the movement primarily loads — consumed by the
  /// plan generator to balance a routine. Expected values: `core`,
  /// `upper_body`, `lower_body`, `full_body`, `cardio`.
  final String targetMuscle;

  /// True when the movement is primarily a conditioning / elevated-HR
  /// exercise rather than a strength movement. The generator uses this to
  /// seed HIIT blocks and to cap cardio density inside strength plans.
  final bool isCardio;

  bool get isRepBased => type == ExerciseType.repBased;
  bool get isTimeBased => type == ExerciseType.timeBased;

  Exercise copyWith({
    String? id,
    String? name,
    ExerciseType? type,
    int? targetReps,
    int? targetDurationInSeconds,
    String? videoUrl,
    int? sets,
    int? restDurationInSeconds,
    ExerciseCategory? category,
    String? description,
    String? shortTip,
    String? difficulty,
    String? targetMuscle,
    bool? isCardio,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      targetReps: targetReps ?? this.targetReps,
      targetDurationInSeconds:
          targetDurationInSeconds ?? this.targetDurationInSeconds,
      videoUrl: videoUrl ?? this.videoUrl,
      sets: sets ?? this.sets,
      restDurationInSeconds:
          restDurationInSeconds ?? this.restDurationInSeconds,
      category: category ?? this.category,
      description: description ?? this.description,
      shortTip: shortTip ?? this.shortTip,
      difficulty: difficulty ?? this.difficulty,
      targetMuscle: targetMuscle ?? this.targetMuscle,
      isCardio: isCardio ?? this.isCardio,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Exercise &&
      other.id == id &&
      other.name == name &&
      other.type == type &&
      other.targetReps == targetReps &&
      other.targetDurationInSeconds == targetDurationInSeconds &&
      other.videoUrl == videoUrl &&
      other.sets == sets &&
      other.restDurationInSeconds == restDurationInSeconds &&
      other.category == category &&
      other.description == description &&
      other.shortTip == shortTip &&
      other.difficulty == difficulty &&
      other.targetMuscle == targetMuscle &&
      other.isCardio == isCardio;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        type,
        targetReps,
        targetDurationInSeconds,
        videoUrl,
        sets,
        restDurationInSeconds,
        category,
        description,
        shortTip,
        difficulty,
        targetMuscle,
        isCardio,
      );
}
