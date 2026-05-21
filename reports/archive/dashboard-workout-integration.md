# Dashboard Workout Integration — Phase 97

**Status:** integration plan + code change for `lib/features/workout/data/workout_repository.dart`. **Dart-side only — no schema changes, no SQL.**
**Generated:** 2026-05-11
**Companion files:** `workout-category-distribution.md` (per-tab map), `new-dashboard-programs.md` (per-card spec with rationale).

---

## 0. Context & TL;DR

Phase 96 added 87 new rows to `public.exercises` and is already live in Supabase. The catalogue is now 138 exercises. The dashboard's two browsing surfaces — **Ekipmanlı Egzersizler** (top horizontal strip) and **Bölgeler** (chip-filtered regional list) — still serve only the original 7 equipment templates and ~21 regional templates from Phases 50A/85. Phase 97's job is to weave the new exercises into those surfaces as **curated workout programs**, not as a raw exercise dump.

Phase 97 adds:
- **8 new equipment programs** to `_equipmentTemplates` (7 existing → 15 total)
- **24 new regional programs** to `_regionalTemplates` (21 existing → 45 total)

All additions follow the existing `_PlanTemplate` shape and the slug-only resolution pattern. Missing slugs drop silently (the live Supabase rows for Phase 96 are guaranteed to resolve since the SQL is applied).

---

## 1. UX Architecture (verified against the code)

### 1.1 The two surfaces

- **`EquipmentStrip`** (`lib/features/home/presentation/widgets/equipment_strip.dart`)
  - Horizontal `ListView.separated`, height 200, card width 240, 12 px separator.
  - Reads `equipmentPlansProvider` (`getEquipmentPlans()` in `WorkoutRepository`).
  - Card tint cycles via `_equipmentTints[index % length]` — adding cards beyond 7 cycles the existing 7 colors. Acceptable for now; could be expanded in a future polish phase.
  - Card visual: tint gradient + dim image overlay + title + summary (`level · X Dk`) + "BAŞLA" pill.
  - Tap → `AppRoutes.planDetail` with the `WorkoutPlan` as `extra`.

- **`AntrenmanTab`** (`lib/features/home/presentation/widgets/antrenman_tab.dart`)
  - "Bölgeler" `_SectionTitle` → `_CategoryChipsRow` → `_RegionalPlansList`.
  - Chip definitions (line 54-62):
    ```dart
    [
      (label: 'Core',    category: ExerciseCategory.core),
      (label: 'Göğüs',   category: ExerciseCategory.chest),
      (label: 'Sırt',    category: ExerciseCategory.back),
      (label: 'Omuz',    category: ExerciseCategory.shoulders),
      (label: 'Kol',     category: ExerciseCategory.arms),
      (label: 'Bacak',   category: ExerciseCategory.legs),
      (label: 'Kardiyo', category: ExerciseCategory.fullBody),
    ]
    ```
  - Plans filtered by `_selectedCategory` (defaults to `core`).
  - Each plan tile: 64×64 image (or fallback icon) + title + summary + chevron pill.
  - Empty state per category: "Bu bölge için plan bulunmuyor — diğer kategorileri keşfedebilirsin." (already polished).

### 1.2 Image rendering reality (important)

The `assets/photos/workouts/` directory is **declared in `pubspec.yaml` but empty**. Every existing template references `'photos/workouts/<id>.webp'`, none of which resolve. The `Image.asset(...).errorBuilder` falls back to a neutral fitness icon. This means:

- I follow the same convention for new templates (`'photos/workouts/<new_id>.webp'`), knowing they will fall back to the same icon as every existing card. Visual parity is preserved.
- If your design team later renders hero images, they can drop them in with the matching filename and every card lights up at once — no code change.
- Alternative would be `image: null`, which the regional tile handles with a built-in fitness icon block too. Both look identical at runtime. I keep the path convention to match the existing pattern.

### 1.3 Existing template count and naming flavor

**Equipment (7 existing):**
| ID | Title | Category | Level | Min |
|---|---|---|---|---|
| `equipment_chest_strength` | Ekipmanlı Göğüs Gücü | chest | Orta düzey | 22 |
| `equipment_back_width` | Ekipmanlı Sırt Genişliği | back | Orta düzey | 24 |
| `equipment_shoulders_round` | Yuvarlak Omuz Şekillendirme | shoulders | Orta düzey | 20 |
| `equipment_arms_biceps` | Ekipmanlı Biceps Pompası | arms | Orta düzey | 14 |
| `equipment_arms_triceps` | Ekipmanlı Triceps Yoğunluğu | arms | Orta düzey | 14 |
| `equipment_legs_power` | Ekipmanlı Bacak Gücü | legs | İleri | 28 |
| `equipment_core_loaded` | Ağırlıklı Karın Şekillendirme | core | İleri | 18 |

Naming variation observed: some are `Ekipmanlı X Y`, some break the prefix (`Yuvarlak Omuz Şekillendirme`, `Ağırlıklı Karın Şekillendirme`). I respect that variation — Phase 97 names blend `Ekipmanlı X`, descriptive Turkish nouns (`Dev Omuz Patlaması`), and program-type suffixes (`HIIT`).

**Regional (21 existing):** distribution per category is uneven — chest has 4 cards, core only 2. Phase 97 rebalances to ≥5 per chip without overloading any one tab.

---

## 2. Integration Philosophy

Three rules that shape every Phase 97 addition:

### Rule 1 — Curated programs, not exercise dumps

Each new template represents a **workout someone could actually do**: a warm-up movement (when relevant), a heavy compound, an accessory, an isolation finisher. Programs follow the implicit `push → pull → fatigue` flow visible in the existing templates.

Example: `chest_bodyweight_burst` doesn't list 8 push-up variants. It lists 4 distinct biomechanical patterns (`wide_push_up` for chest sweep → `diamond_push_up` for inner pec/triceps → `archer_push_up` for unilateral stress → `decline_push_up` for upper chest finisher). One workout, one progression.

### Rule 2 — Equipment programs are equipment-only

The `_equipmentTemplates` list is the **only** way an equipment-only movement (e.g. `hip_thrust`, `kettlebell_swing`, `cable_crossover`) surfaces as a top-strip card. New equipment templates pull exclusively from the equipment-tagged Phase 96 slugs. Bodyweight slugs are explicitly reserved for the regional list.

### Rule 3 — Bodyweight regional programs follow chip semantics

When the user taps "Core", they expect core-targeted exercises. When they tap "Omuz", they expect shoulder work. Phase 97 places each new bodyweight movement under the chip that matches its **primary** target — not its sub-tags. So:
- `dead_bug` → Core (primary = `core`, even though it's also a balance drill)
- `pike_walk` → Omuz (primary = `shoulders`, even though it stretches hamstrings)
- `glute_bridge` → Bacak (primary = `lower_body`, even though it's glute-specific)
- `cat_cow` / `child_pose` / `downward_dog` → Kardiyo (mobility flows live with the cardio category since there's no Mobility chip — by signoff in Phase 96, we did not expand the enum)

### Rule 4 — Difficulty balance is per chip, not per program

Each chip should now have at least one Başlangıç, Orta düzey, AND İleri card so users at any level have an entry point. Phase 97's additions deliberately fill gaps:
- Core had no İleri card → adds nothing (existing core_athletic stays Orta düzey; new core_static_resistance Orta düzey, core_lower_abs Orta düzey, core_oblique_burner Başlangıç, core_mobility_flow Başlangıç). Decision: rely on the equipment_core_stability_weighted İleri card for advanced core. Acceptable since the core chip mainly serves bodyweight.
- Omuz had only one Başlangıç → adds shoulders_mobility_opening (Başlangıç) and shoulders_scapular_stability (Başlangıç) so beginners have multiple paths.
- Sırt only had 2 templates → adds 3 to bring it to 5.

---

## 3. Naming Conventions Applied

Existing Turkish naming style observed:
- 1-3 words, evocative, mid-energy ("Çelik Gibi Karın", "V-Tipi Omuz Şekillendirme")
- Avoids robotic AI tone, avoids excessive English
- Mixes loanwords when standard in TR fitness vernacular (Bench Press, Curl, HIIT)
- Prefix `Ekipmanlı X` for equipment programs (with some exceptions noted above)

Phase 97 names lean into this:
- **Equipment additions:** "Ekipmanlı Sırt Kalınlığı", "Glute Gücü Programı", "Dev Omuz Patlaması", "Ekipmanlı Full Body HIIT", "Ağırlıklı Core Stabilitesi"
- **Regional additions:** "Statik Çekirdek Direnci", "Patlayıcı Plyo Göğüs", "Postüral Sırt Düzeltme", "İleri Bodyweight Omuz", "Glute Aktivasyonu", "Plyometrik Bacak Patlaması", "Mobilite ve Esneklik Akışı"

I avoided:
- Bilingual mush ("Equipment Chest" / "Power HIIT")
- Long-tail SEO-style names ("En İyi Kollar İçin 4-Hareketli Şınav")
- Overly clever metaphors that don't fit the existing register

---

## 4. Card Count After Phase 97

| Section | Pre-Phase-97 | Phase 97 additions | Post-Phase-97 |
|---|---:|---:|---:|
| Ekipmanlı Egzersizler (horizontal strip) | 7 | +8 | **15** |
| Bölgeler › Core | 2 | +4 | **6** |
| Bölgeler › Göğüs | 4 | +3 | **7** |
| Bölgeler › Sırt | 2 | +3 | **5** |
| Bölgeler › Omuz | 3 | +3 | **6** |
| Bölgeler › Kol | 3 | +3 | **6** |
| Bölgeler › Bacak | 4 | +4 | **8** |
| Bölgeler › Kardiyo | 3 | +4 | **7** |
| **Regional total** | **21** | **+24** | **45** |
| **Grand total templates** | **28** | **+32** | **60** |

Every chip now has at least 5 cards. No chip exceeds 8 — comfortable scroll depth in a vertical ListView on a phone screen. The equipment strip at 15 cards is long but discoverable: the user already swipes horizontally, and the variety is now genuine (chest variants, back density, glutes, HIIT, weighted core).

---

## 5. Implementation Surface

### Files touched
- `lib/features/workout/data/workout_repository.dart` — additions to `_equipmentTemplates` (8 new entries) and `_regionalTemplates` (24 new entries).

### Files NOT touched
- `lib/features/home/presentation/widgets/equipment_strip.dart` — the 7-color tint cycle handles >7 cards via modulo. No edits needed unless a unique tint per card is desired (out of scope).
- `lib/features/home/presentation/widgets/antrenman_tab.dart` — chip definitions, filtering logic, plan tile rendering all remain unchanged.
- `analyzer_factory.dart` — already Phase-96-complete; no Phase 97 changes.
- Any model file, any provider file, any SQL file.

### Why this is safe
- The `_PlanTemplate.resolve(bySlug)` path in `workout_repository.dart` already drops missing slugs silently (line 932-965). Phase 96's SQL is applied, so all referenced slugs resolve.
- The `_equipmentTemplates` and `_regionalTemplates` lists are `static const`. Adding entries is a pure compile-time additive change.
- Hero images are missing for every existing template too — the fallback icon path is already production-tested.
- No Riverpod provider invalidation needed; the next time `equipmentPlansProvider` / `workoutPlansProvider` is rebuilt (next app launch), the new cards appear.

---

## 6. Validation Checklist

- [x] Every new template references only Phase-96-or-earlier slugs (no typos, no future slugs).
- [x] Equipment programs contain **only** equipment-compatible slugs.
- [x] Regional bodyweight programs contain **only** bodyweight slugs (one exception flagged: regional bench-using cards may include `bench_dip` / `inverted_row` since they only need a bench/bar already present in most homes).
- [x] No card duplicates an existing program's exact slug list.
- [x] Each chip ends with at least 5 cards.
- [x] Each chip has at least one Başlangıç difficulty card (or, in core's case, the Başlangıç gap is filled by an existing card).
- [x] Realistic durations: 6–28 min range; nothing under 6 min or over 30 min.
- [x] Turkish naming consistent with existing register; no robotic AI titles.
- [x] Image paths follow `photos/workouts/<id>.webp` convention (fallback handles missing files).
- [ ] Pending: `flutter analyze lib/features/workout/data/workout_repository.dart` — expect 0 issues.

---

## 7. Risks & Mitigation

| Risk | Mitigation |
|---|---|
| Phase 96 slug missing from live DB → silent card collapse | The migration is reported as applied. If a slug really is missing, the template's `resolve()` returns a shorter exercise list and the card still renders — same graceful-degradation pattern Phase 50A introduced. |
| 15-card equipment strip feels long | Horizontal scroll is already the interaction model; users self-pace. If the strip is too dense in QA, the lowest-priority cards can be removed without touching anything else. |
| Hero images still missing → fallback icon on every new card | Phase 97 doesn't claim to fix the missing-image issue. Cards render identically to existing cards (which also use the fallback). When images are eventually rendered, drop them in `assets/photos/workouts/` with matching filenames — no code edit. |
| Generator doesn't pick up the new exercises in 30-day plans | The generator reads from the full Supabase pool. Phase 97 doesn't touch the generator. New users + `resetProgress()` users see Phase 96 exercises in their plans, separate from the new dashboard cards. |
| User confusion: equipment cards include exercises they don't have | The card detail screen already shows what each program needs. Phase 97 doesn't change that. Future polish could add an "equipment required" icon list on each card, but out of scope here. |

---

## 8. Memory & Safety Trail

This phase is a Dart-only template addition. Per the `feedback_safety_first_on_shared_state.md` memory:

> Halt before mutating shared/production state — diagnose + artifact + pause-for-signoff.

Phase 97 mutates only static Dart code (compile-time additions). No SQL applied, no Supabase rows touched, no schema changes, no `_planKey` bump. The user's Phase 97 directive ("Modify ALL required files directly") explicitly authorizes the code change. The 3 deliverable reports serve as the diagnosis artifact.

---

End of integration plan.
