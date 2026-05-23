# Visual Swap Mini Session — Report

Branch: `feature/cdn-meal-migration`
Date: 2026-05-22
Scope: pure visual asset replacement (no logic / UI / layout changes)

---

## Task 1 — Global AI coach photo replacement

**Old:** `photos/kişiselyapayzekakoçfoto.webp`
**New:** `photos/PT_FORM.png`

8 occurrences across 7 files:

| File | Line | Context |
| --- | --- | --- |
| `lib/features/onboarding/presentation/steps/act_5_commitment_step.dart` | 564 | `_AiCoachPanel._coachAsset` const |
| `lib/features/home/presentation/widgets/weekly_goal_card.dart` | 240 | `Image.asset` inside `ClipOval` |
| `lib/features/onboarding/presentation/widgets/living_coach_avatar.dart` | 68 | `LivingCoachAvatar.assetPath` default |
| `lib/features/onboarding/presentation/prediction_screen.dart` | 328 | `Image.asset` inside `ClipRRect` |
| `lib/features/onboarding/presentation/onboarding_screen.dart` | 142 | precache list entry |
| `lib/features/progress/presentation/suggestions_screen.dart` | 313 | `Image.asset` inside `ClipOval` |
| `lib/features/home/presentation/widgets/gelisim_tab.dart` | 1647 | doc comment |
| `lib/features/home/presentation/widgets/gelisim_tab.dart` | 1708 | `Image.asset` inside `_CoachAvatar` |

Widget / layout / clip-shape / glow / animation behavior preserved — only the asset string changed.

---

## Task 2 — First opening screen background

**Old:** `photos/ilkkarşılamaanaekranarkaplanı.webp`
**New:** `photos/First_opening.png`

| File | Line | Context |
| --- | --- | --- |
| `lib/features/onboarding/presentation/steps/act_1_hook_step.dart` | 139 | parallax background `Image.asset` |

Text, button, onboarding logic, cinematic effects, gradients, overlays and timing untouched.

---

## Task 3 — Second opening screen background

**Discovered original asset:** `photos/merhababenseninkişiselyapayzekakoçunumyeniarkaplan.webp`
Identified via the "Merhaba, ben Form…" coach line in `act_2_bonding_step.dart` (line 56), whose Stack's first child is the background `Image.asset` at line 163.

**New:** `photos/Second_screen.png`

| File | Line | Context |
| --- | --- | --- |
| `lib/features/onboarding/presentation/steps/act_2_bonding_step.dart` | 163 | parallax background `Image.asset` |

AI typing system, coach avatar logic, bubble, animations, transitions and messaging untouched.

---

## Validation

### grep — old references remaining in code

Command:
```
grep -rln "kişiselyapayzekakoçfoto\|ilkkarşılamaanaekranarkaplanı\|merhababenseninkişiselyapayzekakoçunumyeniarkaplan" --include="*.dart" --include="*.yaml" --include="*.yml"
```

Result: **none** — zero remaining usages in dart/yaml.

Note: `.claude/settings.local.json` still references the old filenames inside Bash permission allowlist patterns (e.g. `identify .../kişiselyapayzekakoçfoto.webp`, `convert .../ilkkarşılamaanaekranarkaplanı.webp ...`). Those are permission rules, not code, and were left alone.

The old `.webp` files themselves remain on disk under `photos/` (asset directory is registered as `- "photos/"` in `pubspec.yaml`); deleting them is out of scope for this visual-swap session.

### flutter analyze

```
Analyzing FormAI-FitnessKoçu...
No issues found! (ran in 7.1s)
```

### Visual sanity

Not exercised in this session (no emulator/device hookup) — all affected widgets keep their wrapping `ClipOval` / `ClipRRect` / `Stack` / `Image.asset` parameters (`fit: BoxFit.cover`, `errorBuilder`, sizing) identical, so layout behavior is unchanged. Worst case (asset decode failure) is already handled by the existing `errorBuilder` fallbacks.

---

## Files changed

```
lib/features/onboarding/presentation/onboarding_screen.dart
lib/features/onboarding/presentation/prediction_screen.dart
lib/features/onboarding/presentation/steps/act_1_hook_step.dart
lib/features/onboarding/presentation/steps/act_2_bonding_step.dart
lib/features/onboarding/presentation/steps/act_5_commitment_step.dart
lib/features/onboarding/presentation/widgets/living_coach_avatar.dart
lib/features/home/presentation/widgets/gelisim_tab.dart
lib/features/home/presentation/widgets/weekly_goal_card.dart
lib/features/progress/presentation/suggestions_screen.dart
```

9 files, 10 string replacements. No structural changes.

---

## Task 4 — First opening screen background (hotfix, supersedes Task 2)

Date: 2026-05-23

**Old:** `photos/First_opening.png`
**New:** `photos/APP_ICON.png`

| File | Line | Context |
| --- | --- | --- |
| `lib/features/onboarding/presentation/steps/act_1_hook_step.dart` | 139 | parallax background `Image.asset` |

Only the asset string changed. `BoxFit.cover`, parallax `AnimatedBuilder` (`_bgPan` transform + scale), `errorBuilder` radial gradient fallback, overlays, gradients, CTA button, text, cinematic effects, animations, and onboarding logic untouched.

### Validation

grep — `First_opening` is gone from `lib/` and `pubspec.yaml`; sole reference now reads `photos/APP_ICON.png`.

```
Analyzing FormAI-FitnessKoçu...
No issues found! (ran in 8.2s)
```

1 file, 1 string replacement.
