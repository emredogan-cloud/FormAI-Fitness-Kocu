# Workout Data Audit Report — Phase 85

Snapshot of the exercise catalogue and plan templates after the Phase 85 rebuild that replaces the four-card "Sınırlarını Zorla" strip with the seven-card "Ekipmanlı Egzersizler" strip.

**Source of truth — exercises:** `supabase/sql/exercises_migration.sql` (Phase 50A, 41 rows) + `supabase/sql/phase85_equipment_exercises.sql` (Phase 85, +10 rows).
**Source of truth — plan templates:** `lib/features/workout/data/workout_repository.dart` → `_equipmentTemplates`, `_regionalTemplates`.

---

## 1. Total exercises

**51** rows in `public.exercises` after Phase 85 (was 41 pre-Phase-85). Distribution by `category` column:

| Category | Pre-85 | +Phase 85 | Total |
|---|---|---|---|
| core | 9 | +3 | 12 |
| chest | 6 | +1 | 7 |
| legs | 6 | +4 | 10 |
| back | 5 | 0 | 5 |
| shoulders | 5 | 0 | 5 |
| arms | 5 | +2 | 7 |
| fullBody (cardio) | 5 | 0 | 5 |
| **Total** | **41** | **+10** | **51** |

---

## 2. Equipment vs non-equipment split

Equipment classification is hardcoded by slug curation in `_equipmentTemplates` — there is no `equipment` column on `public.exercises` yet (deliberate; the user asked to defer the migration). The classification below is the working definition used to build the seven equipment plans.

| Bucket | Count | Slugs |
|---|---|---|
| **Equipment-required** | **27** | bench_press, incline_bench_press, chest_fly, chest_dip, pull_up, chin_up, lat_pulldown, barbell_row, shoulder_press, arnold_press, lateral_raise, front_raise, biceps_curl, hammer_curl, concentration_curl, triceps_dip, triceps_pushdown, skull_crusher, leg_press, barbell_squat, romanian_deadlift, leg_extension, leg_curl, hanging_leg_raise, cable_crunch, weighted_russian_twist, ab_wheel_rollout |
| **Bodyweight** | **19** | push_up, incline_push_up, decline_push_up, superman, pike_push_up, close_grip_push_up, crunch, situp, plank, leg_raise, russian_twist, mountain_climber, bicycle_crunch, flutter_kick, lunge, bulgarian_split_squat, calf_raise, wall_sit, squat |
| **Cardio (full-body)** | **5** | burpee, high_knees, jumping_jack, jump_squat, skipping_rope |
| **Total** | **51** | |

Notes:
- `pull_up` / `chin_up` are counted as equipment because they require a bar. If a future user-survey shows most users don't have a pull-up bar, reclassify these and bump the back card count down.
- `triceps_dip` is parallel-bars or a bench-edge variant — counted as equipment for the strip, but a no-equipment fallback is plausible.
- `squat` / `lunge` / `bulgarian_split_squat` / `calf_raise` are bodyweight by default; barbell variants live as separate slugs (`barbell_squat`, etc.) so plan curation can pick precisely.

---

## 3. Equipment plan distribution (the seven new cards)

| Card | Slug count | Slugs |
|---|---|---|
| Göğüs (Ekipmanlı Göğüs Gücü) | 4 | bench_press, incline_bench_press, chest_fly, chest_dip |
| Sırt (Ekipmanlı Sırt Genişliği) | 4 | pull_up, lat_pulldown, barbell_row, chin_up |
| Omuz (Yuvarlak Omuz Şekillendirme) | 4 | shoulder_press, arnold_press, lateral_raise, front_raise |
| Kol — Biceps (Ekipmanlı Biceps Pompası) | 3 | biceps_curl, hammer_curl, concentration_curl |
| Triceps (Ekipmanlı Triceps Yoğunluğu) | 3 | triceps_pushdown, skull_crusher, triceps_dip |
| Bacak (Ekipmanlı Bacak Gücü) | 5 | barbell_squat, leg_press, romanian_deadlift, leg_extension, leg_curl |
| Karın (Ağırlıklı Karın Şekillendirme) | 4 | cable_crunch, hanging_leg_raise, weighted_russian_twist, ab_wheel_rollout |

Every card carries 3–5 exercises. **No card is empty.** Minimum target (≥3) met across all seven.

---

## 4. Missing categories

None for the seven-card strip. All seven muscle groups are populated.

Categories present in the catalogue but **not** surfaced on the equipment strip (by design):

- **fullBody / cardio** — cardio movements aren't equipment-based; they live in cardio-specific regional plans (`cardio_full_body_burst`, `cardio_morning_quick`).
- **Bodyweight chest/back/shoulders/arms/legs/core variants** — covered by the existing Bölgeler chip strip, which is unchanged.

---

## 5. Suggested new exercises (next batch)

When the catalogue can grow further, the highest-leverage additions are:

| Slug | Turkish name | Category | Why |
|---|---|---|---|
| `dumbbell_row` | Dambıl Row | back | Single-arm variant; common home-gym staple. |
| `face_pull` | Face Pull | shoulders | Rear-delt + posture; underrepresented in current pool. |
| `cable_lateral_raise` | Kablo Lateral Raise | shoulders | Side-delt isolation alternative. |
| `preacher_curl` | Preacher Curl | arms | Strict biceps — adds variety beyond curl/hammer. |
| `overhead_triceps_extension` | Over Head Triceps Extension | arms | Long-head triceps; pairs with skull crusher. |
| `goblet_squat` | Goblet Squat | legs | Beginner-friendly weighted squat without a rack. |
| `dumbbell_lunge` | Dambıl Lunge | legs | Loaded lunge variant. |
| `weighted_plank` | Ağırlıklı Plank | core | Adds load to the most popular bodyweight core hold. |
| `decline_dumbbell_press` | Decline Bench Press | chest | Lower-pec coverage. |
| `pendlay_row` | Pendlay Row | back | Strict barbell row variant for advanced users. |

Adding ~10 more equipment exercises would bring every card to 4–6 slugs and create headroom for level variants ("İleri" tiers per muscle group).

---

## 6. Strategy for the "Bölgeler" section

**Recommendation: keep mixed for now; revisit after equipment-strip metrics arrive.**

The Bölgeler chip strip currently filters `_regionalTemplates` by `ExerciseCategory` (Core / Chest / Back / Shoulders / Arms / Legs / Full body). Phase 85 changes:

- **Removed:** the four core push-limits plans no longer prepend the regional list (`getAllPlans()` now returns only `_regionalTemplates`). Without this change, equipment plans would also surface there and users would see the same plan twice.
- **Unchanged:** every other regional template still flows through Bölgeler. Bodyweight + mixed plans (e.g., `chest_fat_burn_basic`, `back_posture_basic`, `legs_cardio_strength`) keep their place.

Two possible follow-ups, not done in this phase:

1. **Add an "Ekipman" filter chip to Bölgeler.** Lets a power user filter Bölgeler down to equipment-only without leaving the regional surface. Low-cost UI change once the equipment classification graduates from hardcoded slug curation to a proper DB column.
2. **Split Bölgeler into "Vücut Ağırlığı" + "Ekipmanlı"** as separate strips. Higher cost (two new sections), and overlaps the equipment strip we just shipped — would only make sense if the equipment strip proves popular and users want a deeper drill-in.

For now, leave Bölgeler mixed. The new equipment strip is the dedicated entry point; Bölgeler stays the broad regional discovery surface.

---

## 7. Future expansion plan

### Priority order

1. **Generate the 7 equipment-strip cover images** from the prompts in `WORKOUT_IMAGE_PROMPTS.md`. Until they ship, cards fall back to the gradient + fitness-center icon — functional but visually weaker than the chest/back/etc. regional cards that already have bespoke art.
2. **Upload exercise videos for the 10 Phase 85 slugs.** The Storage URL composition is automatic (`InclineBenchPress.mp4`, etc.) — only the asset uploads are missing.
3. **Add the 10 next-batch exercises from §5** so cards can grow to 4–6 slugs and a future "İleri" tier has source material.
4. **Promote equipment classification to a DB column** (`equipment_required boolean` or `equipment_type text`). Eliminates the hardcoded slug curation and unblocks (a) the proposed Bölgeler equipment chip, (b) admin-panel exercise authoring without redeploying Dart.
5. **Equipment-aware plan generator.** Today the `WorkoutGeneratorService` doesn't know about equipment availability — a user with no gear gets the same 30-day program as a user with a full home gym. Once §4 lands, the generator can branch on a stored "fitness goal + has-equipment" pair.

### Categories that need more exercises (in priority order)

1. **Sırt / Back** — only 5 total (4 equipment, 1 bodyweight). Adding `dumbbell_row` and `face_pull` would bring back to 7 and unlock a stronger upper-back plan.
2. **Omuz / Shoulders** — 5 total. Adding `face_pull` and `cable_lateral_raise` rounds out side- and rear-delt coverage.
3. **Bacak — Hamstrings / Glutes** — currently mostly quad-dominant. `goblet_squat` + a hip-thrust slug would close the gap.
4. **Triceps** — 3 equipment. Adding `overhead_triceps_extension` would let the triceps card carry a 4-slug plan and pair well with skull crusher.
5. **Karın — Loaded variants** — 4 equipment. `weighted_plank` is the easiest addition; `decline_weighted_situp` would extend the upper-abs variety.

### Suggested exercise types beyond what the catalogue currently has

- **Push/Pull/Legs split templates** — three regional plans organised by movement pattern instead of muscle group. Would surface as a fourth dashboard strip.
- **Mobility / warm-up flows** — a 5-minute plan that runs before the main workout. Currently absent from the catalogue; users either skip or improvise.
- **Finishers** — short 3-minute density blocks (e.g., 60s on / 30s off × 3) using existing slugs. No new exercises needed; just new plan templates.

---

## 8. Validation summary

- `dart analyze lib/features/workout/ lib/features/home/presentation/widgets/` → **No issues found.**
- All 7 plan templates resolve against the post-Phase-85 slug set.
- `getAllPlans()` no longer prepends equipment plans → Bölgeler shows regional-only, no double-rendering.
- `pubspec.yaml` already lists `photos/workouts/` as a bundled asset directory; new cover images will be picked up on next `flutter pub get` + rebuild.
- `_mealCategoryEntries` and `_budgetCategoryEntries` (the Nutrition tab) are untouched.

### Caveats

- Cards render the fitness-center fallback icon until the seven `equipment_*.webp` cover files are generated and dropped into `photos/workouts/`.
- Exercise videos for the 10 new slugs aren't uploaded yet; the player will surface its empty-video state when those exercises are tapped. No crash.
- Equipment classification is implicit in the curated slug lists — a future engineer adding a slug to `_equipmentTemplates` is responsible for verifying the slug actually requires equipment. Promoting to a DB column eliminates this risk.
