import '../models/exercise_model.dart';
import 'back_legs_analyzers.dart';
import 'chest_analyzers.dart';
import 'core_analyzers.dart';
import 'crunch_analyzer.dart';
import 'pose_analyzer.dart';
import 'shoulders_arms_cardio_analyzers.dart';

/// Returns a fresh [PoseAnalyzer] tuned for [exercise]. Always returns a
/// new instance so set transitions don't carry rep state across boundaries.
///
/// Unknown ids fall back to [SilentHoldAnalyzer] rather than [CrunchAnalyzer]
/// — a neutral "no-op" is safer than a counter that might tick on unrelated
/// movements.
///
/// Time-based holds / rhythmic cardio with no meaningful pose check
/// (`wall_sit`, `calf_raise`, `superman`, `high_knees`, `skipping_rope`)
/// route to [SilentHoldAnalyzer]. Previously they were misrouted to
/// [PlankAnalyzer], which would yell "Kalçanı düz tut, plank pozisyonunu
/// koru" every 8 s because its shoulder-hip-ankle check is meaningless
/// for a seated/standing/prone user.
///
/// Phase 96 · the catalogue grew from 51 → 138 exercises. New slugs are
/// routed to existing analyzer classes wherever the joint geometry
/// matches; movements that don't fit (mobility holds, stretching,
/// balance work, hip-extension-only patterns like glute bridges and
/// kettlebell swings) fall through to [SilentHoldAnalyzer]. No new
/// analyzer classes were introduced — see
/// `/reports/ml-detection-strategy.md` for per-slug rationale.
PoseAnalyzer analyzerFor(Exercise exercise) {
  switch (exercise.id) {
    // ---- Core ----
    case 'crunch':
    case 'situp':
    case 'decline_crunch':
    case 'weighted_sit_up':
    case 'toe_touch':
      return CrunchAnalyzer();
    case 'plank':
      return PlankAnalyzer();
    case 'leg_raise':
    case 'hanging_leg_raise':
    case 'weighted_leg_raise':
    case 'dragon_flag':
    case 'reverse_crunch':
      return LegRaiseAnalyzer();
    case 'russian_twist':
    case 'medicine_ball_russian_twist':
      return RussianTwistAnalyzer();
    case 'mountain_climber':
      return MountainClimberAnalyzer();
    case 'bicycle_crunch':
      return BicycleCrunchAnalyzer();
    case 'flutter_kick':
    case 'dead_bug':
      return FlutterKickAnalyzer();
    // ---- Chest ----
    case 'push_up':
    case 'incline_push_up':
    case 'decline_push_up':
    case 'chest_dip':
    case 'diamond_push_up':
    case 'wide_push_up':
    case 'archer_push_up':
    case 'pseudo_planche_push_up':
    case 'clap_push_up':
    case 'knee_push_up':
      return PushUpAnalyzer();
    case 'bench_press':
    case 'decline_bench_press':
    case 'machine_chest_press':
      return BenchPressAnalyzer();
    case 'chest_fly':
    case 'cable_crossover':
    case 'incline_chest_fly':
      return ChestFlyAnalyzer();
    // ---- Legs ----
    case 'squat':
    case 'lunge':
    case 'bulgarian_split_squat':
    case 'leg_press':
    case 'front_squat':
    case 'goblet_squat':
    case 'dumbbell_step_up':
    case 'walking_lunge_dumbbell':
    case 'pistol_squat':
    case 'sumo_squat':
    case 'box_jump':
    case 'deadlift':
      return SquatAnalyzer();
    case 'wall_sit':
    case 'calf_raise':
      return SilentHoldAnalyzer();
    // ---- Hip hinge family (Tier B.1) ----
    // Shoulder-hip-knee angle cycle. Same state machine across lying
    // glute bridges, hip thrust, single-leg variants, frog pump, and
    // the standing kettlebell swing.
    case 'glute_bridge':
    case 'hip_thrust':
    case 'single_leg_glute_bridge':
    case 'frog_pump':
    case 'single_leg_rdl':
    case 'kettlebell_swing':
      return HipHingeAnalyzer();
    // ---- Back ----
    case 'pull_up':
    case 'chin_up':
    case 'lat_pulldown':
    case 'barbell_row':
    case 'dumbbell_row':
    case 't_bar_row':
    case 'face_pull':
    case 'seated_cable_row':
    case 'inverted_row':
    case 'scapular_pull_up':
    case 'chin_up_negative':
      return PullUpAnalyzer();
    case 'superman':
      return SilentHoldAnalyzer();
    // ---- Shoulders ----
    case 'shoulder_press':
    case 'arnold_press':
    case 'upright_row':
    case 'cuban_press':
    case 'landmine_press':
    case 'machine_shoulder_press':
      return ShoulderPressAnalyzer();
    case 'lateral_raise':
    case 'front_raise':
    case 'rear_delt_fly':
      return LateralRaiseAnalyzer();
    // ---- Scapular / postural (Tier B.2) ----
    case 'prone_y_raise':
    case 'prone_t_raise':
    case 'scapular_wall_slide':
      return ScapularAnalyzer();
    case 'pike_push_up':
    case 'pike_push_up_close':
    case 'handstand_push_up':
      return PushUpAnalyzer();
    // ---- Arms ----
    case 'biceps_curl':
    case 'hammer_curl':
    case 'triceps_pushdown':
    case 'preacher_curl':
    case 'incline_dumbbell_curl':
    case 'cable_curl':
    case 'overhead_triceps_extension':
    case 'rope_triceps_pushdown':
    case 'dumbbell_kickback':
    case 'tricep_extension_floor':
      return BicepsCurlAnalyzer();
    case 'triceps_dip':
    case 'close_grip_push_up':
    case 'bench_dip':
      return PushUpAnalyzer();
    // ---- Cardio / Full Body ----
    case 'burpee':
    case 'squat_thrust':
    case 'half_burpee':
      return BurpeeAnalyzer();
    case 'jumping_jack':
      return JumpingJackAnalyzer();
    case 'jump_squat':
    case 'thruster':
    case 'squat_jump_pulse':
    case 'tuck_jump':
      return SquatAnalyzer();
    case 'high_knees':
    case 'skipping_rope':
      return SilentHoldAnalyzer();
    default:
      return SilentHoldAnalyzer();
  }
}
