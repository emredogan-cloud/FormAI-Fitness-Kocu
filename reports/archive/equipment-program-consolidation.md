# Equipment Program Consolidation — Phase 98

**Status:** record of what was removed and why.
**Generated:** 2026-05-11
**Scope:** the `_equipmentTemplates` static list inside `lib/features/workout/data/workout_repository.dart` only.

---

## 1. Final State

The `_equipmentTemplates` list is back to **exactly 7 entries** — the original Phase 50A / Phase 85 lineup. Phase 97's 8 additions have been deleted from the list. The horizontal "Ekipmanlı Egzersizler" strip on the dashboard renders 7 cards.

| # | ID (preserved) | Title | Category | Level | Min |
|---:|---|---|---|---|---:|
| 1 | `equipment_chest_strength` | Ekipmanlı Göğüs Gücü | chest | Orta düzey | 22 |
| 2 | `equipment_back_width` | Ekipmanlı Sırt Genişliği | back | Orta düzey | 24 |
| 3 | `equipment_shoulders_round` | Yuvarlak Omuz Şekillendirme | shoulders | Orta düzey | 20 |
| 4 | `equipment_arms_biceps` | Ekipmanlı Biceps Pompası | arms | Orta düzey | 14 |
| 5 | `equipment_arms_triceps` | Ekipmanlı Triceps Yoğunluğu | arms | Orta düzey | 14 |
| 6 | `equipment_legs_power` | Ekipmanlı Bacak Gücü | legs | İleri | 28 |
| 7 | `equipment_core_loaded` | Ağırlıklı Karın Şekillendirme | core | İleri | 18 |

Each of these now carries a `premiumExerciseSlugs:` field as well as the original `exerciseSlugs:`. The horizontal strip's rendering is unchanged; the change is fully contained inside the plan-detail screen.

---

## 2. What Was Removed

The 8 Phase 97 templates that have been deleted from `_equipmentTemplates`:

| ID (deleted) | Title (deleted) | Why it didn't survive Phase 98 |
|---|---|---|
| `equipment_chest_sculpt` | Ekipmanlı Göğüs Şekillendirme | Was a sibling chest card to `equipment_chest_strength`. Now lives as the **Premium tier inside `equipment_chest_strength`**. Slugs (`decline_bench_press`, `cable_crossover`, `incline_chest_fly`, `machine_chest_press`, `dumbbell_pullover`) are now its `premiumExerciseSlugs`. |
| `equipment_back_thickness` | Ekipmanlı Sırt Kalınlığı | Was a sibling back card to `equipment_back_width`. Now the **Premium tier of `equipment_back_width`**. Slugs (`t_bar_row`, `dumbbell_row`, `seated_cable_row`, `face_pull`) merged into the premium list, plus `deadlift` and `dumbbell_clean` from the deleted `equipment_fullbody_hiit`. |
| `equipment_shoulder_giant_burst` | Dev Omuz Patlaması | Was a sibling shoulder card. Now the **Premium tier of `equipment_shoulders_round`**. Slugs (`machine_shoulder_press`, `upright_row`, `rear_delt_fly`, `cuban_press`, `landmine_press`) merged into the premium list, plus `thruster` from the deleted `equipment_fullbody_hiit`. |
| `equipment_arms_triceps_burst` | Ekipmanlı Arka Kol Patlaması | Was a sibling arms card. Now the **Premium tier of `equipment_arms_triceps`**. Slugs (`overhead_triceps_extension`, `rope_triceps_pushdown`, `dumbbell_kickback`) merged in; the duplicate `skull_crusher` was dropped (already in the standard list of `equipment_arms_triceps`); `tricep_extension_floor` was added to fill the bodyweight bonus slot. |
| `equipment_arms_biceps_detail` | Ekipmanlı Ön Kol Detayı | Was a sibling arms card. Now the **Premium tier of `equipment_arms_biceps`**. Slugs (`preacher_curl`, `incline_dumbbell_curl`, `cable_curl`) merged in; the duplicate `concentration_curl` was dropped (already standard); `chin_up_negative` was added as a bodyweight bonus. |
| `equipment_glutes_strength` | Glute Gücü Programı | Was a sibling legs card. Now its slugs (`hip_thrust`, `walking_lunge_dumbbell`, `dumbbell_step_up`) feed the **Premium tier of `equipment_legs_power`**. The duplicate `romanian_deadlift` was dropped (already standard). |
| `equipment_core_stability_weighted` | Ağırlıklı Core Stabilitesi | Was a sibling core card. Now the **Premium tier of `equipment_core_loaded`**. Slugs (`weighted_sit_up`, `weighted_leg_raise`, `dragon_flag`, `medicine_ball_russian_twist`) merged in. |
| `equipment_fullbody_hiit` | Ekipmanlı Full Body HIIT | Did not have a 1:1 home (no `equipment_fullbody_*` original). Distributed: `kettlebell_swing` and `box_jump` → legs premium; `thruster` → shoulders premium; `dumbbell_clean` → back premium. The HIIT category is therefore not surfaced as a dedicated equipment card; users find HIIT-style sequences inside the legs/shoulders/back premium tiers + the existing `cardio_hiit_burst` regional card. |

**Total deleted entries:** 8.
**Total preserved entries:** 7.
**Total surviving exercise slugs (now organized as premium tiers):** 35 across the 7 cards. Zero exercises lost in the consolidation.

---

## 3. Slug Migration Map

For each of the 35 Phase 96 advanced slugs, this table records its journey from "Phase 97 standalone card" to "Phase 98 premium tier inside an original card":

| Slug | Phase 97 home (deleted) | Phase 98 home (premium tier of) |
|---|---|---|
| `decline_bench_press` | equipment_chest_sculpt | equipment_chest_strength |
| `cable_crossover` | equipment_chest_sculpt | equipment_chest_strength |
| `incline_chest_fly` | equipment_chest_sculpt | equipment_chest_strength |
| `machine_chest_press` | equipment_chest_sculpt | equipment_chest_strength |
| `dumbbell_pullover` | equipment_chest_sculpt | equipment_chest_strength |
| `t_bar_row` | equipment_back_thickness | equipment_back_width |
| `dumbbell_row` | equipment_back_thickness | equipment_back_width |
| `seated_cable_row` | equipment_back_thickness | equipment_back_width |
| `face_pull` | equipment_back_thickness | equipment_back_width |
| `deadlift` | (regional only) | equipment_back_width |
| `dumbbell_clean` | equipment_fullbody_hiit | equipment_back_width |
| `machine_shoulder_press` | equipment_shoulder_giant_burst | equipment_shoulders_round |
| `upright_row` | equipment_shoulder_giant_burst | equipment_shoulders_round |
| `rear_delt_fly` | equipment_shoulder_giant_burst | equipment_shoulders_round |
| `cuban_press` | equipment_shoulder_giant_burst | equipment_shoulders_round |
| `landmine_press` | equipment_shoulder_giant_burst | equipment_shoulders_round |
| `thruster` | equipment_fullbody_hiit | equipment_shoulders_round |
| `preacher_curl` | equipment_arms_biceps_detail | equipment_arms_biceps |
| `incline_dumbbell_curl` | equipment_arms_biceps_detail | equipment_arms_biceps |
| `cable_curl` | equipment_arms_biceps_detail | equipment_arms_biceps |
| `chin_up_negative` | (regional only) | equipment_arms_biceps |
| `overhead_triceps_extension` | equipment_arms_triceps_burst | equipment_arms_triceps |
| `rope_triceps_pushdown` | equipment_arms_triceps_burst | equipment_arms_triceps |
| `dumbbell_kickback` | equipment_arms_triceps_burst | equipment_arms_triceps |
| `tricep_extension_floor` | (regional only) | equipment_arms_triceps |
| `front_squat` | (regional only) | equipment_legs_power |
| `goblet_squat` | (regional only) | equipment_legs_power |
| `hip_thrust` | equipment_glutes_strength | equipment_legs_power |
| `walking_lunge_dumbbell` | equipment_glutes_strength | equipment_legs_power |
| `kettlebell_swing` | equipment_fullbody_hiit | equipment_legs_power |
| `box_jump` | equipment_fullbody_hiit | equipment_legs_power |
| `weighted_sit_up` | equipment_core_stability_weighted | equipment_core_loaded |
| `weighted_leg_raise` | equipment_core_stability_weighted | equipment_core_loaded |
| `dragon_flag` | equipment_core_stability_weighted | equipment_core_loaded |
| `medicine_ball_russian_twist` | equipment_core_stability_weighted | equipment_core_loaded |

**Slugs not in any premium tier (remain only in regional bodyweight cards):**
- `dumbbell_step_up` — surfaces in regional `legs_single_leg_bodyweight` (Phase 97). Could be added to `equipment_legs_power` premium later if useful; left out to keep that tier at 6 exercises.
- `pistol_squat` — bodyweight, regional only (`legs_single_leg_bodyweight`).
- `single_leg_rdl`, `glute_bridge`, `single_leg_glute_bridge`, `frog_pump`, `nordic_curl` — bodyweight, regional only.
- All 6 mobility/stretching slugs — regional only (`cardio_mobility_stretch`).

This is intentional: equipment premium tiers are for **equipment exercises only**, with select bodyweight bonuses (`tricep_extension_floor`, `chin_up_negative`) where they fit the program's intent.

---

## 4. Why The Consolidation Improves UX

| Before (Phase 97) | After (Phase 98) |
|---|---|
| 15-card horizontal strip | 7-card horizontal strip (back to original density) |
| Each card competes with its sibling for the same muscle group | Each card OWNS its muscle group |
| Two near-identical chest entry points (Strength + Sculpting) | One chest card with Lite + Premium tiers inside |
| Discovery debt: user must read every card title to know which one applies | Discovery is two-step: pick the muscle, then pick the tier |
| The "advanced" feeling is muddled — both cards look equally premium | The "advanced" feeling has a clear visual home: the gold premium button + İleri Seviye section |

---

## 5. Verification

### Code-level
- `flutter analyze workout_repository.dart workout_plan_model.dart plan_detail_screen.dart` → 0 issues.
- `_equipmentTemplates.length == 7` (verified by inspection — list bracket-counted).
- `equipment_strip.dart` cycles `_equipmentTints[index % length]` over 7 colors and 7 cards → every card gets its intended tint.
- `_PlanTemplate.resolve()` materializes `premiumExercises` for the 7 originals; for regional templates (which omit the parameter), the default `const []` keeps `premiumExercises` empty and `hasPremiumTier` returns false.

### Runtime (smoke test todo)
- [ ] Dashboard horizontal strip: 7 cards, identical to Phase 50A/85 visual.
- [ ] Tap any equipment card → detail screen shows two-button layout + İleri Seviye section.
- [ ] Tap any regional Bölgeler card → detail screen shows single-button layout (legacy CTA preserved).

---

End of consolidation record.
