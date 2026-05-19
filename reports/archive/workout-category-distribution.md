# Workout Category Distribution — Phase 97

**Status:** per-tab manifest of every dashboard card after Phase 97 lands.
**Generated:** 2026-05-11
**Purpose:** the cheat-sheet a designer or PM uses to see exactly what shows up under each chip and on the equipment strip.

---

## EQUIPMENT STRIP — 15 cards (7 existing + 8 new)

| # | ID | Title | Cat | Level | Min | Status |
|---:|---|---|---|---|---:|---|
| 1 | `equipment_chest_strength` | Ekipmanlı Göğüs Gücü | chest | Orta düzey | 22 | existing |
| 2 | `equipment_chest_sculpt` | Ekipmanlı Göğüs Şekillendirme | chest | Orta düzey | 22 | **new** |
| 3 | `equipment_back_width` | Ekipmanlı Sırt Genişliği | back | Orta düzey | 24 | existing |
| 4 | `equipment_back_thickness` | Ekipmanlı Sırt Kalınlığı | back | Orta düzey | 22 | **new** |
| 5 | `equipment_shoulders_round` | Yuvarlak Omuz Şekillendirme | shoulders | Orta düzey | 20 | existing |
| 6 | `equipment_shoulder_giant_burst` | Dev Omuz Patlaması | shoulders | İleri | 24 | **new** |
| 7 | `equipment_arms_biceps` | Ekipmanlı Biceps Pompası | arms | Orta düzey | 14 | existing |
| 8 | `equipment_arms_biceps_detail` | Ekipmanlı Ön Kol Detayı | arms | Orta düzey | 16 | **new** |
| 9 | `equipment_arms_triceps` | Ekipmanlı Triceps Yoğunluğu | arms | Orta düzey | 14 | existing |
| 10 | `equipment_arms_triceps_burst` | Ekipmanlı Arka Kol Patlaması | arms | Orta düzey | 16 | **new** |
| 11 | `equipment_legs_power` | Ekipmanlı Bacak Gücü | legs | İleri | 28 | existing |
| 12 | `equipment_glutes_strength` | Glute Gücü Programı | legs | Orta düzey | 22 | **new** |
| 13 | `equipment_core_loaded` | Ağırlıklı Karın Şekillendirme | core | İleri | 18 | existing |
| 14 | `equipment_core_stability_weighted` | Ağırlıklı Core Stabilitesi | core | İleri | 18 | **new** |
| 15 | `equipment_fullbody_hiit` | Ekipmanlı Full Body HIIT | fullBody | İleri | 20 | **new** |

**Distribution by category:** chest 2 · back 2 · shoulders 2 · arms 4 · legs 2 · core 2 · fullBody 1.

**Observation:** arms gets 4 cards because the Phase 96 additions skewed bicep/tricep heavy and the existing arms_biceps / arms_triceps were too thin to absorb everything. The 4 cards are clearly differentiated (Pump / Detail / Yoğunluğu / Patlaması).

---

## BÖLGELER › CORE — 6 cards (2 existing + 4 new)

| ID | Title | Level | Min | Status |
|---|---|---|---:|---|
| `core_steel_abs` | Çelik Gibi Karın | Başlangıç | 15 | existing |
| `core_athletic` | Atletik Core | Orta düzey | 20 | existing |
| `core_static_resistance` | Statik Çekirdek Direnci | Orta düzey | 14 | **new** |
| `core_lower_abs` | Alt Karın Şekillendirme | Orta düzey | 12 | **new** |
| `core_oblique_burner` | Yan Kas Yakıcı | Başlangıç | 12 | **new** |
| `core_mobility_flow` | Mobiliteli Karın Akışı | Başlangıç | 14 | **new** |

**Difficulty mix:** 3 Başlangıç · 3 Orta düzey · 0 İleri (covered by `equipment_core_loaded` + new `equipment_core_stability_weighted` on the strip).

---

## BÖLGELER › GÖĞÜS — 7 cards (4 existing + 3 new)

| ID | Title | Level | Min | Status |
|---|---|---|---:|---|
| `chest_dumbbell_fast` | Dambıl Hızlı Göğüs Yapma | Orta düzey | 14 | existing |
| `chest_activation_growth` | Göğüs Aktivasyonu ve Büyüme | Başlangıç | 6 | existing |
| `chest_full_growth_burst` | Tam Göğüs Büyümesi ve Patlaması | İleri | 22 | existing |
| `chest_fat_burn_basic` | Göğüs Yağ Yakma Temel Planı | Orta düzey | 18 | existing |
| `chest_bodyweight_burst` | Bodyweight Göğüs Patlaması | İleri | 16 | **new** |
| `chest_plyo_explosive` | Patlayıcı Plyo Göğüs | İleri | 18 | **new** |
| `chest_beginner_flow` | Yeni Başlayan Göğüs Akışı | Başlangıç | 8 | **new** |

**Difficulty mix:** 2 Başlangıç · 2 Orta düzey · 3 İleri.

---

## BÖLGELER › SIRT — 5 cards (2 existing + 3 new)

| ID | Title | Level | Min | Status |
|---|---|---|---:|---|
| `back_v_taper` | Geniş V-Taper Sırt | Orta düzey | 22 | existing |
| `back_posture_basic` | Duruş Düzeltici Temel Sırt | Başlangıç | 12 | existing |
| `back_bodyweight_activation` | Bodyweight Sırt Aktivasyonu | Orta düzey | 18 | **new** |
| `back_postural_corrective` | Postüral Sırt Düzeltme | Başlangıç | 14 | **new** |
| `back_hanging_workout` | Asılı Sırt Antrenmanı | İleri | 18 | **new** |

**Difficulty mix:** 2 Başlangıç · 2 Orta düzey · 1 İleri.

---

## BÖLGELER › OMUZ — 6 cards (3 existing + 3 new)

| ID | Title | Level | Min | Status |
|---|---|---|---:|---|
| `shoulders_giant` | Dev Omuzlar | Orta düzey | 18 | existing |
| `shoulders_v_taper` | V-Tipi Omuz Şekillendirme | Başlangıç | 14 | existing |
| `shoulders_power_burst` | Power Omuz Patlaması | İleri | 22 | existing |
| `shoulders_advanced_bodyweight` | İleri Bodyweight Omuz | İleri | 18 | **new** |
| `shoulders_mobility_opening` | Omuz Mobilite ve Açılış | Başlangıç | 10 | **new** |
| `shoulders_scapular_stability` | Skapular Stabilite | Başlangıç | 12 | **new** |

**Difficulty mix:** 3 Başlangıç · 1 Orta düzey · 2 İleri.

---

## BÖLGELER › KOL — 6 cards (3 existing + 3 new)

| ID | Title | Level | Min | Status |
|---|---|---|---:|---|
| `arms_steel` | Çelik Kollar | Orta düzey | 14 | existing |
| `arms_explosive_super` | Patlayıcı Kol Süper Setleri | İleri | 20 | existing |
| `arms_quick_tone` | Hızlı Tonlama Kolları | Başlangıç | 10 | existing |
| `arms_bodyweight_burst` | Bodyweight Kol Patlaması | Orta düzey | 14 | **new** |
| `arms_triceps_bodyweight` | Triceps Yoğun Bodyweight | Orta düzey | 14 | **new** |
| `arms_hanging_grip` | Asılı Kol & Grip Antrenmanı | İleri | 12 | **new** |

**Difficulty mix:** 1 Başlangıç · 3 Orta düzey · 2 İleri.

---

## BÖLGELER › BACAK — 8 cards (4 existing + 4 new)

| ID | Title | Level | Min | Status |
|---|---|---|---:|---|
| `legs_quad_strength` | Büyük ve Güçlü Quadriceps Şekli | Orta düzey | 18 | existing |
| `legs_power_day` | Bacak Gücü Artışı Günü | İleri | 25 | existing |
| `legs_cardio_strength` | Alt Vücut Kardiyo ve Güç | Orta düzey | 20 | existing |
| `legs_elite_sculpt` | Elit Bacak Şekillendirme | İleri | 28 | existing |
| `legs_glute_activation` | Glute Aktivasyonu | Başlangıç | 12 | **new** |
| `legs_single_leg_bodyweight` | Tek Bacak Bodyweight | İleri | 18 | **new** |
| `legs_plyometric_burst` | Plyometrik Bacak Patlaması | İleri | 16 | **new** |
| `legs_sumo_adductor` | Sumo & İç Uyluk | Başlangıç | 14 | **new** |

**Difficulty mix:** 2 Başlangıç · 2 Orta düzey · 4 İleri.

---

## BÖLGELER › KARDİYO — 7 cards (3 existing + 4 new)

(Note: chip label is "Kardiyo" but maps to `ExerciseCategory.fullBody`. All cardio + HIIT + mobility/stretching cards live here.)

| ID | Title | Level | Min | Status |
|---|---|---|---:|---|
| `cardio_fat_burn` | Yağ Yakıcı Kardiyo | Orta düzey | 20 | existing |
| `cardio_full_body_burst` | Tam Vücut Patlama | İleri | 25 | existing |
| `cardio_morning_quick` | Hızlı Sabah Kardiyosu | Başlangıç | 12 | existing |
| `cardio_hiit_burst` | HIIT Patlaması | İleri | 18 | **new** |
| `cardio_mobility_stretch` | Mobilite ve Esneklik Akışı | Başlangıç | 12 | **new** |
| `cardio_shadow_box` | Shadow Box Cardio | Başlangıç | 14 | **new** |
| `cardio_full_body_flow` | Tüm Vücut Hareket Akışı | Orta düzey | 14 | **new** |

**Difficulty mix:** 3 Başlangıç · 2 Orta düzey · 2 İleri.

---

## SUB-MUSCLE / TAG-DRIVEN PLACEMENT VERIFICATION

Cross-check that each Phase 96 sub-muscle gets representation under at least one chip:

| Sub-muscle | Surfaced under | Card(s) |
|---|---|---|
| `abs` (lower) | Core | `core_lower_abs`, `core_steel_abs` (existing) |
| `obliques` | Core | `core_oblique_burner`, `equipment_core_stability_weighted` |
| `lower_back` | Core, Bacak | `core_mobility_flow` (cat_cow + bird_dog) |
| `inner_chest` | Göğüs, Equipment | `chest_bodyweight_burst` (diamond), `equipment_chest_sculpt` (cable_crossover) |
| `upper_chest` | Göğüs, Equipment | `equipment_chest_sculpt` (incline_chest_fly) |
| `lower_chest` | Göğüs, Equipment | `chest_bodyweight_burst` (decline), `equipment_chest_sculpt` (decline_bench) |
| `lats` | Sırt, Equipment | `back_bodyweight_activation`, `equipment_back_thickness` |
| `rhomboids` | Sırt, Equipment | `back_bodyweight_activation` (prone_t_raise), `equipment_back_thickness` (t_bar_row) |
| `traps` | Sırt, Omuz | `back_bodyweight_activation` (prone_y_raise), shoulder upright_row |
| `rear_delt` | Sırt, Omuz, Equipment | `back_bodyweight_activation`, `equipment_shoulder_giant_burst` (rear_delt_fly + cuban_press) |
| `biceps` | Kol, Equipment | `equipment_arms_biceps_detail`, `arms_hanging_grip` (chin_up_negative) |
| `triceps` | Kol, Equipment | `arms_triceps_bodyweight`, `equipment_arms_triceps_burst` |
| `forearms` / `grip` | Kol | `arms_hanging_grip` (dead_hang) — also farmer_carry on equipment_arms_triceps_burst secondarily, but primary surfacing is regional |
| `quads` | Bacak, Equipment | `legs_plyometric_burst`, `legs_quad_strength` (existing) |
| `hamstrings` | Bacak, Equipment | `legs_single_leg_bodyweight` (single_leg_rdl), `cardio_mobility_stretch` (standing_hamstring_stretch) |
| `glutes` | Bacak, Equipment | `legs_glute_activation`, `equipment_glutes_strength` |
| `calves` | Bacak | `legs_single_leg_bodyweight` (calf_raise) |
| `adductors` | Bacak | `legs_sumo_adductor` |
| `mobility` | Kardiyo | `cardio_mobility_stretch`, `core_mobility_flow`, `shoulders_mobility_opening` |
| `stretching` | Kardiyo | `cardio_mobility_stretch` |
| `hiit` | Kardiyo, Equipment | `cardio_hiit_burst`, `equipment_fullbody_hiit` |
| `hip_flexors` | Kardiyo | `cardio_mobility_stretch` |

**Every sub-muscle from Phase 96 has at least one home.** No orphan tags.

---

## TOTAL CARD COUNT BY CHIP (POST-PHASE-97)

```
Equipment strip:  15
─ Core:            6
─ Göğüs:           7
─ Sırt:            5
─ Omuz:            6
─ Kol:             6
─ Bacak:           8
─ Kardiyo:         7
                 ───
Total:            60 plan cards across the dashboard
```

The dashboard now feels populated without any chip dropping below 5 cards or exceeding 8.

---

End of distribution map.
