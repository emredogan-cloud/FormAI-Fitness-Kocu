import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/notification_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/media_url.dart';
import '../../../core/utils/string_case.dart';
import '../domain/services/workout_generator_service.dart';
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
  // Bumped v3 → v4 in phase 75: the cached plan stores resolved
  // `videoUrl` strings on each exercise, and pre-75 plans baked in the
  // old `video_url`-column-derived URLs (which were lowercased / 404ing
  // against case-sensitive Storage). The key bump forces a one-shot
  // regeneration so the slug-to-PascalCase URLs land on existing installs
  // without users having to "Reset progress" by hand.
  static const String _planKey = 'sixpack.user_custom_plan_v4';
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
  // "SINIRLARINI ZORLA" + REGIONAL PLAN TEMPLATES
  // ==========================================================================
  // Plans are defined as static templates (id + slug list); resolution
  // against the live exercise catalogue happens lazily in
  // [getAllPlans] / [getPushLimitsPlans]. Slugs that don't resolve are
  // silently dropped, so deleting an exercise in Supabase doesn't crash
  // the dashboard — the affected plan just gets shorter.
  // ==========================================================================

  static const List<_PlanTemplate> _pushLimitsTemplates = [
    _PlanTemplate(
      id: 'push_limits_abs_hiit',
      title: 'Belirgin Karın Kasları HIIT',
      category: ExerciseCategory.core,
      level: 'Orta düzey',
      durationMinutes: 19,
      exerciseSlugs: [
        'mountain_climber',
        'bicycle_crunch',
        'crunch',
        'leg_raise',
        'plank',
      ],
      image: 'photos/workouts/push_limits_abs_hiit.webp',
    ),
    _PlanTemplate(
      id: 'push_limits_stronger_core',
      title: 'Daha Güçlü Şekil ve Çekirdek',
      category: ExerciseCategory.core,
      level: 'Orta düzey',
      durationMinutes: 24,
      exerciseSlugs: [
        'russian_twist',
        'leg_raise',
        'plank',
        'situp',
        'bicycle_crunch',
      ],
      image: 'photos/workouts/push_limits_stronger_core.webp',
    ),
    _PlanTemplate(
      id: 'push_limits_iron_pack',
      title: 'Demir Altı Paket Gücü',
      category: ExerciseCategory.core,
      level: 'İleri',
      durationMinutes: 18,
      exerciseSlugs: [
        'hanging_leg_raise',
        'crunch',
        'russian_twist',
        'plank',
        'flutter_kick',
      ],
      image: 'photos/workouts/push_limits_iron_pack.webp',
    ),
    _PlanTemplate(
      id: 'push_limits_athletic_core',
      title: 'Atletik Core Kontrolü',
      category: ExerciseCategory.core,
      level: 'Başlangıç',
      durationMinutes: 15,
      exerciseSlugs: [
        'plank',
        'bicycle_crunch',
        'crunch',
        'flutter_kick',
      ],
      image: 'photos/workouts/push_limits_athletic_core.webp',
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
  ];

  /// Materialised Sınırlarını Zorla cards. Resolves the four templates
  /// against the fetched catalogue; missing slugs drop out silently.
  Future<List<WorkoutPlan>> getPushLimitsPlans() async {
    final exercises = await getAllExercises();
    final bySlug = {for (final e in exercises) e.id: e};
    return _pushLimitsTemplates
        .map((t) => t.resolve(bySlug))
        .toList(growable: false);
  }

  /// Materialised regional + Sınırlarını Zorla plan list, in the same
  /// order the dashboard renders them. The strip on the home tab pulls
  /// the four push-limits cards via [getPushLimitsPlans] for tinting,
  /// but the regional list still expects them at the head of the array.
  Future<List<WorkoutPlan>> getAllPlans() async {
    final exercises = await getAllExercises();
    final bySlug = {for (final e in exercises) e.id: e};
    return [
      ..._pushLimitsTemplates.map((t) => t.resolve(bySlug)),
      ..._regionalTemplates.map((t) => t.resolve(bySlug)),
    ];
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
  Future<List<WorkoutDay>> loadOrGenerateProgram({
    required WorkoutGeneratorService generator,
    String? userGoal,
    String? fitnessLevel,
  }) async {
    final completed = await _completedDays();
    final cached = _decodeCachedPlan();
    final List<WorkoutDay> plan;
    if (cached != null) {
      plan = cached;
    } else {
      // Phase 50A · pool now comes from Supabase. The fetch is only
      // exercised on a cold plan cache; once a 30-day schedule is
      // persisted, we never re-touch the catalogue for plan generation
      // (only for ad-hoc regional / push-limits resolutions).
      final pool = await getAllExercises();
      plan = generator.generate30DayPlan(
        userGoal: userGoal ?? 'sixpack',
        fitnessLevel: fitnessLevel ?? 'beginner',
        pool: pool,
      );
      // Fire-and-forget — cache is advisory; if the write fails we'll
      // simply regenerate the same plan next launch (deterministic).
      // Empty-pool runs (offline first launch / fetch failure) return a
      // 30-rest-day stub from the generator; persisting that would mean
      // the next launch never retries the catalogue fetch, so skip the
      // write whenever the pool was empty.
      if (pool.isNotEmpty) {
        unawaited(_cachePlan(plan));
      }
    }
    return plan
        .map((day) =>
            day.copyWith(isCompleted: completed.contains(day.dayNumber)))
        .toList(growable: false);
  }

  /// Reads + decodes the cached plan. Returns null for any failure mode:
  /// missing key, malformed JSON, wrong root type, enum drift, or a
  /// length mismatch — all of which mean "regenerate from scratch".
  List<WorkoutDay>? _decodeCachedPlan() {
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

  Future<void> _cachePlan(List<WorkoutDay> plan) async {
    try {
      final encoded = jsonEncode(
        plan.map((d) => d.toJson()).toList(growable: false),
      );
      await _prefs.setString(_planKey, encoded);
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
  });

  final String id;
  final String title;
  final ExerciseCategory category;
  final String level;
  final int durationMinutes;
  final List<String> exerciseSlugs;
  final String? image;

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
    );
  }
}
