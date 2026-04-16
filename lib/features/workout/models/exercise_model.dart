enum ExerciseType { repBased, timeBased }

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.type,
    this.targetReps,
    this.targetDurationInSeconds,
  });

  final String id;
  final String name;
  final ExerciseType type;
  final int? targetReps;
  final int? targetDurationInSeconds;

  bool get isRepBased => type == ExerciseType.repBased;
  bool get isTimeBased => type == ExerciseType.timeBased;

  @override
  bool operator ==(Object other) =>
      other is Exercise &&
      other.id == id &&
      other.name == name &&
      other.type == type &&
      other.targetReps == targetReps &&
      other.targetDurationInSeconds == targetDurationInSeconds;

  @override
  int get hashCode =>
      Object.hash(id, name, type, targetReps, targetDurationInSeconds);
}
