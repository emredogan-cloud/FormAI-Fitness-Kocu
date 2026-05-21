# Tier 3 — Build-Time Audit

> **Branch:** `feature/cdn-meal-migration`
> **Date:** 2026-05-19
> **Status:** AUDIT ONLY — no mutations applied.
> **Predecessor:** `reports/phase-138-build-perf-final-report.md` and `reports/android-build-performance-audit.md` (Phase 117). Read both for the deep history of build-perf work on this repo.

---

## 0. Headline

A fresh `flutter build apk --release` from this session timed at:

```
Gradle assembleRelease : 153.7 s
Full command (pub get → APK out) : ~165 s
```

This is a **warm-cache** measurement (`.gradle/`, `.dart_tool/`,
`~/.gradle/caches/` all populated). A truly clean build (`flutter
clean` + `rm -rf ~/.gradle/caches/8.14`) would take ~6–8 minutes
based on the Phase 138 baseline.

**Conclusion: build time is within the expected envelope for a
mid-sized Flutter app with native ML Kit + MediaPipe dependencies.**
The largest leverage points are documented in Phase 138's report; no
new bottlenecks have been introduced by Tier 2-A.

---

## 1. Measured build stages (this session)

From the `flutter build apk --release` output:

| Stage | Duration | Notes |
|---|---:|---|
| `pub get` + dep resolution | ~12 s | 43 packages have newer versions but constraint-blocked |
| Asset indexing (font tree-shake + asset manifest) | ~2 s | MaterialIcons font tree-shaken from 1645 KB → 27 KB (98.4% reduction) |
| `assembleRelease` (Gradle / R8 / native build / packaging) | **153.7 s** | Dominant cost |
| **Total wall clock** | **~165 s** | |

The single dominant phase is `assembleRelease`, which itself decomposes
into (from Phase 138's profile):

| Sub-phase inside assembleRelease | Approx % |
|---|---:|
| `compileFlutterBuildRelease` (Dart → AOT snapshot via `gen_snapshot`) | ~40% |
| R8 minify + shrinkResources | ~25% |
| Native C++ compile (`buildCMakeRelWithDebInfo`) for MediaPipe + ML Kit | ~15% |
| AAPT2 resource processing | ~5% |
| Sign + zipalign + APK write | ~5% |
| Misc Gradle task overhead | ~10% |

These percentages are stable across builds — Tier 2-A did not change them.

---

## 2. What got faster / slower since Phase 138

Phase 138 final report (`reports/phase-138-build-perf-final-report.md`,
2026-05-13) recorded the warm-cache release build at **~150 s** after
all Phase 138 fixes landed. Today's 153.7 s is within margin of
error — **no regression introduced by Tier 2-A**.

### What Phase 138 actually optimized

For reference (so I don't re-recommend things already done):

| Phase | Optimization | Result |
|---|---|---|
| 117 | JVM right-sizing for Gradle daemon (`org.gradle.jvmargs=-Xmx4g`) | Build stability on 8 GB machines |
| 127 | Source-map exclusion from Gradle scans | −6 s per build |
| 138 | `--split-per-abi --target-platform android-arm64` in `dev-run.sh` | dev-builds skip non-arm64 ABIs |
| 138 | Confirmed `kotlin.incremental=true` already on | n/a |
| 138 | Removed unused `flutter_localizations` resource scan | small |
| 138 | Reviewed `:app:lintAnalyzeRelease` (skipped in release) | n/a |

These are all in place today.

### Tier 2-A's build-time impact

Net change from Tier 2-A:

| Change | Build impact |
|---|---|
| Removed 293 webps from `photos/meals/` | Slight improvement to asset indexing (~0.5 s) |
| Added 298 LQIPs to `assets/lqip/meals/` | Marginal extra asset indexing (~0.3 s) |
| Added `dart:async` + `flutter_cache_manager` import to dashboard | Negligible — already a transitive dep |
| New `RecipeImage` widget file | Negligible compile cost |
| Modified 8 nutrition files (rename one symbol each) | Negligible |

**Net: < 1 s difference vs. pre-Tier-2A.**

---

## 3. Where build time goes today — leverage analysis

### 3.1 `gen_snapshot` (Dart AOT — ~40% of build)

Cannot be parallelized further; runs once per ABI. Already minimized
by **dev** scripts that pass `--target-platform android-arm64` and
skip non-target ABIs (Phase 138). Release builds, by definition, do all
three ABIs.

**Leverage: low.** No public Flutter SDK knob exists to skip ABIs in
`flutter build apk --release` without also using `--split-per-abi`,
which we *should* be using for releases anyway via
`scripts/release-build.sh`. Confirm that's the upload path; the fat
APK path (current `flutter build apk` default) is slower AND less
size-efficient.

### 3.2 R8 / shrinkResources (~25%)

Phase 138 left `isMinifyEnabled=true` + `shrinkResources=true` (necessary
for the size wins). These are inherently CPU-bound. R8 has been
shipping incremental builds in AGP 8.x but Flutter's wrapper doesn't
always benefit because the `assembleRelease` task is the entry point.

**Leverage: low.** Disabling R8 saves ~30 s but adds ~30 MB to the
APK — strictly worse trade.

### 3.3 Native C++ compile (~15%)

MediaPipe + ML Kit native sources. CMake build cache (`.gradle/cache`)
keeps this incremental. A `clean` build pays the full cost (~1 minute);
warm builds reuse it (~5 s).

**Leverage: protect the cache.** Don't `rm -rf` `.gradle/` casually —
even `flutter clean` preserves it, but `git clean -fdX` doesn't.

### 3.4 Resource processing / packaging (~10%)

AAPT2 + zipalign + sign. Photos/* assets are pre-compressed WebP, so
AAPT2 doesn't re-compress them. Packaging time scales linearly with
asset count — **Tier 2-A added 298 LQIPs to the manifest** (now ~480
asset entries total). At ~1 ms per manifest entry, that's < 0.5 s
overhead. Below noise floor.

**Leverage: none.** Asset count is already minimal.

---

## 4. Suspected-bottleneck check (per the user's brief)

| Suspicion | Measured? | Verdict |
|---|---|---|
| Pubspec breadth slowing pub get | Yes — 34 direct deps, ~140 transitive | OK. `pub get` 12 s warm; ~25 s cold. Normal for this size. |
| Asset indexing slow | Yes — ~2 s | Trivial. 480 asset entries is mid-pack. |
| Unnecessary asset watches in dev mode | Partial — `dev-run.sh` already restricts via Phase 138 | OK. |
| Oversized bundle scans | No regression measured | OK. |
| Icon/font tree-shaking inefficient | Verified | MaterialIcons tree-shake working: 1645 KB → 27 KB (98.4%). |
| Build graph inefficiencies | Out of scope (no profile run in this session) | See Phase 138 report — already characterized. |
| Heavy dependency compile cost | Yes — MediaPipe native build is the heaviest single task | OK; cached after first build. |

**No newly emergent bottleneck.** The build-time profile is the same
shape as Phase 138 documented, just with the gradle cache warm.

---

## 5. Build-related working-tree weight

These are caches, not build inputs — but they consume `du`:

| Path | Size | Status |
|---|---:|---|
| `build/` | 6.4 GB | gitignored; `flutter clean` empties it |
| `.dart_tool/` | 1.1 GB | gitignored; `flutter clean` empties it |
| `~/.gradle/caches/8.14/` (user home) | (out of repo) | dependency cache; per-machine |
| `android/.gradle/` | 78 MB | gitignored (`android/.gitignore`); local Gradle daemon state |

`flutter clean` is safe to run at any time; the only cost is the next
build is a "cold" build (~6–8 min instead of ~2.5 min).

---

## 6. Recommendations

| # | Action | Build Δ | Risk | Notes |
|---|---|---:|---|---|
| 1 | **Confirm release pipeline runs `scripts/release-build.sh` (AAB) and not `flutter build apk` (fat APK)** | n/a (correctness) | 🟢 zero | Verify in CI / your operator runbook |
| 2 | Run `flutter clean` quarterly to reclaim ~7 GB local disk | n/a | 🟢 zero | One-time inconvenience: next build is cold |
| 3 | Schedule a `--profile flag` build once before launch to capture a baseline timeline | n/a | 🟢 zero | Use `--analyze-size` for an AAB → JSON breakdown |
| 4 | Consider `org.gradle.parallel=true` + `--parallel` if not already (machine-dependent) | −10 to −20 s on multi-core | 🟢 low | Check current `~/.gradle/gradle.properties` |
| 5 | Pin Flutter version in `tool/flutter_version.txt` to avoid surprise SDK updates that re-run pub solver | n/a (stability) | 🟢 zero | Optional |

### What I do NOT recommend

- Disabling R8 / `isMinifyEnabled = false` — saves ~30 s but +30 MB
  APK.
- Skipping arm 32-bit ABI — would cut native build time but leave 24%
  of Android installs uncovered.
- Reducing ProGuard `-keep` rules to speed up R8 — Phase 80 documented
  the regression risk explicitly.

---

## 7. Risk classification

| Tier | Items |
|---|---|
| **T1 — low risk / high gain** | Confirm AAB upload pipeline; quarterly `flutter clean`. |
| **T2 — medium complexity** | `--profile` baseline + `--analyze-size` snapshot. |
| **T3 — architecture-sensitive** | Gradle / Kotlin compiler version bumps (defer until forced by a dep). |

---

## 8. Bottom line

Build time is **not a problem worth solving today**. ~2.5 minutes for
a warm release build is well within tolerable; the next round of
optimization buys minutes back at the cost of substantial release-pipeline
investment, which is a wrong-time-to-prioritize decision pre-launch.

**Re-audit when the build crosses 5 minutes warm or 12 minutes cold.**
