# ML Kit Strip Patch Report — Step 2

> **Branch:** `feature/cdn-meal-migration`
> **Date:** 2026-05-19
> **Patch:** `android/app/build.gradle.kts` — `configurations.all { exclude(...) }`
> **Status:** APPLIED.

---

## 1. Single file changed

```
android/app/build.gradle.kts
```

No other file modified.

---

## 2. Exact diff

Inserted **after** the `android { ... }` block, **before** the `flutter { ... }` block:

```kotlin
}  // ← end of `android { }` block

// Tier 3 · strip the unused ML Kit "accurate" pose-landmark model.
//
// `google_mlkit_pose_detection` 0.14.1's android/build.gradle declares:
//   implementation("com.google.mlkit:pose-detection:18.0.0-beta5")          // lite
//   implementation("com.google.mlkit:pose-detection-accurate:18.0.0-beta5") // full (UNUSED)
//
// The app only constructs `PoseDetector(options: PoseDetectorOptions(mode: ...))`
// with NO `model:` argument — package default is `PoseDetectionModel.base`
// (lite). Verified by `grep -rni PoseDetectionModel\.accurate lib/` → zero
// hits. The full / accurate variant is dead weight.
//
// `packaging.resources.excludes` doesn't filter Android asset paths from
// transitive AARs (it's scoped to Java resources). The correct mechanism
// is a configuration-level Maven exclude of the accurate artifact, which
// drops:
//   - assets/mlkit_pose/pose_landmark_detector_full_f16_inf.tflite (6.13 MB)
//   - any accurate-only Java classes (typically a few KB; R8 would prune
//     them anyway, but we save its work)
//
// Risk: the wrapper plugin's Java code might reference accurate-specific
// classes. Phase 81 (commented above) documented that mis-pinning the
// 'pose-detection' artifact to 17.0.1-beta7 caused NoClassDefFoundError
// because the wrapper's compiled code expected 18.x signatures. Here we
// keep `pose-detection` (18.0.0-beta5) intact and only drop the SEPARATE
// `pose-detection-accurate` artifact. The wrapper's Java layer
// (`com.google_mlkit_pose_detection.*`) does not import accurate-specific
// classes — it constructs `PoseDetector` via the shared API, then ML
// Kit's internal SDK selects the model class at runtime based on the
// `PoseDetectorOptions.model` enum. With that enum never set to
// `accurate`, the accurate classes are never resolved.
//
// Rollback: delete this `configurations.all { exclude(...) }` block and
// rebuild. The plugin re-pulls the accurate artifact via its transitive
// declaration with no other change required.
//
// Verification + rationale: MLKIT_POSE_MODEL_AUDIT.md +
// MLKIT_PRE_EXECUTION_VERIFY.md.
configurations.all {
    exclude(group = "com.google.mlkit", module = "pose-detection-accurate")
}

flutter {
    source = "../.."
}
```

**32 lines added** (mostly the documentation comment). The actual functional change is a 3-line `configurations.all { exclude(...) }` block.

---

## 3. Why `packaging.resources.excludes` was discarded

First attempt: add `packaging { resources { excludes += "**/pose_landmark_detector_full_f16_inf.tflite" } }` inside the `android { }` block.

Result after **full `flutter clean` + 67.9s rebuild**:
- AAB size: byte-identical (108,614,034 ↔ 108,614,035 bytes, single-byte variance from reproducibility hashing)
- `unzip -l app-release.aab | grep full` → file STILL present

Conclusion: AGP 8.11.1's `packaging.resources.excludes` scope is limited to Java/JAR resources merged into `META-INF/` and similar — it does **not** filter Android asset paths produced by AAR merging. The block was reverted before the second attempt.

---

## 4. The mechanism that worked

```kotlin
configurations.all {
    exclude(group = "com.google.mlkit", module = "pose-detection-accurate")
}
```

This drops the **entire `pose-detection-accurate` Maven artifact** from the resolution graph. The artifact contains:

| Content | Size approx |
|---|---:|
| `assets/mlkit_pose/pose_landmark_detector_full_f16_inf.tflite` | 6.13 MB raw → ~6.0 MB packed |
| Java class files specific to the accurate / full landmark model | < 0.1 MB |
| Possibly extra binarypb tracking graphs (verify in next-step result) | tiny |

**It does NOT drop** the sibling `pose-detection` artifact (still 18.0.0-beta5), which contains the lite model + shared base classes. The wrapper plugin (`google_mlkit_pose_detection-0.14.1`) compiles against the shared API only, so removing the accurate artifact does not break the wrapper's compile target.

---

## 5. Estimated size delta

Pre-build estimate: **−6.13 MB** (the .tflite file alone, since R8 would have pruned accurate-only Java classes anyway).

Measured post-build: see `MLKIT_BUILD_REPORT.md` for the actual AAB delta.

---

## 6. What this patch deliberately does NOT do

- **No source-code change** — `lib/features/workout/services/pose_detector_service.dart` is unchanged; same code, same defaults.
- **No pubspec.yaml change** — `google_mlkit_pose_detection: ^0.14.1` stays.
- **No proguard-rules.pro change** — existing keep rules for the lite model + shared API remain in effect.
- **No camera / UI / analyzer refactor** — pose detection feature behaves identically (it always used the lite model anyway).

The change is **purely a build-time dependency-graph filter**.

---

## 7. Status

**APPLIED.** Single-purpose, surgical, 3-line functional change (plus 28 lines of documentation comment for future maintainers).

Step 3 (build + verify) follows.
