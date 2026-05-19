# Premium Workout Distribution — Phase 98

**Status:** per-card spec for the 7 equipment programs after the Phase 98 consolidation.
**Generated:** 2026-05-11
**Format:** one block per card with the Lite Seviye list (preserved from the original), the Premium Seviye list (merged from Phase 96 advanced exercises), and the curation rationale + workout flow logic.

Each block reflects exactly what now lives in `_equipmentTemplates` inside `lib/features/workout/data/workout_repository.dart`.

---

## 1. `equipment_chest_strength` — Ekipmanlı Göğüs Gücü

**Category:** chest · **Level:** Orta düzey · **Duration:** 22 min · **Tint:** neon purple

### Lite Seviye (4 exercises — UNCHANGED)
1. `bench_press` — Dambıl Bench Press
2. `incline_bench_press` — Yokuş Yukarı Bench Press
3. `chest_fly` — Chest Fly
4. `chest_dip` — Göğüs Dip

### Premium Seviye (5 exercises — NEW)
1. `decline_bench_press` — Decline Bench Press (lower-chest emphasis)
2. `cable_crossover` — Cable Crossover (peak contraction, inner pec)
3. `incline_chest_fly` — Yokuş Yukarı Chest Fly (upper-chest stretch)
4. `machine_chest_press` — Makine Chest Press (controlled-plane press)
5. `dumbbell_pullover` — Dambıl Pullover (chest + lat finisher stretch)

**Premium curation rationale:** the standard tier is the foundational compound day (heavy bench, incline bench, fly, dip). The premium tier is the **angled / sculpting / contraction** counterpart — different bench angles, cable/machine continuous tension, and a finisher stretch. Zero exercise overlap with the standard list. Flow: heavy decline press → continuous-tension cable crossover → upper-chest fly → controlled machine press → stretch.

---

## 2. `equipment_back_width` — Ekipmanlı Sırt Genişliği

**Category:** back · **Level:** Orta düzey · **Duration:** 24 min · **Tint:** mint green

### Lite Seviye (4 exercises — UNCHANGED)
1. `pull_up` — Pull-up
2. `lat_pulldown` — Lat Pulldown
3. `barbell_row` — Barbell Row
4. `chin_up` — Chin-up

### Premium Seviye (6 exercises — NEW)
1. `t_bar_row` — T-Bar Row (heavy free-weight thickness)
2. `dumbbell_row` — Tek Kol Dambıl Row (unilateral lat detail)
3. `seated_cable_row` — Oturarak Kablo Row (mid-back contraction)
4. `face_pull` — Kablo Face Pull (rear delt / upper trap balance)
5. `deadlift` — Deadlift (full posterior chain compound)
6. `dumbbell_clean` — Dambıl Hang Clean (explosive pull power)

**Premium curation rationale:** the standard tier owns vertical pulling (pull-up, chin-up) + the basic horizontal pull (barbell row). The premium tier is the **thickness / posture / power** counterpart — heavy row variants, postural face pull, the king deadlift, and the explosive clean to round out the pull profile. Flow: heavy t-bar → unilateral DB row → seated cable for mid-back → face pull → deadlift → explosive clean finisher.

---

## 3. `equipment_shoulders_round` — Yuvarlak Omuz Şekillendirme

**Category:** shoulders · **Level:** Orta düzey · **Duration:** 20 min · **Tint:** neon blue

### Lite Seviye (4 exercises — UNCHANGED)
1. `shoulder_press` — Shoulder Press
2. `arnold_press` — Arnold Press
3. `lateral_raise` — Lateral Raise
4. `front_raise` — Front Raise

### Premium Seviye (6 exercises — NEW)
1. `machine_shoulder_press` — Makine Shoulder Press (controlled-plane press)
2. `upright_row` — Upright Row (lateral delt + traps)
3. `rear_delt_fly` — Rear Delt Fly (posterior delt isolation)
4. `cuban_press` — Cuban Press (rotator cuff + 3D shoulder)
5. `landmine_press` — Landmine Press (single-arm pressing variation)
6. `thruster` — Dambıl Thruster (full-body squat-to-press finisher)

**Premium curation rationale:** the standard tier is the all-three-heads basic shoulder day (overhead press, Arnold, lateral, front). The premium tier is the **specialty + posterior + functional** day — every Phase 96 shoulder addition plus the thruster as a metabolic finisher. The 6th slot (`thruster`) has rationale: it's a squat-to-press, the press portion fits the shoulder day, and it gives the program a HIIT closer that ties off the workout. Flow: machine warm-up → upright row → rear delt isolation → cuban press for shoulder health → landmine press → thruster finisher.

---

## 4. `equipment_arms_biceps` — Ekipmanlı Biceps Pompası

**Category:** arms · **Level:** Orta düzey · **Duration:** 14 min · **Tint:** soft pink

### Lite Seviye (3 exercises — UNCHANGED)
1. `biceps_curl` — Biceps Curl
2. `hammer_curl` — Hammer Curl
3. `concentration_curl` — Konsantrasyon Curl

### Premium Seviye (4 exercises — NEW)
1. `preacher_curl` — Preacher Curl (locked-elbow peak)
2. `incline_dumbbell_curl` — Yokuş Yukarı Dambıl Curl (long-head stretch)
3. `cable_curl` — Kablo Curl (constant tension)
4. `chin_up_negative` — Chin-up Negatif (eccentric overload bodyweight bonus)

**Premium curation rationale:** the standard tier is the basics (DB curl, hammer, concentration). The premium tier is the **angle-detail + intensity-technique** day — preacher (locked elbow), incline (stretched long head), cable (continuous tension), and a chin-up negative for eccentric overload. Concentration curl appears in the standard tier only — it's the universal closer and doesn't need duplication in premium.

---

## 5. `equipment_arms_triceps` — Ekipmanlı Triceps Yoğunluğu

**Category:** arms · **Level:** Orta düzey · **Duration:** 14 min · **Tint:** warm gold

### Lite Seviye (3 exercises — UNCHANGED)
1. `triceps_pushdown` — Triceps Pushdown
2. `skull_crusher` — Skull Crusher
3. `triceps_dip` — Triceps Dip

### Premium Seviye (4 exercises — NEW)
1. `overhead_triceps_extension` — Baş Üstü Triceps Extension (long head)
2. `rope_triceps_pushdown` — Halat Triceps Pushdown (lateral head spread)
3. `dumbbell_kickback` — Dambıl Kickback (peak contraction)
4. `tricep_extension_floor` — Yer Üstü Triceps Extension (bodyweight bonus)

**Premium curation rationale:** the standard tier is the foundational triceps trio (pushdown, skull crusher, dip). The premium tier covers the **three triceps heads at different angles** — overhead (long head), rope-spread pushdown (lateral), kickback (full peak), and a floor extension as the bodyweight bonus. Skull crusher only lives in the standard tier — Phase 97's draft had it duplicated in premium too, which would have been redundant.

---

## 6. `equipment_legs_power` — Ekipmanlı Bacak Gücü

**Category:** legs · **Level:** İleri · **Duration:** 28 min · **Tint:** electric green

### Lite Seviye (5 exercises — UNCHANGED)
1. `barbell_squat` — Barbell Squat
2. `leg_press` — Leg Press
3. `romanian_deadlift` — Romen Deadlift
4. `leg_extension` — Leg Extension
5. `leg_curl` — Leg Curl

### Premium Seviye (6 exercises — NEW)
1. `front_squat` — Front Squat (anterior-loaded squat variant)
2. `goblet_squat` — Goblet Squat (technique reset / warm-up)
3. `hip_thrust` — Hip Thrust (glute-isolation king lift)
4. `walking_lunge_dumbbell` — Dambıl Yürüyüş Lunge (unilateral loaded)
5. `kettlebell_swing` — Kettlebell Swing (hip hinge power + cardio)
6. `box_jump` — Box Jump (plyometric power finisher)

**Premium curation rationale:** the standard tier is the bodybuilding-style leg day (squat, leg press, RDL, machine extension, machine curl). The premium tier is the **power + posterior chain + plyo** day. Front squat for anterior loading variation, goblet for warm-up. Hip thrust for glutes (the original tier doesn't isolate glutes well). Walking lunge for unilateral loading. Kettlebell swing for hip-hinge explosive power. Box jump as a metabolic / plyo finisher. Romanian deadlift stays standard-only (it's the staple) and isn't repeated in premium.

---

## 7. `equipment_core_loaded` — Ağırlıklı Karın Şekillendirme

**Category:** core · **Level:** İleri · **Duration:** 18 min · **Tint:** hot pink

### Lite Seviye (4 exercises — UNCHANGED)
1. `cable_crunch` — Kablo Mekik
2. `hanging_leg_raise` — Asılı Bacak Kaldırma
3. `weighted_russian_twist` — Ağırlıklı Rus Dönüşü
4. `ab_wheel_rollout` — Ab Wheel Rollout

### Premium Seviye (4 exercises — NEW)
1. `weighted_sit_up` — Ağırlıklı Sit-up (loaded full-range flexion)
2. `weighted_leg_raise` — Ağırlıklı Bacak Kaldırma (loaded lower abs)
3. `dragon_flag` — Dragon Flag (advanced anti-extension)
4. `medicine_ball_russian_twist` — Sağlık Topuyla Rus Dönüşü (rotational power)

**Premium curation rationale:** the standard tier covers cable + hanging + weighted twist + ab wheel — a strong loaded-core program. The premium tier emphasizes **dumbbell / plate + advanced anti-extension** patterns: weighted sit-up for full-range flexion, weighted leg raise for lower abs under load, dragon flag (one of the hardest core exercises in existence), and medicine-ball Russian twist for rotational power. Both tiers feel "loaded" — the difference is implement (cable/bar vs DB/plate/MB).

---

## Summary Table

| Card | Standard Exercises | Premium Exercises | Total |
|---|---:|---:|---:|
| equipment_chest_strength | 4 | 5 | 9 |
| equipment_back_width | 4 | 6 | 10 |
| equipment_shoulders_round | 4 | 6 | 10 |
| equipment_arms_biceps | 3 | 4 | 7 |
| equipment_arms_triceps | 3 | 4 | 7 |
| equipment_legs_power | 5 | 6 | 11 |
| equipment_core_loaded | 4 | 4 | 8 |
| **TOTAL** | **27** | **35** | **62** |

The 7 equipment cards now offer **62 exercises** organized as 27 Lite Seviye + 35 Premium Seviye. Every Phase 96 advanced equipment exercise (35 of them) now has a clear home inside the original 7 cards. The horizontal strip stayed at 7 cards.

---

## How The Buttons Work (Per-Card Behavior)

For every card above:

- **Left button** ("PLANI BAŞLAT" / "Lite Seviye", purple-blue gradient): calls `WorkoutSessionNotifier.initializeWorkout(plan.exercises)` → starts the camera screen with the **Standard** exercise sequence. Bit-identical to today's behavior.
- **Right button** ("PLANI BAŞLAT" / "Premium Seviye", gold gradient + neon glow): calls `initializeWorkout(plan.premiumExercises)` → starts the camera screen with the **Premium** sequence.
- **Both buttons** respect the existing PRO gate (non-PRO users → paywall) and the Phase 89 offline check.
- The **İleri Seviye section** below the standard exercise list visually previews what the right button will launch.

---

End of premium workout distribution spec.
