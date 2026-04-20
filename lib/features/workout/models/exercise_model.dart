enum ExerciseType { repBased, timeBased }

enum ExerciseCategory { core, chest, legs, back, arms, shoulders, fullBody }

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.type,
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

  bool get isRepBased => type == ExerciseType.repBased;
  bool get isTimeBased => type == ExerciseType.timeBased;

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
      other.shortTip == shortTip;

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
      );
}
