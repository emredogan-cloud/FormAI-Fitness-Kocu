enum ExerciseType { repBased, timeBased }

enum ExerciseCategory { core, chest, legs, back, arms, shoulders, fullBody }

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.type,
    this.targetReps,
    this.targetDurationInSeconds,
    this.videoAsset,
    this.sets = 1,
    this.restDurationInSeconds = 30,
    this.category = ExerciseCategory.core,
    this.startCommand,
  });

  final String id;
  final String name;
  final ExerciseType type;
  final int? targetReps;
  final int? targetDurationInSeconds;
  final String? videoAsset;
  final int sets;
  final int restDurationInSeconds;
  final ExerciseCategory category;

  /// Optional full-phrase override spoken at the start of this exercise.
  /// When null, the lifecycle announcer falls back to the generic
  /// "Sıradaki hareket: NAME. Başlayın!" pattern.
  final String? startCommand;

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
      other.videoAsset == videoAsset &&
      other.sets == sets &&
      other.restDurationInSeconds == restDurationInSeconds &&
      other.category == category &&
      other.startCommand == startCommand;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        type,
        targetReps,
        targetDurationInSeconds,
        videoAsset,
        sets,
        restDurationInSeconds,
        category,
        startCommand,
      );
}
