# Stash Phase A — Low-Risk Extraction

**Phase:** A (low-risk extraction; commit-allowed).
**Scope:** Tracks 1 + 4 of `STASH_TRIAGE_REPORT.md` §7.
**Stash mutation:** **None.** Files were extracted via
`git show stash@{0}:<path>` and applied as edits — the stash itself
remains intact at `stash@{0}: closure-work-2026-05-22`.

---

## 1 · What was extracted and applied

### 1.1 · Repo hygiene — root cleanup

Three root-level diagnostic reports archived via `git mv` to
`docs/archive/diagnostics/` (continuing the convention from
`56a5912 chore(docs): archive 50 root reports`).

| File | Destination |
|---|---|
| `RELEASE_BLACK_SCREEN_ROOT_CAUSE_REPORT.md` | `docs/archive/diagnostics/RELEASE_BLACK_SCREEN_ROOT_CAUSE_REPORT.md` |
| `RELEASE_FIXES_APPLIED.md` | `docs/archive/diagnostics/RELEASE_FIXES_APPLIED.md` |
| `RELEASE_HARDENING_CHECKLIST.md` | `docs/archive/diagnostics/RELEASE_HARDENING_CHECKLIST.md` |

Note: the stash *deletes* these three. The triage chose **archive over
delete** to preserve the historical context, consistent with the
prior archive sweep. The end-state on root is identical to the stash
(root is cleaner), but no content is destroyed.

### 1.2 · Code — self-contained helper

`lib/core/utils/app_haptics.dart` — added one public helper
(`refreshTrigger`) routing to `mediumImpact` for pull-to-refresh
gestures. +7 lines, no new imports, no dependency on Progress
Redesign companions, no behavior change on existing call sites.

### 1.3 · Docs — single-edit text fix

`web/public/privacy.html` — Delete Account paragraph rewritten for
clarity (KVKK-friendly wording, mentions in-app deletion path + email
fallback). 1-line edit, no schema or schema-link change.

---

## 2 · What was validated (no apply)

Per the Phase A contract, the SKU rename in the docs is **not** apply-
able without external (RevenueCat console + Play Console / App Store
Connect) verification. The app code does NOT reference the changed
SKUs directly — it consumes RevenueCat's standard
`current.{monthly,threeMonth,annual}` package getters — so the docs
edit cannot be validated against the repo alone.

| File | What the stash changes | Status |
|---|---|---|
| `docs/AI_CONTEXT_REPORT.md` | 1 line: `formai_pro_quarterly→_3month`, `formai_pro_yearly→_annual` | **HOLD** — pending RC config confirmation |
| `docs/ROADMAP.md` | 3 lines: same SKU triplet rename | **HOLD** — same |
| `docs/MASTER_LAUNCH_ROADMAP.md` | P1.4 status flip ⛔→🟡 + SKU rename + Phase 92-96 status snapshot | **HOLD** — status flips need PM sign-off; current row reads "⛔ Bekliyor" |
| `docs/MONETIZATION_LAUNCH_GUIDE.md` | SKU rename throughout § E (RevenueCat product setup) | **HOLD** — needs confirmation that the new SKUs are what's actually deployed |

All four docs are still resolvable from `stash@{0}` whenever the SKU
config is confirmed. None require companion files; they can be
cherry-picked in a docs-only PR independently of the Progress Redesign
recovery (Track 3).

---

## 3 · Photo deletion inventory (no mutation)

The stash deletes 9 `.webp` assets. Per Phase A contract, **only
inventory** was performed; nothing was deleted.

Tracked in HEAD: **9 / 9** (all are still committed assets).
Bundled into the APK: **9 / 9** (via `pubspec.yaml: assets: - "photos/"`,
which recursively bundles the directory).

Reference counts:

| Photo | `lib/` refs | Docs refs | Cross-locale risk |
|---|---|---|---|
| `alınanbilgileregörekişiselplanoluşturmaörnek.webp` | 0 | 0 | safe to delete |
| `cinsiyet_diger.webp` | 0 | 1 in `docs/IMAGE_PROMPTS.md` (asset proposal note) | safe; docs note can stay |
| `kişiselkoçarkaplanfoto.webp` | 0 | 0 | safe to delete |
| `kullanıcıbilgilerinegörekişiselplanoluşturma.webp` | 0 | 0 | safe to delete |
| `onboarding_ilk_karşılama_metninin_arkaplanı.webp` | 0 | 0 | safe to delete |
| `vucütseçimiNormal.webp` | 0 | 0 | safe to delete |
| `vücutseçimiZayıf.webp` | 0 | 0 | safe to delete |
| `vücutseçimikiloluhacimli.webp` | 0 | 1 in `docs/PROJECT_DOCUMENTATION.md` (file-list example) | safe; docs note can stay |
| `özelplanınhazırörnekfoto.webp` | 0 | 1 in `docs/ROADMAP.md` (mapped to `prediction_screen.dart`) | **stale doc mapping** — `prediction_screen.dart:328` actually uses `PT_FORM.png` now, not this webp. ROADMAP mapping is out-of-date. |

**Conclusion:** none of the 9 photos are runtime-referenced. The 3
docs references are either advisory notes (safe to keep) or stale
mappings (worth correcting in a follow-up docs PR). Deletion is safe
in principle, but **not executed in Phase A** to keep the commit
focused on extraction.

---

## 4 · What was dropped from stash consideration

Per Track 4. No action taken; these will not re-appear in any
Progress Recovery PR series.

| Item | Reason |
|---|---|
| `lib/features/workout/models/workout_plan_model.dart` | Already in HEAD via `7a742da fix(ci): restore analyze…`. Stash post-state blob is identical to HEAD. No-op. |
| `logs.txt` | Developer log artifact (~24 k lines). Not source. |
| `pubspec.lock` | Drift only; CI regenerates via `flutter pub get` before analyze. |
| `macos/Flutter/GeneratedPluginRegistrant.swift` | Auto-generated by the Flutter tool on macOS build. |

`pubspec.yaml` (version bump `0.1.0+6 → +8`) was **also held** — the
two-step bump suggests an internal `+7` build went out, and applying
a `+8` without that context risks an unexplained metadata gap. Hold
for a small follow-up that ties the bump to a specific release event.

---

## 5 · Branch state and pre-flight

Before Phase A:
* Branch: `feature/cdn-meal-migration`
* HEAD: `166a3a3 chore(assets): swap AI coach + opening backgrounds to new PNG assets`
* `flutter analyze`: clean
* `flutter test`: 56/56 passing (from prior phase)

After Phase A (working tree, pre-commit):
* `flutter analyze`: clean ✓
* No stash drop, no `git stash apply`, no `git stash pop` ✓

---

## 6 · What remains blocked

| Item | Blocked on |
|---|---|
| The 4 docs SKU renames | External confirmation that RevenueCat / store SKUs now match `formai_pro_3month` + `formai_pro_annual` |
| `MASTER_LAUNCH_ROADMAP.md` P1.4 status flip | PM sign-off that backend is actually live |
| `pubspec.yaml` build-number bump | Confirming the gap with internal `+7` build |
| The 9 photo deletions | Phase A inventory done; deletion can land in a follow-up cleanup PR (any time) |
| Phase 100 home-only generator filter (Track 2) | PM/UX sign-off on the behavior change. Not part of this commit. |
| Progress Redesign Track 3 | **Unblocked** by the recovery in `PROGRESS_FILE_RECOVERY_REPORT.md` §3. Ready to materialise on user approval. |

---

## 7 · This commit

Five staged changes (3 renames + 2 edits) plus the three triage /
recovery report files this multi-turn investigation has produced.
Nothing else is staged or pushed.
