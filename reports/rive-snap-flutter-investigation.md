# Rive native build under Snap Flutter — investigation & deferral

> **Phase 103 · 2026-05-09**
> **Status:** Rive removed from `pubspec.yaml`. Onboarding ships fully cinematic via hand-coded motion primitives. Re-add Rive only when **both** blockers in §5 clear.

---

## 1. Symptom

Local Android build (`flutter run` / `flutter build apk`) fails inside `rive_common` native compilation with header-resolution errors pointing at the Snap-confined Flutter toolchain:

```
/snap/flutter/current/usr/include/c++/9/...
```

The cinematic onboarding implementation itself is **not** the source of the failure — every primitive under `lib/core/motion/` is pure Dart with no native side. The break is entirely on the package `rive` → `rive_common` native CMake/NDK build chain.

## 2. Why this manifested only when Rive was added

The project already depends on plenty of native plugins that build cleanly under the same Snap Flutter:

- `sentry_flutter`, `posthog_flutter`, `app_tracking_transparency`
- `camera`, `google_mlkit_pose_detection`, `permission_handler`
- `supabase_flutter`, `purchases_flutter`, `home_widget`, `live_activities`
- `connectivity_plus`, `share_plus`, `path_provider`, `cached_network_image`

Most of these use C / lightweight JNI bindings. Rive is materially different:

- Heavy modern C++ rendering core (Skia-style 2D vector graphics)
- Template-heavy headers (animation state machines, interpolation graphs)
- CMake-driven native build that resolves system C++ stdlib headers explicitly

The Snap Flutter container ships **its own bundled GCC 9 stdlib** at `/snap/flutter/current/usr/include/c++/9/`. When Rive's CMake build runs under Snap confinement, it picks up those Snap-confined headers instead of the Android NDK's clang headers. The Snap GCC 9 headers don't compile cleanly against Rive's template instantiation paths.

This is consistent with how Snap confinement works: the package vendor (Flutter) bundles a fixed toolchain inside the snap, and any process spawned under Snap sees that toolchain first on its include path.

## 3. Confirmed environment

| Check | Result |
|---|---|
| `which flutter` | `/snap/bin/flutter` |
| `flutter --version` | Flutter 3.41.8 stable, Dart 3.11.5 |
| Installed NDKs | `25.1.8937393`, `28.2.13676358` |
| `package:rive` imports in `lib/` | **0** (dep was scaffolded for the artist's `.riv` asset, never imported) |
| `pubspec.yaml` post-fix | `rive` removed; explanatory comment retained |
| `pubspec.lock` post-fix | `rive`, `rive_common`, transitive `graphs` all removed |
| Plugin registrants (linux/macos/windows) | auto-cleaned by `flutter pub get` |
| `flutter analyze lib/features/onboarding/ lib/core/motion/` | clean |

## 4. Why removing the dep is safe

Zero `import 'package:rive'` lines in the entire `lib/` tree — confirmed via `grep -rn "package:rive"`. The cinematic Form-presence feel is driven by hand-coded primitives:

- `BreathingBox` — alpha pulse on the avatar halo
- `GlowPulse` — radial-shadow breathing on the inner photo
- `KineticTextReveal` — character-by-character coach line typewriter
- `AmbientParticles` — drifting motes for atmospheric depth
- `MorphingNumber` — confidence/metric overshoot landing
- `SceneTransition` — crossfade-and-rise between screens

These run on `AnimationController` + `CustomPainter`. No native code, no NDK, no toolchain involvement. Snap Flutter handles them fine — they're already shipping in Phase 97–102 commits.

## 5. Re-enable protocol

Re-add `rive: ^0.14.x` to `pubspec.yaml` only when **both** of:

### Blocker A — artist deliverable
- `.riv` asset exists with the eight facial states scoped in Phase 97 (`idle`, `listening`, `thinking`, `surprised`, `encouraging`, `celebrating`, `reflecting`, `concerned`).
- State-machine input names agreed in advance so the Riverpod wiring lands in one motion.

### Blocker B — toolchain compatibility
Pick **one** of the following paths (in order of preference):

1. **Migrate off Snap Flutter (recommended).** Install Flutter via the official tarball or via a version manager (`fvm`, `asdf`, manual `~/flutter`). Verify `which flutter` is no longer `/snap/bin/flutter` before re-adding the dep.
2. **Pin NDK 25 explicitly.** In `android/app/build.gradle`:
   ```gradle
   android {
       ndkVersion '25.1.8937393'
   }
   ```
   Then upgrade to Rive `^0.14.x` (which has better NDK 25 compatibility than 0.13). Test `./gradlew :rive_common:assembleDebug` from inside `android/` to confirm before doing a full `flutter run`.
3. **CI-only Rive build.** Keep local dev on hand-coded primitives, build Rive-enabled releases via GitHub Actions / a non-Snap CI image. The `LivingCoachAvatar` adapter shape supports this — gate the Rive backend behind a `kCoachUsesRive` const.
4. **Vendor a prebuilt rive_common.aar.** Lift the rive_common native artifacts out of band (e.g. from a CI build) and drop them under `android/app/libs/`. Highest maintenance cost; reserve for emergencies.

## 6. Adapter readiness

`lib/features/onboarding/presentation/widgets/living_coach_avatar.dart` has the swap-in protocol documented in its top docstring. The widget is a single source of truth for Form's avatar; both `CoachIntroStep` and `NameCaptureStep` already consume it. Adding a Rive backend is a 4-step in-place edit to that file — no change at the call sites.

The cinematic onboarding emotional layer (Acts 1, 2, 4, 5 — Phases 97–102) is fully decoupled from Rive. None of the felt qualities (breathing avatar, kinetic typewriter, morphing numbers, scene crossfades, ambient particles, confidence overshoot, name personalization) require it.

## 7. Verdict

The Rive blocker is a build-environment issue, not an architecture one. The user's goal — "the onboarding should still ship and run beautifully using GlowPulse / BreathingBox / KineticTextReveal / AmbientParticles / MorphingNumber / SceneTransition choreography" — is met as of Phase 103. Re-introducing Rive remains a clean drop-in once the artist asset and toolchain blockers clear.
