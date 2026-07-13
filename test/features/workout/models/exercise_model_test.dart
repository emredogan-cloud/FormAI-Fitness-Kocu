import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/workout/models/exercise_model.dart';

Exercise _ex({
  String id = 'pushup',
  String name = 'Push Up',
  ExerciseType type = ExerciseType.repBased,
  String difficulty = 'beginner',
  String targetMuscle = 'upper_body',
  bool isCardio = false,
  int? targetReps = 12,
  int? targetDurationInSeconds,
  String? videoUrl = 'PushUp.mp4',
  int sets = 3,
  int restDurationInSeconds = 30,
  ExerciseCategory category = ExerciseCategory.chest,
  String description = 'desc',
  String shortTip = 'tip',
  bool isPremium = false,
  bool isNew = false,
}) =>
    Exercise(
      id: id,
      name: name,
      type: type,
      difficulty: difficulty,
      targetMuscle: targetMuscle,
      isCardio: isCardio,
      targetReps: targetReps,
      targetDurationInSeconds: targetDurationInSeconds,
      videoUrl: videoUrl,
      sets: sets,
      restDurationInSeconds: restDurationInSeconds,
      category: category,
      description: description,
      shortTip: shortTip,
      isPremium: isPremium,
      isNew: isNew,
    );

void main() {
  group('serialization', () {
    test('toJson → fromJson round-trips a fully-populated exercise', () {
      final original = _ex(isPremium: true, isNew: true);
      expect(Exercise.fromJson(original.toJson()), original);
    });

    test('round-trips with null optional fields', () {
      final original = _ex(
        type: ExerciseType.timeBased,
        targetReps: null,
        targetDurationInSeconds: 45,
        videoUrl: null,
      );
      expect(Exercise.fromJson(original.toJson()), original);
    });

    test('fromJson applies documented defaults for absent optionals', () {
      final json = <String, dynamic>{
        'id': 'x',
        'name': 'X',
        'type': 'repBased',
        'difficulty': 'beginner',
        'targetMuscle': 'core',
        'isCardio': false,
      };
      final ex = Exercise.fromJson(json);
      expect(ex.sets, 1);
      expect(ex.restDurationInSeconds, 30);
      expect(ex.category, ExerciseCategory.core);
      expect(ex.description, '');
      expect(ex.shortTip, '');
      expect(ex.isPremium, isFalse);
      expect(ex.isNew, isFalse);
    });

    test('fromJson throws FormatException on an unknown exercise type', () {
      final json = _ex().toJson()..['type'] = 'bogus';
      expect(() => Exercise.fromJson(json), throwsFormatException);
    });

    test('fromJson falls back to core for an unknown category', () {
      final json = _ex().toJson()..['category'] = 'not_a_category';
      expect(Exercise.fromJson(json).category, ExerciseCategory.core);
    });

    test('fromJson throws when a required primitive is missing', () {
      final json = _ex().toJson()..remove('id');
      expect(() => Exercise.fromJson(json), throwsA(isA<TypeError>()));
    });
  });

  group('type getters', () {
    test('repBased exercise is rep-based, not time-based', () {
      final ex = _ex(type: ExerciseType.repBased);
      expect(ex.isRepBased, isTrue);
      expect(ex.isTimeBased, isFalse);
    });

    test('timeBased exercise is time-based, not rep-based', () {
      final ex = _ex(type: ExerciseType.timeBased);
      expect(ex.isTimeBased, isTrue);
      expect(ex.isRepBased, isFalse);
    });
  });

  group('copyWith', () {
    test('overrides only the named field', () {
      final original = _ex();
      final copy = original.copyWith(name: 'Renamed', isPremium: true);
      expect(copy.name, 'Renamed');
      expect(copy.isPremium, isTrue);
      // Everything else is preserved.
      expect(copy.id, original.id);
      expect(copy.type, original.type);
      expect(copy.targetReps, original.targetReps);
      expect(copy, isNot(original));
    });

    test('with no arguments produces an equal value', () {
      final original = _ex();
      expect(original.copyWith(), original);
    });
  });

  group('equality', () {
    test('identical field values are equal and share a hashCode', () {
      expect(_ex(), _ex());
      expect(_ex().hashCode, _ex().hashCode);
    });

    test('a single differing field breaks equality', () {
      expect(_ex(name: 'A'), isNot(_ex(name: 'B')));
    });
  });
}
