# =============================================================================
# Phase 77 · ProGuard / R8 keep rules
# =============================================================================
# Wired in via `android/app/build.gradle.kts` `buildTypes.release`:
#   proguardFiles(
#     getDefaultProguardFile("proguard-android-optimize.txt"),
#     "proguard-rules.pro"
#   )
#
# `isMinifyEnabled` is currently `false`, so these rules are dormant —
# but keeping them in place means the moment minification is enabled,
# the JNI-bound ML Kit + MediaPipe classes stay intact instead of being
# renamed/stripped (which produced the
# `JNI ... NoSuchFieldError: no "[B" field "value"` crash in
# `mlkit_vision_mediapipe.zzib` the PM saw in phase 77).
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

# Camera2 / CameraX — referenced by the pose-detection pipeline at
# runtime; warnings here are noisy but harmless. Kept off the keep
# list because we don't bind to internal CameraX fields directly.
-dontwarn androidx.camera.**
