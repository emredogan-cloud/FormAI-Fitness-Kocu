/// Phase 134 · client-side premium / new tagging for exercises.
///
/// The Supabase `public.exercises` table has no `is_premium` /
/// `is_new` columns — we tag here instead so the emotional-monetization
/// phase can ship without a database migration. Tags are applied at
/// hydration time inside `WorkoutRepository._exerciseFromRow()`, and
/// every cache read goes through that function (the legacy plan cache
/// re-hydrates through `Exercise.fromJson`, which defaults both fields
/// to `false`, but the workout-provider invalidates and refetches when
/// `_planKey` bumps — see `workout_repository.dart` v5 → v6).
///
/// Maintenance:
///   • Adding a new "Yeni" exercise: append the slug to [newSlugs].
///   • Promoting an existing exercise to premium: add to [premiumSlugs].
///   • Slugs are case-sensitive and must match the Supabase `slug`
///     column exactly (which in turn matches the [Exercise.id] field).
///
/// Why two sets instead of an enum field on Exercise: the source of
/// truth is operational (which exercises are gated, which are flagged
/// as new — copy decisions, not data shape decisions). Future revisions
/// can move this to PostHog remote-config or a separate Supabase table
/// without touching the model.
class PremiumExerciseTags {
  const PremiumExerciseTags._();

  /// Exercises that read as premium-only inside equipment plans.
  /// Tagging the Phase 85 set (10 exercises, all explicitly machine /
  /// barbell / cable / bench based) gives a clean division: free-tier
  /// users see bodyweight + light dumbbell movements run normally and
  /// the gym-equipment depth waiting behind the paywall.
  static const Set<String> premiumSlugs = {
    'ab_wheel_rollout',
    'barbell_squat',
    'cable_crunch',
    'concentration_curl',
    'incline_bench_press',
    'leg_curl',
    'leg_extension',
    'romanian_deadlift',
    'skull_crusher',
    'weighted_russian_twist',
  };

  /// Exercises flagged with a "Yeni" chip in the regions menu — the
  /// Phase 96 expansion set (87 net-new movements). Locked for non-pro
  /// users so the regions menu reads as having depth and recent
  /// curation, both of which lean into the aspiration / curiosity
  /// emotional pull the spec calls for.
  static const Set<String> newSlugs = {
    'archer_push_up',
    'bear_crawl',
    'bench_dip',
    'bird_dog',
    'box_jump',
    'cable_crossover',
    'cable_curl',
    'cat_cow',
    'child_pose',
    'chin_up_negative',
    'clap_push_up',
    'cobra_stretch',
    'cuban_press',
    'dead_bug',
    'dead_hang',
    'deadlift',
    'decline_bench_press',
    'decline_crunch',
    'diamond_push_up',
    'downward_dog',
    'dragon_flag',
    'dumbbell_clean',
    'dumbbell_kickback',
    'dumbbell_pullover',
    'dumbbell_row',
    'dumbbell_step_up',
    'face_pull',
    'farmer_carry',
    'frog_pump',
    'front_squat',
    'glute_bridge',
    'goblet_squat',
    'half_burpee',
    'handstand_hold',
    'handstand_push_up',
    'hip_flexor_stretch',
    'hip_thrust',
    'hollow_hold',
    'hyperextension',
    'incline_chest_fly',
    'incline_dumbbell_curl',
    'inverted_row',
    'kettlebell_swing',
    'knee_push_up',
    'landmine_press',
    'lateral_shuffle',
    'machine_chest_press',
    'machine_shoulder_press',
    'medicine_ball_russian_twist',
    'nordic_curl',
    'overhead_triceps_extension',
    'pike_push_up_close',
    'pike_walk',
    'pistol_squat',
    'plank_jack',
    'preacher_curl',
    'prone_t_raise',
    'prone_y_raise',
    'pseudo_planche_push_up',
    'rear_delt_fly',
    'reverse_crunch',
    'rope_triceps_pushdown',
    'scapular_pull_up',
    'scapular_wall_slide',
    'seated_cable_row',
    'seated_calf_raise',
    'shadow_boxing',
    'side_plank',
    'single_leg_calf_raise',
    'single_leg_glute_bridge',
    'single_leg_rdl',
    'squat_jump_pulse',
    'squat_thrust',
    'standing_hamstring_stretch',
    'sumo_squat',
    'swimmer',
    't_bar_row',
    'thruster',
    'toe_touch',
    'tricep_extension_floor',
    'tuck_jump',
    'upright_row',
    'walking_lunge_dumbbell',
    'wall_walk',
    'weighted_leg_raise',
    'weighted_sit_up',
    'wide_push_up',
  };

  /// Convenience predicate consumed by `WorkoutRepository._exerciseFromRow`
  /// when hydrating Supabase rows. Kept inline-static so the lookup is
  /// `O(1)` and there's zero allocation per row.
  static bool isPremium(String slug) => premiumSlugs.contains(slug);

  /// Convenience predicate, paired with [isPremium].
  static bool isNew(String slug) => newSlugs.contains(slug);
}
