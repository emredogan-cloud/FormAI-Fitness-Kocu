#!/usr/bin/env bash
# =============================================================================
# Dev cycle wrapper — Phase 138.PERF
# =============================================================================
# Single entry point for dev builds. Defaults to debug mode with the fastest
# possible cycle on the Xiaomi 22095RA98C ("light", HyperOS / MIUI 14).
#
# ─── Root-cause history (Phase 117 → 138) ────────────────────────────────────
#
# Phase 117 — JVM oversizing: gradle.properties had -Xmx8G on a 15 GB machine
#   → 4.9 GB swap used during every build. Fixed: -Xmx4G.
#
# Phase 127 — Wrong iteration mode: user was running `flutter run --release`
#   for cinematic onboarding tuning. Release mode forces AOT + R8/ProGuard
#   + multi-ABI packing = 12-15 min cycles. Fixed: debug + hot reload by default.
#
# Phase 128 — Snap Flutter: SDK in a squashfs mount. Migrated to manual SDK
#   at ~/dev/flutter. Build time benefit ~0 % on warm builds (page cache
#   absorbs it), but Rive native build is now unblocked and AppArmor gone.
#
# Phase 138.PERF — Two new permanent fixes:
#
#   (A) APK size: `flutter run` auto-detects device ABI and restricts only
#   libflutter.so; plugin native libs (libxeno_native, libsentry, etc.) still
#   ship in all 3 ABIs. `--split-per-abi` restricts EVERYTHING to arm64-v8a.
#   Measured: 203 MB (vs 325 MB all-ABI / 265 MB flutter-run-default).
#   37 % smaller → ~37 % less dexopt time on every install.
#
#   (B) MIUI install gate: every `adb install` on HyperOS triggers an "Install"
#   confirmation dialog. If not tapped within ~5-14 min, the install fails with
#   INSTALL_FAILED_USER_RESTRICTED. The MIUI dialog cannot be bypassed from the
#   host — the user must tap the phone at session start.
#   Play Protect APK scanning CAN be disabled (`verifier_verify_adb_installs=0`)
#   and is applied by this script to save 10-60 s on each install.
#   Permanent fix: Developer Options → USB Installation → ON (removes dialog).
#   Tested and rejected: `adb install --no-streaming` pushes at 0.3 MB/s
#   (vs 30 MB/s streaming) — takes 10+ min just for the file transfer.
#
# ─── Usage ────────────────────────────────────────────────────────────────────
#
#   scripts/dev-run.sh                # debug (default) — hot reload
#   scripts/dev-run.sh profile        # profile — AOT, DevTools
#   scripts/dev-run.sh release        # release — pre-commit smoke test
#
# After the initial install, use scripts/dev-attach.sh to reconnect to the
# running app without reinstalling — hot reload cycle is 1-3 s.
#
# Pairs with:
#   scripts/dev-attach.sh                          — reconnect without reinstall
#   reports/android-build-performance-audit.md     — Phase 117 root-cause audit
#   reports/phase-127-build-iteration-forensic.md  — Phase 127/128 forensic

set -euo pipefail

MODE="${1:-debug}"

PKG="com.emredogan.formaifit"
ACTIVITY="${PKG}/.MainActivity"
ADB="${ANDROID_HOME:-$HOME/Android/Sdk}/platform-tools/adb"
if [[ ! -x "$ADB" ]]; then
  ADB=adb
fi

# Verify a device is connected before spending time on a build.
if ! "$ADB" get-state 2>/dev/null | grep -q "^device$"; then
  echo "Error: no ADB device in 'device' state. Connect the Xiaomi and try again." >&2
  echo "  adb devices   — to verify connection" >&2
  exit 1
fi

# Disable Google Play Protect APK scan — saves 10-60 s on installs of fresh APKs.
# Does NOT bypass the MIUI "tap to install" UI dialog, which is a separate
# MIUI security layer. The MIUI dialog appears within ~30 s of starting the
# install; the user must tap "Install" on the phone promptly.
# One-time device fix to remove the dialog permanently:
#   Settings → Additional Settings → Developer Options → USB Installation → ON
_miui_verifier_disable() {
  "$ADB" shell settings put global verifier_verify_adb_installs 0 2>/dev/null || true
  "$ADB" shell settings put global package_verifier_enable 0 2>/dev/null || true
}

_miui_verifier_restore() {
  "$ADB" shell settings put global verifier_verify_adb_installs 1 2>/dev/null || true
  "$ADB" shell settings put global package_verifier_enable 1 2>/dev/null || true
}

_install_and_attach() {
  local apk="$1"
  local size
  size=$(du -sh "$apk" | cut -f1)

  _miui_verifier_disable

  echo ""
  echo "  ┌──────────────────────────────────────────────────────────────┐"
  echo "  │  TAP 'Install' ON YOUR PHONE when the dialog appears!        │"
  echo "  │  The prompt appears within ~30 s. Dexopt then runs ~4-5 min. │"
  echo "  │  Permanent fix: Developer Options → USB Installation → ON    │"
  echo "  └──────────────────────────────────────────────────────────────┘"
  echo ""
  echo "→ Installing ${size} APK (streaming)..."
  if "$ADB" install -t -r "$apk"; then
    _miui_verifier_restore
  else
    _miui_verifier_restore
    echo "Error: adb install failed." >&2
    echo "  If you missed the MIUI 'Install' prompt, run this script again." >&2
    exit 1
  fi

  echo "→ Launching ${ACTIVITY}..."
  "$ADB" shell am start -n "$ACTIVITY" > /dev/null

  echo "→ Attaching Flutter hot-reload session (~30 s VM discovery)..."
  echo "   Press 'r' to hot-reload (1-3 s), 'R' to hot-restart, 'q' to quit."
  exec flutter attach
}

case "$MODE" in
  debug)
    # --split-per-abi --target-platform android-arm64 produces only the arm64
    # slice (203 MB vs 325 MB universal). Warm incremental builds: ~7 s (cold: ~20 s).
    echo "→ [debug] Building arm64-only APK (split + target-platform, ~7 s warm)..."
    flutter build apk --debug --split-per-abi --target-platform android-arm64
    _install_and_attach "build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk"
    ;;
  profile)
    echo "→ [profile] Building arm64-only profile APK..."
    flutter build apk --profile --split-per-abi --target-platform android-arm64
    _install_and_attach "build/app/outputs/flutter-apk/app-arm64-v8a-profile.apk"
    ;;
  release)
    echo "→ [release] Full release build + install (pre-commit smoke test only)."
    exec flutter run --release
    ;;
  *)
    echo "Usage: $0 [debug|profile|release]" >&2
    echo "  debug   (default)  — arm64-only APK, MIUI bypass, hot reload" >&2
    echo "  profile            — arm64-only APK, MIUI bypass, DevTools" >&2
    echo "  release            — full release build" >&2
    exit 64
    ;;
esac
