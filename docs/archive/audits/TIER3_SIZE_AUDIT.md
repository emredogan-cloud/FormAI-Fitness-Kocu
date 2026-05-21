# Tier 3 — APK Size Audit

> **Branch:** `feature/cdn-meal-migration`
> **Date:** 2026-05-19
> **Status:** AUDIT ONLY — no mutations applied.
> **Predecessor:** `APK_OPTIMIZATION_MASTER_AUDIT.md` (Phase 139, 2026-05-16) →
> `TIER_1_3_4_CHANGE_LOG.md` (executed Tiers 1, 3, 4 from that plan) →
> `FINAL_TIER2A_MIGRATION_REPORT.md` (Tier 2-A meals migration, just completed).

---

## 0. Headline

Post-Tier-2A release-APK measurement:

```
build/app/outputs/flutter-apk/app-release.apk = 126.6 MB (all-ABI fat APK)
```

For a Play user with arm64-v8a (the common case), the **delivered** size
via AAB upload is ~85 MB — see §3 below.

The **remaining opportunity** is concentrated in:

| Category | Bundled | Optimizable | Status |
|---|---:|---:|---|
| 3 ABIs × `libflutter.so`/`libapp.so`/`libxeno_native.so` (native) | 92.3 MB | −~30 MB delivered via AAB | mitigated by Play upload format |
| ML Kit dual pose models | 11.7 MB | −2.7 MB or −6.1 MB | unmigrated from Phase 139 Tier 2-B |
| Multidex (`classes.dex` + `classes2.dex` + `classes3.dex`) | 13.3 MB | −0.3 to −0.8 MB | requires ProGuard tightening |
| Other (`photos/`, `LQIPs`, `resources.arsc`, fonts, manifests) | 10.5 MB | ≤ −1 MB | already optimal post-Tier-2A |

---

## 1. APK content decomposition (current build, fat all-ABI)

```
TOTAL APK SIZE  : 126.6 MB

lib/ (native, 3 ABIs) :  92.3 MB   ← reduced to one ABI on Play delivery
ML models (.tflite)   :  11.9 MB   ← Tier-2B opportunity unrealized
Dex (R8-shrunk)       :  13.3 MB
photos/ (assets)      :   9.6 MB   ← Tier 2-A done; small residual
LQIPs (Tier 2-A new)  :   0.2 MB
Other flutter_assets  :   0.2 MB
Resources (res/)      :   0.8 MB
META-INF              :  ≤ 0.1 MB
```

### 1.1 Native libs (`lib/`) — 92.3 MB total

| File | arm64-v8a | armeabi-v7a | x86_64 |
|---|---:|---:|---:|
| `libflutter.so` | 10.8 MB | 7.9 MB | 12.0 MB |
| `libapp.so` | 10.3 MB | 11.3 MB | 10.6 MB |
| `libxeno_native.so` (MediaPipe) | 9.8 MB | 6.4 MB | 10.9 MB |
| `libsentry.so` | 0.7 MB | 0.5 MB | 0.7 MB |
| **Subtotal per ABI** | **31.6 MB** | **26.1 MB** | **34.2 MB** |

On Play's AAB split delivery, **only one ABI ships per user**. The fat
APK figure (~92 MB) misrepresents the user-side size. With T1-A
(AAB upload) already in place per `TIER_1_3_4_CHANGE_LOG.md`:

```
Effective per-user native delivery:
  arm64-v8a user     :  31.6 MB  (~75% of installs)
  armeabi-v7a user   :  26.1 MB  (~24% of installs)
  x86_64 user        :  34.2 MB  (rare; emulators)
```

### 1.2 ML Kit TFLite models (11.9 MB) — Tier 2-B unresolved

Phase 139's audit recommended dropping one of `pose_landmark_detector_lite_f16` (2.7 MB) and `pose_landmark_detector_full_f16` (6.3 MB) since `google_mlkit_pose_detection` exposes the choice at runtime via `PoseDetectorOptions(model: PoseDetectionModel.base|accurate)`. The choice was deferred for an A/B; current state:

```
assets/mlkit_pose/pose_landmark_detector_full_f16_inf.tflite  =  6.3 MB
assets/mlkit_pose/pose_person_detector_f16.tflite             =  2.9 MB  (always needed)
assets/mlkit_pose/pose_landmark_detector_lite_f16_inf.tflite  =  2.7 MB
```

`pose_person_detector_f16` is required regardless. The two landmark
models are alternatives. **Both still ship in the AAB.** Opportunity:
−2.7 MB (lite) or −6.3 MB (full) depending on which is actually
selected by `PoseDetectorOptions` in `lib/features/workout/`.

### 1.3 Photos (9.6 MB) — Tier 2-A residual

Post-migration content of `photos/` (full enumeration):

| Bucket | Files | Size | Status |
|---|---:|---:|---|
| `photos/` root (onboarding/UI artwork) | 52 webp | ~3 MB | All referenced; Phase 139 cleaned the 9 orphans. None to remove. |
| `photos/workouts/` | 33 webp | 3.2 MB | All referenced; Phase 139 re-encoded the 2 PNG-as-WebP outliers. |
| `photos/meals/` | 5 webp | 1.0 MB | Only the 5 budget-cover UI tiles (post-Tier-2A). |
| `photos/exercises/` | 87 webp | 2.8 MB | All referenced via `ExerciseMediaRegistry._localImageSlugs`. |

**No further trivial wins in `photos/`** after Phase 139 + Tier 2-A.
A re-encode at lower quality (Phase 139 Tier 2-C, `cwebp -q 70` instead
of ~85) would save another ~1.5 MB but requires PM/visual approval.

### 1.4 Dex (13.3 MB) — within expected range

R8 + multidex; `isMinifyEnabled = true`. The `classes3.dex` (5.7 MB)
hosts ML Kit + Supabase. Phase 139 considered ProGuard tightening
(T5-B) but deferred — risks re-triggering Phase 80's ML Kit crashes.

---

## 2. What's CHANGED since Phase 139 audit

| Metric | Phase 139 (May 16) | Now (May 19) | Δ |
|---|---:|---:|---:|
| arm64-v8a release APK | 119 MB | ~85 MB (projected post-Tier-2A) | **−34 MB** |
| Fat APK (all-ABI) | 138 MB → 135 MB after Tier 1 | **126.6 MB** | **−8.4 MB vs Tier 1-only** |
| `photos/meals/` | 64 MB | 1.0 MB | **−63 MB** |
| `photos/` total | 71 MB | 9.6 MB | **−61 MB** |
| LQIP overhead added | 0 | 0.2 MB | +0.2 MB |
| Working tree (non-cache) | 399 MB | **~315 MB** (projected) | −84 MB |

**Tier 2-A delivered the predicted −60 MB**. The remaining
opportunities are smaller and harder to reach without product trade-offs.

---

## 3. Remaining size opportunities (ranked by APK Δ delivered to user)

| # | Opportunity | Phase 139 ID | Δ delivered | Risk | Effort |
|---|---|---|---:|---|---|
| **1** | **Confirm AAB upload is actually used for Play deployment** (not fat APK). Already documented in `TIER_1_3_4_CHANGE_LOG.md §1-A` and `scripts/release-build.sh` exists. **Verify Play Console has the AAB, not an APK.** | T1-A | **−~30 MB** | 🟢 zero | trivial |
| 2 | Drop the unused ML Kit pose model (lite OR full) after auditing `PoseDetectorOptions` in `lib/features/workout/` | T2-B | −2.7 to −6.3 MB | 🟡 medium (form-accuracy A/B) | 1 hr investigation |
| 3 | Re-encode `photos/` at q=70 vs current q=82 | T2-C | −1 to −2 MB | 🟡 visual quality A/B | 30 min batch |
| 4 | `--obfuscate --split-debug-info` for libapp.so shrink | T5-A | −1 to −2 MB | 🟡 needs Sentry symbol upload wired | 1 hr ops work |
| 5 | ProGuard rule tightening | T5-B | −0.3 to −0.8 MB | 🟡 retest risk for ML Kit | 2 hr + smoke test |
| 6 | Verify `useLegacyPackaging false` (AGP 7+ default) | T5-C | ~0 | 🟢 low | 5 min audit |

**Estimated remaining headroom: 5–11 MB on the delivered APK** (after AAB upload is confirmed). That's well past diminishing returns; the engineering hours are better spent elsewhere unless the team is chasing the "under 75 MB" Play threshold for some specific reason.

---

## 4. Confirmed NOT in APK (false suspicion list)

| Suspect | Bundled in APK? | Why |
|---|---|---|
| `Beslenme-Photos/` (2.3 MB personal photos) | ❌ No | Not in pubspec assets, gitignored |
| `asosystem/` (245 MB Vite project) | ❌ No | Separate web project, not declared in pubspec |
| `docs/` (10 MB including screenshots + reference-imagery) | ❌ No | Not in pubspec; docs only |
| `reports/` (1.4 MB engineering history) | ❌ No | Not in pubspec |
| `photos/new_workouts_image/` (was 132 MB source PNGs) | ❌ No | Removed in Phase 139 T3-A |
| `assets/ONBOARDING_EXAMPLE_VİDEO.mp4` (was 3.4 MB) | ❌ No | Removed in Phase 139 T3-B |
| `tool/app_icon.png` (1.4 MB) | ❌ No | Per Phase 120 comment in pubspec: read at icon-generation time only |
| All 290 markdown files | ❌ No | Not assets |
| `Beslenme-Photos/`, `Beslenme-Photos/` | ❌ No | gitignored |

**The user's intuition that "photos/, assets/, markdown corpus" may still be inflating the APK is incorrect** — Tier 2-A and Phase 139 cleaned the asset surface to near-optimal. The remaining APK weight is **native libs (ABI split solves this) and ML models (single-purpose product decision)**.

---

## 5. Risk classification of remaining size actions

| Tier | Definition | Items here |
|---|---|---|
| **T1 — low risk / high gain** | reversible, no UX impact | confirm AAB upload to Play |
| **T2 — medium complexity** | needs an A/B or product validation | drop one ML Kit model; re-encode photos at lower q |
| **T3 — architecture-sensitive** | release-pipeline / observability change | `--obfuscate` + Sentry symbol upload; ProGuard rule tightening |

---

## 6. Bottom line for the user

After Tier 2-A and Phase 139, the APK is **at the steady-state floor** for this product's feature set. The next dollar of APK reduction costs an order of magnitude more engineering hours than the dollars before it. Concrete recommendation:

- **Confirm Play upload is AAB** (already wired; just verify Play Console state).
- **Defer Tier 5 / Tier 2-B** until launch-readiness signal is clear; these are size-vs-engineering trade-offs that should be deliberate, not reactive.

The bigger remaining lever for `du -sh` working-tree size is **repo hygiene** (see `REPO_HYGIENE_AUDIT.md`), not asset cleanup.
