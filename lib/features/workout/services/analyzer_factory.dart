import '../models/exercise_model.dart';
import 'back_legs_analyzers.dart';
import 'chest_analyzers.dart';
import 'core_analyzers.dart';
import 'crunch_analyzer.dart';
import 'pose_analyzer.dart';
import 'shoulders_arms_cardio_analyzers.dart';

/// Returns a fresh [PoseAnalyzer] tuned for [exercise]. Always returns a
/// new instance so set transitions don't carry rep state across boundaries.
/// Unknown ids fall back to [CrunchAnalyzer] so legacy data still ticks.
/// Time-based holds without a meaningful pose check (calf raises, wall
/// sits, supermans) route to [PlankAnalyzer] so the screen still surfaces
/// posture warnings while the timer counts down.
PoseAnalyzer analyzerFor(Exercise exercise) {
  switch (exercise.id) {
    // ---- Core ----
    case 'crunch':
    case 'situp':
      return CrunchAnalyzer();
    case 'plank':
      return PlankAnalyzer();
    case 'leg_raise':
    case 'hanging_leg_raise':
      return LegRaiseAnalyzer();
    case 'russian_twist':
      return RussianTwistAnalyzer();
    case 'mountain_climber':
      return MountainClimberAnalyzer();
    case 'bicycle_crunch':
      return BicycleCrunchAnalyzer();
    case 'flutter_kick':
      return FlutterKickAnalyzer();
    // ---- Chest ----
    case 'push_up':
    case 'incline_push_up':
    case 'decline_push_up':
    case 'chest_dip':
      return PushUpAnalyzer();
    case 'bench_press':
      return BenchPressAnalyzer();
    case 'chest_fly':
      return ChestFlyAnalyzer();
    // ---- Legs ----
    case 'squat':
    case 'lunge':
    case 'bulgarian_split_squat':
    case 'leg_press':
      return SquatAnalyzer();
    case 'wall_sit':
    case 'calf_raise':
      return PlankAnalyzer();
    // ---- Back ----
    case 'pull_up':
    case 'chin_up':
    case 'lat_pulldown':
    case 'barbell_row':
      return PullUpAnalyzer();
    case 'superman':
      return PlankAnalyzer();
    // ---- Shoulders ----
    case 'shoulder_press':
    case 'arnold_press':
      return ShoulderPressAnalyzer();
    case 'lateral_raise':
    case 'front_raise':
      return LateralRaiseAnalyzer();
    case 'pike_push_up':
      return PushUpAnalyzer();
    // ---- Arms ----
    case 'biceps_curl':
    case 'hammer_curl':
    case 'triceps_pushdown':
      return BicepsCurlAnalyzer();
    case 'triceps_dip':
    case 'close_grip_push_up':
      return PushUpAnalyzer();
    // ---- Cardio / Full Body ----
    case 'burpee':
      return BurpeeAnalyzer();
    case 'jumping_jack':
      return JumpingJackAnalyzer();
    case 'jump_squat':
      return SquatAnalyzer();
    case 'high_knees':
    case 'skipping_rope':
      return PlankAnalyzer();
    default:
      return CrunchAnalyzer();
  }
}
