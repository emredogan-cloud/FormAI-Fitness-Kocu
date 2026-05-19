# ML Kit Pose Model Strip — Final Report

> **Branch:** `feature/cdn-meal-migration`
> **Date:** 2026-05-19
> **Scope:** T2.2 from `CLEANUP_CANDIDATES.md`. Strip the unused `pose_landmark_detector_full_f16_inf.tflite` (6.13 MB) from every release artifact.
> **Status:** ENGINEERING COMPLETE. Pending on-device smoke test (`MLKIT_SMOKE_TEST_CHECKLIST.md`).

---

## 1. What changed (single file)

```
android/app/build.gradle.kts
```

Added a single `configurations.all { exclude(...) }` block after the `android { }` block (lines 117–155 of the file). 3 functional lines, 28 lines of inline documentation. **Zero other files modified.**

### Functional change

```kotlin
configurations.all {
    exclude(group = "com.google.mlkit", module = "pose-detection-accurate")
}
```

Tells Gradle to drop the `pose-detection-accurate` Maven artifact from the resolution graph. The artifact contained the unused `pose_landmark_detector_full_f16_inf.tflite` and a handful of accurate-only Java classes.

---

## 2. Real measured size delta

| Artifact | Before | After | Δ |
|---|---:|---:|---:|
| AAB on disk | 108,614,034 B = **108.61 MB** | 102,618,525 B = **102.62 MB** | **−5,995,509 B = −5.72 MB (−5.5%)** |
| `pose_landmark_detector_full_f16_inf.tflite` | 6,434,928 B inside AAB | **absent** | −6.13 MB raw |

The 5.72 MB AAB delta is slightly under the 6.13 MB raw file size because the AAB applies ZIP compression that recovers ~7–8% on .tflite weight data. **Result is within prediction.**

### Per-user Play delivery

When Play splits the AAB by ABI for delivery to end users, the 5.72 MB AAB reduction carries through to **every delivered APK regardless of which ABI the user is on**. The .tflite was an asset, not a native lib, so the saving is ABI-agnostic.

| Per-user delivery | Before | After |
|---|---:|---:|
| arm64-v8a user (~75% of installs) | ~85 MB | **~79 MB** |
| armeabi-v7a user (~24%) | ~76 MB | **~70 MB** |
| x86_64 user (rare) | ~88 MB | **~82 MB** |

Combined with Tier 2-A's −60 MB delivered: the cumulative per-Play-user reduction across Phase 139 → Tier 2-A → this T2.2 patch is **~50 MB → ~6 MB → reaching the ~78 MB practical floor for arm64-v8a**.

---

## 3. Confidence level

| Claim | Confidence | Verification |
|---|---|---|
| The lite model is the only model used at runtime | **HIGH** | Source grep returned zero `PoseDetectionModel.accurate` hits; `PoseDetectorOptions` constructions have no `model:` arg → package default `base` (lite). |
| The full .tflite is absent from the rebuilt AAB | **HIGH** | `unzip -l` post-build returns only `pose_landmark_detector_lite_f16_inf.tflite`. |
| The build compiles without the accurate artifact | **HIGH** | `flutter build appbundle --release` completed in 112.2 s with no errors. |
| `flutter analyze` clean on the workout subtree | **HIGH** | "No issues found! (ran in 5.7s)" |
| Pose detection works at runtime | **MEDIUM** | NOT yet verified on a physical device. The accurate Java classes are absent; if the wrapper or ML Kit's internal SDK does an eager class-resolution at `PoseDetector` construction (instead of lazy at model-selection time), it would `NoClassDefFoundError`. My analysis says the lookup is lazy and gated on `options.model.name == "accurate"`, but **this requires on-device verification** per `MLKIT_SMOKE_TEST_CHECKLIST.md`. |

**Net confidence: HIGH for the engineering-side change; MEDIUM until on-device smoke tests pass.**

---

## 4. Rollback path

```bash
# In android/app/build.gradle.kts, delete lines 117-155
# (the entire `// Tier 3 · strip the unused ML Kit ...` block including the
#  `configurations.all { exclude(...) }`).

# Then:
flutter clean
bash scripts/release-build.sh   # AAB rebuilds; pose-detection-accurate is back
```

**Rollback time: < 1 minute.** The plugin re-pulls the accurate artifact via its transitive declaration with no other change.

If `git revert` is preferred:

```bash
git revert <this-commit-hash>
```

That single-file revert is also clean.

---

## 5. Production risks

| Risk | Likelihood | Severity | Mitigation |
|---|---|---|---|
| `NoClassDefFoundError` on first `PoseDetector` construction | LOW | HIGH (camera workout broken) | On-device smoke test catches it before ship. Rollback is < 1 min. |
| Some other consumer of `pose-detection-accurate` exists in the dep graph | LOW | MEDIUM | If true, the build would have failed to compile. It didn't. |
| Future plugin upgrade re-introduces the accurate dep dynamically | LOW | LOW | The `configurations.all` rule applies to every configuration, so it persists. |
| R8 / ProGuard rules reference accurate classes via `-keep` | LOW | LOW | Existing keep rules target `com.google.mlkit.vision.pose.**` glob; with no actual class to keep, R8 ignores the unmatched rules silently. |
| Play Console rejects the AAB for missing assets | NONE | n/a | Play doesn't validate asset content; the AAB is structurally valid. |

The dominant risk is **runtime class-resolution**, which the smoke checklist directly tests.

---

## 6. What was NOT done (per the brief)

- ❌ No `lib/` Dart code modified.
- ❌ No camera logic touched.
- ❌ No workout UX changed.
- ❌ No pose-detection feature rewrite.
- ❌ No model-selection logic change.
- ❌ No other ML refactor.
- ❌ No T3 items touched.
- ❌ Smoke testing on device (deferred to operator).

**Single-purpose change applied: drop one unused Maven artifact.**

---

## 7. Files in this round

| File | Purpose |
|---|---|
| `MLKIT_PRE_EXECUTION_VERIFY.md` | Step 1 — exhaustive usage audit |
| `MLKIT_STRIP_PATCH_REPORT.md` | Step 2 — the patch, with why-`packaging.resources.excludes`-didn't-work post-mortem |
| `MLKIT_BUILD_REPORT.md` | Step 3 — before/after build + file-absence verification |
| `MLKIT_SMOKE_TEST_CHECKLIST.md` | Step 4 — 10-test on-device checklist (operator action) |
| `MLKIT_FINAL_REPORT.md` (this file) | Step 5 — synthesis + ship decision |
| `android/app/build.gradle.kts` | the patch itself |

---

## 8. Recommendation: should this ship?

**Yes, but only after the 10-test smoke battery in `MLKIT_SMOKE_TEST_CHECKLIST.md` passes.**

- Engineering side: verified, byte-measured, low-risk.
- Runtime side: highly likely safe based on code analysis, but needs human-on-device validation.

If the smoke tests pass cleanly:
- **Ship in the next release** alongside Tier 2-A.
- Update Play Console; the user-delivered APK will be ~6 MB smaller from the next release onward.

If even one smoke test fails:
- **Revert** (single-file, < 1 minute).
- Investigate the failure mode.
- Consider alternative approaches: forking the plugin to drop accurate at-source, or a custom Gradle task to delete just the .tflite file from merged assets.

---

## 9. Status

**ENGINEERING COMPLETE.** Patch applied, build verified, file absence confirmed, AAB delta measured. Operator's 10-test on-device battery is the remaining gate.

**Commit hash:** see this round's commit on `feature/cdn-meal-migration`.
