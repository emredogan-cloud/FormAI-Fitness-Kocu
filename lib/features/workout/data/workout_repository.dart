import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/app_preferences.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/media_url.dart';
import '../../../core/utils/string_case.dart';
import '../domain/services/workout_generator_service.dart';
import 'premium_exercise_tags.dart';
import 'session_log_repository.dart';
import '../models/exercise_model.dart';
import '../models/workout_day_model.dart';
import '../models/workout_plan_model.dart';

class WorkoutRepository {
  WorkoutRepository(this._prefs, {SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SharedPreferences _prefs;
  final SupabaseClient _client;

  static const String _completedKey = 'sixpack.completed_days';
  static const String _pendingSyncKey = 'sixpack.pending_sync_days';
  // Bumped v5 → v6 in phase 134: `Exercise` gained `isPremium` and
  // `isNew` flags so the emotional-monetization phase can render
  // locked previews inside otherwise free plans. Existing v5 caches
  // hydrate through `Exercise.fromJson`, which defaults the new
  // flags to `false` — bumping the key forces a regen so the
  // [PremiumExerciseTags] applied in [_exerciseFromRow] actually
  // surface on next launch.
  // Bumped v4 → v5 in phase 86: the goal/level normaliser now defaults
  // to `tone` instead of `sixpack` when onboarding is empty, and the
  // bucket interleave was rewritten to spread shorter buckets evenly
  // through the merged list. Existing v4 caches were generated under
  // the old core-biased path and must be regenerated to pick up the
  // fix; bumping the key forces that on next launch without users
  // having to "Reset progress" by hand. (Prior bump v3 → v4 in phase 75
  // was a similar one-shot for video URL casing.)
  static const String _planKey = 'sixpack.user_custom_plan_v6';

  /// Companion key holding a `goal:level` fingerprint of the inputs
  /// that produced the cached plan. Read at decode time; if the
  /// current onboarding inputs no longer match, the cached plan is
  /// treated as stale and regenerated. Closes the gap where a user
  /// changes their goal in profile-edit but keeps seeing the original
  /// plan because the cache had no concept of input identity.
  static const String _planFingerprintKey =
      'sixpack.user_custom_plan_fingerprint_v6';
  static const String _progressTable = 'user_progress';
  static const String _exercisesTable = 'exercises';

  /// Phase 50A · in-flight cache for the catalogue fetch. Memoised here so
  /// repeat calls within the same repository instance share a single
  /// network round-trip; the Riverpod-side [exercisesProvider] adds
  /// app-level dedup on top so widgets calling concurrently coalesce too.
  Future<List<Exercise>>? _exercisesFuture;

  // ==========================================================================
  // HERO IMAGE PATHS — phase 70. The Phase 35 Unsplash URLs and the two
  // Phase 53 default photo constants the templates used to share are
  // gone; every plan now points at a bespoke bundled VP8 WebP under
  // `photos/workouts/`. The path slug exactly matches the plan `id` so
  // adding a new template only requires generating the matching asset
  // and listing the slug — no new constant indirection here.
  // ==========================================================================
  // EXERCISE CATALOGUE — Phase 50A · Supabase migration
  // ==========================================================================
  // The 41 movements that used to live as `static final Exercise _crunch =
  // ...` literals here are now seeded into the `public.exercises` table
  // by `supabase/sql/exercises_migration.sql`. The async getters below are the
  // single read path; everything in this repository (plan templates,
  // generator pool, regional filters) hangs off `getAllExercises()`.
  //
  // Cache shape:
  //   • Per-instance `_exercisesFuture` memoises the network call so
  //     subsequent getXxx() calls in the same session reuse the result.
  //   • The Riverpod `exercisesProvider` (workout_provider.dart) caches
  //     across the widget tree, so independent UI consumers also coalesce.
  //
  // Failure mode: an empty list is returned (never null) so callers can
  // pipe straight into `.where(...)` without null-safety wrappers. The
  // generator's existing `dailyPool.isEmpty` guard already turns an empty
  // catalogue into "rest-only" days, which is the safest visual fallback
  // (and far better than crashing the antrenman tab).
  // ==========================================================================

  /// Fetches the entire exercise catalogue from Supabase, cached per
  /// instance. Subsequent calls return the same future without re-hitting
  /// the network. On error the catalogue resolves to an empty list and
  /// the failure is logged — see the failure-mode note above for why we
  /// don't surface a throw.
  Future<List<Exercise>> getAllExercises() {
    return _exercisesFuture ??= _fetchExercises();
  }

  /// Filtered view by [ExerciseCategory]. Reads through the same shared
  /// future as [getAllExercises] so adding more callers does not multiply
  /// the network cost.
  Future<List<Exercise>> getExercisesByCategory(
      ExerciseCategory category) async {
    final all = await getAllExercises();
    return all.where((e) => e.category == category).toList(growable: false);
  }

  /// Filtered view by `target_muscles` membership. Accepts the singular
  /// muscle string consumed by the generator (`core`, `upper_body`,
  /// `lower_body`, `full_body`, `cardio`) and matches against the row's
  /// array for forward-compatibility with multi-muscle entries.
  Future<List<Exercise>> getExercisesByTarget(String targetMuscle) async {
    final all = await getAllExercises();
    return all
        .where((e) => e.targetMuscle == targetMuscle)
        .toList(growable: false);
  }

  /// Filtered view by difficulty bucket (`beginner` | `intermediate` |
  /// `advanced`). Exposed for the future admin panel's catalogue browser
  /// so the generator's level-ramp logic isn't the only consumer.
  Future<List<Exercise>> getExercisesByDifficulty(String difficulty) async {
    final all = await getAllExercises();
    return all.where((e) => e.difficulty == difficulty).toList(growable: false);
  }

  Future<List<Exercise>> _fetchExercises() async {
    // Phase 89 · short-circuit when the platform reports no active
    // network interface. Without this the Supabase round-trip waits
    // for the full HTTP/TCP timeout (~30 s) before falling through to
    // the empty-pool path — a perceivable freeze every cold start
    // on a flight or in an elevator. Empty-pool is already a graceful
    // fallback (`generate30DayPlan` returns 30 rest days), and we
    // null out `_exercisesFuture` before returning so the next call
    // retries once the connection is back.
    final results = await Connectivity().checkConnectivity();
    final isOnline = results.any((r) => r != ConnectivityResult.none);
    if (!isOnline) {
      AppLogger.warning(
        'WorkoutRepository: offline — skipping exercises fetch',
        category: 'workout',
      );
      _exercisesFuture = null;
      return const [];
    }
    try {
      final rows = await _client.from(_exercisesTable).select().order('slug');
      return rows.map(_exerciseFromRow).toList(growable: false);
    } catch (e, st) {
      AppLogger.error(
        'WorkoutRepository: exercises fetch failed',
        e,
        stackTrace: st,
        category: 'workout',
      );
      // Forget the failed future so the next caller retries instead of
      // being permanently stuck on an empty catalogue.
      _exercisesFuture = null;
      return const [];
    }
  }

  /// Maps a `public.exercises` row to the in-memory [Exercise] model. The
  /// row → Dart contract:
  ///   • `slug` becomes `Exercise.id` (kept for plan-cache compatibility
  ///     with installs from before the migration).
  ///   • The first element of `target_muscles` becomes `targetMuscle`.
  ///     Multi-muscle entries are tolerated; the rest are ignored until
  ///     a future generator revision can make use of them.
  ///   • `instructions` becomes `description`. The split between
  ///     instructions (long form) and shortTip (one-liner) is preserved.
  ///   • `videoUrl` is composed from `slug` via [_composeVideoUrl]
  ///     (Phase 75) — the row's `video_url` column is intentionally
  ///     unused because live-DB drift left some rows with a snake_case
  ///     slug derivative there while Supabase Storage holds PascalCase
  ///     filenames. Sourcing the URL from `slug` guarantees the right
  ///     casing every time.
  static Exercise _exerciseFromRow(Map<String, dynamic> row) {
    final slug = row['slug'] as String;
    return Exercise(
      id: slug,
      name: row['name'] as String,
      type: ExerciseType.values.firstWhere(
        (v) => v.name == row['type'],
        orElse: () => ExerciseType.repBased,
      ),
      targetReps: row['target_reps'] as int?,
      targetDurationInSeconds: row['target_duration_in_seconds'] as int?,
      sets: (row['sets'] as int?) ?? 1,
      restDurationInSeconds: (row['rest_duration_in_seconds'] as int?) ?? 30,
      category: ExerciseCategory.values.firstWhere(
        (v) => v.name == row['category'],
        orElse: () => ExerciseCategory.core,
      ),
      description: (row['instructions'] as String?) ?? '',
      shortTip: (row['short_tip'] as String?) ?? '',
      difficulty: (row['difficulty'] as String?) ?? 'beginner',
      targetMuscle: _firstTargetMuscle(row['target_muscles']),
      isCardio: (row['is_cardio'] as bool?) ?? false,
      videoUrl: _composeVideoUrl(slug),
      // Phase 134 · premium / new flags layered in at hydration time.
      // Source of truth is [PremiumExerciseTags] (client-side); the
      // Supabase row has no equivalent columns. Flags drive the
      // `LockedOverlay` + "Yeni" chip render decisions downstream.
      isPremium: PremiumExerciseTags.isPremium(slug),
      isNew: PremiumExerciseTags.isNew(slug),
    );
  }

  static String _firstTargetMuscle(dynamic raw) {
    if (raw is List && raw.isNotEmpty) {
      final first = raw.first;
      if (first is String && first.isNotEmpty) return first;
    }
    if (raw is String && raw.isNotEmpty) return raw;
    return 'core';
  }

  /// Composes the public Supabase Storage URL the player streams.
  ///
  /// Phase 75 · the URL is derived purely from the exercise `slug`:
  ///   1. Convert the snake_case slug to PascalCase via
  ///      [StringCase.snakeToPascal] (Storage is case-sensitive — see
  ///      [StringCase] for the mismatch this fixes).
  ///   2. Append `.mp4`.
  ///   3. Route through [MediaUrl.resolve] against the `exercises`
  ///      bucket so a configured `CDN_BASE_URL` still rewrites the
  ///      Supabase host while the bucket + filename tail stay intact.
  ///
  /// Pre-Phase-75 the function read the row's `video_url` column. That
  /// path was abandoned because live-DB drift left some rows with
  /// inconsistent casing/extensions there, and the Storage bucket is
  /// the canonical source.
  static String? _composeVideoUrl(String slug) {
    // Phase 79 · strip all whitespace (incl. tabs / newlines / non-breaking
    // spaces) before the snake_case → PascalCase conversion. A DB row whose
    // `slug` accidentally has a trailing newline or stray space would
    // otherwise leak into the filename ("Push Up.mp4" instead of
    // "PushUp.mp4") and Supabase Storage 400s the request.
    final sanitizedSlug = slug.trim().replaceAll(RegExp(r'\s+'), '');
    if (sanitizedSlug.isEmpty) return null;
    final fileName = '${StringCase.snakeToPascal(sanitizedSlug)}.mp4';
    return MediaUrl.resolve(fileName, bucket: 'exercises');
  }

  // ==========================================================================
  // "EKİPMANLI EGZERSİZLER" + REGIONAL PLAN TEMPLATES
  // ==========================================================================
  // Plans are defined as static templates (id + slug list); resolution
  // against the live exercise catalogue happens lazily in
  // [getAllPlans] / [getEquipmentPlans]. Slugs that don't resolve are
  // silently dropped, so deleting an exercise in Supabase doesn't crash
  // the dashboard — the affected plan just gets shorter.
  //
  // Phase 85 · the four core "Sınırlarını Zorla" templates were replaced
  // with seven muscle-group cards driven entirely off equipment-only
  // slugs. The slug curation IS the equipment classification — there's
  // no runtime equipment field on Exercise (yet), so the only way a
  // bodyweight movement could end up on this strip is by being added to
  // one of the lists below. Re-curate carefully.
  // ==========================================================================

  // Phase 98 · The original 7 equipment programs are preserved as the only
  // entries on the dashboard's horizontal strip. Each carries a Lite Seviye
  // (`exerciseSlugs`) AND an İleri Seviye (`premiumExerciseSlugs`) pulled
  // from the Phase 96 advanced catalogue. The plan-detail screen reads
  // `WorkoutPlan.premiumExercises` to render a half-width "Premium Seviye"
  // launcher beside the existing "Lite Seviye" button, plus an İleri Seviye
  // section below the standard exercise list. Phase 97's mistake — adding
  // 8 new equipment cards alongside the 7 — has been reverted; the new
  // exercises now live INSIDE these 7 cards as the premium tier.
  static const List<_PlanTemplate> _equipmentTemplates = [
    _PlanTemplate(
      id: 'equipment_chest_strength',
      title: 'Ekipmanlı Göğüs Gücü',
      category: ExerciseCategory.chest,
      level: 'Orta düzey',
      durationMinutes: 22,
      exerciseSlugs: [
        'bench_press',
        'incline_bench_press',
        'chest_fly',
        'chest_dip',
      ],
      premiumExerciseSlugs: [
        'decline_bench_press',
        'cable_crossover',
        'incline_chest_fly',
        'machine_chest_press',
        'dumbbell_pullover',
      ],
      image: 'photos/workouts/equipment_chest_strength.webp',
    ),
    _PlanTemplate(
      id: 'equipment_back_width',
      title: 'Ekipmanlı Sırt Genişliği',
      category: ExerciseCategory.back,
      level: 'Orta düzey',
      durationMinutes: 24,
      exerciseSlugs: [
        'pull_up',
        'lat_pulldown',
        'barbell_row',
        'chin_up',
      ],
      premiumExerciseSlugs: [
        't_bar_row',
        'dumbbell_row',
        'seated_cable_row',
        'face_pull',
        'deadlift',
        'dumbbell_clean',
      ],
      image: 'photos/workouts/equipment_back_width.webp',
    ),
    _PlanTemplate(
      id: 'equipment_shoulders_round',
      title: 'Yuvarlak Omuz Şekillendirme',
      category: ExerciseCategory.shoulders,
      level: 'Orta düzey',
      durationMinutes: 20,
      exerciseSlugs: [
        'shoulder_press',
        'arnold_press',
        'lateral_raise',
        'front_raise',
      ],
      premiumExerciseSlugs: [
        'machine_shoulder_press',
        'upright_row',
        'rear_delt_fly',
        'cuban_press',
        'landmine_press',
        'thruster',
      ],
      image: 'photos/workouts/equipment_shoulders_round.webp',
    ),
    _PlanTemplate(
      id: 'equipment_arms_biceps',
      title: 'Ekipmanlı Biceps Pompası',
      category: ExerciseCategory.arms,
      level: 'Orta düzey',
      durationMinutes: 14,
      exerciseSlugs: [
        'biceps_curl',
        'hammer_curl',
        'concentration_curl',
      ],
      premiumExerciseSlugs: [
        'preacher_curl',
        'incline_dumbbell_curl',
        'cable_curl',
        'chin_up_negative',
      ],
      image: 'photos/workouts/equipment_arms_biceps.webp',
    ),
    _PlanTemplate(
      id: 'equipment_arms_triceps',
      title: 'Ekipmanlı Triceps Yoğunluğu',
      category: ExerciseCategory.arms,
      level: 'Orta düzey',
      durationMinutes: 14,
      exerciseSlugs: [
        'triceps_pushdown',
        'skull_crusher',
        'triceps_dip',
      ],
      premiumExerciseSlugs: [
        'overhead_triceps_extension',
        'rope_triceps_pushdown',
        'dumbbell_kickback',
        'tricep_extension_floor',
      ],
      image: 'photos/workouts/equipment_arms_triceps.webp',
    ),
    _PlanTemplate(
      id: 'equipment_legs_power',
      title: 'Ekipmanlı Bacak Gücü',
      category: ExerciseCategory.legs,
      level: 'İleri',
      durationMinutes: 28,
      exerciseSlugs: [
        'barbell_squat',
        'leg_press',
        'romanian_deadlift',
        'leg_extension',
        'leg_curl',
      ],
      premiumExerciseSlugs: [
        'front_squat',
        'goblet_squat',
        'hip_thrust',
        'walking_lunge_dumbbell',
        'kettlebell_swing',
        'box_jump',
      ],
      image: 'photos/workouts/equipment_legs_power.webp',
    ),
    _PlanTemplate(
      id: 'equipment_core_loaded',
      title: 'Ağırlıklı Karın Şekillendirme',
      category: ExerciseCategory.core,
      level: 'İleri',
      durationMinutes: 18,
      exerciseSlugs: [
        'cable_crunch',
        'hanging_leg_raise',
        'weighted_russian_twist',
        'ab_wheel_rollout',
      ],
      premiumExerciseSlugs: [
        'weighted_sit_up',
        'weighted_leg_raise',
        'dragon_flag',
        'medicine_ball_russian_twist',
      ],
      image: 'photos/workouts/equipment_core_loaded.webp',
    ),
  ];

  static const List<_PlanTemplate> _regionalTemplates = [
    // ---- Core ----
    _PlanTemplate(
      id: 'core_steel_abs',
      title: 'Çelik Gibi Karın',
      category: ExerciseCategory.core,
      level: 'Başlangıç',
      durationMinutes: 15,
      exerciseSlugs: [
        'plank',
        'russian_twist',
        'leg_raise',
        'mountain_climber',
        'bicycle_crunch',
      ],
      image: 'photos/workouts/core_steel_abs.webp',
    ),
    _PlanTemplate(
      id: 'core_athletic',
      title: 'Atletik Core',
      category: ExerciseCategory.core,
      level: 'Orta düzey',
      durationMinutes: 20,
      exerciseSlugs: [
        'crunch',
        'bicycle_crunch',
        'leg_raise',
        'flutter_kick',
        'plank',
      ],
      image: 'photos/workouts/core_athletic.webp',
    ),
    // ---- Göğüs (Chest) ----
    _PlanTemplate(
      id: 'chest_dumbbell_fast',
      title: 'Dambıl Hızlı Göğüs Yapma',
      category: ExerciseCategory.chest,
      level: 'Orta düzey',
      durationMinutes: 14,
      exerciseSlugs: ['bench_press', 'chest_fly', 'push_up'],
      image: 'photos/workouts/chest_dumbbell_fast.webp',
    ),
    _PlanTemplate(
      id: 'chest_activation_growth',
      title: 'Göğüs Aktivasyonu ve Büyüme',
      category: ExerciseCategory.chest,
      level: 'Başlangıç',
      durationMinutes: 6,
      exerciseSlugs: ['incline_push_up', 'push_up'],
      image: 'photos/workouts/chest_activation_growth.webp',
    ),
    _PlanTemplate(
      id: 'chest_full_growth_burst',
      title: 'Tam Göğüs Büyümesi ve Patlaması',
      category: ExerciseCategory.chest,
      level: 'İleri',
      durationMinutes: 22,
      exerciseSlugs: [
        'push_up',
        'incline_push_up',
        'decline_push_up',
        'chest_dip',
        'bench_press',
        'chest_fly',
      ],
      image: 'photos/workouts/chest_full_growth_burst.webp',
    ),
    _PlanTemplate(
      id: 'chest_fat_burn_basic',
      title: 'Göğüs Yağ Yakma Temel Planı',
      category: ExerciseCategory.chest,
      level: 'Orta düzey',
      durationMinutes: 18,
      exerciseSlugs: [
        'push_up',
        'decline_push_up',
        'chest_dip',
        'chest_fly',
      ],
      image: 'photos/workouts/chest_fat_burn_basic.webp',
    ),
    // ---- Sırt (Back) ----
    _PlanTemplate(
      id: 'back_v_taper',
      title: 'Geniş V-Taper Sırt',
      category: ExerciseCategory.back,
      level: 'Orta düzey',
      durationMinutes: 22,
      exerciseSlugs: ['pull_up', 'chin_up', 'lat_pulldown', 'barbell_row'],
      image: 'photos/workouts/back_v_taper.webp',
    ),
    _PlanTemplate(
      id: 'back_posture_basic',
      title: 'Duruş Düzeltici Temel Sırt',
      category: ExerciseCategory.back,
      level: 'Başlangıç',
      durationMinutes: 12,
      exerciseSlugs: ['superman', 'lat_pulldown', 'barbell_row'],
      image: 'photos/workouts/back_posture_basic.webp',
    ),
    // ---- Omuz (Shoulders) ----
    _PlanTemplate(
      id: 'shoulders_giant',
      title: 'Dev Omuzlar',
      category: ExerciseCategory.shoulders,
      level: 'Orta düzey',
      durationMinutes: 18,
      exerciseSlugs: [
        'shoulder_press',
        'lateral_raise',
        'front_raise',
        'arnold_press',
      ],
      image: 'photos/workouts/shoulders_giant.webp',
    ),
    _PlanTemplate(
      id: 'shoulders_v_taper',
      title: 'V-Tipi Omuz Şekillendirme',
      category: ExerciseCategory.shoulders,
      level: 'Başlangıç',
      durationMinutes: 14,
      exerciseSlugs: ['lateral_raise', 'front_raise', 'pike_push_up'],
      image: 'photos/workouts/shoulders_v_taper.webp',
    ),
    _PlanTemplate(
      id: 'shoulders_power_burst',
      title: 'Power Omuz Patlaması',
      category: ExerciseCategory.shoulders,
      level: 'İleri',
      durationMinutes: 22,
      exerciseSlugs: [
        'arnold_press',
        'shoulder_press',
        'lateral_raise',
        'pike_push_up',
      ],
      image: 'photos/workouts/shoulders_power_burst.webp',
    ),
    // ---- Kol (Arms) ----
    _PlanTemplate(
      id: 'arms_steel',
      title: 'Çelik Kollar',
      category: ExerciseCategory.arms,
      level: 'Orta düzey',
      durationMinutes: 14,
      exerciseSlugs: ['biceps_curl', 'hammer_curl', 'triceps_dip'],
      image: 'photos/workouts/arms_steel.webp',
    ),
    _PlanTemplate(
      id: 'arms_explosive_super',
      title: 'Patlayıcı Kol Süper Setleri',
      category: ExerciseCategory.arms,
      level: 'İleri',
      durationMinutes: 20,
      exerciseSlugs: [
        'biceps_curl',
        'hammer_curl',
        'triceps_dip',
        'triceps_pushdown',
        'close_grip_push_up',
      ],
      image: 'photos/workouts/arms_explosive_super.webp',
    ),
    _PlanTemplate(
      id: 'arms_quick_tone',
      title: 'Hızlı Tonlama Kolları',
      category: ExerciseCategory.arms,
      level: 'Başlangıç',
      durationMinutes: 10,
      exerciseSlugs: ['biceps_curl', 'hammer_curl', 'triceps_pushdown'],
      image: 'photos/workouts/arms_quick_tone.webp',
    ),
    // ---- Bacak (Legs) ----
    _PlanTemplate(
      id: 'legs_quad_strength',
      title: 'Büyük ve Güçlü Quadriceps Şekli',
      category: ExerciseCategory.legs,
      level: 'Orta düzey',
      durationMinutes: 18,
      exerciseSlugs: ['squat', 'lunge', 'leg_press', 'calf_raise'],
      image: 'photos/workouts/legs_quad_strength.webp',
    ),
    _PlanTemplate(
      id: 'legs_power_day',
      title: 'Bacak Gücü Artışı Günü',
      category: ExerciseCategory.legs,
      level: 'İleri',
      durationMinutes: 25,
      exerciseSlugs: [
        'squat',
        'bulgarian_split_squat',
        'leg_press',
        'calf_raise',
      ],
      image: 'photos/workouts/legs_power_day.webp',
    ),
    _PlanTemplate(
      id: 'legs_cardio_strength',
      title: 'Alt Vücut Kardiyo ve Güç',
      category: ExerciseCategory.legs,
      level: 'Orta düzey',
      durationMinutes: 20,
      exerciseSlugs: ['squat', 'lunge', 'calf_raise', 'wall_sit'],
      image: 'photos/workouts/legs_cardio_strength.webp',
    ),
    _PlanTemplate(
      id: 'legs_elite_sculpt',
      title: 'Elit Bacak Şekillendirme',
      category: ExerciseCategory.legs,
      level: 'İleri',
      durationMinutes: 28,
      exerciseSlugs: [
        'bulgarian_split_squat',
        'leg_press',
        'wall_sit',
        'lunge',
        'calf_raise',
      ],
      image: 'photos/workouts/legs_elite_sculpt.webp',
    ),
    // ---- Kardiyo & Full Body ----
    _PlanTemplate(
      id: 'cardio_fat_burn',
      title: 'Yağ Yakıcı Kardiyo',
      category: ExerciseCategory.fullBody,
      level: 'Orta düzey',
      durationMinutes: 20,
      exerciseSlugs: ['burpee', 'jumping_jack', 'high_knees', 'jump_squat'],
      image: 'photos/workouts/cardio_fat_burn.webp',
    ),
    _PlanTemplate(
      id: 'cardio_full_body_burst',
      title: 'Tam Vücut Patlama',
      category: ExerciseCategory.fullBody,
      level: 'İleri',
      durationMinutes: 25,
      exerciseSlugs: [
        'burpee',
        'jump_squat',
        'mountain_climber',
        'skipping_rope',
        'jumping_jack',
      ],
      image: 'photos/workouts/cardio_full_body_burst.webp',
    ),
    _PlanTemplate(
      id: 'cardio_morning_quick',
      title: 'Hızlı Sabah Kardiyosu',
      category: ExerciseCategory.fullBody,
      level: 'Başlangıç',
      durationMinutes: 12,
      exerciseSlugs: ['jumping_jack', 'high_knees', 'skipping_rope'],
      image: 'photos/workouts/cardio_morning_quick.webp',
    ),
    // ========================================================================
    // Phase 97 expansion · 24 new regional bodyweight programs
    // ========================================================================
    // Surfaces every Phase 96 bodyweight slug (mobility/stretching included)
    // under the chip that matches its primary target. Sub-tags determine
    // secondary placement; the chip filter in antrenman_tab.dart keys off
    // `category` only. See /reports/workout-category-distribution.md for the
    // full per-chip manifest.
    // ---- Phase 97 · Core ----
    _PlanTemplate(
      id: 'core_static_resistance',
      title: 'Statik Çekirdek Direnci',
      category: ExerciseCategory.core,
      level: 'Orta düzey',
      durationMinutes: 14,
      exerciseSlugs: [
        'plank',
        'hollow_hold',
        'side_plank',
        'bird_dog',
        'dead_bug',
      ],
      image: 'photos/workouts/core_static_resistance.webp',
    ),
    _PlanTemplate(
      id: 'core_lower_abs',
      title: 'Alt Karın Şekillendirme',
      category: ExerciseCategory.core,
      level: 'Orta düzey',
      durationMinutes: 12,
      exerciseSlugs: [
        'reverse_crunch',
        'leg_raise',
        'hanging_leg_raise',
        'toe_touch',
      ],
      image: 'photos/workouts/core_lower_abs.webp',
    ),
    _PlanTemplate(
      id: 'core_oblique_burner',
      title: 'Yan Kas Yakıcı',
      category: ExerciseCategory.core,
      level: 'Başlangıç',
      durationMinutes: 12,
      exerciseSlugs: [
        'russian_twist',
        'bicycle_crunch',
        'side_plank',
        'mountain_climber',
      ],
      image: 'photos/workouts/core_oblique_burner.webp',
    ),
    _PlanTemplate(
      id: 'core_mobility_flow',
      title: 'Mobiliteli Karın Akışı',
      category: ExerciseCategory.core,
      level: 'Başlangıç',
      durationMinutes: 14,
      exerciseSlugs: [
        'cat_cow',
        'bird_dog',
        'dead_bug',
        'side_plank',
        'plank',
      ],
      image: 'photos/workouts/core_mobility_flow.webp',
    ),
    // ---- Phase 97 · Göğüs ----
    _PlanTemplate(
      id: 'chest_bodyweight_burst',
      title: 'Bodyweight Göğüs Patlaması',
      category: ExerciseCategory.chest,
      level: 'İleri',
      durationMinutes: 16,
      exerciseSlugs: [
        'wide_push_up',
        'diamond_push_up',
        'archer_push_up',
        'decline_push_up',
      ],
      image: 'photos/workouts/chest_bodyweight_burst.webp',
    ),
    _PlanTemplate(
      id: 'chest_plyo_explosive',
      title: 'Patlayıcı Plyo Göğüs',
      category: ExerciseCategory.chest,
      level: 'İleri',
      durationMinutes: 18,
      exerciseSlugs: [
        'clap_push_up',
        'decline_push_up',
        'archer_push_up',
        'push_up',
      ],
      image: 'photos/workouts/chest_plyo_explosive.webp',
    ),
    _PlanTemplate(
      id: 'chest_beginner_flow',
      title: 'Yeni Başlayan Göğüs Akışı',
      category: ExerciseCategory.chest,
      level: 'Başlangıç',
      durationMinutes: 8,
      exerciseSlugs: ['knee_push_up', 'incline_push_up', 'push_up'],
      image: 'photos/workouts/chest_beginner_flow.webp',
    ),
    // ---- Phase 97 · Sırt ----
    _PlanTemplate(
      id: 'back_bodyweight_activation',
      title: 'Bodyweight Sırt Aktivasyonu',
      category: ExerciseCategory.back,
      level: 'Orta düzey',
      durationMinutes: 18,
      exerciseSlugs: [
        'inverted_row',
        'swimmer',
        'prone_y_raise',
        'prone_t_raise',
        'scapular_pull_up',
      ],
      image: 'photos/workouts/back_bodyweight_activation.webp',
    ),
    _PlanTemplate(
      id: 'back_postural_corrective',
      title: 'Postüral Sırt Düzeltme',
      category: ExerciseCategory.back,
      level: 'Başlangıç',
      durationMinutes: 14,
      exerciseSlugs: [
        'swimmer',
        'bird_dog',
        'prone_y_raise',
        'prone_t_raise',
        'scapular_wall_slide',
      ],
      image: 'photos/workouts/back_postural_corrective.webp',
    ),
    _PlanTemplate(
      id: 'back_hanging_workout',
      title: 'Asılı Sırt Antrenmanı',
      category: ExerciseCategory.back,
      level: 'İleri',
      durationMinutes: 18,
      exerciseSlugs: ['scapular_pull_up', 'dead_hang', 'pull_up', 'chin_up'],
      image: 'photos/workouts/back_hanging_workout.webp',
    ),
    // ---- Phase 97 · Omuz ----
    _PlanTemplate(
      id: 'shoulders_advanced_bodyweight',
      title: 'İleri Bodyweight Omuz',
      category: ExerciseCategory.shoulders,
      level: 'İleri',
      durationMinutes: 18,
      exerciseSlugs: [
        'handstand_hold',
        'wall_walk',
        'handstand_push_up',
        'pike_push_up',
      ],
      image: 'photos/workouts/shoulders_advanced_bodyweight.webp',
    ),
    _PlanTemplate(
      id: 'shoulders_mobility_opening',
      title: 'Omuz Mobilite ve Açılış',
      category: ExerciseCategory.shoulders,
      level: 'Başlangıç',
      durationMinutes: 10,
      exerciseSlugs: ['scapular_wall_slide', 'pike_walk', 'downward_dog'],
      image: 'photos/workouts/shoulders_mobility_opening.webp',
    ),
    _PlanTemplate(
      id: 'shoulders_scapular_stability',
      title: 'Skapular Stabilite',
      category: ExerciseCategory.shoulders,
      level: 'Başlangıç',
      durationMinutes: 12,
      exerciseSlugs: [
        'scapular_wall_slide',
        'scapular_pull_up',
        'prone_y_raise',
        'prone_t_raise',
      ],
      image: 'photos/workouts/shoulders_scapular_stability.webp',
    ),
    // ---- Phase 97 · Kol ----
    _PlanTemplate(
      id: 'arms_bodyweight_burst',
      title: 'Bodyweight Kol Patlaması',
      category: ExerciseCategory.arms,
      level: 'Orta düzey',
      durationMinutes: 14,
      exerciseSlugs: [
        'close_grip_push_up',
        'diamond_push_up',
        'bench_dip',
        'tricep_extension_floor',
      ],
      image: 'photos/workouts/arms_bodyweight_burst.webp',
    ),
    _PlanTemplate(
      id: 'arms_triceps_bodyweight',
      title: 'Triceps Yoğun Bodyweight',
      category: ExerciseCategory.arms,
      level: 'Orta düzey',
      durationMinutes: 14,
      exerciseSlugs: [
        'bench_dip',
        'close_grip_push_up',
        'tricep_extension_floor',
        'pike_push_up_close',
      ],
      image: 'photos/workouts/arms_triceps_bodyweight.webp',
    ),
    _PlanTemplate(
      id: 'arms_hanging_grip',
      title: 'Asılı Kol & Grip Antrenmanı',
      category: ExerciseCategory.arms,
      level: 'İleri',
      durationMinutes: 12,
      exerciseSlugs: ['chin_up_negative', 'dead_hang', 'scapular_pull_up'],
      image: 'photos/workouts/arms_hanging_grip.webp',
    ),
    // ---- Phase 97 · Bacak ----
    _PlanTemplate(
      id: 'legs_glute_activation',
      title: 'Glute Aktivasyonu',
      category: ExerciseCategory.legs,
      level: 'Başlangıç',
      durationMinutes: 12,
      exerciseSlugs: [
        'glute_bridge',
        'frog_pump',
        'single_leg_glute_bridge',
        'sumo_squat',
      ],
      image: 'photos/workouts/legs_glute_activation.webp',
    ),
    _PlanTemplate(
      id: 'legs_single_leg_bodyweight',
      title: 'Tek Bacak Bodyweight',
      category: ExerciseCategory.legs,
      level: 'İleri',
      durationMinutes: 18,
      exerciseSlugs: [
        'pistol_squat',
        'bulgarian_split_squat',
        'single_leg_rdl',
        'calf_raise',
      ],
      image: 'photos/workouts/legs_single_leg_bodyweight.webp',
    ),
    _PlanTemplate(
      id: 'legs_plyometric_burst',
      title: 'Plyometrik Bacak Patlaması',
      category: ExerciseCategory.legs,
      level: 'İleri',
      durationMinutes: 16,
      exerciseSlugs: [
        'box_jump',
        'tuck_jump',
        'jump_squat',
        'squat_jump_pulse',
      ],
      image: 'photos/workouts/legs_plyometric_burst.webp',
    ),
    _PlanTemplate(
      id: 'legs_sumo_adductor',
      title: 'Sumo & İç Uyluk',
      category: ExerciseCategory.legs,
      level: 'Başlangıç',
      durationMinutes: 14,
      exerciseSlugs: [
        'sumo_squat',
        'single_leg_glute_bridge',
        'frog_pump',
        'lunge',
      ],
      image: 'photos/workouts/legs_sumo_adductor.webp',
    ),
    // ---- Phase 97 · Kardiyo & Full Body ----
    _PlanTemplate(
      id: 'cardio_hiit_burst',
      title: 'HIIT Patlaması',
      category: ExerciseCategory.fullBody,
      level: 'İleri',
      durationMinutes: 18,
      exerciseSlugs: [
        'burpee',
        'squat_thrust',
        'half_burpee',
        'jump_squat',
        'mountain_climber',
      ],
      image: 'photos/workouts/cardio_hiit_burst.webp',
    ),
    _PlanTemplate(
      id: 'cardio_mobility_stretch',
      title: 'Mobilite ve Esneklik Akışı',
      category: ExerciseCategory.fullBody,
      level: 'Başlangıç',
      durationMinutes: 12,
      exerciseSlugs: [
        'cat_cow',
        'child_pose',
        'downward_dog',
        'cobra_stretch',
        'hip_flexor_stretch',
        'standing_hamstring_stretch',
      ],
      image: 'photos/workouts/cardio_mobility_stretch.webp',
    ),
    _PlanTemplate(
      id: 'cardio_shadow_box',
      title: 'Shadow Box Cardio',
      category: ExerciseCategory.fullBody,
      level: 'Başlangıç',
      durationMinutes: 14,
      exerciseSlugs: [
        'shadow_boxing',
        'lateral_shuffle',
        'high_knees',
        'jumping_jack',
      ],
      image: 'photos/workouts/cardio_shadow_box.webp',
    ),
    _PlanTemplate(
      id: 'cardio_full_body_flow',
      title: 'Tüm Vücut Hareket Akışı',
      category: ExerciseCategory.fullBody,
      level: 'Orta düzey',
      durationMinutes: 14,
      exerciseSlugs: [
        'bear_crawl',
        'mountain_climber',
        'plank_jack',
        'lateral_shuffle',
      ],
      image: 'photos/workouts/cardio_full_body_flow.webp',
    ),
  ];

  /// Materialised Ekipmanlı Egzersizler cards. Resolves the seven
  /// muscle-group templates against the fetched catalogue; missing
  /// slugs drop out silently so the same template stays shippable
  /// before its corresponding Phase 85 exercises land in Supabase.
  Future<List<WorkoutPlan>> getEquipmentPlans() async {
    final exercises = await getAllExercises();
    final bySlug = {for (final e in exercises) e.id: e};
    return _equipmentTemplates
        .map((t) => t.resolve(bySlug))
        .toList(growable: false);
  }

  /// Materialised regional plan list for the Bölgeler chip strip.
  ///
  /// Phase 85 · this used to also prepend the four push-limits cards
  /// (which were all `category: core`) so the Core chip showed them at
  /// the top of the regional list. With the strip rebuilt as seven
  /// equipment cards spread across chest/back/shoulders/arms/legs/core,
  /// folding them in here would surface the same plan twice (once on
  /// the equipment strip, once under whichever Bölgeler chip matched).
  /// The equipment strip is now the only entry point for those plans.
  Future<List<WorkoutPlan>> getAllPlans() async {
    final exercises = await getAllExercises();
    final bySlug = {for (final e in exercises) e.id: e};
    return _regionalTemplates
        .map((t) => t.resolve(bySlug))
        .toList(growable: false);
  }

  // ==========================================================================
  // PROGRAM
  // Replaces the former `_staticProgram`: the 30-day schedule is now
  // generated on first load by [WorkoutGeneratorService] from the user's
  // stored goal + level, then cached as JSON in SharedPreferences under
  // [_planKey]. Subsequent launches read the cache so the plan is stable
  // across sessions until the user explicitly resets progress.
  // ==========================================================================

  /// Returns the user's 30-day plan with completion flags overlaid from
  /// local + remote progress. On a cold cache (or when a previous cache
  /// entry is unparseable), fetches the exercise catalogue and falls back
  /// to [generator] before persisting the result.
  ///
  /// `isStub == true` signals "no real plan available" — the cache was
  /// empty AND the live pool fetch returned nothing (offline first launch
  /// / catalogue fetch failure). The 30 rest-day fallback the generator
  /// returns in that case is renderable but is NOT a real plan; the UI
  /// must treat it as "data not yet loaded" rather than "all days
  /// complete", because [_firstIncomplete] would otherwise resolve to
  /// null on a list of empty rest days and the dashboard would mistake
  /// the placeholder for a finished program.
  Future<({List<WorkoutDay> days, bool isStub})> loadOrGenerateProgram({
    required WorkoutGeneratorService generator,
    String? userGoal,
    String? fitnessLevel,
    bool? hasEquipment,
  }) async {
    final completed = await _completedDays();
    // Phase 86 · the cache is keyed by an input fingerprint so a
    // profile-edit that changes goal or activity level invalidates the
    // stored plan instead of silently serving the old one.
    //
    // Phase 133 · [hasEquipment] joined the fingerprint so a user who
    // flips the equipment answer (back through onboarding, or via
    // future profile-edit) gets a fresh plan generated against the
    // new filter rather than reading a stale cache. Legacy installs
    // with `hasEquipment == null` collapse to `"true"` in the
    // fingerprint string so they hold their old fingerprint stable.
    final fingerprint = _fingerprint(userGoal, fitnessLevel, hasEquipment);
    final cached = _decodeCachedPlan(fingerprint);
    final List<WorkoutDay> plan;
    var isStub = false;
    if (cached != null) {
      plan = cached;
    } else {
      // Phase 50A · pool now comes from Supabase. The fetch is only
      // exercised on a cold plan cache; once a 30-day schedule is
      // persisted, we never re-touch the catalogue for plan generation
      // (only for ad-hoc regional / push-limits resolutions).
      final pool = await getAllExercises();
      // Empty pool ⇒ no cached plan + no fresh catalogue. The generator
      // returns a 30-rest-day list to keep the UI renderable, but flag
      // it so the dashboard can show "Senkronize ediliyor" instead of
      // "Tebrikler, tamamlandı".
      isStub = pool.isEmpty;
      plan = generator.generate30DayPlan(
        userGoal: userGoal ?? 'sixpack',
        fitnessLevel: fitnessLevel ?? 'beginner',
        pool: pool,
        // Legacy installs predate the equipment question — default to
        // `true` (= preserve existing mixed-exercise behaviour) so
        // they don't suddenly start filtering. Fresh installs always
        // pass an explicit bool through the wizard.
        hasEquipment: hasEquipment ?? true,
      );
      // Fire-and-forget — cache is advisory; if the write fails we'll
      // simply regenerate the same plan next launch (deterministic).
      // Empty-pool runs (offline first launch / fetch failure) return a
      // 30-rest-day stub from the generator; persisting that would mean
      // the next launch never retries the catalogue fetch, so skip the
      // write whenever the pool was empty.
      if (!isStub) {
        unawaited(_cachePlan(plan, fingerprint));
      }
    }
    final days = plan
        .map((day) =>
            day.copyWith(isCompleted: completed.contains(day.dayNumber)))
        .toList(growable: false);
    return (days: days, isStub: isStub);
  }

  /// Stable identity for the inputs that produced a cached plan. Null
  /// raw values collapse to empty strings so a transition from
  /// `null → "sixpack"` (i.e. user finishes onboarding for the first
  /// time) is detectable as a fingerprint change. [hasEquipment] joins
  /// the fingerprint (Phase 133) — `null` collapses to `"true"`
  /// because legacy installs that finished onboarding before the
  /// equipment question existed should keep their existing plan, and
  /// the generator treats null-equipment as "preserve current
  /// behaviour" (≡ has-equipment).
  String _fingerprint(
    String? userGoal,
    String? fitnessLevel,
    bool? hasEquipment,
  ) {
    final eqStr = (hasEquipment ?? true) ? 'true' : 'false';
    return '${userGoal ?? ''}|${fitnessLevel ?? ''}|$eqStr';
  }

  /// Reads + decodes the cached plan. Returns null for any failure mode:
  /// missing key, malformed JSON, wrong root type, enum drift, length
  /// mismatch, or a fingerprint mismatch — all of which mean
  /// "regenerate from scratch".
  List<WorkoutDay>? _decodeCachedPlan(String currentFingerprint) {
    final cachedFp = _prefs.getString(_planFingerprintKey);
    if (cachedFp != currentFingerprint) {
      // First-run + post-onboarding-edit both land here. Logging at
      // info-level so the structured log explains why a regeneration
      // happened on this launch — useful when a user reports their
      // plan unexpectedly changed.
      AppLogger.info(
        'WorkoutRepository · plan cache miss — input fingerprint changed',
        category: 'workout',
        data: {
          'cached_fingerprint': cachedFp ?? '',
          'current_fingerprint': currentFingerprint,
        },
      );
      return null;
    }
    final raw = _prefs.getString(_planKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      final days = decoded
          .map((e) => WorkoutDay.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
      // A partial write (power loss mid-save, say) would leave fewer
      // than 30 entries — treat as corrupt rather than serving a short
      // plan that silently fails the 30-day UI.
      if (days.length != 30) return null;
      return days;
    } catch (e, st) {
      AppLogger.warning(
        'WorkoutRepository: plan cache decode failed — regenerating',
        category: 'workout',
        data: {'error': e.toString(), 'stack': st.toString()},
      );
      return null;
    }
  }

  Future<void> _cachePlan(List<WorkoutDay> plan, String fingerprint) async {
    try {
      final encoded = jsonEncode(
        plan.map((d) => d.toJson()).toList(growable: false),
      );
      await _prefs.setString(_planKey, encoded);
      // Persist the fingerprint AFTER the plan write so a partial
      // success (plan written, fingerprint failed) leaves the cache
      // looking stale to the next read instead of looking valid against
      // an outdated identity. setString is independent per-key, but the
      // ordering still helps when both happen to fail.
      await _prefs.setString(_planFingerprintKey, fingerprint);
    } catch (e, st) {
      AppLogger.error(
        'WorkoutRepository: plan cache encode failed',
        e,
        stackTrace: st,
        category: 'workout',
      );
    }
  }

  Future<void> markDayCompleted(int dayNumber) async {
    final merged = _localCompleted()..add(dayNumber);
    await _saveLocal(merged);

    // Phase 52 · momentum retention. Schedule (or replace) a 48 h
    // streak-warning notification so a user who finishes a workout
    // gets a "before you lose your streak" ping before the day-3
    // dropoff. Fire-and-forget — the underlying scheduler is on a
    // platform channel that can take 30-100 ms, and we don't want
    // the completion flow to wait on it. Cancellation of the
    // previous warning happens inside the service.
    unawaited(NotificationService.instance.scheduleStreakWarning());

    final user = _client.auth.currentUser;
    if (user == null) {
      // Not yet signed in (first-run before auth completes, rare). Queue so
      // we can replay as soon as a session exists.
      await _queueSync(dayNumber);
      return;
    }
    if (!await _upsertCompleted(user.id, dayNumber)) {
      // Offline / network error — keep the local cache and remember to
      // flush this to Supabase the next time _completedDays() runs.
      await _queueSync(dayNumber);
    }
  }

  Future<void> resetProgress() async {
    await _prefs.remove(_completedKey);
    await _prefs.remove(_pendingSyncKey);
    // Drop the cached plan too — a full reset should yield a fresh
    // regeneration against whatever the user's current goal/level is.
    await _prefs.remove(_planKey);
    await _prefs.remove(_planFingerprintKey);
    // Progress Phase 2.A · session logs reference dayNumbers from the
    // completion ledger we're about to wipe. Drop them in lockstep so
    // the calendar drilldown can't surface "Gün 5 — 32 reps" against a
    // ledger that no longer thinks day 5 was done.
    await SessionLogRepository(_prefs).clearAll();
    // Progress Phase 5.D · clear the Year-in-Review seen flag so a
    // user who restarts the 30-day arc gets the Day-30 celebration
    // again on their next completion (otherwise the modal would feel
    // like it's "already been seen" forever).
    await AppPreferences(_prefs).clearSeenYearInReview();
    // Phase 52 · the user just wiped their streak, so the pending
    // 48 h "you'll lose your streak" warning would fire about a
    // streak that no longer exists. Cancel it.
    unawaited(NotificationService.instance.cancelStreakWarning());
  }

  Future<Set<int>> _completedDays() async {
    // Every time the program loads is a chance to retry dropped syncs —
    // cheap when the queue is empty, automatic recovery when it isn't.
    await _flushPending();

    final local = _localCompleted();
    final user = _client.auth.currentUser;
    if (user == null) return local;

    try {
      final rows = await _client
          .from(_progressTable)
          .select('day_number, is_completed')
          .eq('user_id', user.id)
          .eq('is_completed', true);
      final remote = <int>{
        for (final row in rows)
          if (row['day_number'] is int) row['day_number'] as int,
      };
      final merged = {...local, ...remote};
      if (merged.length != local.length) {
        await _saveLocal(merged);
      }
      return merged;
    } catch (_) {
      return local;
    }
  }

  /// Attempts a single upsert, returns true on success. Isolated so both the
  /// live markDayCompleted path and the background flush can share exactly
  /// the same write — no chance of drift between them.
  Future<bool> _upsertCompleted(String userId, int dayNumber) async {
    try {
      await _client.from(_progressTable).upsert(
        {
          'user_id': userId,
          'day_number': dayNumber,
          'is_completed': true,
          'completed_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,day_number',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Set<int> _pendingSync() {
    final raw = _prefs.getStringList(_pendingSyncKey) ?? const <String>[];
    return raw.map(int.tryParse).whereType<int>().toSet();
  }

  Future<void> _savePending(Set<int> days) async {
    if (days.isEmpty) {
      await _prefs.remove(_pendingSyncKey);
      return;
    }
    await _prefs.setStringList(
      _pendingSyncKey,
      days.map((e) => e.toString()).toList(),
    );
  }

  Future<void> _queueSync(int dayNumber) async {
    final pending = _pendingSync()..add(dayNumber);
    await _savePending(pending);
  }

  /// Replays any completions that failed to reach Supabase. Anything that
  /// succeeds is removed from the queue; anything that still fails stays
  /// queued for the next flush. Anonymous→real upgrades keep the same
  /// user_id (see auth_screen._submit), so queued rows sync cleanly once
  /// the user signs up.
  Future<void> _flushPending() async {
    final pending = _pendingSync();
    if (pending.isEmpty) return;
    final user = _client.auth.currentUser;
    if (user == null) return;

    final remaining = <int>{};
    for (final dayNumber in pending) {
      final ok = await _upsertCompleted(user.id, dayNumber);
      if (!ok) remaining.add(dayNumber);
    }
    if (remaining.length != pending.length) {
      await _savePending(remaining);
    }
  }

  Set<int> _localCompleted() {
    final raw = _prefs.getStringList(_completedKey) ?? const <String>[];
    return raw.map(int.tryParse).whereType<int>().toSet();
  }

  Future<void> _saveLocal(Set<int> days) async {
    await _prefs.setStringList(
      _completedKey,
      days.map((e) => e.toString()).toList(),
    );
  }
}

/// Internal description of a [WorkoutPlan] keyed by exercise slugs. The
/// concrete `WorkoutPlan` is rebuilt on demand from [resolve] against
/// whatever exercises Supabase currently exposes — that decoupling is
/// what lets a deleted exercise just shrink a plan instead of crashing
/// the antrenman tab.
class _PlanTemplate {
  const _PlanTemplate({
    required this.id,
    required this.title,
    required this.category,
    required this.level,
    required this.durationMinutes,
    required this.exerciseSlugs,
    this.image,
    this.premiumExerciseSlugs = const [],
  });

  final String id;
  final String title;
  final ExerciseCategory category;
  final String level;
  final int durationMinutes;
  final List<String> exerciseSlugs;
  final String? image;

  /// Phase 98 · second tier of slugs surfaced by the plan-detail screen
  /// as the "Premium Seviye" launcher. Empty for plans without a premium
  /// upgrade (every regional bodyweight card stays single-button); the 7
  /// equipment programs populate this with Phase 96 advanced movements.
  final List<String> premiumExerciseSlugs;

  WorkoutPlan resolve(Map<String, Exercise> bySlug) {
    return WorkoutPlan(
      id: id,
      title: title,
      category: category,
      level: level,
      durationMinutes: durationMinutes,
      image: image,
      exercises: exerciseSlugs
          .map((s) => bySlug[s])
          .whereType<Exercise>()
          .toList(growable: false),
      premiumExercises: premiumExerciseSlugs
          .map((s) => bySlug[s])
          .whereType<Exercise>()
          .toList(growable: false),
    );
  }
}
