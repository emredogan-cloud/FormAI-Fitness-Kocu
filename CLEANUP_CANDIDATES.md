# Tier 3 — Cleanup Candidates (Ranked)

> **Branch:** `feature/cdn-meal-migration`
> **Date:** 2026-05-19
> **Status:** AUDIT ONLY — every item below is a *recommendation*, not an applied change.
> **Sister reports:** `TIER3_SIZE_AUDIT.md`, `BUILD_TIME_AUDIT.md`, `ASSET_SCOPE_AUDIT.md`, `REPO_HYGIENE_AUDIT.md`, `MARKDOWN_CORPUS_AUDIT.md`.

---

## 0. How to read this

Items are ranked into three tiers by *risk vs. gain*. **Tier numbering here is internal to this cleanup phase** — it does not map onto the Phase 139 "Tier 1/2/3/4/5/6" numbering or the Tier 2-A migration plan.

| This-doc Tier | Criteria |
|---|---|
| **T1** | Zero or near-zero risk + measurable win + reversible in seconds |
| **T2** | Medium complexity / requires a small product call / not instantly reversible but no data loss |
| **T3** | Architecture-sensitive / multi-week scope / cross-team coordination needed |

---

## 1. Working-tree size today

```
Total                 8.2 GB
├── build/            6.4 GB    reclaimable via `flutter clean`
├── .dart_tool/       1.1 GB    reclaimable via `flutter clean`
├── .git/             456 MB    reclaimable via `git gc` (T1 item below)
├── asosystem/        245 MB    untracked Vite project (T1 / T2 item below)
├── android/           75 MB    Gradle tooling
├── photos/            10 MB    clean post-Tier-2A
├── docs/              10 MB    incl. screenshots + reference imagery
├── other            < 20 MB    everything else
```

`flutter clean` is always safe; not listed below because it's a routine command rather than a "cleanup".

---

## 2. T1 — Low risk, high gain (apply immediately)

| # | Action | Impact | Risk | Reversible? | Notes |
|---|---|---|---|---|---|
| **T1.1** | `git gc --aggressive --prune=now` | **−360 MB** in `.git/`; faster `git status`/`log`/`fetch` | 🟢 zero | n/a (git's normal storage shape) | 4,965 loose objects → ~80–100 MB packed. See `REPO_HYGIENE_AUDIT.md §3`. |
| **T1.2** | Add `asosystem/` to **root `.gitignore`** (single line) | 0 MB working tree; eliminates accidental-stage risk for 245 MB / 700+ untracked files | 🟢 zero | git revert the .gitignore line | See `REPO_HYGIENE_AUDIT.md §1`. Keeps the Vite project locally usable. |
| **T1.3** | Confirm Play upload uses **AAB** (`scripts/release-build.sh`), not fat APK | **−~30 MB delivered per Play user** | 🟢 zero | n/a (the script exists; just verify what's uploaded) | The fat APK ships all 3 ABIs. AAB lets Play deliver per-device. Phase 139 T1-A already wired this; verify it's in use. |
| **T1.4** | Delete `docs/PROJECT_DOCUMENTATION1.md` (obsolete Turkish duplicate, superseded by `PROJECT_DOCUMENTATION.md`) | −27 KB | 🟢 zero | git revert | Diff with `PROJECT_DOCUMENTATION.md` confirms it's a v0.1.0+1 / Phase 39 Turkish copy of the Phase 58 English current doc. Before deletion: spot-check for any Turkish-only nuance worth folding into a `_TR.md` companion. |

**T1 total: ~390 MB working-tree reclaim + 30 MB APK delivery improvement + reduced accident risk.**

---

## 3. T2 — Medium complexity (apply with product/eng input)

| # | Action | Impact | Risk | Notes |
|---|---|---|---|---|
| **T2.1** | Decide `asosystem/` long-term: stay-as-monorepo (T1.2 gitignore) vs. **split to its own repo** (`formai-aso`) | If split: −245 MB working tree on Flutter repo; cleaner mental model | 🟡 process | `asosystem/` is a Vite + Tailwind landing-page project. Owners likely different from Flutter eng. **Recommend: split, unless the user explicitly wants monorepo.** |
| **T2.2** | Audit ML Kit pose model selection in `lib/features/workout/` — drop the unused `_lite_f16` (2.7 MB) OR `_full_f16` (6.3 MB) | **−2.7 to −6.3 MB APK** | 🟡 form-accuracy A/B | Phase 139 T2-B, still open. Quick: grep `PoseDetectorOptions` to see which model the code actually requests. Then `assets/mlkit_pose/` filter for the unused one. |
| **T2.3** | Re-encode `photos/` at `cwebp -q 70` (currently ~82) | **−1 to −2 MB APK** | 🟡 visual quality A/B | Phase 139 T2-C, deferred (correctly) until Tier 2-A landed. Visual A/B on the workout/exercise/onboarding photos. |
| **T2.4** | Move 5 `budget_cover_*.webp` from `photos/meals/` → `photos/category_covers/`; update `nutrition_tab.dart` paths; remove `- "photos/meals/"` from pubspec | 0 MB APK; clarity win | 🟡 source-edit, smoke-test required | Eliminates the now-confusing situation where `photos/meals/` holds 5 non-meal UI tiles. See `ASSET_SCOPE_AUDIT.md §5`. |
| **T2.5** | Archive Tier 2-A reports + auth diagnostics to `docs/archive/` after operator validates the migration | 0 MB; less root clutter | 🟢 low | See `MARKDOWN_CORPUS_AUDIT.md §9` proposed structure. |
| **T2.6** | Move 19 strategic/research .md files (`reports/phase-N-*/`) to `docs/archive/strategy-research/` (or leave as-is if already cleanly siloed) | 0 MB; tidier reports/ | 🟢 zero | Cosmetic, content preserved. |
| **T2.7** | Decide `Beslenme-Photos/` retention (already gitignored, 2.3 MB) | −2.3 MB if deleted | 🟡 personal content | User's personal nutrition reference photos. Per Phase 40 comment. **User decision required.** |

**T2 total (if T2.1 split is taken): ~250 MB working tree + 4–8 MB APK + clarity wins.**

---

## 4. T3 — Architecture-sensitive (defer to a deliberate cycle)

| # | Action | Impact | Risk | Notes |
|---|---|---|---|---|
| **T3.1** | `--obfuscate --split-debug-info` for release builds + wire Sentry symbol upload | **−1 to −2 MB APK** | 🟡 medium — Sentry plumbing change | Phase 139 T5-A. Needs CI/CD changes to upload symbols on each release. Not blocking launch. |
| **T3.2** | Tighten ProGuard rules; audit `-keep` scope | −0.3 to −0.8 MB dex | 🟡 medium — risk of ML Kit Phase 80 regression | Phase 139 T5-B. Needs camera-screen smoke test on release build. |
| **T3.3** | Schedule `flutter run --profile` + DevTools timeline session for runtime perf baseline | n/a (measurement) | 🟢 low | Phase 139 Tier 6 / Phase 122 guide both reference this. Worth doing once before launch as a baseline; no immediate action. |
| **T3.4** | Consider splitting strategic .md masterplans (`*_MASTERPLAN_TR.md`) into a separate `formai-product-docs` repo if root continues to clutter | 0 MB; org clarity | 🟡 cross-team | Lower urgency than the asosystem split (T2.1). Only if root .md hygiene becomes a recurring concern. |

---

## 5. Items considered and rejected

The user asked for evidence-based recommendations. Below are things I **considered but reject** based on the evidence in the audit:

| Considered | Rejected because |
|---|---|
| Delete `assets/lqip/meals/` to "shrink the bundle" | It's the Tier 2-A LQIP layer; deletion would re-introduce grey-hole behaviour on cold cache. |
| Delete `photos/exercises/` to migrate to CDN like meals | 2.8 MB total at ~32 KB avg — **smaller than the LQIPs+round-trip we'd add**. Net loss; offline workouts are also a UX hard requirement (gym wifi unreliable). |
| Delete `photos/workouts/` similarly | Dashboard hero cards rendered on first app open. Network not available pre-onboarding. |
| Delete `photos/` root onboarding artwork | First-paint cinematic depends on these being bundled. |
| Re-encode `photos/exercises/` at lower quality | Already at avg ~32 KB / file. Diminishing returns. |
| Remove `connectivity_plus` dep | Used at multiple call sites; not orphan. |
| Remove `flutter_cache_manager` direct dep | Phase 139 already audited; the direct API IS used by `antrenman_tab.dart` and our new `dashboard_screen.dart`. |
| Drop `cached_network_image` and roll our own | Reinvention; same package already battle-tested in the codebase. |
| Reduce 87-strong `photos/exercises/` corpus | Each is a distinct exercise. Removal would also require dropping exercises from the library. |
| `git filter-branch` history rewrite to drop old large objects | High risk; rewrites SHAs. The `git gc` packing (T1.1) already reclaims the storage without rewriting history. |

---

## 6. Reality check: how much further can the APK shrink?

Composing T1.3 + T2.2 (highest-confidence remaining):

```
Current fat APK (this build)        : 126.6 MB
After AAB upload (T1.3) per-user     : ~85 MB  (-30 MB delivered)
After dropping unused pose model     : ~82 MB  (T2.2, -2.7 MB) OR
                                      ~78 MB  (T2.2, -6.3 MB)
After --obfuscate split-debug-info   : ~80 MB  (T3.1, -1-2 MB)
After ProGuard tightening + quality  : ~78–80 MB  (T2.3 + T3.2)
```

**Realistic launch-time APK: ~78–80 MB delivered per Play user.**
**Floor: ~75 MB.** Below that requires architectural change (drop ML Kit pose detection → −9.8 MB native + −12 MB models, or drop a feature).

Tier 2-A delivered ~60 MB. The remaining 10–15 MB of recoverable APK requires engineering hours that buy far less per hour than Tier 2-A did. **Conclusion: the next significant launch-blocker is not size, it is feature completeness / smoke testing / Play submission.**

---

## 7. Working-tree opportunity summary

```
Current working tree                  : 8.2 GB
After T1.1 (git gc --aggressive)      : ~7.8 GB   (-360 MB in .git/)
After T1.2 (asosystem gitignore)      : ~7.8 GB   (no working-tree change, just safety)
After T1.4 (delete duplicate doc)     : ~7.8 GB   (-27 KB)
After flutter clean (routine)         : ~0.7 GB   (-7.5 GB in caches)
After T2.1 if asosystem split out     : ~0.5 GB   (-245 MB more)
After T2.7 if Beslenme-Photos deleted : ~0.5 GB   (-2.3 MB)
```

**Sustainable steady state: ~500 MB working tree.** This is what a fresh `git clone` + `flutter pub get` produces, modulo `.dart_tool/` and `build/` which any developer rebuilds on demand.

---

## 8. Recommended order of operations (when the user is ready to act)

```
1. T1.4  delete docs/PROJECT_DOCUMENTATION1.md      (30 s, single-file commit)
2. T1.2  add asosystem/ to root .gitignore           (1 min)
3. T1.1  git gc --aggressive --prune=now             (3–5 min)
4. T1.3  verify AAB is the Play upload path          (visual check)
5. operator: complete Tier 2-A operator checklist    (cache-control SQL + smoke)
6. T2.5  archive Tier 2-A reports to docs/archive/  (after step 5)
7. T2.2  audit ML Kit pose model + drop one          (2 hr investigate + smoke)
8. T2.3  re-encode photos/ at q=70 (visual A/B)      (1 hr batch + visual review)
9. T2.4  move budget_covers to category_covers/      (30 min source edit)
10. T2.1 decide asosystem long-term home             (product/eng meeting)
11. T2.6 archive strategy-research reports           (cosmetic, anytime)
12. T2.7 decide Beslenme-Photos retention            (user-personal call)
13. T3.x defer to post-launch                        (not blocking)
```

Steps 1–4 are 10 minutes of zero-risk work that should run before any further launch milestone. Step 5 must come before step 6 (don't archive references the operator still needs).

---

## 9. Bottom line

The audit found **2 immediate hygiene wins** (`git gc` + `asosystem` gitignore), **1 single-file delete**, and **1 release-pipeline verification** that together reclaim ~390 MB working tree + ~30 MB per Play user — all with zero risk and no code change.

Everything else is medium-effort / medium-risk and represents the **post-launch optimization backlog**, not a pre-launch blocker. The asset surface is at steady state; the build is within historical envelope; the markdown corpus needs reorganization not deletion. **The biggest remaining win is process** (decide `asosystem/`'s home), not bytes.
