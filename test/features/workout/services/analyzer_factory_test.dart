// Phase 1 (P-Risk) · routing contract for analyzerFor(). Locks every
// exercise-slug → analyzer mapping so a future re-categorisation that
// misroutes a movement (the audit's §4 class of bug — e.g. dead_bug once
// wrongly hit FlutterKick) fails a test instead of shipping a counter that
// ticks on the wrong motion. The analyzer behaviour itself is covered by the
// golden-frame tests; this only asserts the dispatch.

import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/workout/models/exercise_model.dart';
import 'package:sixpack_ai/features/workout/services/analyzer_factory.dart';
import 'package:sixpack_ai/features/workout/services/back_legs_analyzers.dart';
import 'package:sixpack_ai/features/workout/services/chest_analyzers.dart';
import 'package:sixpack_ai/features/workout/services/core_analyzers.dart';
import 'package:sixpack_ai/features/workout/services/crunch_analyzer.dart';
import 'package:sixpack_ai/features/workout/services/shoulders_arms_cardio_analyzers.dart';

Exercise _ex(String id) => Exercise(
      id: id,
      name: id,
      type: ExerciseType.repBased,
      difficulty: 'beginner',
      targetMuscle: 'core',
      isCardio: false,
    );

void main() {
  // Expected analyzer type → every slug the factory routes to it.
  final routing = <Type, List<String>>{
    CrunchAnalyzer: [
      'crunch',
      'situp',
      'decline_crunch',
      'weighted_sit_up',
      'toe_touch',
    ],
    PlankAnalyzer: ['plank'],
    LegRaiseAnalyzer: [
      'leg_raise',
      'hanging_leg_raise',
      'weighted_leg_raise',
      'dragon_flag',
      'reverse_crunch',
    ],
    RussianTwistAnalyzer: ['russian_twist', 'medicine_ball_russian_twist'],
    MountainClimberAnalyzer: ['mountain_climber'],
    BicycleCrunchAnalyzer: ['bicycle_crunch'],
    FlutterKickAnalyzer: ['flutter_kick'],
    PushUpAnalyzer: [
      'push_up',
      'incline_push_up',
      'decline_push_up',
      'chest_dip',
      'diamond_push_up',
      'wide_push_up',
      'archer_push_up',
      'pseudo_planche_push_up',
      'clap_push_up',
      'knee_push_up',
      'pike_push_up',
      'pike_push_up_close',
      'handstand_push_up',
      'triceps_dip',
      'close_grip_push_up',
      'bench_dip',
    ],
    BenchPressAnalyzer: [
      'bench_press',
      'decline_bench_press',
      'machine_chest_press',
    ],
    ChestFlyAnalyzer: ['chest_fly', 'cable_crossover', 'incline_chest_fly'],
    SquatAnalyzer: [
      'squat',
      'lunge',
      'bulgarian_split_squat',
      'leg_press',
      'front_squat',
      'goblet_squat',
      'dumbbell_step_up',
      'walking_lunge_dumbbell',
      'pistol_squat',
      'sumo_squat',
      'box_jump',
      'deadlift',
      'jump_squat',
      'thruster',
      'squat_jump_pulse',
      'tuck_jump',
    ],
    HipHingeAnalyzer: [
      'glute_bridge',
      'hip_thrust',
      'single_leg_glute_bridge',
      'frog_pump',
      'single_leg_rdl',
      'kettlebell_swing',
    ],
    PullUpAnalyzer: [
      'pull_up',
      'chin_up',
      'lat_pulldown',
      'barbell_row',
      'dumbbell_row',
      't_bar_row',
      'face_pull',
      'seated_cable_row',
      'inverted_row',
      'scapular_pull_up',
      'chin_up_negative',
    ],
    ShoulderPressAnalyzer: [
      'shoulder_press',
      'arnold_press',
      'upright_row',
      'cuban_press',
      'landmine_press',
      'machine_shoulder_press',
    ],
    LateralRaiseAnalyzer: ['lateral_raise', 'front_raise', 'rear_delt_fly'],
    ScapularAnalyzer: ['prone_y_raise', 'prone_t_raise', 'scapular_wall_slide'],
    BicepsCurlAnalyzer: [
      'biceps_curl',
      'hammer_curl',
      'triceps_pushdown',
      'preacher_curl',
      'incline_dumbbell_curl',
      'cable_curl',
      'overhead_triceps_extension',
      'rope_triceps_pushdown',
      'dumbbell_kickback',
      'tricep_extension_floor',
    ],
    BurpeeAnalyzer: ['burpee', 'squat_thrust', 'half_burpee'],
    JumpingJackAnalyzer: ['jumping_jack'],
    // Time-based holds / rhythmic cardio with no meaningful pose check, plus
    // dead_bug (deliberately NOT FlutterKick — audit §4 D-fix-2).
    SilentHoldAnalyzer: [
      'dead_bug',
      'wall_sit',
      'calf_raise',
      'superman',
      'high_knees',
      'skipping_rope',
    ],
  };

  routing.forEach((type, slugs) {
    test('routes ${slugs.length} slug(s) to $type', () {
      for (final slug in slugs) {
        expect(analyzerFor(_ex(slug)).runtimeType, type,
            reason: 'slug "$slug"');
      }
    });
  });

  test('an unknown slug falls back to SilentHoldAnalyzer', () {
    expect(analyzerFor(_ex('does_not_exist')).runtimeType, SilentHoldAnalyzer);
    expect(analyzerFor(_ex('')).runtimeType, SilentHoldAnalyzer);
  });

  test('returns a fresh instance on every call (no shared rep state)', () {
    final a = analyzerFor(_ex('squat'));
    final b = analyzerFor(_ex('squat'));
    expect(identical(a, b), isFalse);
  });
}
