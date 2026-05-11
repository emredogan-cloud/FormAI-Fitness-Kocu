#!/usr/bin/env bash
# =============================================================================
# Dev cycle wrapper — Phase 127 → Phase 128.1
# =============================================================================
# Single entry point for `flutter run` during the cinematic onboarding tuning
# loop. Defaults to debug mode — the fastest possible cycle on this hardware
# (hot reload, 5–50 ms reloads).
#
# Why this wrapper exists:
#   Phase 117/120/121 + 127 found the iteration crisis was caused by
#   `flutter run --release` being used reflexively for tuning. Release mode
#   pays AOT + R8/ProGuard + ~7 min adb install on this Xiaomi entry-level
#   device. Debug + hot reload skips all of that. This script encodes
#   "debug is the default" structurally — you have to opt in to
#   profile / release.
#
# Why no explicit `--target-platform` / ABI flag:
#   The Phase 127 script passed `--target-platform=android-arm64`. That flag
#   no longer exists on `flutter run` in Flutter 3.41.x — it errors with
#   `Could not find an option named "--target-platform"`. The Flutter tool
#   now auto-detects the connected device's ABI (via
#   `adb shell getprop ro.product.cpu.abi`) and passes the matching
#   `android.injected.target.abi=<abi>` to Gradle internally — so the
#   wrapper does not need to. With the Xiaomi 22095RA98C ("light",
#   arm64-v8a) attached, `flutter run` automatically:
#     • compiles Dart AOT only for arm64-v8a (profile / release modes),
#     • installs only the arm64-v8a slice of the APK on the device.
#   The 290 MB debug APK on disk still contains all 3 ABIs (debug
#   `libflutter.so` is the biggest contributor), but adb pushes only the
#   arm64 portion to the device, so install size on-device matches what
#   the manual `--target-platform` flag used to give. Verified empirically
#   in Phase 128.1 — see the forensic report §11.
#
#   For a TRULY ABI-stripped APK file (e.g. for direct distribution outside
#   the Play Store), use `flutter build apk --release --split-per-abi`;
#   that produces a 119 MB arm64-v8a-only APK file. Not used by this
#   wrapper because `flutter run` already handles the on-device path
#   correctly without it.
#
# Usage:
#   scripts/dev-run.sh                # debug    (default — hot reload)
#   scripts/dev-run.sh profile        # profile  (AOT, no hot reload, frame-pacing accurate)
#   scripts/dev-run.sh release        # release  (full minified release smoke)
#
# Pairs with:
#   docs/dev-iteration-workflow.md                          — workflow philosophy
#   reports/android-build-performance-audit.md              — Phase 117 measurements
#   reports/phase-127-build-iteration-forensic.md           — current bottleneck deep dive (+ Phase 128 outcome)
set -euo pipefail

MODE="${1:-debug}"

case "$MODE" in
  debug)
    exec flutter run
    ;;
  profile)
    exec flutter run --profile
    ;;
  release)
    exec flutter run --release
    ;;
  *)
    echo "Usage: $0 [debug|profile|release]" >&2
    echo "  debug   (default)  — hot reload, fastest iteration" >&2
    echo "  profile            — AOT, accurate frame pacing, no hot reload" >&2
    echo "  release            — full minified release smoke test" >&2
    exit 64
    ;;
esac
