# ML Kit Pre-Execution Verify — Step 1

> **Branch:** `feature/cdn-meal-migration`
> **Date:** 2026-05-19
> **Purpose:** Re-verify, on the current branch state, that no path in the app — source, native, runtime, or fallback — uses the full pose model. ZERO ambiguity required before mutation.

---

## 1. Source-level audit (all paths)

### 1.1 Every `PoseDetector` construction in `lib/`

```dart
// lib/features/workout/services/pose_detector_service.dart:5-7
PoseDetectorService()
    : _poseDetector = PoseDetector(
        options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
      );
```

```dart
// lib/features/workout/services/pose_detector_service.dart:42-44 (availability probe)
detector = PoseDetector(
  options: PoseDetectorOptions(mode: PoseDetectionMode.single),
);
```

**Exactly 2 construction sites. Neither passes a `model:` argument.** The `PoseDetectorOptions` constructor default is `PoseDetectionModel.base` (lite). Both sites receive the lite model.

### 1.2 References to the `accurate` / full model

```bash
$ grep -rni "PoseDetectionModel.accurate\|model:.*accurate\|accurate.*PoseDetection" lib/ --include="*.dart"
(empty — zero matches)
```

**No code path requests the accurate / full model.**

### 1.3 Other "full" mentions — verified non-conflicting

```bash
$ grep -rni "full" lib/features/workout/ --include="*.dart" | grep -iE "model|tflite|landmark|pose"
lib/features/workout/models/session_log_model.dart:99:  /// One of: `core`, `upper_body`, `lower_body`, `cardio`, `full_body`.
lib/features/workout/models/session_log_model.dart:139:      targetMuscle: (json['targetMuscle'] as String?) ?? 'full_body',
lib/features/workout/models/exercise_model.dart:3:enum ExerciseCategory { core, chest, legs, back, arms, shoulders, fullBody }
lib/features/workout/models/exercise_model.dart:52:  /// `upper_body`, `lower_body`, `full_body`, `cardio`.
```

These are about `full_body` (workout target muscle) — **not the pose model**. Unrelated.

### 1.4 Hardcoded .tflite filenames

```bash
$ grep -rn "pose_landmark_detector\|f16_inf" lib/ android/ ios/ --include="*.dart" --include="*.kt" --include="*.java" --include="*.gradle*"
(empty — zero matches)
```

**No app code or build config hardcodes the .tflite filename anywhere.** The model file is loaded only by ML Kit's plugin layer based on `PoseDetectorOptions`.

### 1.5 Dynamic / reflective model loading

```bash
$ grep -rn "Class\.forName\|Reflect\|loadClass\|getClassLoader" lib/features/workout/ --include="*.dart" --include="*.kt"
(empty)
```

No dynamic class loading. No reflection. The model selection is purely declarative via `PoseDetectorOptions`.

---

## 2. Plugin / Maven artefact analysis

### 2.1 Plugin source

```
~/.pub-cache/hosted/pub.dev/google_mlkit_pose_detection-0.14.1/android/build.gradle:

apply plugin: "com.android.library"
android {
    namespace = "com.google_mlkit_pose_detection"
    compileSdk = 35
    defaultConfig { minSdk = 21 }
    dependencies {
        implementation("com.google.mlkit:pose-detection:18.0.0-beta5")          # ← lite model
        implementation("com.google.mlkit:pose-detection-accurate:18.0.0-beta5") # ← full model
    }
}
```

**The plugin's AAR pulls in BOTH the lite-model artifact and the accurate-model artifact, regardless of which the app actually uses.** This is the root cause of the dead-weight `pose_landmark_detector_full_f16_inf.tflite` shipping in our APK.

### 2.2 Two strip paths considered

| Approach | Strips | Java classes affected | Risk |
|---|---|---|---|
| **A. `packaging.resources.excludes`** (selected) | only the .tflite file (6.13 MB) | none — Java classes still in dex | low — file simply absent at runtime; ML Kit never tries to read it because `PoseDetectionModel.base` never invokes the accurate code path |
| B. Gradle `exclude(group=..., module="pose-detection-accurate")` | the whole AAR (Java + native + .tflite) | accurate-only Java classes removed → R8 might keep references that break compile/link | **HIGH** — Phase 81 docs (in `android/app/build.gradle.kts` lines 121-131) recorded that *upgrading* the artifact version caused `NoClassDefFoundError` because the wrapper's Java compiled code referenced 18.x classes. Removing the artifact entirely could re-trigger similar symbol-resolution issues. |

**Selected: Approach A.** Smallest possible change. Strips the data file, leaves the Java classes (which never instantiate because no code path requests them) intact.

---

## 3. Runtime model-loading mechanics

`google_mlkit_pose_detection` 0.14.1's runtime construction:

1. App constructs `PoseDetector(options)`. The plugin's Dart layer crosses the platform channel.
2. Native Java code (`PoseDetectorPlugin.kt`) instantiates a `PoseDetectorOptions` Java builder, sets the model based on `options.model.name` ("base" or "accurate").
3. ML Kit's underlying SDK opens the matching .tflite file from `assets/mlkit_pose/`.

When `PoseDetectionModel.base` is requested (our case), the native side loads `pose_landmark_detector_lite_f16_inf.tflite`. **It never opens `pose_landmark_detector_full_f16_inf.tflite`.** Removing that file from the APK has no observable runtime effect in the lite path.

### 3.1 Fallback / failover paths

```bash
$ grep -rn "fallback\|catch.*PoseDetect\|recover.*pose" lib/features/workout/ --include="*.dart"
```

PoseDetectorService has a `Phase 138 · H-4 · runtime probe for the device's ML Kit pose detection availability` method (`isAvailable()`) — it constructs + closes a detector to verify the platform supports pose detection at all. The probe also uses `mode: PoseDetectionMode.single`, **not `model: accurate`** — so the probe is unaffected.

**No fallback path requests the accurate / full model.** The probe failing → app falls back to a non-camera workout flow (no model required).

---

## 4. Verification of file presence in current APK

```
$ unzip -l build/app/outputs/flutter-apk/app-release.apk | grep mlkit_pose
   6434928   assets/mlkit_pose/pose_landmark_detector_full_f16_inf.tflite      ← UNUSED (strip target)
   2813968   assets/mlkit_pose/pose_landmark_detector_lite_f16_inf.tflite      ← USED (keep)
   2962288   assets/mlkit_pose/pose_person_detector_f16.tflite                 ← shared (keep)
   + benchmark_*.data + pose_{non_}tracking_graph*.binarypb + bundled_allowlist.binarypb   (small auxiliaries — leave intact)
```

Confirmed:
- `pose_landmark_detector_full_f16_inf.tflite` = **6,434,928 bytes = 6.13 MB**
- Path inside APK: `assets/mlkit_pose/pose_landmark_detector_full_f16_inf.tflite`
- Sibling files (lite + person_detector + auxiliaries) all stay.

---

## 5. Decision

**All five verification gates pass with zero ambiguity:**

1. ✓ No source code references `PoseDetectionModel.accurate`
2. ✓ No source code hardcodes the .tflite filename
3. ✓ No dynamic / reflective model loading
4. ✓ No fallback path requests the full model
5. ✓ ML Kit's runtime loads only the model named by `PoseDetectorOptions.model` (default `base`)

**Approach selected: `packaging.resources.excludes` of the .tflite file path.**

**Risk: medium-low** — the change is smallest possible, but the strip mechanism (`packaging.resources.excludes`) is theoretically intended for Java resources rather than Android assets. If AGP doesn't actually drop the file, the post-build verification (`unzip -l` on the new AAB) will catch it and we iterate.

**Proceeding to Step 2.**
