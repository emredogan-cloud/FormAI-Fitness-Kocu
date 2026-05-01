# =============================================================================
# ProGuard / R8 keep rules — added Phase 77, expanded Phase 80.
# =============================================================================
# Wired in via `android/app/build.gradle.kts` `buildTypes.release`:
#   proguardFiles(
#     getDefaultProguardFile("proguard-android-optimize.txt"),
#     "proguard-rules.pro"
#   )
#
# Phase 78 turned `isMinifyEnabled` on, so these rules are now LIVE on
# every release build. Without them, R8 strips classes the ML Kit /
# MediaPipe / CameraX layers reach via JNI or reflection, producing
# either `NoSuchFieldError ...zzib` or
# `NoClassDefFoundError com.google.mlkit.vision.common.Detector` the
# moment the camera screen opens.
# =============================================================================

# ML Kit (vision, common, pose detection) — keep all classes and members
# end-to-end because the JNI layer binds to specific field/method names
# and any obfuscation would break the native ↔ JVM contract.
-keep class com.google.mlkit.** { *; }
-keep interface com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# MediaPipe internals (`mlkit_vision_mediapipe`) — `zzib` and friends
# are the obfuscated JNI-bound holders, so we keep the entire package
# and forbid further obfuscation.
-keep class com.google.android.gms.internal.mlkit_vision_mediapipe.** { *; }
-dontwarn com.google.android.gms.internal.mlkit_vision_mediapipe.**

# `google_mlkit_commons` and the wider `mlkit_vision_*` family share a
# small surface of native bindings. Belt-and-braces against future
# additions in transitive deps.
-keep class com.google.android.gms.internal.mlkit_vision_** { *; }
-dontwarn com.google.android.gms.internal.mlkit_vision_**

# Camera2 / CameraX — Phase 80 promoted from `-dontwarn` only to a
# full `-keep`. Even though this app doesn't bind to internal CameraX
# fields directly, ML Kit's pose-detection pipeline does — and when
# R8 strips a CameraX class that ML Kit's vision-common layer reaches
# via reflection, the class loader fails resolution of dependent
# `com.google.mlkit.vision.common.*` classes (the Phase 80 crash).
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# =============================================================================
# Phase 80 · widen ML Kit / Google-Play-services coverage.
# =============================================================================
# The Phase 77 rules covered `com.google.mlkit.**` and the
# `com.google.android.gms.internal.mlkit_vision_**` family. The crash
# the PM hit on the first minified release build (`Failed resolution
# of: Lcom/google/mlkit/vision/common/Detector;`) showed those weren't
# enough — `Detector` resolves transitively against
# `com.google.android.gms.vision.**` (the legacy Vision API surface
# the new ML Kit Detector inherits from) and against assorted
# `com.google.android.gms.**` warnings R8 was raising as missing
# references. Both gaps are closed below.
-keep class com.google.android.gms.vision.** { *; }
-dontwarn com.google.android.gms.**
