import 'exercise_model.dart';

class WorkoutDay {
  const WorkoutDay({
    required this.dayNumber,
    required this.exercises,
    this.isCompleted = false,
  });

  final int dayNumber;
  final List<Exercise> exercises;
  final bool isCompleted;

  WorkoutDay copyWith({
    int? dayNumber,
    List<Exercise>? exercises,
    bool? isCompleted,
  }) {
    return WorkoutDay(
      dayNumber: dayNumber ?? this.dayNumber,
      exercises: exercises ?? this.exercises,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WorkoutDay &&
      other.dayNumber == dayNumber &&
      other.isCompleted == isCompleted &&
      _listEquals(other.exercises, exercises);

  @override
  int get hashCode =>
      Object.hash(dayNumber, isCompleted, Object.hashAll(exercises));

  static bool _listEquals(List<Exercise> a, List<Exercise> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
