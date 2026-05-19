# APK Optimization · Master Audit (Phase 139)

> **Date:** 2026-05-16
> **Scope:** Production-readiness audit of bundle size, runtime perf, asset bloat, dependency cost, and repo hygiene for SixPack AI (Flutter, Play Store launch).
> **Status:** Audit only — no destructive changes applied. Action plan below requires per-tier go/no-go before execution.

---

## 0. Baseline measurements (verified)

| Metric | Value | Source |
|---|---|---|
| Release APK (arm64-v8a) | **119 MB** | `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` |
| Release APK (x86_64) | 122 MB | same dir |
| Release APK (armeabi-v7a) | 114 MB | same dir |
| Release APK (all-ABI fat) | 138 MB | `app-release.apk` |
| Debug APK | 225 MB | reference only |
| Project working tree (excl. .git) | **~7.5 GB** | `du` |
| `.git` | 440 MB | `du` |
| Tracked files | 871 | `git ls-files` |

**Already-applied wins (do not regress):** `isMinifyEnabled=true`, R8 + shrinkResources, ML Kit/MediaPipe/CameraX keep-rules, Flutter icon tree-shake (MaterialIcons ⇒ 26 KB), Phase 117 JVM right-sizing, Phase 138 `--split-per-abi --target-platform android-arm64` in dev script.

---

## 1. APK content decomposition (arm64-v8a release, 119 MB)

| Bucket | Size | Notes |
|---|---|---|
| Flutter assets · `photos/*` | **68.7 MB** (58%) | The single biggest spend |
| Native code | 31.7 MB | `libflutter.so` 10.8 + `libapp.so` 10.3 + `libxeno_native.so` 9.8 (MediaPipe runtime) + `libsentry.so` 0.7 + tiny |
| Dex | 12.9 MB | `classes.dex` 7.5 + `classes2.dex` 0.2 + `classes3.dex` 5.4 (multidex) |
| ML Kit TFLite models | 11.7 MB | `pose_landmark_detector_full_f16` 6.14 + `pose_person_detector_f16` 2.83 + `pose_landmark_detector_lite_f16` 2.68 |
| Resources / manifests / misc | ~0.6 MB | `resources.arsc` 0.51, shaders 0.04, fonts 0.03, NOTICES.Z 0.12 |
| **Total** | **~125.6 MB raw** | Compressed APK = 119 MB |

### 1.1 `flutter_assets/photos/` (68.7 MB) deep-dive

| Sub-bucket | Files | Size | Status |
|---|---|---|---|
| `photos/` root (onboarding artwork) | 52 webp | ~3 MB | **9 orphan files, 279 KB** — declared in pubspec but unreferenced in `lib/` |
| `photos/meals/` | ~230 webp | **64 MB** | All present; uniformly sized 116–611 KB |
| `photos/workouts/` | ~33 webp | 6.7 MB | **2 outliers**: `cardio_full_body_flow.webp` (1.9 MB) + `cardio_mobility_stretch.webp` (1.8 MB) are PNGs with `.webp` extension at 1536×1024 — 8–10× larger than siblings |
| `photos/exercises/` | 87 webp | 2.8 MB | All referenced via `ExerciseMediaRegistry._localImageSlugs` |

### 1.2 ML Kit TFLite models (11.65 MB)

Both `lite` (2.68 MB) AND `full` (6.14 MB) pose-landmark models ship. The `google_mlkit_pose_detection` plugin bundles both by default and the active model is selected at runtime via `PoseDetectorOptions.model`. If only one is actually used, the other is dead weight.

### 1.3 `libxeno_native.so` (9.8 MB) is MediaPipe

Provenance verified: `~/.gradle/caches/.../mediapipe-internal-17.0.0-beta10/jni/...`. Pulled in transitively by `google_mlkit_pose_detection`. **Unavoidable** for the camera form-coaching feature. Already deduplicated to arm64-only via Phase 138 `--split-per-abi`.

---

## 2. Optimization tiers (prioritized)

### 🟢 Tier 1 — Largest APK wins, very low risk

| # | Action | APK Δ | Risk | Effort | Reversible? |
|---|---|---|---|---|---|
| T1-A | **Upload AAB to Play, not fat APK** — `flutter build appbundle --release`. Play auto-splits per ABI + density + locale, so each user gets only their slice (~85 MB instead of 119 MB; -29% download size). | **−25 to −35 MB delivered to user** | 🟢 zero | 1 line in release pipeline | ✓ trivial |
| T1-B | **Re-encode `cardio_full_body_flow.webp` + `cardio_mobility_stretch.webp` as real VP8 WebP** (currently PNG-with-webp-extension, 1.9 + 1.8 MB at 1536×1024) | **−3.4 MB** APK | 🟢 low | 1 `cwebp -q 80` per file | ✓ git mv back |
| T1-C | **Delete 9 orphan photos at `photos/` root** (279 KB, declared in pubspec but unreferenced in `lib/`) | **−279 KB** APK | 🟢 low | rm + remove from working tree | ✓ git revert |
| | **Tier 1 total (APK delivered)** | **≈ −29 to −39 MB** | | | |

### 🟡 Tier 2 — Significant wins, requires PM/product input

| # | Action | APK Δ | Risk | Effort | Notes |
|---|---|---|---|---|---|
| T2-A | **Migrate `photos/meals/` (64 MB, ~230 files) to Supabase Storage / CDN.** Stream + cache via `cached_network_image` (already in pubspec). Bundle only 6–10 lowest-resolution placeholders for offline first-paint. | **−55 to −60 MB** APK | 🟡 medium | New `RecipeImage` widget + Supabase bucket + cache warming on dashboard open | UX risk: first-paint placeholder before image streams in. Mitigated by shipping LQIP blurhash strings + offline fallbacks |
| T2-B | **Drop one of the two ML Kit pose models** (`pose_landmark_detector_lite` vs `_full`). Determine which is actually used via `PoseDetectorOptions` config in `lib/features/workout/`. | **−2.7 MB or −6.1 MB** | 🟡 medium | Set `PoseDetectorOptions(model: PoseDetectionModel.base)` or `accurate`, verify the other model file isn't bundled | Need form-detection accuracy A/B; current state suggests we already chose at runtime but the unused .tflite still ships |
| T2-C | **Re-encode `photos/meals/` at `cwebp -q 70` (currently appears to be q≈85)** | **−10 to −15 MB** | 🟡 medium-high | Batch ImageMagick / cwebp script | PM must approve visual quality |
| | **Tier 2 total (APK)** | **−68 to −81 MB** if all three applied | | | |

### 🔵 Tier 3 — Repo hygiene (no APK impact, no risk)

| # | Action | Working tree Δ | Risk | Notes |
|---|---|---|---|---|
| T3-A | Delete `photos/new_workouts_image/` (132 MB, 88 source PNGs, **not tracked in git, not bundled in APK**) | −132 MB | 🟢 zero | Pure source artwork; keep elsewhere or in a separate "assets-source" repo |
| T3-B | Delete `assets/ONBOARDING_EXAMPLE_VİDEO.mp4` (3.4 MB, **not declared in pubspec, not referenced in lib/**) | −3.4 MB | 🟢 zero | Leftover from earlier onboarding iteration |
| T3-C | Clean `terraform/legal_pages/.terraform/` (675 MB, provider cache, already gitignored) | −675 MB | 🟢 zero | `terraform init -reconfigure` re-pulls when needed |
| T3-D | Decide whether `asosystem/` (245 MB, untracked, contains `node_modules`) belongs in this repo at all | −245 MB | 🟡 (process) | Either move to its own repo or add `asosystem/` to `.gitignore` |
| T3-E | Delete `Beslenme-Photos/` (2.3 MB, already gitignored, just lingering) | −2.3 MB | 🟢 zero | |
| | **Tier 3 total (working tree)** | **−1.0 to −1.05 GB** | | |

### 🟣 Tier 4 — Dependency hygiene (tiny APK win, cleanliness)

| # | Action | APK Δ | Risk | Notes |
|---|---|---|---|---|
| T4-A | Remove `cupertino_icons` from `pubspec.yaml` dependencies (0 imports in `lib/`; already tree-shaken to 848 B in APK) | ~0 | 🟢 zero | Cleanliness, not size |
| T4-B | Move `change_app_package_name` to `dev_dependencies` (it's a one-shot CLI, 0 runtime imports) | ~0 | 🟢 zero | Cleanliness, not size |
| T4-C | Audit `flutter_cache_manager` direct dep — could possibly come from `cached_network_image` transitively. Verify call site in `ExerciseGuidePlayer` actually needs the direct API. | ~0 | 🟢 zero | Pubspec hygiene |

### 🔴 Tier 5 — Build flags (small APK wins, medium ops risk)

| # | Action | APK Δ | Risk | Notes |
|---|---|---|---|---|
| T5-A | Add `--split-debug-info=build/debug-info --obfuscate` to release builds (Flutter docs recommend this for Play). Symbols externalized; libapp.so shrinks 10-20%. | **−1 to −2 MB** | 🟡 medium | **Requires uploading symbol files to Sentry** for crash reporting to resolve frames. Plumbing change |
| T5-B | Verify ProGuard rules aren't over-broad — current `-keep class com.google.mlkit.** { *; }` is necessary, but other rules could be tightened. Run `proguardOptimizations`. | **−0.3 to −0.8 MB** dex | 🟡 medium | Risk: a too-tight keep rule re-triggers ML Kit crashes from Phase 80. Needs camera-screen smoke test on release build |
| T5-C | Enable `useLegacyPackaging false` (default since AGP 7) and verify zipalign + minSdkVersion 24 are emitting compressed native libs efficiently | ~0 | 🟢 low | Hygiene only |

### ⚪ Tier 6 — Runtime perf (not measured in this audit)

Phase 6 of the mission asks for runtime/render optimization. This audit doesn't include FPS / rebuild measurements — those require a `flutter run --profile` session with the DevTools timeline open on the target device. **Recommendation:** run that as a separate Phase 6 mission once Tiers 1-3 ship, so before/after comparisons aren't muddied. Existing reports already document `_PaywallCinematicBackdrop` as profile-aware (single AnimationController, RepaintBoundary, no BackdropFilter at parallax time).

---

## 3. Asset migration to Supabase / CDN (Tier 2-A deep dive)

This is the largest single win available. Designing for it carefully:

### 3.1 What stays local

| Category | Why | Size impact |
|---|---|---|
| `photos/` root onboarding artwork (52 files, ~3 MB) | First-paint on app open; **emotional pacing is part of the premium feel** and must not depend on network | Keep |
| `photos/exercises/` (87 files, 2.8 MB) | Shown during workout — must be available offline (gym wifi is unreliable). Already small (~32 KB avg) | Keep |
| `photos/workouts/` thumbnails (after T1-B re-encode, ~5 MB) | Dashboard cards visible immediately on app open | Keep |
| **`photos/meals/` (64 MB)** | Recipe list scroll. **Visible only after user navigates to nutrition tab.** First-app-open never shows these. → eligible for CDN | **MIGRATE** |

### 3.2 Recommended CDN strategy for `photos/meals/`

1. **Supabase Storage bucket `meal-images/`** (public read, no signed URLs needed — these are not user-specific).
2. **`cached_network_image` already in pubspec** — handles disk + memory cache, retry, fade-in. No new dep.
3. **LQIP / blurhash placeholders** — generate a 32×32 webp thumbnail per meal (~1 KB) and bundle the *thumbnails only* with the APK. First paint shows the thumbnail (sharp) before the full image streams in. Total bundled thumbnails: ~230 × 1 KB = 230 KB.
4. **Cache warming on dashboard open** — when the user lands on the dashboard, prefetch the meals they're most likely to see (today's plan + tomorrow's). Use `precacheImage()`. Roughly 6–12 photos × 280 KB = 1.7–3.4 MB downloaded in background; far cheaper than shipping 64 MB.
5. **Offline fallback** — if cache miss + no network, show the LQIP thumbnail + a soft gradient placeholder. Never show a blank rectangle.
6. **First-app-cold-start guarantee** — meals tab isn't part of the onboarding cinematic, so a one-time placeholder flash on first meals-tab open is acceptable.

### 3.3 Anti-jank guarantees

- `cached_network_image` `placeholderFadeInDuration: 200ms` + `fadeOutDuration: 200ms` — eliminates the "blank → image pop" effect.
- Bundle the LQIP thumbnails so first paint is **never** a grey rectangle.
- Use `CachedNetworkImageProvider` with `precacheImage()` at provider warm-up.
- Set HTTP cache headers on Supabase Storage (`Cache-Control: public, max-age=2592000`) — once cached, no re-download for 30 days.

### 3.4 Estimated bundle size after Tier 2-A

- 119 MB (current) − 64 MB (meals removed) + 0.23 MB (LQIPs added) ≈ **55 MB APK arm64**.
- Combined with T1-A (AAB delivery): ~**45 MB per-device download**. That's a **−62%** reduction.

---

## 4. Risk-classified action list (for your go/no-go)

| Action | APK Δ | Working tree Δ | Risk | Reversible? | Recommend |
|---|---|---|---|---|---|
| T1-A: AAB delivery | −25 to −35 MB | 0 | 🟢 zero | ✓ | **Apply immediately** |
| T1-B: Re-encode 2 oversized workouts | −3.4 MB | 0 | 🟢 low | ✓ | **Apply immediately** |
| T1-C: Delete 9 orphan root photos | −0.28 MB | −0.28 MB | 🟢 low | ✓ | **Apply immediately** |
| T2-A: Migrate `photos/meals/` to Supabase | −60 MB | −64 MB | 🟡 medium | ✓ (re-bundle) | **Plan + execute in parallel** |
| T2-B: Drop unused ML Kit model | −2.7 or −6.1 MB | 0 | 🟡 medium | ✓ | **Investigate which model is used first** |
| T2-C: Re-encode meals at lower quality | −10 to −15 MB | −10 to −15 MB | 🟡 high (visual) | ✓ | **Skip if T2-A applied** (CDN serves originals) |
| T3-A: Delete `photos/new_workouts_image/` | 0 | −132 MB | 🟢 zero | ⚠ unrecoverable (not in git) | **Move to a backup location first, then delete** |
| T3-B: Delete `assets/ONBOARDING_EXAMPLE_VİDEO.mp4` | 0 | −3.4 MB | 🟢 zero | ⚠ unrecoverable | **Same — back up first** |
| T3-C: Clean `terraform/.terraform/` | 0 | −675 MB | 🟢 zero | ✓ (`terraform init`) | **Apply immediately** |
| T3-D: Externalize `asosystem/` | 0 | −245 MB | 🟡 process | depends | **Decide with you — keep as monorepo or split?** |
| T3-E: Delete `Beslenme-Photos/` | 0 | −2.3 MB | 🟢 zero | ⚠ unrecoverable | **Confirm contents not personally valuable, then delete** |
| T4-A/B/C: Dependency cleanup | ~0 | 0 | 🟢 zero | ✓ | **Apply immediately** |
| T5-A: `--split-debug-info --obfuscate` | −1 to −2 MB | 0 | 🟡 medium | ✓ | **Apply only after Sentry symbol upload is wired** |
| T5-B/C: ProGuard / packaging audit | −0.3 to −0.8 MB | 0 | 🟡 medium | ✓ | **Defer to Phase 6** |
| Tier 6: Runtime perf | (separate scope) | 0 | — | — | **Separate audit pass** |

---

## 5. Total opportunity summary

| If we apply… | APK delivered to user | Working tree |
|---|---|---|
| Tier 1 only (zero-risk wins) | **−29 to −39 MB** (→ ~80–90 MB download) | −0.28 MB |
| + Tier 2-A (meals CDN) | **−85 to −95 MB delivered** (→ ~25–35 MB download) | −64 MB |
| + Tier 3 (repo hygiene, no APK impact) | unchanged | **−1.05 GB** |
| + Tier 4/5 (small wins) | additional −1 to −3 MB | 0 |

**Realistic end-state:** A user on Play Store downloads ~35–45 MB instead of ~119 MB. Working tree shrinks from 7.5 GB to ~6.5 GB.

---

## 6. What I will NOT do without your go-ahead

Per your "evidence-based, measured, reversible, audit-friendly" rule and the project's `safety_first_on_shared_state` memory:

1. **No file deletions yet** — every Tier 3 deletion is irrecoverable for untracked files.
2. **No pubspec edits yet** — dependency changes affect every developer's lockfile.
3. **No Supabase Storage bucket creation** — touches production infrastructure.
4. **No image re-encoding yet** — even reversible, it edits art assets.
5. **No build flag changes yet** — release pipeline mutations need an A/B size measurement.

---

## 7. Recommended execution order (proposed)

If you green-light everything, the safe order is:

1. **Apply Tier 1** (AAB build + 2 image re-encodes + 9 orphan deletes). Measure new APK. Smoke test on a real device.
2. **Apply Tier 3** (repo hygiene). No app change, just disk reclamation.
3. **Apply Tier 4** (pubspec cleanup). Verify pub get still succeeds.
4. **Decide Tier 2-A** (meals → CDN) — bigger architectural decision, needs design alignment.
5. **Investigate Tier 2-B** (ML Kit model choice) — requires reading the active `PoseDetectorOptions` config and a form-accuracy A/B.
6. **Defer Tier 5** (build flags) until after Sentry symbol upload is wired into release pipeline.
7. **Schedule Tier 6** (runtime perf) as a separate mission once the above lands and we have a stable baseline to A/B against.

---

## 8. Open questions for you

Before I touch anything in Tier 1 or 3, I need your call on:

- **Q1.** Apply Tier 1 (AAB + 2 re-encodes + 9 orphan deletes) now? *(Recommended yes — zero risk, highest leverage.)*
- **Q2.** Apply Tier 3-A/B (delete `photos/new_workouts_image/` + `assets/ONBOARDING_EXAMPLE_VİDEO.mp4`)? These are untracked, so deletion is **irrecoverable** from this repo. If yes, I'll move them to `/tmp/sixpack-cleanup-backup-<date>/` first as a safety net.
- **Q3.** Tier 2-A meal CDN migration — do you want me to design the full migration plan (bucket schema, LQIP generation pipeline, fallback widget, cache warming hooks) and stop short of execution, or skip until later?
- **Q4.** `asosystem/` — does this belong in the main repo? Should it be its own repo, or just gitignored?
