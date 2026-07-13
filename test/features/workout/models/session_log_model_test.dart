import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/workout/models/session_log_model.dart';

ExerciseLog _exLog({
  String exerciseId = 'ex1',
  String exerciseName = 'Push Up',
  String targetMuscle = 'upper_body',
  bool isCardio = false,
  int plannedSets = 3,
  int plannedReps = 12,
  int actualSets = 3,
  int actualReps = 11,
  int durationSeconds = 90,
}) =>
    ExerciseLog(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      targetMuscle: targetMuscle,
      isCardio: isCardio,
      plannedSets: plannedSets,
      plannedReps: plannedReps,
      actualSets: actualSets,
      actualReps: actualReps,
      durationSeconds: durationSeconds,
    );

void main() {
  group('SessionLog', () {
    test('toJson → fromJson is a lossless round-trip', () {
      final original = SessionLog(
        dayNumber: 7,
        completedAtIso: '2026-06-23T10:30:00.000Z',
        durationSeconds: 1200,
        exerciseLogs: [
          _exLog(exerciseId: 'a', actualReps: 10),
          _exLog(exerciseId: 'b', isCardio: true, actualReps: 30),
        ],
      );

      final restored = SessionLog.fromJson(original.toJson());

      // No value equality on the model — compare the serialised forms.
      expect(restored.toJson(), original.toJson());
      expect(restored.exerciseLogs, hasLength(2));
    });

    test('totalReps sums actualReps across every exercise', () {
      final log = SessionLog(
        dayNumber: 1,
        completedAtIso: '',
        durationSeconds: 0,
        exerciseLogs: [
          _exLog(actualReps: 10),
          _exLog(actualReps: 15),
          _exLog(actualReps: 5),
        ],
      );
      expect(log.totalReps, 30);
    });

    test('totalReps is 0 for an empty session', () {
      final log = SessionLog(
        dayNumber: 1,
        completedAtIso: '',
        durationSeconds: 0,
        exerciseLogs: const [],
      );
      expect(log.totalReps, 0);
    });

    test('fromJson fills optional fields with safe defaults', () {
      final json = jsonDecode('{"dayNumber":4,"exerciseLogs":[]}')
          as Map<String, dynamic>;
      final log = SessionLog.fromJson(json);
      expect(log.dayNumber, 4);
      expect(log.completedAtIso, '');
      expect(log.durationSeconds, 0);
      expect(log.exerciseLogs, isEmpty);
    });

    test('fromJson throws when dayNumber is missing', () {
      final json = jsonDecode('{"exerciseLogs":[]}') as Map<String, dynamic>;
      expect(() => SessionLog.fromJson(json), throwsFormatException);
    });

    test('fromJson throws when dayNumber is not an int', () {
      final json = jsonDecode('{"dayNumber":"7","exerciseLogs":[]}')
          as Map<String, dynamic>;
      expect(() => SessionLog.fromJson(json), throwsFormatException);
    });

    test('fromJson throws when exerciseLogs is not a List', () {
      final json = jsonDecode('{"dayNumber":1,"exerciseLogs":{}}')
          as Map<String, dynamic>;
      expect(() => SessionLog.fromJson(json), throwsFormatException);
    });

    test('fromJson silently drops non-map entries in exerciseLogs', () {
      final json = jsonDecode(
        '{"dayNumber":2,"exerciseLogs":[{"exerciseId":"a","actualReps":10},"garbage",42]}',
      ) as Map<String, dynamic>;
      final log = SessionLog.fromJson(json);
      expect(log.exerciseLogs, hasLength(1));
      expect(log.exerciseLogs.single.exerciseId, 'a');
      expect(log.totalReps, 10);
    });
  });

  group('ExerciseLog', () {
    test('toJson → fromJson is a lossless round-trip', () {
      final original = _exLog(
        exerciseId: 'squat',
        exerciseName: 'Air Squat',
        targetMuscle: 'lower_body',
        isCardio: false,
        plannedSets: 4,
        plannedReps: 15,
        actualSets: 4,
        actualReps: 14,
        durationSeconds: 120,
      );
      final restored = ExerciseLog.fromJson(original.toJson());
      expect(restored.toJson(), original.toJson());
    });

    test('fromJson applies defaults for a completely empty map', () {
      final log = ExerciseLog.fromJson(const <String, dynamic>{});
      expect(log.exerciseId, '');
      expect(log.exerciseName, '');
      expect(log.targetMuscle, 'full_body'); // documented default
      expect(log.isCardio, isFalse);
      expect(log.plannedSets, 0);
      expect(log.plannedReps, 0);
      expect(log.actualSets, 0);
      expect(log.actualReps, 0);
      expect(log.durationSeconds, 0);
    });
  });
}
