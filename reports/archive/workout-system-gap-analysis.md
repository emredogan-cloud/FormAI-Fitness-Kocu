# Workout System — Gap Analysis & Expansion Decision Brief

**Status:** read-only analysis. **No code, SQL, or Supabase rows have been mutated.**
**Generated:** 2026-05-09
**Companion to:** `workout-system-analysis.md`
**Audience:** the human who must approve scope before Phase 96 expansion lands.

---

## 0. TL;DR — what needs your decision before I generate exercises

The user prompt asks for:

> **5+ exercises per muscle group** for **18 muscle groups** × **2 equipment categories** (= ~180 new exercises minimum), each with ML detection, Kling video prompt, full schema metadata, and direct file modifications.

Doing that literally **conflicts with the existing system in 4 places**. I need your call on each before I ship a single new row.

| # | Conflict | Default-safe path | Aggressive path |
|---|---|---|---|
| **A** | Codebase has only **7 category enums** (`core, chest, legs, back, arms, shoulders, fullBody`). User asked for **18 groups** including Biceps/Triceps/Forearms/Glutes/Quads/Hamstrings/Calves/HIIT/Mobility/Stretching. | **Map sub-groups via `target_muscles[]` array** (already a `text[]` in DB, GIN-indexed, unused beyond element [0]). No schema migration. UI strip stays unchanged. | Expand `ExerciseCategory` enum + DB CHECK + plan templates + chip strip. Bumps `_planKey` to v6, schema migration, multi-screen UX work. |
| **B** | Only **17 ML analyzers** map to specific joint geometries. Forearm rotation, grip work, balance holds, dynamic stretching, foam-rolling, mobility flows have **no ML coverage**. | Constrain new exercises to movements that route to an existing analyzer **or** explicitly use `SilentHoldAnalyzer` (no rep counting, time-based holds with throttled encouragement). | Build new analyzers (each is 60–120 LOC + threshold tuning + per-exercise QA on real video) — adds weeks of work. |
| **C** | **5 × 2 × 18 = ~180 exercises** — many cells (e.g. *Forearms equipment beginner*, *HIIT bodyweight*, *Calves equipment*) cannot be filled with 5 high-quality, ML-compatible, biomechanically distinct movements. Forcing the quota produces filler. | **Aim for quality:** ~60–90 high-quality net-new exercises, balanced across the 7 real category buckets, with `target_muscles[]` sub-tagging. Strict-quota cells get whatever count makes sense (often 2–3, occasionally 5+). | Pad to 180+ with low-confidence variants (3-second-hold-with-towel "Forearm Static Grip" filler). I do not recommend this. |
| **D** | **Videos must be rendered + uploaded** to the `exercises` Supabase Storage bucket. The pipeline accepts only `http(s)` URLs and PascalCase filenames. Until videos land, every new exercise shows the neon `_FallbackTile` ("Video yüklenemedi" looks identical to "render in progress" without context). | **Generate all Kling AI prompts in `exercise-video-prompts.md`** as a deliverable; flag the empty-tile state as expected; ship the SQL + analyzer wiring; videos are rendered + uploaded out-of-band. | Block the SQL/code expansion until videos exist. Worst of both worlds — delays user-visible value behind a content production lag. |

**My recommendation: A1 + B1 + C1 + D1** (the safe paths above). It honors the user's intent (massive expansion, ML-aware, video-prompt-ready) while respecting Phase 50A–94's load-bearing constraints.

---

## 1. Current Coverage Inventory

### 1.1 By category (51 total)

| Category | Count | Beginner | Intermediate | Advanced | Time-based | Equipment-leaning slugs |
|---|---|---|---|---|---|---|
| `core` | 12 | 7 | 4 | 1 | 2 (`plank`, `flutter_kick`) | `cable_crunch`, `weighted_russian_twist`, `ab_wheel_rollout`, `hanging_leg_raise` |
| `chest` | 7 | 1 | 4 | 2 | 0 | `bench_press`, `incline_bench_press`, `chest_fly`, `chest_dip` |
| `legs` | 10 | 5 | 3 | 2 | 2 (`calf_raise`, `wall_sit`) | `barbell_squat`, `romanian_deadlift`, `leg_extension`, `leg_curl`, `leg_press` |
| `back` | 5 | 1 | 2 | 2 | 1 (`superman`) | `lat_pulldown`, `barbell_row`, `pull_up`, `chin_up` |
| `shoulders` | 5 | 2 | 2 | 1 | 0 | `shoulder_press`, `arnold_press`, `lateral_raise`, `front_raise` |
| `arms` | 7 | 3 | 3 | 0 | 0 | `concentration_curl`, `skull_crusher`, `triceps_pushdown`, `biceps_curl`, `hammer_curl` |
| `fullBody` | 5 | 3 | 1 | 1 | 3 (`jumping_jack`, `high_knees`, `skipping_rope`) | (none — all bodyweight) |

### 1.2 Equipment vs bodyweight breakdown (using the slug curation in `_equipmentTemplates`)

| Bucket | Equipment | Bodyweight | Notes |
|---|---|---|---|
| chest | 4 (`bench_press`, `incline_bench_press`, `chest_fly`, `chest_dip`) | 3 (`push_up`, `incline_push_up`, `decline_push_up`) | dip is borderline (parallel bars) |
| back | 4 (`pull_up`, `lat_pulldown`, `barbell_row`, `chin_up`) | 1 (`superman`) | pull/chin-up need a bar = "equipment" |
| shoulders | 4 (`shoulder_press`, `arnold_press`, `lateral_raise`, `front_raise`) | 1 (`pike_push_up`) | |
| biceps | 3 (`biceps_curl`, `hammer_curl`, `concentration_curl`) | 0 | |
| triceps | 3 (`triceps_pushdown`, `skull_crusher`, `triceps_dip`) | 1 (`close_grip_push_up`) | dip again borderline |
| legs | 5 (`barbell_squat`, `leg_press`, `romanian_deadlift`, `leg_extension`, `leg_curl`) | 5 (`squat`, `lunge`, `bulgarian_split_squat`, `calf_raise`, `wall_sit`) | balanced |
| core | 4 (`cable_crunch`, `hanging_leg_raise`, `weighted_russian_twist`, `ab_wheel_rollout`) | 8 | rich bodyweight |
| cardio | 0 (no equipment cardio yet) | 5 (`burpee`, `jumping_jack`, `high_knees`, `jump_squat`, `skipping_rope`) | rope counts as minimal-equipment |

### 1.3 Underrepresented vs the user's 18-group ask

Mapping the requested 18 groups against existing coverage (✅ = adequate, 🟡 = thin, ❌ = absent):

| Requested group | Existing slugs (mapped via primary muscle worked) | Status |
|---|---|---|
| **Chest** | 7 | ✅ but missing decline-bench, cable crossover, push-up variants (diamond, archer, pseudo-planche) |
| **Back** | 5 | 🟡 missing: t-bar row, dumbbell row, face pull, hyperextension, inverted row, single-arm row |
| **Shoulders** | 5 | 🟡 missing: rear delt fly, upright row, handstand hold, cuban press, scapular wall slides |
| **Biceps** | 3 (`biceps_curl`, `hammer_curl`, `concentration_curl`) | 🟡 missing: preacher curl, incline curl, cable curl, chin-up isolated |
| **Triceps** | 4 (`triceps_pushdown`, `skull_crusher`, `triceps_dip`, `close_grip_push_up`) | 🟡 missing: overhead extension, kickback, diamond push-up, bench dip |
| **Forearms** | 0 (none isolated) | ❌ wrist curl, reverse curl, farmer carry, dead hang — none are reliably ML-detectable |
| **Core** | 12 | ✅ thorough |
| **Abs** (⊂ core) | already merged | ✅ |
| **Obliques** (⊂ core) | russian_twist + weighted_russian_twist + bicycle_crunch | ✅ |
| **Glutes** (⊂ legs) | indirectly via squat/lunge variants | 🟡 missing: hip thrust, glute bridge, kickback, frog pump, cable pull-through |
| **Quads** (⊂ legs) | squat-family is quad-dominant | ✅ |
| **Hamstrings** (⊂ legs) | `romanian_deadlift`, `leg_curl` | 🟡 missing: nordic curl, single-leg RDL, good morning, glute-ham raise |
| **Calves** (⊂ legs) | `calf_raise` only | 🟡 missing: seated calf raise, single-leg calf raise, donkey calf raise, jump rope (already exists as cardio) |
| **Full Body** | 5 (cardio family) | 🟡 missing: turkish get-up, kettlebell swing, thruster, clean+press, wall ball |
| **Mobility** | 0 | ❌ no analyzer support — must use `SilentHoldAnalyzer` |
| **Cardio** | 5 | ✅ for bodyweight; missing rower, treadmill, cycling (out of in-app scope) |
| **HIIT** | 0 (concept absent) | ❌ no separate category; could be `fullBody` + `is_cardio: true` + new `target_muscles: ['hiit']` tag |
| **Stretching** | 0 | ❌ same constraint as Mobility |

**Honest assessment:** the system as-built is **strength-training-with-pose-detection** first, conditioning second. Mobility / Stretching / Forearm isolation **do not have ML scaffolding**. Forcing them into the catalogue creates SilentHoldAnalyzer-only entries — which is fine if the user accepts that those exercises won't have rep counting or form correction.

---

## 2. ML Analyzer Reuse Matrix (what new exercises CAN have real detection)

For each existing analyzer, listing the additional movements it can correctly count without code changes:

| Existing analyzer | Reusable for these new exercises (no new analyzer needed) |
|---|---|
| `PushUpAnalyzer` | diamond push-up, wide push-up, archer push-up, pseudo-planche push-up, shoulder tap push-up, hindu push-up, decline dip variants, ring dip |
| `BenchPressAnalyzer` | incline DB press already there; flat barbell BP, decline BP, floor press (all elbow-flexion against load) |
| `ChestFlyAnalyzer` | cable crossover, dumbbell pullover (hand-distance-vs-shoulder-width works) — NB pullover is borderline |
| `SquatAnalyzer` | goblet squat, sumo squat, sissy squat, pistol squat, box squat, front squat, hack squat, step-up, jump lunge, walking lunge, reverse lunge, curtsy lunge, hip thrust (knee-angle still cycles), glute bridge |
| `PullUpAnalyzer` | inverted row, wide-grip pull-up, neutral-grip pull-up, t-bar row, dumbbell row, seated cable row (all are loaded elbow flexion) |
| `BicepsCurlAnalyzer` | preacher curl, incline curl, cable curl, spider curl, drag curl, reverse curl (any controlled elbow flexion) |
| `ShoulderPressAnalyzer` | seated DB press, push press, machine shoulder press, landmine press |
| `LateralRaiseAnalyzer` | rear delt fly (still shoulder-vertex angle, just mirrored — works), upright row (borderline) |
| `LegRaiseAnalyzer` | hanging knee raise, lying windshield wiper (sort of), reverse crunch |
| `RussianTwistAnalyzer` | seated woodchoppers (manual), standing twist (poor accuracy — caveat) |
| `MountainClimberAnalyzer` | cross-body MC, slow MC, plank knee-tucks |
| `BicycleCrunchAnalyzer` | cross-body crunch (single-side variant) |
| `FlutterKickAnalyzer` | scissor kick, dead bug (one-sided) |
| `JumpingJackAnalyzer` | half-jacks, plyo lateral lunge variants (borderline) |
| `BurpeeAnalyzer` | half-burpee, burpee box-jump (still STANDING→DOWN→STANDING) |
| `CrunchAnalyzer` | basic crunch variants, reverse crunch (borderline geometry), oblique crunch |
| `PlankAnalyzer` | side plank (rotated geometry — actually a bad fit, prefer SilentHold), forearm plank, RKC plank |
| `SilentHoldAnalyzer` | every mobility/stretch/balance hold, every cardio that's not jumping-jacks, every grip/forearm exercise |

**Net:** I can add **~80–100 movements with full ML rep counting + form coaching reuse**, plus **another ~30–60 SilentHold time-based holds** (mobility, balance, isolation that doesn't track joint cleanly), without writing a single new analyzer.

If you want **net-new analyzers** (e.g. for nordic hamstring curl, hip thrust isolated, single-leg RDL, kettlebell swing, turkish get-up), each is a separate engineering effort with its own threshold-tuning QA pass.

---

## 3. Schema Decision — recommended path

### Stay within the 7-category enum. Use `target_muscles[]` for sub-tagging.

Rationale:
- **Zero schema migration.** The CHECK constraint stays. The plan cache stays valid. The chip strip keeps working.
- The `target_muscles` column is **already `text[]`**, **already GIN-indexed**, and **already a forward-compat tagging surface** (per the Phase 50A migration's own comments).
- Conventional sub-tag values (proposed standard going forward):

  | Bucket | Sub-tags to apply via `target_muscles[]` |
  |---|---|
  | `core` | `abs`, `obliques`, `core` (keep primary), `lower_back` |
  | `chest` | `chest`, `upper_chest`, `lower_chest`, `inner_chest`, `triceps_secondary` |
  | `legs` | `quads`, `hamstrings`, `glutes`, `calves`, `adductors`, `lower_body` (keep primary) |
  | `back` | `lats`, `rhomboids`, `traps`, `lower_back`, `rear_delts`, `upper_body` (keep primary) |
  | `shoulders` | `front_delt`, `side_delt`, `rear_delt`, `traps`, `upper_body` |
  | `arms` | `biceps`, `triceps`, `forearms`, `upper_body` |
  | `fullBody` | `cardio`, `hiit`, `mobility`, `stretching`, `conditioning`, `full_body` |

  Convention: **first element stays the existing canonical value** (`upper_body` / `lower_body` / `core` / `cardio` / `full_body`) so `_firstTargetMuscle()` keeps working unchanged. Sub-tags are appended.

- The Dart `Exercise.targetMuscle` getter only reads element [0], so the generator's bucket interleave (Phase 86) keeps working with no code change.
- A future admin panel or filter UI can read element [1+] when needed, with no migration.

### What this DOES NOT solve

- **Mobility / Stretching / HIIT** still don't have a category enum value. They land in `fullBody` with sub-tags. Plan templates and the Bölgeler chip strip do not surface them as their own card unless you also add new templates. **My default plan: do not add new templates in this phase.** They appear in the catalogue (and would be picked up by the generator if it gets HIIT-aware in a later phase) but no user-visible chip changes.

If you want a "Mobility" or "HIIT" Bölgeler chip, that's a separate UX scope.

---

## 4. Quota Decision — proposed exercise counts per cell

Honest target (with my reasoning), assuming you approve the safe path A1+B1+C1+D1:

| Bucket | Equipment additions | Bodyweight additions | Notes |
|---|---|---|---|
| `core` (incl. abs/obliques) | +5 | +6 | Bodyweight has rich variation; equipment additions cluster around weighted variants |
| `chest` | +5 | +6 | Multiple push-up variants are biomechanically distinct + ML-friendly |
| `back` | +6 | +5 | Strong room for growth; analyzer reuse is excellent |
| `shoulders` | +5 | +5 | Including handstand hold (Silent), pike-walks, etc. |
| `arms` (biceps + triceps + forearms) | +7 | +5 | Forearms get 1–2 SilentHold entries (dead hang, farmer carry); we're transparent about no rep counting |
| `legs` (quads + hams + glutes + calves) | +6 | +9 | Single-leg variants, glute bridges, calf variations |
| `fullBody` (cardio + HIIT + conditioning) | +3 | +8 | Mostly bodyweight HIIT; equipment cardio (kettlebell swing, thruster) gets 3 |
| `fullBody` mobility/stretching | 0 | +6 | All SilentHold — flagged as "no rep counting, hold for time" |

**Total: ~36 equipment + ~50 bodyweight = ~86 net-new exercises** (vs the 51 already shipped). Final library: **~137 exercises**.

This is **less than the literal 5×2×18 = 180** but it is **all high-quality, all ML-routed (real or explicit Silent), all video-prompt-renderable**.

If you want me to push further toward the literal 180 quota I will do so but I'll need explicit sign-off because the marginal exercises will be filler.

---

## 5. Video Asset Reality

- The Supabase Storage `exercises` bucket needs **one PascalCase `.mp4`** per new slug.
- Until those land, the PIP slot shows the **neon error tile** ("Video yüklenemedi"). This is Phase-75-level UX: it's intentional, but it does mean every new SQL row is **temporarily user-visible-broken** until the corresponding video is rendered + uploaded.
- I will deliver `exercise-video-prompts.md` with one Kling AI prompt per exercise, each:
  - Preserving character / lighting / environment / camera lock per the user's spec,
  - Filename matching the auto-composed PascalCase URL,
  - Loop-friendly 3-5 s phrasing.
- **You / your content team render + upload the videos out-of-band.** I cannot generate or upload videos myself.
- Recommendation: **stage the SQL behind a feature flag** OR **upload videos before merging the SQL** OR **accept the broken-tile period explicitly** (a known launch risk per memory note about Phase 94 release resilience).

---

## 6. Cache & Generator Behaviour After Expansion

- Existing user plans stay valid. Phase 86 fingerprint = `goal|level`; we don't change goals or levels.
- New users (or anyone calling `resetProgress()`) get the new exercises immediately.
- The generator picks from the full pool — **new exercises with `is_cardio: true` will affect HIIT density on existing plans the next time those plans regenerate**. This is a behavior change, surfaceable to QA.
- If you want **all existing users** to see the new exercises immediately, bump `_planKey` from `v5` to `v6`. **My default: don't bump.** New cohort gets the new pool, existing cohort stays on their current plan until they edit goal/level. Less disruptive.

---

## 7. Production Safety Checklist (per Phase 94 / memory)

Before any mutation:
- [x] Diagnosis report (this file + analysis file) exists.
- [x] Pause-for-signoff invoked (via `AskUserQuestion`, see chat).
- [ ] User explicitly approves scope (A1+B1+C1+D1 or alternative).
- [ ] User confirms whether to bump `_planKey` to v6.
- [ ] User confirms whether to ship SQL before videos or after.
- [ ] Phase number assigned (assume **Phase 96** following Phase 95's paywall localization fix).

When mutations happen:
- [ ] New SQL file: `supabase/sql/phase96_workout_library_expansion.sql` — additive only, `ON CONFLICT (slug) DO NOTHING`, idempotent.
- [ ] Update `lib/features/workout/services/analyzer_factory.dart` — add new slug → analyzer cases, all reusing existing analyzer classes (no new classes needed under the safe path).
- [ ] Verify every new slug snake-to-Pascal cleanly (no Unicode, no double underscore).
- [ ] Optional: `_PlanTemplate` additions in `workout_repository.dart` if surfacing new dashboard cards.

---

## 8. Decisions I need from you

I'll ask via `AskUserQuestion` immediately after this report. Preview of the choices:

1. **Schema strategy** — A1 (sub-tag in `target_muscles[]`, no migration) OR A2 (expand enum + migration).
2. **Exercise count target** — quality (~86 new) OR literal quota (~180 new with filler).
3. **Pre-video go-live policy** — ship SQL now and accept fallback tiles OR block SQL until videos exist.
4. **Plan cache invalidation** — keep `_planKey` at v5 (gradual rollout) OR bump to v6 (all users see new pool on next launch).

Once you answer those four, I generate `new-exercise-library.md`, `exercise-video-prompts.md`, `ml-detection-strategy.md`, and `workout-integration-summary.md`, and apply the SQL + analyzer changes.

---

End of gap analysis.
