# Release Hardening Checklist

A pre-flight + ongoing maintenance checklist that, if followed,
prevents another silent black-screen regression.

Drop this in the team's PR template / release runbook. The first
section is one-time setup; the rest runs every release.

---

## Section A · One-time hardening (already done in Phase 94)

- [x] **Global error handlers installed in `main()`**:
      `FlutterError.onError`, `PlatformDispatcher.instance.onError`,
      `runZonedGuarded` outer wrapper, `ErrorWidget.builder`
      override. Verified at `lib/main.dart`.
- [x] **`SentryFlutter.init` wrapped in try/catch**, with
      fallback `runApp` call so `runApp` is reached *unconditionally*
      by the end of `main()`.
- [x] **Safe dotenv accessor (`_envSafe`)** so `NotInitializedError`
      can never propagate up into a startup crash.
- [x] **Bounded timeouts on every cold-start network await:**
      Supabase 8 s, PostHog 5 s.
- [x] **Differentiated error screen** that distinguishes config-time
      failures (un-recoverable by retry) from network failures
      (recoverable by retry).
- [x] **Defensive ProGuard keep rules** for Sentry, PostHog,
      RevenueCat, google_sign_in, flutter_local_notifications,
      home_widget — see `android/app/proguard-rules.pro`.

---

## Section B · Pre-release release-candidate validation

Run before every `flutter build appbundle --release` that goes to
the Play Store.

### B.1 · Local sanity (must be green)

- [ ] `flutter clean && flutter pub get` runs without errors.
- [ ] `flutter analyze` returns "No issues found!"
- [ ] `flutter test` — all unit + widget tests pass.
- [ ] `flutter test integration_test/` (the on-device
      `app_test.dart`) passes.
- [ ] `flutter doctor` — no missing components, no licensing issues.

### B.2 · `.env` integrity

- [ ] `.env` file exists at repo root.
- [ ] All required keys are non-empty:
      `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_WEB_CLIENT_ID`,
      `SENTRY_DSN`, `POSTHOG_API_KEY`, `POSTHOG_HOST`,
      `REVENUECAT_ANDROID_KEY` (and `REVENUECAT_IOS_KEY` for iOS
      submissions).
- [ ] Values match the production project (not a dev / staging
      project — easy to mix up).
- [ ] After `flutter build appbundle --release` succeeds, verify
      `.env` is bundled into the artifact:
      ```bash
      unzip -l build/app/outputs/bundle/release/app-release.aab \
        | grep flutter_assets/.env
      # expect a line showing assets/flutter_assets/.env at 800-1000 bytes
      ```
      A missing or zero-byte line = ship blocker.

### B.3 · Release-mode boot smoke test (must, on a physical device)

The single most important check. **Cannot be skipped.**

- [ ] Build the release APK locally:
      ```bash
      flutter build apk --release
      adb install -r build/app/outputs/flutter-apk/app-release.apk
      adb logcat -c && adb shell am start -n \
        com.emredogan.formaifit/.MainActivity & sleep 8 && adb logcat -d -s flutter:V
      ```
- [ ] App boots to either the FormAI splash → first route, OR
      `_BootErrorScreen` with one of the two known copies. **Never a
      black screen with no text.**
- [ ] Repeat on **airplane mode** — must show the wifi-off
      `_BootErrorScreen`, not a black screen.
- [ ] Repeat with `.env` deliberately renamed locally and rebuilt —
      must show the config-error `_BootErrorScreen` with the
      "Uygulama yapılandırılamadı" copy.

### B.4 · Internal Testing track validation

- [ ] After upload, **install via Play Store** (not sideload). The
      install path through Play exercises Play App Signing, which
      can produce signature-mismatch issues that don't surface in
      sideload.
- [ ] Open immediately on a real device with a real SIM (not
      emulator, not Android Studio device).
- [ ] Open in airplane mode → expect retry screen.
- [ ] Open with airplane mode toggled off → app proceeds to /auth or
      /onboarding.
- [ ] Open from cold (force-stop, then tap icon) → 4 s ceiling on
      reaching the first interactive screen.
- [ ] Test on a low-end device (Redmi Note 10 / Samsung A12) — the
      ML Kit / camera path is fragile here per Phase 77-81 history.

### B.5 · Soak

- [ ] **Minimum 72 hours** on Internal Testing before promoting to
      Closed / Open Testing.
- [ ] Sentry dashboard: zero `BootGate init failed` events.
- [ ] Sentry dashboard: zero events with title containing
      `_MissingConfigurationError`.
- [ ] PostHog dashboard: `paywall_viewed`,
      `onboarding_step_completed` events present and incrementing.

---

## Section C · Per-PR pre-merge gates

Add these to the PR template / CI pipeline.

- [ ] If the PR touches **`lib/main.dart`**, the PR description
      includes a one-line "release-bootstrap impact" note. (This is
      the highest-risk file in the codebase post-Phase-94.)
- [ ] If the PR adds a **new native plugin** (`pubspec.yaml`
      dependencies block), the proguard-rules.pro is updated with a
      conservative `-keep` rule for the plugin's package
      *unless* the plugin's pub.dev page explicitly states
      "ProGuard rules are bundled."
- [ ] If the PR changes the **Android applicationId / namespace**,
      every `qualifiedAndroidName=` reference is searched and updated:
      ```bash
      grep -rn "com\.emredogan\.formaifit\|com\.formai\.app" lib/ android/
      ```
      The home-widget provider FQN is the most common drift point.
- [ ] If the PR adds a new env var (touches `.env.example`), the
      `_envSafe(...)` accessor is used at the read site (never
      `dotenv.env[k] ?? '…'` directly), AND `_BootGate._init`'s
      pre-flight check is updated if the value is required for cold
      start.

---

## Section D · Quarterly / version-bump audit

Every Flutter SDK bump, AGP bump, Kotlin bump, or major-version
plugin bump (Riverpod 3→4, Sentry 9→10, etc.):

- [ ] Re-run Section B.3 in full on at least 3 device profiles
      (low-end Android, mid-range Android, high-end Android).
- [ ] Diff `pubspec.lock` before/after — for every plugin that
      bumped a major version, re-verify its consumer-rules ProGuard
      file has shipped:
      ```bash
      find ~/.pub-cache/hosted/pub.dev/<plugin>/android/ -name '*.pro' \
        -o -name 'consumer-rules.pro'
      ```
- [ ] Re-build with `flutter build appbundle --release --verbose`
      and grep for `R8: Missing class` warnings in the build
      output. Each one is a candidate for a new `-dontwarn` or
      `-keep` rule.

---

## Section E · Monitoring / alerting recommendations

These are best-practice setups that would have caught the Phase 92
black screen automatically.

### E.1 · Sentry alerts

- [ ] Alert on **any event with title `BootGate init failed`** —
      page on first occurrence per release.
- [ ] Alert on **any `_MissingConfigurationError` event** — these
      indicate a build-time misconfiguration shipped to production
      and require an emergency rebuild.
- [ ] Alert on **events with category `boot` and level `error`** —
      these are the new structured boot failures from
      `AppLogger.error('BootGate init failed', …)`.
- [ ] Set up a release-tracking Sentry release for each Play Store
      version code so per-version error rates are visible.

### E.2 · PostHog funnel alert

- [ ] If `app_opened` events exist for a version code but
      `onboarding_step_completed` (step 0) events are <80% of opens,
      raise a P0 — strong signal of post-launch boot failure.
      (Pre-Phase-94 this would have been the *only* signal of the
      black screen.)

### E.3 · Crashlytics-style "boot started but never reported open"

- [ ] Add a fire-and-forget `analytics.boot_started` event at the
      top of `main()` (before any await), and a `analytics.boot_completed`
      event after `runApp` is called. The ratio of completed/started
      across app installs is the cleanest live signal of broken
      cold-start.

> Implementation note: do NOT add this until B.5 soak is clean and
> the post-Phase-94 build is confirmed stable. We don't want to
> introduce another startup-blocking analytics call while we're
> still validating the existing one.

---

## Section F · CI/CD recommendations

Currently the project doesn't have a release-gate CI pipeline. For
when one is added:

- [ ] **Required job:** `flutter analyze` + `flutter test`. Block
      merge to main if either fails.
- [ ] **Required job:** `flutter build appbundle --release` against
      a CI-only `.env.ci` file (with stub values that aren't real
      credentials). The build must succeed end-to-end. This catches
      ProGuard misconfig and asset-bundling regressions before they
      reach Play.
- [ ] **Required job:** `unzip -l app-release.aab | grep
      'flutter_assets/.env'` — bytes > 0. Catches asset-bundle
      regressions.
- [ ] **Required job:** `apksigner verify --verbose
      app-release.aab`. Catches signing config drift (Phase 89-90
      class of bug).
- [ ] **Optional job:** `flutter drive` of `integration_test/app_test.dart`
      against an emulator. Slow but catches widget-tree boot
      failures.

---

## Section G · Documentation hygiene

- [ ] Keep `MASTER_LAUNCH_ROADMAP.md` Phase notes updated with
      every shipped fix — the existing convention of `**Durum:** ✅
      Tamamlandı (commit: <sha>, tarih: <yyyy-mm-dd>)` is good;
      maintain it.
- [ ] When a phase fixes a release-only bug, **the phase's Durum
      line names the symptom and the verifier**, not just the fix.
      Example: "Phase 94 — release-build black-screen fixed; verified
      by deploying to Internal Testing on 2026-05-09 and confirming
      cold start on Pixel 6 / Redmi Note 10 / Samsung A12 reaches
      `/onboarding` within 4 s."
- [ ] If a future Phase reverts any of Section A's fixes, the
      revert MUST cite which forensic-report root cause it
      revisits. Otherwise we'll re-fix it in another emergency
      release.

---

## Section H · "Things we deliberately did not do"

Documented for future readers so they know not to chase these as
"low-hanging fruit":

1. **We did not switch from `dotenv` + `.env` asset to
   `--dart-define`.** The `.env` flow is working (verified bundled
   in `flutter_assets/`); the issue was only how it was *handled*
   on missing values. Switching to `--dart-define` would also
   break the `MediaUrl._normalised('CDN_BASE_URL')` and
   `revenueCatApiKey()` accessors — bigger refactor than warranted.
2. **We did not bump Flutter / Riverpod / Sentry / RevenueCat
   versions.** The Phase 92 build clearly compiled and signed with
   the current pinned versions. Bumping would introduce new failure
   modes during a release-stability window.
3. **We did not split the `_BootGate` into a `FutureProvider` +
   gate widget.** The current shape works; the pre-fix bug was in
   `main()`, not `_BootGate`'s design.
4. **We did not add an explicit splash plugin
   (`flutter_native_splash`).** The Android `LaunchTheme` +
   `_BootSplash` already cover the splash window. Adding the
   plugin would change launch UX without addressing the black
   screen.
5. **We did not add `assert` calls in startup code as guards.**
   Asserts are stripped in release; they would create the exact
   release-only divergence pattern we're trying to eliminate.

---

## Quick reference · the four numbers to memorize

| Number | What | Defined where |
|---|---|---|
| 8 s | Supabase init timeout | `main.dart` `_BootGate._init` |
| 5 s | PostHog setup timeout | `main.dart` `_BootGate._init` |
| 72 h | Internal Testing soak before Closed | This file, B.5 |
| 80% | onboarding step-0 completion floor | This file, E.2 |

If any of these change in code, update this file in the same commit.
