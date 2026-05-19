# ML Kit Pose Model Audit — T2.2

> **Branch:** `feature/cdn-meal-migration`
> **Date:** 2026-05-19
> **Action:** Trace `PoseDetectorOptions` usage in `lib/features/workout/`; identify which pose model is selected.
> **Status:** AUDIT ONLY — no model files touched.

---

## 1. Current usage

There are exactly **2 sites** in `lib/` that construct a `PoseDetector`:

```dart
// lib/features/workout/services/pose_detector_service.dart:5-7
PoseDetector(
  options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
)

// lib/features/workout/services/pose_detector_service.dart:42-44
PoseDetector(
  options: PoseDetectorOptions(mode: PoseDetectionMode.single),
)
```

The first is the live in-workout detector (stream mode). The second is a Phase-138 availability probe (construct + immediately close to verify GMS / MediaPipe is present on the device).

**Neither call passes a `model:` parameter.** That means the package's default — `PoseDetectionModel.base` (alias for the lite model) — is used in both cases.

---

## 2. Confirming the default

`google_mlkit_pose_detection` v0.14.1 (pinned in `pubspec.lock` via `^0.14.1` in `pubspec.yaml`) exposes:

```dart
enum PoseDetectionModel {
  base,      // "lite" model — pose_landmark_detector_lite_f16_inf.tflite (~2.7 MB)
  accurate,  // "full" model — pose_landmark_detector_full_f16_inf.tflite (~6.3 MB)
}
```

In the plugin's `PoseDetectorOptions` constructor:

```dart
class PoseDetectorOptions {
  PoseDetectorOptions({
    this.mode = PoseDetectionMode.stream,
    this.model = PoseDetectionModel.base,  // ← default
  });
  ...
}
```

The code uses the default → **`base` (lite)** is the active model.

---

## 3. What ships in the APK

```
assets/mlkit_pose/pose_landmark_detector_full_f16_inf.tflite   6.3 MB  ← UNUSED (full)
assets/mlkit_pose/pose_landmark_detector_lite_f16_inf.tflite   2.7 MB  ← used (default)
assets/mlkit_pose/pose_person_detector_f16.tflite              2.9 MB  ← required by both models
```

**Total ML Kit pose-model payload: 11.9 MB.**
**Unused dead weight: 6.3 MB** (`pose_landmark_detector_full_f16_inf.tflite`).

---

## 4. Why both files ship even though only one is used

`google_mlkit_pose_detection` declares **both .tflite files** as bundled plugin assets (in the plugin's `android/build.gradle`). The runtime selects which model to load at `PoseDetector` construction time based on `PoseDetectorOptions.model`. There is **no pubspec-level mechanism** for the consuming app to opt out of one of the two.

This is a common ML-Kit-Flutter-plugin shape: the plugin trades shipping both models for runtime flexibility. For a single-model app like SixPack AI, that trade is suboptimal — the unused 6.3 MB ships forever.

---

## 5. Removal mechanisms (NOT EXECUTED)

| Mechanism | APK Δ | Risk | Reversible? |
|---|---:|---|---|
| **A.** `android/app/build.gradle.kts` — `packagingOptions.resources.excludes += "assets/mlkit_pose/pose_landmark_detector_full_f16_inf.tflite"` | **−6.3 MB** APK | 🟡 medium — must verify ML Kit's Java loader doesn't pre-check both files at init | ✓ revert build.gradle line |
| **B.** Fork / vendor the plugin and remove the `full` model from its bundled assets | −6.3 MB | 🔴 high — adds maintenance burden (vendor fork drift vs upstream) | ✓ unfork |
| **C.** Use `PoseDetectionModel.accurate` and remove `lite` instead | −2.7 MB | 🟡 medium — `accurate` is ~2× slower per frame; form-detection fps would drop | ✓ revert + re-add lite asset |
| **D.** Open a PR upstream to make model selection a build-time flag | (long-term) | 🟢 low | n/a |

**Recommended: Option A** (build.gradle exclude). Lowest-risk concrete win. The exact line:

```kotlin
// android/app/build.gradle.kts
android {
    packaging {
        resources {
            excludes += setOf(
                "assets/mlkit_pose/pose_landmark_detector_full_f16_inf.tflite",
            )
        }
    }
}
```

### Verification path for Option A

1. Apply the build.gradle change.
2. `bash scripts/release-build.sh` → produces a new AAB.
3. `unzip -l build/app/outputs/bundle/release/app-release.aab | grep mlkit_pose` — confirm only 2 .tflite files (lite + person_detector), not 3.
4. **Smoke-test on a real device**: open Antrenman tab → start any workout that uses pose detection (e.g. a Squat or Plank exercise) → verify pose skeleton overlay renders correctly.
5. Watch logcat for ML Kit init errors: `adb logcat -s flutter:* MlKitPose:*`.

If logcat is clean and the skeleton draws, the removal is safe.

### Why Option A has medium risk

ML Kit's native Java loader might:
- Pre-validate the existence of both .tflite files at `PoseDetector` construction → would throw `FileNotFoundException`.
- Lazily load only when first detection is requested → works fine without the unused file.

The plugin's source suggests the latter (lazy load by `model:` selection), but verification on a real device is mandatory before shipping.

---

## 6. Accuracy implications of staying on `base`/lite

We're already on `base`/lite. **No accuracy change** if Option A is applied — we ship the same model we already use. The change is purely "stop shipping the file we don't load".

If a future product call decides to upgrade to `accurate`/full for better form analysis (gym-grade accuracy at higher CPU cost), the trade reverses: ship full, exclude lite.

**Current product state: `base`/lite is the right model for real-time form coaching on mid-tier Android.** This is the trade-off Phase 96's ML Kit strategy implicitly chose by not passing a `model:` argument.

---

## 7. APK impact recap

| Action | APK Δ delivered to Play user (post-AAB) |
|---|---:|
| Today (both .tflite bundled) | reference 0 |
| Apply Option A (exclude unused full model) | **−6.3 MB** |

This stacks with the other audited wins:

```
Current per-Play-user delivered (post-Tier-1-A + Tier-2-A) :  ~85 MB
After Option A (this audit's recommendation)               :  ~79 MB  (−6.3 MB)
After --obfuscate + Sentry symbol upload (T3.1)            :  ~77-78 MB
```

**~78 MB delivered per Play user** is the realistic launch-time floor without architectural change.

---

## 8. Confidence

| Claim | Confidence |
|---|---|
| Code uses `PoseDetectionModel.base` (lite) today | **HIGH** — explicit `PoseDetectorOptions(mode: ...)` with no `model:` argument; package default is `base` |
| Removing `full` saves 6.3 MB APK | **HIGH** — verified file size via `unzip -l` |
| `packagingOptions.resources.excludes` is the right mechanism | **HIGH** — standard AGP feature |
| ML Kit loader won't crash if `full` is absent | **MEDIUM** — needs real-device verification |
| Visual smoke test of pose skeleton will pass | **HIGH** — model selection happens at the same place that already works today |

---

## 9. Recommendation

**Apply Option A** in a follow-up cycle:

```kotlin
// android/app/build.gradle.kts — add inside `android { ... }` block
packaging {
    resources {
        excludes += setOf(
            "assets/mlkit_pose/pose_landmark_detector_full_f16_inf.tflite",
        )
    }
}
```

Followed by a release-AAB rebuild + on-device pose-detection smoke test.

**Effort: ~30 minutes including smoke test. Risk: medium (real-device validation required). APK win: −6.3 MB delivered.**

This is the highest-confidence remaining size lever after Tier 2-A. It deserves its own brief execution cycle once smoke-test access is available.

---

## 10. Status

**AUDIT COMPLETE.** No files modified. Recommendation documented for future execution. T2.2 closed; the `packagingOptions` change is a gated next step.
