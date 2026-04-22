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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'targetReps': targetReps,
        'targetDurationInSeconds': targetDurationInSeconds,
        'videoUrl': videoUrl,
        'sets': sets,
        'restDurationInSeconds': restDurationInSeconds,
        'category': category.name,
        'description': description,
        'shortTip': shortTip,
        'difficulty': difficulty,
        'targetMuscle': targetMuscle,
        'isCardio': isCardio,
      };

  /// Throws [FormatException] if a required primitive is missing or the
  /// enum name is unknown. Callers (the plan cache) catch the throw and
  /// regenerate from scratch rather than surface a half-parsed plan.
  factory Exercise.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'];
    final categoryName = json['category'];
    return Exercise(
      id: json['id'] as String,
      name: json['name'] as String,
      type: ExerciseType.values.firstWhere(
        (v) => v.name == typeName,
        orElse: () => throw FormatException('Unknown ExerciseType: $typeName'),
      ),
      targetReps: json['targetReps'] as int?,
      targetDurationInSeconds: json['targetDurationInSeconds'] as int?,
      videoUrl: json['videoUrl'] as String?,
      sets: (json['sets'] as int?) ?? 1,
      restDurationInSeconds: (json['restDurationInSeconds'] as int?) ?? 30,
      category: ExerciseCategory.values.firstWhere(
        (v) => v.name == categoryName,
        orElse: () => ExerciseCategory.core,
      ),
      description: (json['description'] as String?) ?? '',
      shortTip: (json['shortTip'] as String?) ?? '',
      difficulty: json['difficulty'] as String,
      targetMuscle: json['targetMuscle'] as String,
      isCardio: json['isCardio'] as bool,
    );
  }

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
