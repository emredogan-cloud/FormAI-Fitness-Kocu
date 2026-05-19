# Workout System Analysis

**Status:** read-only audit. No production code or SQL has been mutated by this report.
**Generated:** 2026-05-09
**Scope:** Everything that contributes to the in-app exercise experience — schema, catalogue, ML pose detection, plan generation, playback, and asset pipeline.

---

## 0. TL;DR

- **Stack:** Flutter + Dart, Riverpod state, Supabase Postgres + Storage backend, Google ML Kit Pose Detection on-device.
- **Catalogue lives in Supabase** (`public.exercises` table), seeded from `supabase/sql/exercises_migration.sql` (41 rows · Phase 50A) and `supabase/sql/phase85_equipment_exercises.sql` (10 rows · Phase 85). **Total: 51 exercises.**
- **Schema is fixed and narrow** — only **7 category enum values** and the in-Dart `targetMuscle` is a single string drawn from {`core`, `upper_body`, `lower_body`, `full_body`, `cardio`}. `target_muscles` is a `text[]` in the DB but only element [0] is currently consumed.
- **Video URLs are auto-composed** from `slug` (snake_case → PascalCase + `.mp4`, resolved against the `exercises` Storage bucket via `MediaUrl.resolve`). The DB's `video_url` column is intentionally ignored.
- **17 distinct pose analyzers** cover ~25 unique slugs via a slug → analyzer switch in `analyzer_factory.dart`. Unmapped slugs default to `SilentHoldAnalyzer` (no rep counting, no form warnings, throttled encouragement).
- **Plans are static templates** of slug lists; missing slugs drop out silently (no crash).
- **Plan cache is fingerprinted** (`goal:level`) at `_planFingerprintKey` v5 — adding new exercises does NOT invalidate cached plans, but changing the generator behaviour does.

---

## 1. Data Model

### 1.1 `Exercise` (Dart) — `lib/features/workout/models/exercise_model.dart:5`

```dart
class Exercise {
  final String id;                      // = Supabase `slug`
  final String name;                    // Turkish display name
  final ExerciseType type;              // repBased | timeBased
  final int? targetReps;
  final int? targetDurationInSeconds;
  final String? videoUrl;               // composed, NOT read from DB
  final int sets;                       // default 1 in code, 3 in DB
  final int restDurationInSeconds;      // default 30
  final ExerciseCategory category;      // enum, 7 values (see 1.3)
  final String description;             // long-form Turkish "HAZIRLAN!" text
  final String shortTip;                // 4-6 word in-set pill
  final String difficulty;              // free string: 'beginner'|'intermediate'|'advanced'
  final String targetMuscle;            // free string: see 1.4
  final bool isCardio;                  // generator gate for HIIT density
}
```

Cache compatibility: `Exercise.fromJson` THROWS on unknown `ExerciseType`/missing primitives (the plan cache catches and regenerates). Adding new enum values to `ExerciseCategory` would force a cache regeneration on first launch but is otherwise safe — the JSON falls back to `core` if unknown.

### 1.2 Supabase row — `public.exercises` (`supabase/sql/exercises_migration.sql:47`)

```sql
CREATE TABLE public.exercises (
  id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug                        text UNIQUE NOT NULL,
  name                        text NOT NULL,
  type                        text NOT NULL CHECK (type IN ('repBased','timeBased')),
  category                    text NOT NULL CHECK (category IN
                                ('core','chest','legs','back','arms','shoulders','fullBody')),
  difficulty                  text NOT NULL CHECK (difficulty IN
                                ('beginner','intermediate','advanced')),
  target_muscles              text[] NOT NULL DEFAULT '{}',
  target_reps                 int,
  target_duration_in_seconds  int,
  sets                        int NOT NULL DEFAULT 3,
  rest_duration_in_seconds    int NOT NULL DEFAULT 30,
  is_cardio                   boolean NOT NULL DEFAULT false,
  instructions                text NOT NULL DEFAULT '',
  short_tip                   text NOT NULL DEFAULT '',
  video_url                   text,                           -- IGNORED at read time
  thumbnail_url               text,                           -- not currently consumed
  created_at                  timestamptz DEFAULT now(),
  updated_at                  timestamptz DEFAULT now()       -- auto-bumped via trigger
);
```

GIN index on `target_muscles` exists; sub-tag queries are already cheap server-side.

### 1.3 `ExerciseCategory` enum — **HARD CONSTRAINT**

```dart
enum ExerciseCategory { core, chest, legs, back, arms, shoulders, fullBody }
```

These are the **only** category buckets the app understands:
- The DB CHECK constraint enforces them.
- The `analyzer_factory` switch keys off `exercise.id`, but the UI strip filters by category.
- Adding `biceps` / `triceps` / `glutes` / `quads` / `hiit` / `mobility` / `stretching` requires:
  1. New DB CHECK values (or relaxing the constraint),
  2. A schema migration in `supabase/sql/`,
  3. Bumping `_planKey` to invalidate cached plans (Phase 86 fingerprint pattern),
  4. Likely a new chip in the dashboard "Bölgeler" strip.

### 1.4 `targetMuscle` (Dart string) vs `target_muscles` (Postgres `text[]`)

- DB: `text[]` — currently every shipped row contains a single-element array.
- Dart: `targetMuscle` reads only element [0] via `_firstTargetMuscle()` (`workout_repository.dart:197`).
- Conventional values seen in seed: `core`, `upper_body`, `lower_body`, `full_body`, `cardio`.
- The generator uses `targetMuscle` to balance routines; the array is forward-compat for sub-muscle tagging that the UI does not yet read.

---

## 2. Catalogue Pipeline

### 2.1 Read path — `WorkoutRepository.getAllExercises()`

`lib/features/workout/data/workout_repository.dart:88`

1. Connectivity gate (offline → return `const []`, drop the in-flight future so the next call retries).
2. `client.from('exercises').select().order('slug')`.
3. Per-row hydration via `_exerciseFromRow` (line 171):
   - `slug → id`,
   - `target_muscles[0] → targetMuscle`,
   - `instructions → description`,
   - `video_url` IGNORED, `videoUrl` composed via `_composeVideoUrl(slug)`.
4. Future memoised on the instance + Riverpod-level dedup in `exercisesProvider`.

Failure mode: empty list (never null). The plan generator's `dailyPool.isEmpty` branch gracefully falls through to a 30-rest-day "stub" and the dashboard treats it as "Senkronize ediliyor", not "complete".

### 2.2 Video URL composition — `_composeVideoUrl(slug)` — line 221

```
slug = 'incline_bench_press'
       → trim + remove whitespace
       → StringCase.snakeToPascal → 'InclineBenchPress'
       → '.mp4' suffix → 'InclineBenchPress.mp4'
       → MediaUrl.resolve(filename, bucket: 'exercises')
       → final URL: {SUPABASE_URL}/storage/v1/object/public/exercises/InclineBenchPress.mp4
                    or {CDN_BASE_URL}/exercises/InclineBenchPress.mp4 if configured
```

**Implication for new exercises:** every new slug MUST produce a valid PascalCase filename. Slugs with unconventional characters or accidental trailing whitespace produce 404s (Phase 79 hardened the trim path).

### 2.3 Storage bucket

- Bucket: `exercises` (public).
- Filenames: PascalCase + `.mp4` (e.g. `Crunch.mp4`, `BarbellSquat.mp4`).
- Two assets in current seed deviate from convention but still resolve: `LegRaise_demo.mp4` (legacy underscore + suffix) and `HighKness.mp4` (typo preserved deliberately).
- Thumbnails: `thumbnail_url` column exists but is unused by `ExerciseGuidePlayer`; it falls back to a neon `_FallbackTile` until video loads.

### 2.4 Asset playback — `ExerciseGuidePlayer`

`lib/features/workout/presentation/widgets/exercise_guide_player.dart`

- Network-only video (Phase 76); non-`http(s)` paths fall back to `_FallbackTile`.
- Image extensions (`.jpg/.png/.webp/etc.`) render via `Image.asset` (no remote image support today).
- Phase 51 cache: hit → `VideoPlayerController.file`; miss → network controller + background `cacheManager.downloadFile` warm.
- Phase 77+79: trims quotes (curly + ASCII) and `Uri.encodeFull` before handing to ExoPlayer.
- Failure → `_FallbackTile(errorMode: true)` shows "Video yüklenemedi" + the exercise name.

---

## 3. Pose / ML Kit Architecture

### 3.1 Detector — `PoseDetectorService` — single-image stream mode

`lib/features/workout/services/pose_detector_service.dart`

Wraps `google_mlkit_pose_detection`'s `PoseDetector` in `PoseDetectionMode.stream`. Returns `List<Pose>`; analyzers consume the first.

### 3.2 Analyzer interface — `PoseAnalyzer`

`lib/features/workout/services/pose_analyzer.dart`

```dart
abstract class PoseAnalyzer {
  CrunchResult analyze(Pose pose);
  void reset();
}
```

`CrunchResult` (kept under that name for back-compat with the original crunch-only flow) is the universal frame output:

```dart
class CrunchResult {
  final int reps;
  final CrunchState state;            // unknown | down | up
  final double? torsoAngle;           // debug-only, varies by analyzer
  final double? neckAngle;            // crunch-specific
  final String? formWarning;          // e.g. "Boynunu düz tut!"
  final bool repJustCompleted;
  final String? pacingFeedback;       // throttled "slow down" / "keep going"
  final String? contextualCue;        // throttled phase guidance (e.g. burpee)
}
```

### 3.3 Analyzer roster — 17 distinct classes

| Analyzer | Detection mechanic | Landmarks | Routes from these slugs |
|---|---|---|---|
| `CrunchAnalyzer` | Torso angle (shoulder-hip-knee) DOWN→UP | shoulder, hip, knee, ear (form) | `crunch`, `situp` |
| `PlankAnalyzer` | Body-line angle sag (shoulder-hip-ankle < 155°) | shoulder, hip, ankle | `plank` |
| `LegRaiseAnalyzer` | Hip angle (shoulder-hip-ankle) DOWN→UP | shoulder, hip, ankle | `leg_raise`, `hanging_leg_raise` |
| `RussianTwistAnalyzer` | Shoulder-mid vs hip-mid horizontal offset, side flips | shoulders, hips | `russian_twist` |
| `MountainClimberAnalyzer` | Knee→same-side-shoulder distance, alternating sides | shoulders, hips, knees | `mountain_climber` |
| `BicycleCrunchAnalyzer` | Cross-pair elbow↔knee distance, side flips | elbows, knees, shoulders | `bicycle_crunch` |
| `FlutterKickAnalyzer` | Ankle-y delta side flips | ankles | `flutter_kick` |
| `PushUpAnalyzer` | Elbow flexion (shoulder-elbow-wrist) | shoulder, elbow, wrist | `push_up`, `incline_push_up`, `decline_push_up`, `chest_dip`, `pike_push_up`, `triceps_dip`, `close_grip_push_up` |
| `BenchPressAnalyzer` | PushUp subclass, tighter ROM | shoulder, elbow, wrist | `bench_press` |
| `ChestFlyAnalyzer` | Wrist gap / shoulder width (open→close→open) | shoulders, wrists | `chest_fly` |
| `SquatAnalyzer` | Knee angle (hip-knee-ankle) DOWN→UP | hip, knee, ankle | `squat`, `lunge`, `bulgarian_split_squat`, `leg_press`, `jump_squat` |
| `PullUpAnalyzer` | Elbow flexion inverted (DOWN = arms long, UP = pulled in) | shoulder, elbow, wrist | `pull_up`, `chin_up`, `lat_pulldown`, `barbell_row` |
| `BicepsCurlAnalyzer` | Elbow flexion tighter (UP < 50°, DOWN > 150°) | shoulder, elbow, wrist | `biceps_curl`, `hammer_curl`, `triceps_pushdown` |
| `ShoulderPressAnalyzer` | Wrist Y vs shoulder Y delta with partial-range warning | shoulders, wrists | `shoulder_press`, `arnold_press` |
| `LateralRaiseAnalyzer` | Shoulder vertex angle (elbow-shoulder-hip) | shoulder, elbow, hip | `lateral_raise`, `front_raise` |
| `JumpingJackAnalyzer` | Ankle spread + wrist height combined | shoulders, ankles, wrists | `jumping_jack` |
| `BurpeeAnalyzer` | 3-state phase machine via shoulder Y self-calibrated min/max | shoulder | `burpee` |
| `SilentHoldAnalyzer` | Neutral (no rep, no warning, throttled encouragement every 18 s) | none | `wall_sit`, `calf_raise`, `superman`, `high_knees`, `skipping_rope`, plus default fallback |

### 3.4 Routing — `analyzer_factory.dart::analyzerFor(exercise)`

Switch on `exercise.id`. Default → `SilentHoldAnalyzer`. **Critical:** the factory was deliberately switched (Phase 30-ish) to fall back to `SilentHoldAnalyzer` rather than `CrunchAnalyzer` because the previous misroute would tick rep counters on unrelated movements.

### 3.5 Form-correction & coaching emit pipeline

- Each analyzer can emit `formWarning` (throttled per-analyzer, typically 8-15 s cooldown).
- `pacingFeedback` & `contextualCue` flow through to TTS in `workout_camera_screen.dart`.
- `_pickHigher` / per-side fallback is the standard pattern: one occluded side does not break detection.
- Likelihood < 0.4 on any required landmark → frame is dropped (no false rep).

### 3.6 ML detectability fence

A new exercise can claim **real ML rep counting only if** its dominant joint motion matches one of the existing analyzers' geometries. New movements that don't fit (wrist rotation, grip work, balance holds, dynamic mobility flows) must route to `SilentHoldAnalyzer` and be presented as time-based holds. Failing to do this surfaces phantom reps or constant misfires — exactly the bug Phase 30 fixed.

---

## 4. Plan Generation & Templates

### 4.1 Generator — `WorkoutGeneratorService.generate30DayPlan(...)`

Consumed by `WorkoutRepository.loadOrGenerateProgram()`. Inputs:

- `userGoal` (default `'sixpack'`, Phase 86 default switched from `'sixpack'` to `'tone'` on empty onboarding),
- `fitnessLevel` (default `'beginner'`),
- `pool: List<Exercise>` (the entire catalogue from Supabase).

Output: `List<WorkoutDay>` of length 30. Empty pool → 30 rest days (`isStub: true` flag for the dashboard).

### 4.2 Plan templates — `_PlanTemplate` (static slug lists)

`workout_repository.dart:932`

Two static lists keyed by exercise slug:

- `_equipmentTemplates` (7) — drives the "Ekipmanlı Egzersizler" dashboard strip.
- `_regionalTemplates` (~17) — drives the "Bölgeler" chip strip per category.

Resolution: `WorkoutPlan resolve(Map<String, Exercise> bySlug)` — missing slugs are silently dropped (the plan just gets shorter). **Adding new exercises does not require touching these templates; touching templates is only required when surfacing a new card.**

### 4.3 Cache — `_planKey` / `_planFingerprintKey` v5

- `_planKey` = `sixpack.user_custom_plan_v5` — JSON-encoded list of `WorkoutDay`.
- `_planFingerprintKey` = `sixpack.user_custom_plan_fingerprint_v5` — `'goal|level'` string.
- Adding new exercises to Supabase **does not** invalidate the cache. The new exercises appear in next-launch regenerations only after the user changes goal/level, calls `resetProgress()`, or we bump `_planKey` to v6.

---

## 5. Workout UX Flow

### 5.1 Pre-exercise overlay — "HAZIRLAN!"

Triggered before each exercise starts. Shows:

- 3-second countdown + the **PIP video preview** via `ExerciseGuidePlayer` looping the `videoUrl`,
- Exercise **`name`** and long-form **`description`** Turkish text,
- TTS reads `description` (handled in `workout_camera_screen.dart`).

### 5.2 During exercise

- Live camera feed + `PosePainter` overlay.
- Per-frame analyzer output:
  - `reps` driving the on-screen rep counter,
  - `formWarning` → TTS + visual flash,
  - `pacingFeedback` → "biraz yavaşla, kaslarını hisset" / "hadi pes etme",
  - `contextualCue` → phase guidance (e.g. burpee step-2 line),
- Translucent **`shortTip`** pill above the camera control panel for the duration of the active set.
- Time-based exercises (plank, wall_sit, calf_raise, superman, high_knees, skipping_rope, jumping_jack, flutter_kick, jump_squat, …) run the timer + analyzer in parallel; rep-based count up to `targetReps`.

### 5.3 Post-set transitions

Rest screen counts down `restDurationInSeconds`, then the next set or next exercise starts. Set completion reset is handled in the camera screen state machine.

---

## 6. State / Provider Wiring

`lib/features/workout/providers/workout_provider.dart` exposes:

- `exercisesProvider` — Riverpod-coalesced read of the catalogue.
- Plan / day providers driving the 30-day program tab.

Riverpod-side dedup means concurrent UI consumers share one network round-trip per app lifetime (see `_exercisesFuture` memoisation in the repository).

---

## 7. Localization & Naming Conventions

- **All user-visible text is Turkish.** New exercises must follow:
  - `name`: Turkish display ("Mekik", "Yokuş Yukarı Şınav"). Loanwords (Bench Press, Curl) are kept in English when standard in TR fitness vernacular.
  - `description`: 1–2 sentence Turkish "HAZIRLAN!" guidance, ends in a complete thought, no trailing ellipsis.
  - `short_tip`: 4–6 word Turkish coaching pill, imperative voice ("Boyuna asma, karnınla çek.").
- **Slug:** lowercase snake_case. **Must** Pascal-case cleanly (no hyphens, accents, or Turkish characters).
- **Filename:** PascalCase + `.mp4`. Trailing `_demo` was used once (`LegRaise_demo.mp4`) and is supported but not preferred.
- **Difficulty:** the three string values; capital-letter Turkish equivalents (`Başlangıç` / `Orta düzey` / `İleri`) are used in `_PlanTemplate.level` only, not on the row.

---

## 8. Phase History Touchpoints (load-bearing notes)

These are not just history — they constrain what you can safely do next.

- **Phase 50A** lifted 41 hard-coded exercises into Supabase. The `static final Exercise _crunch = ...` literals are gone; the SQL is now the source.
- **Phase 75** swapped video URL composition from the row column to the slug-derived path. Don't try to re-introduce the row column.
- **Phase 76** banned non-`http(s)` video paths in `ExerciseGuidePlayer`. New exercises CANNOT ship a bundled-asset video.
- **Phase 77/79** added quote-strip + `Uri.encodeFull` sanitisation. New slugs with Unicode or stray whitespace will break.
- **Phase 79 retro** (per memory): forcing a native dep version without verifying the wrapper's required version downgraded ML Kit pose detection by accident. Anything touching `pubspec.yaml` for `google_mlkit_*` must verify the wrapper's `android/build.gradle` first.
- **Phase 85** added the equipment strip. The seven equipment templates now own the bicep/tricep/leg/core equipment surfacing.
- **Phase 86** introduced the input-fingerprint plan cache. Adding categories or changing the generator's bucket weights silently invalidates plans on next launch — surface the change so QA expects it.
- **Phase 89** added the offline short-circuit. The empty-pool path is graceful, not a crash.
- **Phase 94** is the release-build resilience layer. New code that touches camera permissions / native plugins must respect the 4-layer error guard pattern.

---

## 9. Inputs to the Gap Analysis

Carried forward into `workout-system-gap-analysis.md`:

1. **51 existing exercises across 7 categories.**
2. **17 analyzers covering ~25 slugs.** Anything outside this geometry routes to silent.
3. **Schema cap:** 7 categories, 5 conventional `targetMuscle` strings.
4. **Asset reality:** every new exercise needs a PascalCase `.mp4` rendered + uploaded; until then, the player shows the fallback tile.
5. **Cache reality:** new rows do not auto-surface in cached plans without bumping `_planKey` or the user editing goal/level.
6. **Production safety memory:** halt before mutating shared/production state; produce diagnosis + artifact; await sign-off.

---

End of analysis.
