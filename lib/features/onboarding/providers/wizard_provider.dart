import 'package:flutter_riverpod/flutter_riverpod.dart';

enum Gender { female, male, other }

enum Physique { slim, normal, heavy }

enum GoalPhysique { tone, bulk, sixpack }

enum ActivityLevel { sedentary, light, active }

class WizardState {
  const WizardState({
    this.gender,
    this.age,
    this.heightCm,
    this.weightKg,
    this.currentPhysique,
    this.targetPhysique,
    this.activityLevel,
  });

  final Gender? gender;
  final int? age;
  final int? heightCm;
  final int? weightKg;
  final Physique? currentPhysique;
  final GoalPhysique? targetPhysique;
  final ActivityLevel? activityLevel;

  WizardState copyWith({
    Gender? gender,
    int? age,
    int? heightCm,
    int? weightKg,
    Physique? currentPhysique,
    GoalPhysique? targetPhysique,
    ActivityLevel? activityLevel,
  }) {
    return WizardState(
      gender: gender ?? this.gender,
      age: age ?? this.age,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      currentPhysique: currentPhysique ?? this.currentPhysique,
      targetPhysique: targetPhysique ?? this.targetPhysique,
      activityLevel: activityLevel ?? this.activityLevel,
    );
  }

  Map<String, dynamic> toJson() => {
        'gender': gender?.name,
        'age': age,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'currentPhysique': currentPhysique?.name,
        'targetPhysique': targetPhysique?.name,
        'activityLevel': activityLevel?.name,
      };
}

class WizardController extends Notifier<WizardState> {
  @override
  WizardState build() => const WizardState();

  void setGender(Gender v) => state = state.copyWith(gender: v);
  void setAge(int v) => state = state.copyWith(age: v);
  void setHeight(int v) => state = state.copyWith(heightCm: v);
  void setWeight(int v) => state = state.copyWith(weightKg: v);
  void setCurrentPhysique(Physique v) =>
      state = state.copyWith(currentPhysique: v);
  void setTargetPhysique(GoalPhysique v) =>
      state = state.copyWith(targetPhysique: v);
  void setActivityLevel(ActivityLevel v) =>
      state = state.copyWith(activityLevel: v);
}

final wizardProvider =
    NotifierProvider<WizardController, WizardState>(WizardController.new);
