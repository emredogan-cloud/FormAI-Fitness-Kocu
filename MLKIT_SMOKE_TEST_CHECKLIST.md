# ML Kit Smoke Test Checklist — Step 4

> **Branch:** `feature/cdn-meal-migration`
> **Date:** 2026-05-19
> **Status:** HANDOFF. Claude cannot drive a physical phone; the operator must run these tests on a real Android device.

---

## 0. Why these specific tests

The patch removes the `pose-detection-accurate` Maven artifact from the build. We've **verified at the BUILD level** that:

1. ✓ The full / accurate `.tflite` file is absent from the new AAB.
2. ✓ The lite `.tflite` + shared `pose_person_detector` are still present.
3. ✓ The build compiled and linked cleanly (no `NoClassDefFoundError` etc.).
4. ✓ `flutter analyze` is clean.

**Build-level success does NOT guarantee runtime correctness.** ML Kit's Java/Kotlin layer might lazily look up the accurate classes at `PoseDetector` construction time, throw, and crash the camera workout flow. The smoke checklist below verifies the lazy-lookup path is safe.

---

## 1. Install instructions

```bash
# Build a fat APK for sideload (the AAB is for Play, but for device install we use APK):
flutter build apk --release
# OR per-ABI for smaller install:
bash scripts/release-build.sh split

# Install to your test device (Xiaomi 22095RA98C or any Android 7+):
adb install -r build/app/outputs/flutter-apk/app-release.apk
# OR for split-per-abi:
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

The fat APK is what `bash scripts/release-build.sh apk` produces. The AAB itself can be installed via `bundletool install-apks` if you want to test the exact Play-delivered shape.

---

## 2. Test cases — RUN ALL TEN

Each test is **PASS** if the described behaviour is observed and the device's logcat shows **no MLKitException / NoClassDefFoundError / FileNotFoundException / java.io.IOException** referencing `mlkit_pose` paths.

While running each test, in a separate terminal:

```bash
adb logcat -c                                          # clear log first
adb logcat -s flutter:V FlutterPosePlugin:V \
            "com.google.mlkit.vision.pose:V" \
            "com.google.android.gms.vision:V" \
            AndroidRuntime:E
```

### Test 1 · Cold start, app opens
- **Action:** Tap launcher icon. Wait for dashboard to appear.
- **Expected:** Dashboard renders within the normal ~3s window. No splash-screen-hang.
- **Fail signal:** App crashes during init. Logcat shows `NoClassDefFoundError: com.google.mlkit.vision.pose.accurate.*` or similar.

### Test 2 · Phase 138 availability probe
- **Action:** Open app, observe initial flow.
- **Expected:** No "Pose detection unavailable" banner / fallback UI.
- **Fail signal:** Probe returns false → app routes to no-camera workout fallback path. Indicates `PoseDetector` construct-and-close throws.

### Test 3 · Camera workout screen opens
- **Action:** Navigate to Antrenman tab → tap any program → start a workout that uses pose detection (Plank, Squat, Push-up, etc.). The first exercise should bring up the camera.
- **Expected:** Camera permission prompt (if not granted) → camera preview appears → countdown begins.
- **Fail signal:** Black screen on camera open. Logcat shows ML Kit init exception.

### Test 4 · Pose detection initialises and draws
- **Action:** Stand in the camera frame so the user's body is visible.
- **Expected:** Pose skeleton overlay (line drawings between keypoints) appears within 1 second. Joints track movement.
- **Fail signal:** No overlay despite body being in frame. Logcat shows `Failed to load model` referencing the lite path, or no pose detection callbacks fire.

### Test 5 · Rep-counting / form analysis
- **Action:** Perform 3-5 reps of the exercise.
- **Expected:** Rep counter increments. Form analysis feedback (good/bad) shows.
- **Fail signal:** Counter stuck at 0. Logcat shows analyzer errors.

### Test 6 · End workout, return to dashboard
- **Action:** Tap "Bitir" / done. Workout completes; navigate back.
- **Expected:** Workout summary shows correct rep / duration. Return to dashboard works.
- **Fail signal:** Crash on dispose. Logcat shows `PoseDetector.close()` errors.

### Test 7 · Re-open workout
- **Action:** Start another workout (any exercise).
- **Expected:** Camera + pose detection work identically to Test 4.
- **Fail signal:** Second-init fails. Different from first-init failure mode — indicates a leaked native resource.

### Test 8 · Cold cache + airplane mode
- **Action:** Force-stop the app. Enable airplane mode. Open app. Start a workout.
- **Expected:** Pose detection works offline (ML Kit runs on-device, no network needed). Pose model is bundled in APK; airplane mode is irrelevant.
- **Fail signal:** Pose detection fails offline → would indicate the patch broke something other than the network path.

### Test 9 · Long-running session (5+ minutes)
- **Action:** Stay in camera workout for 5+ minutes. Watch memory usage via `adb shell dumpsys meminfo com.emredogan.formaifit`.
- **Expected:** Memory stays stable (no leak). Pose detection continues at expected fps (~15-30 fps).
- **Fail signal:** Memory grows unbounded. Pose tracking lags / stops.

### Test 10 · Force a fresh PoseDetector construction
- **Action:** Bring the app to background while in workout. Wait 30s. Foreground the app.
- **Expected:** Pose detection resumes after re-init (ML Kit detectors get re-constructed on resume).
- **Fail signal:** Re-init throws. Logcat shows different exception on the second construction than the first.

---

## 3. What "PASS" means for shipping

**All 10 tests PASS** → the patch is **safe to ship** in the next release. The 5.72 MB AAB reduction carries through to every Play user.

**ANY test FAILS** → roll back immediately:

```bash
# In android/app/build.gradle.kts, remove the block:
#   configurations.all {
#       exclude(group = "com.google.mlkit", module = "pose-detection-accurate")
#   }
# Then rebuild:
flutter clean
bash scripts/release-build.sh
```

The 6 lines of code change can be reverted in seconds.

---

## 4. Why we expect all 10 to PASS

| Test | Rationale for expected PASS |
|---|---|
| 1 cold start | Patch doesn't touch app init. Same Flutter startup, same Riverpod tree. |
| 2 probe | Probe constructs with `PoseDetectionMode.single` and `model=base` (default). Lite model is present. Should succeed identically. |
| 3 camera | Camera permission + lifecycle unchanged. |
| 4 detection draws | The lite model is what was ALWAYS used (verified across all PoseDetectorOptions sites). Behaviour should be byte-identical. |
| 5 analysis | Analyzer logic is in lib/features/workout/services/*_analyzers.dart — unchanged. |
| 6 dispose | `PoseDetectorService.dispose` is unchanged. |
| 7 re-open | Same lifecycle as 3-6, just twice. |
| 8 airplane | ML Kit runs on-device — network has nothing to do with it. |
| 9 memory | No memory profile change introduced. |
| 10 background/foreground | Native lifecycle behaviour preserved. |

The patch removes **only the never-used full model file** and the **never-instantiated accurate Java classes**. Nothing in the active code path crosses the deleted surface.

---

## 5. Logcat patterns to ALERT on

```
NoClassDefFoundError: com.google.mlkit.vision.pose.accurate.*
NoClassDefFoundError: com.google.mlkit.vision.pose.PoseLandmarkerAccurate
java.io.FileNotFoundException: ...pose_landmark_detector_full_f16_inf.tflite
java.lang.RuntimeException: Failed to load model: pose_landmark_detector_full...
MlKitException: Failed to load TFLite model
```

If any of these surface, the patch interacts with a code path I didn't catch in the verify step. Revert and report exactly which logcat line appeared.

---

## 6. Common false positives to IGNORE

These are pre-existing benign log entries that have nothing to do with the patch:

- `Expected to find fonts for (packages/cupertino_icons/CupertinoIcons, ...)` — Flutter's font manifest scanner; benign since Phase 139 T4-A removed cupertino_icons.
- `W ResolveInfo: Missing application label` — Android packaging quirk.
- `W FlutterEngine: ...` related to lifecycle.
- Any `posthog_flutter` analytics chatter on session start.

---

## 7. Time budget

| Test | Estimated time |
|---|---|
| 1, 2 | ~30 s (app open) |
| 3, 4, 5 | ~3 min (one workout) |
| 6, 7 | ~1 min |
| 8 | ~30 s |
| 9 | 5+ min |
| 10 | ~1 min |
| **Total** | **~12 minutes** |

A single tester can finish the full battery in under 15 minutes on a real device.

---

## 8. Status

**HANDOFF.** All build-level checks pass. Runtime validation is the operator's gate. After the 10 tests come back clean, the patch is shippable.
