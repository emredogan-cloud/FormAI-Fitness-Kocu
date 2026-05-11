#!/usr/bin/env bash
# =============================================================================
# Dev attach wrapper — Phase 128.1
# =============================================================================
# Connects to the *already-installed* app on the device and enables hot reload.
# Use after the once-a-session `scripts/dev-run.sh` (or after a manual
# adb install) has put the debug APK on the device. Attach takes ~33 s; hot
# reload after attach is 1–3 s per code change.
#
# Why this exists alongside `scripts/dev-run.sh`:
#   `flutter run` always re-installs the APK before attaching. On the
#   Xiaomi 22095RA98C (MIUI 14 / HyperOS), every install triggers a
#   MIUI confirmation prompt that times out after ~14 min if the phone
#   isn't tapped — Phase 128.1 hit this three times. For the second and
#   subsequent iteration cycles of the day, skipping the re-install
#   removes that bottleneck entirely.
#
# Usage:
#   scripts/dev-attach.sh             # launches app on device, attaches to it
#
# Assumes the app is already installed. If `adb shell pm list packages`
# does not show `com.emredogan.formaifit`, run `scripts/dev-run.sh` first
# (or the four-line build → install --no-streaming → start → attach
# sequence documented in reports/phase-127-build-iteration-forensic.md §12.5).
set -euo pipefail

PKG="com.emredogan.formaifit"
ACTIVITY="${PKG}/.MainActivity"
ADB="${ANDROID_HOME:-$HOME/Android/Sdk}/platform-tools/adb"

if [[ ! -x "$ADB" ]]; then
  ADB=adb
fi

if ! "$ADB" shell pm list packages | grep -q "$PKG"; then
  echo "Error: $PKG is not installed on the device." >&2
  echo "Run scripts/dev-run.sh first (or the four-line workflow in the forensic report)." >&2
  exit 1
fi

echo "→ launching $ACTIVITY on device"
"$ADB" shell am start -n "$ACTIVITY" > /dev/null

echo "→ flutter attach (this discovers the running Dart VM Service)"
exec flutter attach
