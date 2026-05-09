# FormAI · Dev Iteration Workflow

> **Purpose:** the canonical workflow for the cinematic onboarding rebuild's high-frequency emotional-tuning phase.
> Iteration speed is product-critical infrastructure now. Use this guide instead of guesses.
> Phase 121 · companion to `reports/android-build-performance-audit.md` (Phase 117).

---

## 1. Daily quick reference (the cheat sheet)

```text
                                                 │ time         │ when
─────────────────────────────────────────────────┼──────────────┼────────────────────────────────
  press `r` in flutter run terminal              │ 5–50 ms       │ ANY copy / colour /
   (hot reload)                                  │              │ widget-tree-stable change
─────────────────────────────────────────────────┼──────────────┼────────────────────────────────
  press `R` in flutter run terminal              │ 1–3 s        │ widget tree / state needs
   (hot restart)                                 │              │ reset (controllers, providers)
─────────────────────────────────────────────────┼──────────────┼────────────────────────────────
  flutter run                                    │ 2–8 min      │ pubspec / android/* / native
   (full debug build + deploy)                   │              │ code change
─────────────────────────────────────────────────┼──────────────┼────────────────────────────────
  flutter run --profile                          │ 4–12 min     │ smoothness validation; AOT
   (profile mode + AOT compile)                  │              │ build approximates release
─────────────────────────────────────────────────┼──────────────┼────────────────────────────────
  flutter clean                                  │ 5 s          │ ONLY if a build artefact is
                                                 │              │ visibly broken — see §5
─────────────────────────────────────────────────┴──────────────┴────────────────────────────────
```

**Most important rule:** every avoided full `flutter run` saves 2–8 minutes. Your default action for a code change should be hot reload.

---

## 2. Session start — once per day

```bash
# 2.1 — kill any stale Gradle daemon left over from yesterday's session.
cd ~/Downloads/SixPack-AI
./android/gradlew --stop

# 2.2 — close Android Studio if you're not actively using it for code
# navigation today. Frees ~1.7 GB RAM and removes Gradle-daemon
# competition during your cycle.

# 2.3 — verify ADB sees your device.
adb devices                # → device should be listed as "device", not
                          #   "unauthorized" or "offline"

# 2.4 — open a terminal in the project root.  This is your iteration
# control surface — keep it visible.
```

After session-start, jump to step 3 (the cycle loop).

---

## 3. The cycle loop

### 3.1 — Cold start (first build of the session)

```bash
flutter run
```

This will be slow (3–10 min depending on hardware + cache state). After the device shows the running app, the terminal becomes interactive — `r` for reload, `R` for restart, `q` to quit.

### 3.2 — Iteration on copy / colour / motion params / layouts (95 % of cinematic work)

Save the file in your editor. Then:

```text
press  `r`   in the flutter run terminal
```

The change is live in 5–50 ms. The Dart VM hot-swaps the new code into the running app *without losing state* — you don't lose the screen you're on, the wizard's progress, the typed name, etc.

**What hot reload CAN do:**
- Change any const string, color, number, function body
- Restructure children inside a widget
- Add / remove animations within an existing controller
- Modify per-mood configs in `coach_mood.dart`
- Tune timing constants in `motion_tokens.dart`
- Edit any text in `lib/features/onboarding/`
- Change theme colors in `app_colors.dart`

**What hot reload CANNOT do (use hot restart instead):**
- Add or remove a top-level field on a stateful widget
- Add or remove a `late final` declaration
- Change `initState()` logic that's already executed
- Change Riverpod provider definitions
- Add a new `@override` method

### 3.3 — When hot reload says "Reloaded with X changes" but the screen looks unchanged

That usually means the change is in code that already executed (e.g., `initState`). Press `R` for hot restart instead — it re-mounts the app from scratch (1–3 s) but skips the full Gradle rebuild.

Hot restart is the right choice for:
- Resetting the wizard to step 0 to feel-test changes from the top
- Verifying state-machine flag changes (e.g., `_userMsgPosted` flow)
- Picking up new `late` field declarations
- Running a fresh entry animation (e.g., the Phase 108 ArrivalPulse)

### 3.4 — When you genuinely need a full rebuild

Trigger a full `flutter run` (after `q`-quitting the previous one) when ANY of:

1. `pubspec.yaml` dependencies changed (new package added or removed)
2. `android/build.gradle` or `android/app/build.gradle` modified
3. `android/gradle.properties` modified (and after `./android/gradlew --stop`)
4. Any file under `android/app/src/main/kotlin/` changed
5. New asset added to `pubspec.yaml`'s `assets:` list
6. Kotlin native plugin code changed
7. Hot reload reports an error you can't trace from your edit
8. The app is in a corrupted state that hot restart can't recover

In every other case, hot reload + hot restart cover you. **Resist the urge to "just run it again clean" — it costs 5+ minutes per occurrence.**

---

## 4. Profile mode for smoothness validation

Debug mode is great for iteration but bad for "does this animation feel premium?" testing. Debug builds carry:
- JIT compilation overhead (slower frames in steady state)
- Full assertions (extra checks per frame)
- DevTools instrumentation
- Larger APK
- No tree shaking

Profile mode (AOT-compiled, assertions stripped, debugging payload removed) is the closest thing to release performance you can interact with:

```bash
flutter run --profile
```

**Use profile mode when validating:**
- Frame pacing on `SceneTransition` cross-fades (Phase 99)
- LivingCoachAvatar mood transitions (the AnimatedSwitcher cross-fade — Phase 105)
- AmbientParticles 60 fps cost across multiple screens
- DynamicReport staggered reveal (Phase 106)
- Paywall cinematic backdrop parallax (Phase 115)
- Anything with the question "is this smooth on a real device?"

**Don't use profile mode** for changing copy / layout / colours — debug + hot reload is faster (profile mode has no hot reload, only hot restart).

**On profile mode + DevTools:** open `https://...devtools-...` URL printed by the run command in your browser. Watch the *Performance* tab while interacting with the app. Look for:
- Yellow / red bars on the per-frame chart (slow frames)
- Identify which widget rebuilds correlate with slow frames
- The "Frame analysis" panel surfaces specific render-pipeline bottlenecks

If a frame budget breach appears in profile mode, that's a real signal. If it only appears in debug mode, it's likely just the debug overhead.

---

## 5. The `flutter clean` nuclear option

`flutter clean` deletes:
- `.dart_tool/` (Dart build cache, kernel snapshots)
- `build/` (Flutter intermediate outputs)
- `android/.gradle/` (per-project Gradle cache)
- `android/app/build/` (Android module outputs)

Everything has to be regenerated on the next `flutter run`. **This is ~10x slower than a normal incremental rebuild.**

**Almost never run `flutter clean`.** The list of cases where it's actually warranted:

| Scenario | Cleaner alternative |
|---|---|
| Your build is failing with a weird error | Read the error first; usually the fix is targeted, not a clean |
| You upgraded Flutter | `flutter doctor -v` first; clean only if the error message says so |
| A native plugin platform-side glue mismatch (rare) | Try hot restart first; `flutter pub get`; clean as last resort |
| Asset shows wrong on device after `pubspec.yaml` change | Try hot restart first |
| Working tree is so corrupted nothing else works | OK, then clean |

**If you find yourself running `flutter clean` more than once a week, something in your workflow is wrong.** Stop, find the actual cause.

---

## 6. Daemon lifecycle management

The Gradle daemon is a JVM that stays running between builds to skip JVM startup costs. Phase 117 tuned its memory args.

```bash
# 6.1 — see what daemons exist for your current Gradle version.
./android/gradlew --status

# 6.2 — stop them all (use after gradle.properties change, or if a
# daemon got into a bad state). The next gradle invocation spawns a
# fresh daemon with current config.
./android/gradlew --stop

# 6.3 — verify a freshly-spawned daemon picked up the right args.
PID=$(pgrep -f "GradleDaemon 8.14" | head -1) && \
  cat /proc/$PID/cmdline | tr '\0' ' ' | \
  grep -oE 'Xmx[0-9]+[GgMm]?|MaxMetaspaceSize=[^ ]+|ReservedCodeCacheSize=[^ ]+'

# Output should match android/gradle.properties' org.gradle.jvmargs.
```

**The daemon does NOT need to be stopped between regular builds** — that defeats the entire purpose. Only stop it after a config change, or if Gradle is misbehaving.

---

## 7. Android Studio policy

Android Studio is excellent for code navigation, refactoring, and Riverpod inspection. It's a memory hog (1.7 GB RSS idle) and an indexer competing with Gradle for I/O.

**Use Android Studio for:**
- Refactoring across files
- Riverpod provider tracing
- "Find usages" / "Find implementations"
- Hover-doc lookups
- Initial project setup

**Don't use Android Studio for:**
- Running the app during cycle-time-sensitive iteration. Use the terminal `flutter run`.
- Sitting open passively while you're cycling. Close it; open it when you need it.

The mental model: Android Studio is a refactoring tool, not a build environment.

---

## 8. ADB / USB throughput optimisation

The connected device transfers the APK over USB. Some hygiene wins here:

```bash
# 8.1 — verify USB negotiated USB 2.0 or 3.0.
adb shell cat /sys/devices/<...>/speed       # rarely needed; usually fine
# A rough gauge: if `time adb push <50MB-file> /sdcard/` takes >5s, you're
# on USB 2.0. ADB transfer speed is the bottleneck for the install step.

# 8.2 — confirm device authorisation is sticky.
adb devices                                  # → "device" not "unauthorized"
ls ~/.android/adbkey*                        # adb keys exist; persist
                                             # device trust across reboots

# 8.3 — restart adb if it gets stuck.
adb kill-server && adb start-server && adb devices

# 8.4 — keep the device screen on during installs.  Some Android
# versions throttle ADB when the screen is off.  Use the device's
# "Stay awake" developer option.
```

Smaller APK = faster install. Phase 120 moved the launcher-icon source out of the asset bundle — saves ~50–200 ms per install. The remaining 64 MB of meal photos is a founder decision (audit §2.5).

---

## 9. Common slowdowns & their actual causes

| Symptom | Likely cause | Fix |
|---|---|---|
| First `flutter run` of the day takes 8+ min | Gradle daemon cold-start + asset bundle build | Normal. Subsequent runs are warm. |
| Every `flutter run` takes 8+ min | Memory pressure → swap thrashing | Phase 117 fix already shipped. Run `./android/gradlew --stop` if you didn't yet. |
| `flutter run` fast but `r` slow (>500 ms) | Dart VM is rebuilding too much | Save smaller diffs; avoid touching `main.dart` casually. |
| Hot reload reports OK but UI doesn't update | Change is in already-executed code | Hot restart (`R`) instead. |
| Hot restart re-mounts but state is unexpectedly preserved | Riverpod provider hasn't been invalidated | The provider holds across restart by design. Quit + `flutter run` to reset. |
| Frame skipping warnings on real device | Could be a layout assertion (Phase 116) or genuine GPU pressure | Run `flutter run --profile` to disambiguate. Debug mode is misleading for fps. |
| `Skipped 100+ frames` warning | Layout-assertion retry storm (Phase 116) | Find the assertion in the device log; fix the constraint. |
| Build hangs on "Running Gradle task assembleDebug" | Daemon stuck or memory exhausted | `./android/gradlew --stop`, retry. |
| `pub get` slow | Cold pub-cache or network | Normal once. Subsequent calls hit `~/.pub-cache`. |
| App mysteriously launches old code | Build cache + APK install collision | Hot restart, then full `flutter run` if needed. |
| Asset shows wrong / missing | Forgot to add to pubspec, or pub-cache stale | `flutter pub get`; if still broken, `flutter clean` (last resort) |

---

## 10. Recommended editor setup (informational)

Optional — these don't affect iteration speed but improve the experience:

- **Format on save** — keeps `dart format` consistent without manual runs
- **Hot reload on save** — VS Code Dart extension supports this
- **Riverpod plugin (IntelliJ)** — provider tracing in-IDE
- **Flutter DevTools as a tab** — open the printed URL in a browser tab for the duration of the session

---

## 11. The big-picture optimisation map

| Layer | What's tuned | Phase |
|---|---|---|
| JVM heap (Gradle) | -Xmx 8G → 4G; parallel; caching | Phase 117 |
| Asset bundle | app_icon.png → tool/ (no longer bundled) | Phase 120 |
| Render layout | LivingCoachAvatar wrapped in SizedBox (no infinite-h crash) | Phase 116 |
| (Pending) Snap Flutter migration | manual install → 20-40 % cycle time | Phase 119 (guide only) |
| (Pending) Meal photos architecture | 64 MB → remote-loaded | Founder decision |

When iteration speed feels off, walk these in order — JVM args first (already shipped), then check workflow (this doc), then consider the pending items.

---

## 12. When to escalate

If after applying:
- Phase 117 commit (`gradle.properties`)
- `./android/gradlew --stop` (force fresh daemon)
- Closing Android Studio during cycles
- Hot reload for code changes (vs full `flutter run`)

…cycle time is still > 8 min for a full rebuild, the next escalation steps are:

1. **Snap migration (Phase 119 guide).** Estimated -20-40 % more.
2. **Profile a real build with `flutter run --verbose`.** Look at the slowest steps. Common offenders: `:app:processDebugResources`, `:app:dexBuilderDebug`, `:app:transformClassesAndResourcesWithR8ForDebug`.
3. **Run `flutter build apk --analyze-size`** (release build with size breakdown). Surface unexpected APK bloat — meal photos + native libraries usually top the list.
4. **Hardware bottleneck check.** `iotop` during a build to see if the SSD is saturated; `htop` to see CPU usage. If neither pegs, it's likely a tool wait (network, ADB).

Each step narrows the bottleneck further. Don't skip ahead — work the list in order.
