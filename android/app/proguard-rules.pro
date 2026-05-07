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

# =============================================================================
# Phase 81 · Firebase components keep rule.
# =============================================================================
# ML Kit's vision-common layer is wired to Firebase's component framework
# (`com.google.firebase.components.ComponentRegistrar` discovery + DI).
# The Phase 81 root cause turned out to be the Phase 79 native-artifact
# downgrade (forced 17.0.1-beta7 vs the 18.0.0-beta5 the wrapper was
# built against), but R8 was also pruning the Firebase-components
# bridge in some configurations. Keeping it explicitly closes that
# door even after the version-force regression is undone.
#
# Other rules from the Phase 81 directive
# (`com.google.mlkit.vision.common.**`, `com.google.mlkit.vision.pose.**`,
# the `mlkit_vision_pose_common` internal subpackage) are intentionally
# NOT re-listed because the existing `com.google.mlkit.**` and
# `com.google.android.gms.internal.mlkit_vision_**` wildcards above
# already cover them — ProGuard's `**` matches across package levels.
-keep class com.google.firebase.components.** { *; }
-dontwarn com.google.firebase.components.**

# =============================================================================
# Phase 94 · belt-and-braces keep rules for startup-critical native
# bridges. Every plugin below ships its own consumer ProGuard rules
# inside the AAR, so these are mostly belt-and-braces — but a single
# stripped JNI binding on the cold-start path = a permanent black
# screen on the first .aab the user installs from Play, and the
# Phase 92 incident showed how easily that can ship undetected. The
# extra ~30 KB on the release artifact is a cheap insurance policy.
# =============================================================================

# Sentry — the SDK reaches into a fair bit of itself reflectively to
# discover integrations / event processors at init. A stripped
# integration would surface as a startup throw inside the
# `SentryFlutter.init` options builder.
-keep class io.sentry.** { *; }
-keepattributes LineNumberTable,SourceFile
-renamesourcefileattribute SourceFile
-dontwarn io.sentry.**

# PostHog — the analytics plugin exposes a singleton via reflection
# and queues events through a worker thread that boots from a static
# init block. Pruning that path produces the "Posthog().setup() never
# returns" hang that black-screened the splash.
-keep class com.posthog.** { *; }
-dontwarn com.posthog.**

# RevenueCat — the BillingClient bridge resolves Google Play Billing
# product details via reflection on Play Services classes. Without
# the keep, the IAP flow opens but immediately reports
# "configuration_error" and the paywall hangs.
-keep class com.revenuecat.purchases.** { *; }
-dontwarn com.revenuecat.purchases.**

# google_sign_in v7 — major rewrite from v6. The plugin uses the
# CredentialManager API and registers nested classes that R8 has
# been observed to prune in 8.x configurations.
-keep class com.google.android.gms.auth.api.** { *; }
-keep class com.google.android.libraries.identity.** { *; }
-dontwarn com.google.android.gms.auth.api.**
-dontwarn com.google.android.libraries.identity.**

# flutter_local_notifications — uses Gson + reflection to serialise
# scheduled notification payloads through AlarmManager. Stripped
# fields = silent reminder loss, not a black screen, but bundling
# the rule keeps the failure mode consistent with everything else
# we keep.
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keepclassmembers class * { @com.google.gson.annotations.SerializedName <fields>; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# home_widget — the Kotlin provider class is reflected by name
# (`qualifiedAndroidName` in `WidgetSyncService`) and the OS
# resolves it via ClassLoader.forName. R8 must not rename it.
-keep class com.emredogan.formaifit.widget.** { *; }
-keep class es.antonborri.home_widget.** { *; }
