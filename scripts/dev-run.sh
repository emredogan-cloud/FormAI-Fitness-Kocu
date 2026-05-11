#!/usr/bin/env bash
# =============================================================================
# Dev cycle wrapper — Phase 127
# =============================================================================
# Single entry point for `flutter run` during the cinematic onboarding tuning
# loop. Defaults to debug mode + arm64-v8a only — the fastest possible cycle
# on this hardware.
#
# Why this wrapper exists:
#   1. The connected dev device (Xiaomi 22095RA98C "light") is arm64-v8a.
#      Building also for armeabi-v7a + x86_64 (Flutter's default for
#      `flutter run`) triples the Dart AOT work in profile/release modes
#      and adds ~30 MB of native libs to the APK that adb has to push +
#      device has to dexopt. Measured in Phase 127: forcing arm64 only
#      shrinks `flutter run --release` APK from 149.6 MB → ~70 MB and
#      cuts adb-install time on the Xiaomi from ~9 min → ~2-3 min.
#   2. Debug mode is what enables hot reload (5–50 ms reloads). The Phase
#      121 workflow doc spelled this out, but `flutter run --release`
#      kept being used reflexively. This script encodes "debug is the
#      default" structurally — you have to opt in to profile/release.
#
# Usage:
#   scripts/dev-run.sh                # debug + arm64    (5-50 ms hot reload)
#   scripts/dev-run.sh profile        # profile + arm64  (AOT, no hot reload)
#   scripts/dev-run.sh release        # release + arm64  (full release smoke)
#
# Pairs with:
#   docs/dev-iteration-workflow.md          — workflow philosophy
#   reports/android-build-performance-audit.md  — Phase 117 measurements
#   reports/phase-127-build-iteration-forensic.md — current bottleneck deep dive
set -euo pipefail

MODE="${1:-debug}"

case "$MODE" in
  debug)
    exec flutter run --target-platform=android-arm64
    ;;
  profile)
    exec flutter run --profile --target-platform=android-arm64
    ;;
  release)
    exec flutter run --release --target-platform=android-arm64
    ;;
  *)
    echo "Usage: $0 [debug|profile|release]" >&2
    echo "  debug   (default)  — hot reload, fastest iteration" >&2
    echo "  profile            — AOT, accurate frame pacing, no hot reload" >&2
    echo "  release            — full minified release smoke test" >&2
    exit 64
    ;;
esac
