import 'exercise_model.dart';

class WorkoutDay {
  const WorkoutDay({
    required this.dayNumber,
    required this.exercises,
    this.isCompleted = false,
    this.title = '',
  });

  final int dayNumber;
  final List<Exercise> exercises;
  final bool isCompleted;

  /// Display label for the day. Empty for legacy days that have no custom
  /// title; set to "Dinlenme Günü" by the generator for rest days and
  /// optionally to "Gün N" for active days.
  final String title;

  bool get isRestDay => exercises.isEmpty;

  Map<String, dynamic> toJson() => {
        'dayNumber': dayNumber,
        'exercises': exercises.map((e) => e.toJson()).toList(growable: false),
        'isCompleted': isCompleted,
        'title': title,
      };

  /// Throws [FormatException] if the `exercises` list is malformed or any
  /// nested exercise fails to parse. The plan-cache loader catches these
  /// throws and regenerates from the generator service.
  factory WorkoutDay.fromJson(Map<String, dynamic> json) {
    final rawExercises = json['exercises'];
    if (rawExercises is! List) {
      throw const FormatException('WorkoutDay.exercises was not a list');
    }
    return WorkoutDay(
      dayNumber: json['dayNumber'] as int,
      exercises: rawExercises
          .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      isCompleted: (json['isCompleted'] as bool?) ?? false,
      title: (json['title'] as String?) ?? '',
    );
  }

  WorkoutDay copyWith({
    int? dayNumber,
    List<Exercise>? exercises,
    bool? isCompleted,
    String? title,
  }) {
    return WorkoutDay(
      dayNumber: dayNumber ?? this.dayNumber,
      exercises: exercises ?? this.exercises,
      isCompleted: isCompleted ?? this.isCompleted,
      title: title ?? this.title,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WorkoutDay &&
      other.dayNumber == dayNumber &&
      other.isCompleted == isCompleted &&
      other.title == title &&
      _listEquals(other.exercises, exercises);

  @override
  int get hashCode => Object.hash(
        dayNumber,
        isCompleted,
        title,
        Object.hashAll(exercises),
      );

  static bool _listEquals(List<Exercise> a, List<Exercise> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
