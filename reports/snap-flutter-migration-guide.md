# Snap Flutter → Manual SDK Migration Guide

> **Phase 119** · companion to `reports/android-build-performance-audit.md` §2.2.
> **Status:** instructions only. Does NOT execute the migration. The user runs each step manually with the rollback path in scope.

## 0. Why this matters (in one paragraph)

Snap Flutter installs the SDK inside a confined squashfs mount under `/snap/flutter/current/`. Every Gradle classpath resolution, Dart compile, and tooling lookup pays an AppArmor + cgroups + decompression tax per syscall. The cost compounds across the millions of file accesses a Flutter Android build performs. Industry estimates for similar setups: **15-40 % of total build time lost to Snap confinement** for projects of this size and complexity. Migrating to a regular ext4-resident Flutter clone removes that overhead — and as a bonus, fixes the Phase 103 Rive native-build blocker (the GCC 9 stdlib bundled inside the Snap conflicted with Rive's modern C++).

## 1. Current state — confirmed before you migrate

Run these to verify the migration is needed (each line should match ✓):

```bash
which flutter                          # → /snap/bin/flutter           ✓ Snap-bound
readlink -f $(which flutter)           # → /usr/bin/snap                ✓ confirms
flutter --version | head -1            # → Flutter 3.41.8 stable …      ← write this DOWN
ls -la /snap/flutter/current/          # → readable squashfs mount      ✓ Snap install present
du -sh ~/snap/flutter                  # → ~2.3 GB user data            ✓
```

If any of those don't match, the audit's premise is wrong — STOP and re-audit before continuing.

## 2. Pre-migration validation — must pass before step 3

```bash
# 2.1 — git is installed (you'll need it to clone the Flutter repo).
git --version                          # any 2.x is fine

# 2.2 — internet is reachable (clones ~600 MB shallow + materialises ~3 GB
#       on first `flutter doctor`).
curl -sI https://github.com/flutter/flutter | head -1   # 200 / 301 OK

# 2.3 — disk space.  Manual Flutter clone + pub cache + Dart tooling
#       needs ~5 GB headroom.  The current Snap is 2.3 GB; you'll free
#       that AFTER step 6.  During migration both coexist.
df -h ~                                # >5 GB free required

# 2.4 — your shell rc.  We need to add the new path BEFORE the snap path
#       in PATH.  Confirm which file is your shell's startup:
echo $SHELL                            # → /bin/bash or /bin/zsh
ls -la ~/.bashrc ~/.zshrc ~/.profile 2>/dev/null
# If $SHELL is bash → ~/.bashrc is the target.
# If zsh           → ~/.zshrc.

# 2.5 — record current Flutter doctor output as a pre-migration baseline.
flutter doctor -v 2>&1 > /tmp/flutter-doctor-pre-migration.txt
# This file is your reference if something looks different post-migration.

# 2.6 — record your project's current pub-cache + dart_tool state.
du -sh ~/.pub-cache                    # → ~891 MB; preserved by migration
ls -la ~/.dart_tool 2>/dev/null        # may not exist; project's is at
                                       #   ~/Downloads/SixPack-AI/.dart_tool
```

Do NOT proceed if any of 2.1–2.4 fails. 2.5 + 2.6 are baselines to compare to later.

## 3. Install the manual Flutter SDK

```bash
mkdir -p ~/dev
cd ~/dev

# Clone the stable channel.  --depth 1 keeps it small and fast; you can
# unshallow later if you ever need to inspect Flutter framework history.
git clone --depth 1 -b stable https://github.com/flutter/flutter.git

# Verify the clone landed.
ls ~/dev/flutter/bin/flutter           # → executable file
~/dev/flutter/bin/flutter --version | head -1
# This should pull the latest stable, which may be NEWER than 3.41.8.
# That's fine — once we wire it up, run `flutter doctor` and Flutter
# will materialise the toolchain matching that channel.
```

## 4. Wire it into your shell — before removing the snap

This is the only step where mistakes can leave you with no Flutter at all. Do it CAREFULLY.

```bash
# 4.1 — open your shell rc.  For bash users:
nano ~/.bashrc        # or any editor; vi is also fine
# For zsh users: nano ~/.zshrc

# 4.2 — add this ONE line at the END of the file (after any existing
# PATH manipulation):
export PATH="$HOME/dev/flutter/bin:$PATH"

# 4.3 — save and exit.
# 4.4 — apply the change to the CURRENT shell session:
source ~/.bashrc      # or  source ~/.zshrc

# 4.5 — verify the new install is now first in PATH:
which flutter         # → /home/emre/dev/flutter/bin/flutter   ← CRITICAL
                      #   if this still says /snap/bin/flutter,
                      #   the export is wrong or PATH already had snap
                      #   first AND wasn't superseded.

flutter --version     # should print, may be a newer 3.x than 3.41.8
```

If 4.5 still points to snap, your `~/.bashrc` may set PATH AFTER your `export` line later. Check: `tail -30 ~/.bashrc | grep -i path`. If something else mutates PATH after, move the export to be the LAST PATH line in the file.

## 5. First-run materialisation + project test

The git clone only contains scripts; the actual Dart SDK + caches materialise on first invocation.

```bash
# 5.1 — let Flutter rebuild its tooling under the new path.
flutter doctor -v 2>&1 | tee /tmp/flutter-doctor-post-migration.txt

# Compare with /tmp/flutter-doctor-pre-migration.txt — every section
# should be GREEN except possibly:
#   - Android licenses (re-accept with `flutter doctor --android-licenses`)
#   - Chrome / web (irrelevant for Android-only iteration)
#   - Linux desktop toolchain (irrelevant; we ship to Android)

# 5.2 — test build the project.
cd ~/Downloads/SixPack-AI
flutter clean                          # nukes Snap-bound build artefacts
flutter pub get                        # reuses ~/.pub-cache; may pull a
                                       #   couple of plugins; ~10-30 s
flutter run                            # full debug build + deploy

# 5.3 — measure cycle time.  First build will still be slow (cold caches
#       under the new install).  Watch for any RED errors.
```

If `flutter run` succeeds and the app launches on device → **the migration is functionally complete**. The Snap install is now redundant; remove it in step 6.

If `flutter run` fails:
- Check the error message
- Don't panic-rollback yet — most failures are configuration drift (license re-acceptance, missing platform tools), not the migration itself
- See §8 (rollback) only if you need to revert

## 6. Remove the Snap install (only after step 5 succeeds)

```bash
# 6.1 — confirm the new install is the active one (defensive check).
which flutter         # MUST be /home/emre/dev/flutter/bin/flutter

# 6.2 — remove the snap.  --purge also clears the user data dir
#       (~/snap/flutter, ~2.3 GB).
sudo snap remove flutter --purge

# 6.3 — verify the snap is gone.
snap list | grep flutter      # should print nothing
ls /snap/bin/flutter 2>&1     # No such file or directory
ls ~/snap/flutter 2>&1        # No such file or directory

# 6.4 — final sanity check.
which flutter         # /home/emre/dev/flutter/bin/flutter  (UNCHANGED)
flutter --version     # still prints
```

## 7. Post-migration validation

Run the project's normal cycle twice and time it.

```bash
cd ~/Downloads/SixPack-AI

# 7.1 — first cycle (cold caches; expect partial improvement only).
./android/gradlew --stop
flutter clean
time flutter run                       # capture wall-clock time

# 7.2 — second cycle (warm caches; expect the full Snap-removal saving
#       to materialise).
# Stop the current run with `q` in the flutter terminal.
flutter run                            # incremental rebuild + reinstall
                                       # use the on-screen `time` output
                                       # OR add  `time` prefix yourself

# 7.3 — compare against the audit's projected timing.  Targets:
#   • Pre-Phase-117 (snap, old JVM):    ~15-20 min cold cycle
#   • Phase 117 only (snap, new JVM):    ~10-13 min cold cycle  (-30%)
#   • Post-migration (no snap, new JVM): ~6-9 min cold cycle    (additional -25%)
#   • Hot reload (any post-117 state):   <100 ms
```

Validate that nothing else regressed:

```bash
# 7.4 — Android device + tooling.
adb devices                            # device still listed
flutter devices                        # at least one Android device

# 7.5 — Plugin / dependency health.  No NEW warnings vs your pre-
#       migration doctor capture.
diff /tmp/flutter-doctor-pre-migration.txt /tmp/flutter-doctor-post-migration.txt | head -40

# 7.6 — pub-cache reused?
du -sh ~/.pub-cache                    # ~890 MB, untouched
```

If 7.4–7.6 all pass and the cycle in 7.2 is meaningfully faster than the audit baseline, the migration is **fully complete and validated**.

## 8. Rollback procedure

If anything in steps 5-6 fails AND you've removed the snap, the recovery path is:

```bash
# 8.1 — rollback option A: re-install snap (fastest).
sudo snap install flutter --classic
# This re-pulls the snap (~2.3 GB), takes 1-2 minutes.

# 8.2 — remove the manual install if you want to fully revert.
rm -rf ~/dev/flutter

# 8.3 — undo the PATH export.  Edit ~/.bashrc (or ~/.zshrc) and
#       delete the line  export PATH="$HOME/dev/flutter/bin:$PATH"
nano ~/.bashrc

# 8.4 — apply the change to the CURRENT shell.
source ~/.bashrc
which flutter         # → /snap/bin/flutter (back to original)

# 8.5 — re-do `flutter clean` in the project to clear any caches that
#       reference the manual install path.
cd ~/Downloads/SixPack-AI
flutter clean
flutter pub get
flutter doctor -v
```

Total rollback time: ~5-10 minutes. The risk window is small.

## 9. Things to fix in IDE configurations after migration

Some IDEs cache the Flutter SDK path. After migration:

### Android Studio
- Settings → Languages & Frameworks → Flutter → Flutter SDK path
- Old: `/snap/flutter/current/...` or `~/snap/flutter/...`
- New: `/home/emre/dev/flutter`
- Apply, restart Android Studio.

### VS Code (if used)
- `~/.config/Code/User/settings.json` may have `"dart.flutterSdkPath"` set.
- Update to `/home/emre/dev/flutter`.
- Reload window.

### Other places to check
- Project-local `.vscode/settings.json`
- Project-local `.idea/` files
- Any shell scripts in `tool/` or CI configs that hardcode the Snap path

## 10. Realistic performance expectation

The audit projects Snap migration delivers a **~20-40 % cycle-time reduction on top of the Phase 117 Gradle JVM tuning**. On the user's hardware, that translates to:

| Cycle stage | Pre-Phase 117 | Post-117 only | Post-117 + post-migration |
|---|---|---|---|
| Cold build (`flutter clean` + `flutter run`) | 15-20 min | 10-13 min | **6-9 min** |
| Warm incremental rebuild | 5-8 min | 3-5 min | 2-3 min |
| Hot reload | unchanged | unchanged | <100 ms |
| Hot restart | unchanged | unchanged | 1-3 s |

Hot reload + hot restart speeds are bottlenecked by the Dart VM, not the Flutter SDK location, so they don't move with this migration. The savings are concentrated in the cold + warm rebuild paths — exactly the paths that hurt during onboarding tuning iteration.

## 11. What this migration does NOT change

- **Android SDK location** stays at `~/Android/Sdk`. Untouched.
- **ADB binary** stays at `/usr/bin/adb` and `~/Android/Sdk/platform-tools/adb`. Untouched.
- **Pub cache** stays at `~/.pub-cache`. Reused.
- **Project source / git history / pubspec / lock file** all untouched.
- **Connected Android device authorisation** persists in `~/.android/adbkey*`. Untouched.
- **App launcher icons / signing keys / build configs** all untouched.

The migration is purely a swap of *which* `flutter` executable runs the build pipeline. Everything around it stays.

## 12. Recommended timing

- Pick a calm working window (start of day, between major commits)
- Have the project on a clean git working tree (`git status` clean) so any post-migration changes are clearly separable
- Plan ~30-45 minutes total: 10 min for setup + clone, 15 min for first `flutter run` to materialise tooling, 5-15 min for IDE config updates and validation
- Have this guide open on a second monitor / device — you don't want to be searching it inside the terminal you're migrating

---

**End of guide.** Ready to execute when the user has a calm window. The Phase 119 commit is documentation only — no executable changes ship in it.
