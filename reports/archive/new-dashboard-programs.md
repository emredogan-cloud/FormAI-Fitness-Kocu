# New Dashboard Programs — Phase 97 Per-Card Spec

**Status:** specification for the 32 new `_PlanTemplate` entries that land in `lib/features/workout/data/workout_repository.dart`.
**Generated:** 2026-05-11
**Format:** one block per card with the literal Dart-side fields, the curation rationale, and the workout flow logic.

Each block can be transcribed directly into the `_equipmentTemplates` or `_regionalTemplates` lists. The Dart edit in the next deliverable does exactly that.

---

## EQUIPMENT STRIP — 8 NEW PROGRAMS

### `equipment_chest_sculpt` — Ekipmanlı Göğüs Şekillendirme
- Category: `chest` · Level: `Orta düzey` · 22 min · 5 exercises
- Exercise slugs (in order): `decline_bench_press`, `incline_chest_fly`, `cable_crossover`, `machine_chest_press`, `dumbbell_pullover`
- **Rationale:** the existing `equipment_chest_strength` covers heavy compound chest work (bench press, incline bench press, fly, dip). This new card is the **sculpting / detail** counterpart: angled work (decline bench, incline fly), peak contraction work (cable crossover), and a finisher stretch (pullover). Zero exercise overlap with existing chest cards. Flow: heavy-press → upper-chest fly → inner-chest squeeze → light-press finisher → stretch.
- Image: `photos/workouts/equipment_chest_sculpt.webp`

### `equipment_back_thickness` — Ekipmanlı Sırt Kalınlığı
- Category: `back` · Level: `Orta düzey` · 22 min · 4 exercises
- Slugs: `t_bar_row`, `dumbbell_row`, `seated_cable_row`, `face_pull`
- **Rationale:** existing `equipment_back_width` is the **width** card (pull-up, lat pulldown, barbell row, chin-up) — vertical pulling and wide-grip horizontal pulling. The new card focuses on **thickness/density** via row variants (T-bar, single-arm DB, seated cable) plus a rear-delt face pull finisher for posture/health balance. Flow: heavy free-weight row → unilateral work → machine row → upper-back finisher.
- Image: `photos/workouts/equipment_back_thickness.webp`

### `equipment_shoulder_giant_burst` — Dev Omuz Patlaması
- Category: `shoulders` · Level: `İleri` · 24 min · 5 exercises
- Slugs: `machine_shoulder_press`, `upright_row`, `rear_delt_fly`, `cuban_press`, `landmine_press`
- **Rationale:** existing `equipment_shoulders_round` is a beginner/intermediate set of fundamentals (DB shoulder press, Arnold, lateral raise, front raise). The new İleri card pulls together every Phase 96 shoulder addition into a single comprehensive workout: machine press warm-up → upright row for traps/side delt → rear delt fly → cuban press for rotator cuff → landmine press as finisher. All five named per the user's example "Ekipmanlı Omuz Gücü"-style request.
- Image: `photos/workouts/equipment_shoulder_giant_burst.webp`

### `equipment_arms_triceps_burst` — Ekipmanlı Arka Kol Patlaması
- Category: `arms` · Level: `Orta düzey` · 16 min · 4 exercises
- Slugs: `overhead_triceps_extension`, `rope_triceps_pushdown`, `dumbbell_kickback`, `skull_crusher`
- **Rationale:** the user explicitly requested "Ekipmanlı Arka Kol Patlaması" as a desired addition. Existing `equipment_arms_triceps` was thin (3 exercises: triceps_pushdown, skull_crusher, triceps_dip). This card is a complete triceps day with all three triceps-head angles: long head (overhead extension), lateral head (rope pushdown, kickback), full sweep (skull crusher). Skull crusher overlap with existing card is intentional — both are triceps days but from different angles.
- Image: `photos/workouts/equipment_arms_triceps_burst.webp`

### `equipment_arms_biceps_detail` — Ekipmanlı Ön Kol Detayı
- Category: `arms` · Level: `Orta düzey` · 16 min · 4 exercises
- Slugs: `preacher_curl`, `incline_dumbbell_curl`, `cable_curl`, `concentration_curl`
- **Rationale:** existing `equipment_arms_biceps` is the foundation card (biceps_curl, hammer_curl, concentration_curl). This is the **isolation-detail variant** focused on different elbow angles: preacher (locked, peak), incline (stretched, long head emphasis), cable (constant tension), concentration (squeeze finisher). Concentration appears in both cards intentionally — it's the universal closer.
- Image: `photos/workouts/equipment_arms_biceps_detail.webp`

### `equipment_glutes_strength` — Glute Gücü Programı
- Category: `legs` · Level: `Orta düzey` · 22 min · 4 exercises
- Slugs: `hip_thrust`, `walking_lunge_dumbbell`, `dumbbell_step_up`, `romanian_deadlift`
- **Rationale:** the user explicitly requested "Ekipmanlı Glute Gücü". Existing `equipment_legs_power` is quad-dominant (barbell squat, leg press, RDL, leg extension, leg curl). This card prioritizes the **glute** chain: hip thrust as primary, walking lunge for unilateral activation, step-up for glute medius, RDL for posterior chain. RDL overlap with existing legs_power is fine — two different program purposes.
- Title note: dropped the "Ekipmanlı" prefix because "Glute Gücü Programı" reads more native in TR fitness vernacular than "Ekipmanlı Glute Gücü".
- Image: `photos/workouts/equipment_glutes_strength.webp`

### `equipment_core_stability_weighted` — Ağırlıklı Core Stabilitesi
- Category: `core` · Level: `İleri` · 18 min · 4 exercises
- Slugs: `weighted_sit_up`, `weighted_leg_raise`, `dragon_flag`, `medicine_ball_russian_twist`
- **Rationale:** existing `equipment_core_loaded` covers cable-based and hanging core work (cable crunch, hanging leg raise, weighted russian twist, ab wheel rollout). The new card is the **dumbbell / loaded-bodyweight** counterpart with specific anti-extension and dynamic-strength emphasis: weighted sit-up (loaded flexion), weighted leg raise (loaded hip flexion), dragon flag (anti-extension peak), MB russian twist (rotational power). Different equipment, different stimulus. The two cards together deliver a complete loaded-core program.
- Image: `photos/workouts/equipment_core_stability_weighted.webp`

### `equipment_fullbody_hiit` — Ekipmanlı Full Body HIIT
- Category: `fullBody` · Level: `İleri` · 20 min · 4 exercises
- Slugs: `kettlebell_swing`, `thruster`, `dumbbell_clean`, `box_jump`
- **Rationale:** the user explicitly requested "Ekipmanlı Full Body HIIT". The existing equipment strip had no full-body card. This pulls together the four Phase 96 dynamic full-body / Olympic-style movements: KB swing (hip hinge power), thruster (squat + press), DB hang clean (triple extension), box jump (lower-body plyo finisher). Cardio category, advanced level, designed for circuit / EMOM-style execution.
- Image: `photos/workouts/equipment_fullbody_hiit.webp`

---

## REGIONAL — 24 NEW PROGRAMS

### Core (4 new)

#### `core_static_resistance` — Statik Çekirdek Direnci
- Category: `core` · Level: `Orta düzey` · 14 min · 5 exercises
- Slugs: `plank`, `hollow_hold`, `side_plank`, `bird_dog`, `dead_bug`
- **Rationale:** static + anti-rotation focus — distinct from the existing `core_steel_abs` (which leans dynamic with russian_twist + mountain_climber + bicycle_crunch). Pure stability work. Flow: front plank → hollow body → lateral plank → quadruped balance → supine balance.
- Image: `photos/workouts/core_static_resistance.webp`

#### `core_lower_abs` — Alt Karın Şekillendirme
- Category: `core` · Level: `Orta düzey` · 12 min · 4 exercises
- Slugs: `reverse_crunch`, `leg_raise`, `hanging_leg_raise`, `toe_touch`
- **Rationale:** lower-abs targeted card — most existing core templates emphasize upper abs / obliques. Reverse crunch and hanging leg raise both isolate the lower portion of rectus abdominis. Flow: reverse crunch (foundation) → leg raise (isometric strength) → hanging leg raise (peak loading) → toe touch (full chain).
- Image: `photos/workouts/core_lower_abs.webp`

#### `core_oblique_burner` — Yan Kas Yakıcı
- Category: `core` · Level: `Başlangıç` · 12 min · 4 exercises
- Slugs: `russian_twist`, `bicycle_crunch`, `side_plank`, `mountain_climber`
- **Rationale:** dedicated oblique day — pulls four distinct rotation/anti-rotation / lateral-flexion movements. Russian twist and bicycle crunch overlap with `core_athletic` but the program purpose is different (oblique focus, not all-around core). Flow: rotation → cross-pattern → lateral hold → dynamic conditioning.
- Image: `photos/workouts/core_oblique_burner.webp`

#### `core_mobility_flow` — Mobiliteli Karın Akışı
- Category: `core` · Level: `Başlangıç` · 14 min · 5 exercises
- Slugs: `cat_cow`, `bird_dog`, `dead_bug`, `side_plank`, `plank`
- **Rationale:** the only core card built for users who can't do hard crunches yet — flexibility-friendly, lower-back-friendly entry. Cat-cow (mobility warm-up) → bird dog (anti-rotation) → dead bug (anti-extension) → side plank (lateral) → plank (front). Progressive stability with no spinal flexion required.
- Image: `photos/workouts/core_mobility_flow.webp`

---

### Chest (3 new)

#### `chest_bodyweight_burst` — Bodyweight Göğüs Patlaması
- Category: `chest` · Level: `İleri` · 16 min · 4 exercises
- Slugs: `wide_push_up`, `diamond_push_up`, `archer_push_up`, `decline_push_up`
- **Rationale:** all advanced bodyweight push-up variants from Phase 96 in one workout. Different angles + grip widths hit chest from every plane: wide (sweep), diamond (inner pec/triceps), archer (unilateral overload), decline (upper chest finisher). No equipment needed.
- Image: `photos/workouts/chest_bodyweight_burst.webp`

#### `chest_plyo_explosive` — Patlayıcı Plyo Göğüs
- Category: `chest` · Level: `İleri` · 18 min · 4 exercises
- Slugs: `clap_push_up`, `decline_push_up`, `archer_push_up`, `push_up`
- **Rationale:** explosive/plyometric chest day. Clap push-up as the primary plyo movement, decline + archer as advanced strength, regular push-up as a fatigue closer (high-rep). Different exercise mix from `chest_bodyweight_burst` (no diamond, no wide, but with clap + push_up). Cards are distinct.
- Image: `photos/workouts/chest_plyo_explosive.webp`

#### `chest_beginner_flow` — Yeni Başlayan Göğüs Akışı
- Category: `chest` · Level: `Başlangıç` · 8 min · 3 exercises
- Slugs: `knee_push_up`, `incline_push_up`, `push_up`
- **Rationale:** entry-level progression. Knee push-up (regression) → incline push-up (intermediate) → standard push-up (target). Replaces the gap below `chest_activation_growth` (which is also Başlangıç but only has 2 exercises). 8-minute commitment makes it usable as a quick first session.
- Image: `photos/workouts/chest_beginner_flow.webp`

---

### Back (3 new)

#### `back_bodyweight_activation` — Bodyweight Sırt Aktivasyonu
- Category: `back` · Level: `Orta düzey` · 18 min · 5 exercises
- Slugs: `inverted_row`, `swimmer`, `prone_y_raise`, `prone_t_raise`, `scapular_pull_up`
- **Rationale:** the only back card requiring no weights (one bar / table for inverted row + scapular pull-up). Hits every back region: lats (inverted row), erectors (swimmer), upper back / rhomboids (Y-raise, T-raise), scapular control (scap pull-up). Flow: compound bodyweight pull → posterior chain → scapular detail.
- Image: `photos/workouts/back_bodyweight_activation.webp`

#### `back_postural_corrective` — Postüral Sırt Düzeltme
- Category: `back` · Level: `Başlangıç` · 14 min · 5 exercises
- Slugs: `swimmer`, `bird_dog`, `prone_y_raise`, `prone_t_raise`, `scapular_wall_slide`
- **Rationale:** dedicated posture-correction card (similar intent to existing `back_posture_basic` but uses bodyweight only and distinct exercises). Flow targets the kyphotic-shoulders pattern: swimmer (full posterior chain), bird dog (anti-rotation core/back), Y/T raises (rhomboid retraction), scapular slide (mobility).
- Image: `photos/workouts/back_postural_corrective.webp`

#### `back_hanging_workout` — Asılı Sırt Antrenmanı
- Category: `back` · Level: `İleri` · 18 min · 4 exercises
- Slugs: `scapular_pull_up`, `dead_hang`, `pull_up`, `chin_up`
- **Rationale:** all hanging/bar work in one card. Scapular pull-up activates → dead hang builds grip endurance → pull-up (overhand) → chin-up (underhand) build mass. Pull-up + chin-up overlap with `back_v_taper` (which uses both) but the program structure is different — V-taper opens with pull-up + chin-up + lat pulldown + barbell row (mixed equipment). The new card is bar-only.
- Image: `photos/workouts/back_hanging_workout.webp`

---

### Shoulders (3 new)

#### `shoulders_advanced_bodyweight` — İleri Bodyweight Omuz
- Category: `shoulders` · Level: `İleri` · 18 min · 4 exercises
- Slugs: `handstand_hold`, `wall_walk`, `handstand_push_up`, `pike_push_up`
- **Rationale:** the only "Bölgeler › Omuz" card that doesn't require dumbbells. Pure inverted bodyweight progression: handstand hold (isometric base) → wall walk (eccentric/dynamic) → handstand push-up (full ROM) → pike push-up (volume finisher when shoulders are fatigued).
- Image: `photos/workouts/shoulders_advanced_bodyweight.webp`

#### `shoulders_mobility_opening` — Omuz Mobilite ve Açılış
- Category: `shoulders` · Level: `Başlangıç` · 10 min · 3 exercises
- Slugs: `scapular_wall_slide`, `pike_walk`, `downward_dog`
- **Rationale:** beginner / warm-up card. Wall slide for scapular mobility → pike walk for anterior chain stretch + shoulder loading → downward dog as final hold. 10-minute flow that doubles as a daily mobility routine.
- Image: `photos/workouts/shoulders_mobility_opening.webp`

#### `shoulders_scapular_stability` — Skapular Stabilite
- Category: `shoulders` · Level: `Başlangıç` · 12 min · 4 exercises
- Slugs: `scapular_wall_slide`, `scapular_pull_up`, `prone_y_raise`, `prone_t_raise`
- **Rationale:** scapular control + rotator-cuff health. Slide warm-up → scap pull-up (loaded depression/retraction) → Y-raise (lower trap) → T-raise (rhomboid). Excellent prehab card for office workers and lifters with rounded shoulders.
- Image: `photos/workouts/shoulders_scapular_stability.webp`

---

### Arms (3 new)

#### `arms_bodyweight_burst` — Bodyweight Kol Patlaması
- Category: `arms` · Level: `Orta düzey` · 14 min · 4 exercises
- Slugs: `close_grip_push_up`, `diamond_push_up`, `bench_dip`, `tricep_extension_floor`
- **Rationale:** the only "Bölgeler › Kol" card that needs zero dumbbells. Triceps-dominant movements via four different angles. Diamond appears in both `chest_bodyweight_burst` and here — it's the universal arm/chest movement; users naturally find it in both contexts.
- Image: `photos/workouts/arms_bodyweight_burst.webp`

#### `arms_triceps_bodyweight` — Triceps Yoğun Bodyweight
- Category: `arms` · Level: `Orta düzey` · 14 min · 4 exercises
- Slugs: `bench_dip`, `close_grip_push_up`, `tricep_extension_floor`, `pike_push_up_close`
- **Rationale:** specialized triceps card. Three distinct triceps mechanics: dip (lateral head), close-grip push (long head), floor extension (medial head), close pike (overhead-position long head). All bodyweight. Pike close + close-grip push overlap is intentional — they are biomechanically different (different pressing angles).
- Image: `photos/workouts/arms_triceps_bodyweight.webp`

#### `arms_hanging_grip` — Asılı Kol & Grip Antrenmanı
- Category: `arms` · Level: `İleri` · 12 min · 3 exercises
- Slugs: `chin_up_negative`, `dead_hang`, `scapular_pull_up`
- **Rationale:** dedicated grip + biceps pull strength. Chin-up negative (eccentric biceps overload), dead hang (grip endurance), scapular pull-up (back/biceps activation). Short workout because all three exercises are nervous-system intensive.
- Image: `photos/workouts/arms_hanging_grip.webp`

---

### Legs (4 new)

#### `legs_glute_activation` — Glute Aktivasyonu
- Category: `legs` · Level: `Başlangıç` · 12 min · 4 exercises
- Slugs: `glute_bridge`, `frog_pump`, `single_leg_glute_bridge`, `sumo_squat`
- **Rationale:** dedicated glute warm-up / activation card — perfect either as a standalone or before any leg day. Bridge → frog pump → single-leg bridge → sumo squat builds from foundational to compound. No equipment.
- Image: `photos/workouts/legs_glute_activation.webp`

#### `legs_single_leg_bodyweight` — Tek Bacak Bodyweight
- Category: `legs` · Level: `İleri` · 18 min · 4 exercises
- Slugs: `pistol_squat`, `bulgarian_split_squat`, `single_leg_rdl`, `calf_raise`
- **Rationale:** unilateral lower-body specialist card. Pistol squat (peak strength) → BSS (split-stance) → single-leg RDL (posterior chain) → calf raise (downstream). Tests balance, strength, and proprioception all from one leg.
- Image: `photos/workouts/legs_single_leg_bodyweight.webp`

#### `legs_plyometric_burst` — Plyometrik Bacak Patlaması
- Category: `legs` · Level: `İleri` · 16 min · 4 exercises
- Slugs: `box_jump`, `tuck_jump`, `jump_squat`, `squat_jump_pulse`
- **Rationale:** all four jump variants from the catalogue in one HIIT-style card. Box jump (max effort) → tuck jump (knee drive) → jump squat (continuous power) → squat pulse jump (endurance finisher). Cardiovascular + lower-body power.
- Image: `photos/workouts/legs_plyometric_burst.webp`

#### `legs_sumo_adductor` — Sumo & İç Uyluk
- Category: `legs` · Level: `Başlangıç` · 14 min · 4 exercises
- Slugs: `sumo_squat`, `single_leg_glute_bridge`, `frog_pump`, `lunge`
- **Rationale:** inner-thigh / adductor card. Sumo squat as primary (wide stance loads adductors), single-leg bridge for glute medius assist, frog pump for hip-external-rotation activation, lunge as a closing compound. Minor overlap with `legs_glute_activation` but a different focus.
- Image: `photos/workouts/legs_sumo_adductor.webp`

---

### Cardio / Full Body (4 new — under Kardiyo chip)

#### `cardio_hiit_burst` — HIIT Patlaması
- Category: `fullBody` · Level: `İleri` · 18 min · 5 exercises
- Slugs: `burpee`, `squat_thrust`, `half_burpee`, `jump_squat`, `mountain_climber`
- **Rationale:** the dedicated HIIT card the user explicitly listed as a goal. All burpee-family + jump-squat + mountain climber. Designed for round/AMRAP execution. Distinct from existing `cardio_full_body_burst` (which mixes burpee + jumping_jack + skipping_rope) by focusing on the harder ground-work variants.
- Image: `photos/workouts/cardio_hiit_burst.webp`

#### `cardio_mobility_stretch` — Mobilite ve Esneklik Akışı
- Category: `fullBody` · Level: `Başlangıç` · 12 min · 6 exercises
- Slugs: `cat_cow`, `child_pose`, `downward_dog`, `cobra_stretch`, `hip_flexor_stretch`, `standing_hamstring_stretch`
- **Rationale:** the only **mobility / stretching** card in the entire dashboard. Lives under Kardiyo because no Mobility chip exists (Phase 96 signoff). Full-body stretch flow: spine mobility → rest position → posterior chain stretch → anterior chain stretch → hip flexor → hamstring. Yoga-class pacing.
- Image: `photos/workouts/cardio_mobility_stretch.webp`

#### `cardio_shadow_box` — Shadow Box Cardio
- Category: `fullBody` · Level: `Başlangıç` · 14 min · 4 exercises
- Slugs: `shadow_boxing`, `lateral_shuffle`, `high_knees`, `jumping_jack`
- **Rationale:** beginner-friendly cardio with movement variety. Shadow boxing is a Phase 96 add — pairs naturally with lateral shuffle, high knees, and jumping jacks for a 14-minute round-robin. Lower-impact than HIIT.
- Image: `photos/workouts/cardio_shadow_box.webp`

#### `cardio_full_body_flow` — Tüm Vücut Hareket Akışı
- Category: `fullBody` · Level: `Orta düzey` · 14 min · 4 exercises
- Slugs: `bear_crawl`, `mountain_climber`, `plank_jack`, `lateral_shuffle`
- **Rationale:** ground-work conditioning card. Bear crawl (multi-limb coordination) → mountain climber (core + cardio) → plank jack (core + lateral) → lateral shuffle (athletic stance). Conditions cardiovascularly while reinforcing core stability under load.
- Image: `photos/workouts/cardio_full_body_flow.webp`

---

## Implementation Notes

The Dart edit appends each block above to `_equipmentTemplates` (8 entries, after `equipment_core_loaded`) and `_regionalTemplates` (24 entries, distributed by category to keep the existing `// ---- X ----` comment structure tidy).

The `image:` field on every new template uses the same `'photos/workouts/<id>.webp'` convention as existing templates. Since `assets/photos/workouts/` is empty, the cards render the fallback fitness icon — identical visual to every existing card. When dedicated hero images are produced later, the matching filenames light up the cards automatically.

No new constants needed in `equipment_strip.dart` for tints — the `_equipmentTints[index % length]` modulo cycles existing colors. If a future polish phase wants per-card unique colors, the tint list can be extended; not required for Phase 97.

---

End of new dashboard programs spec.
