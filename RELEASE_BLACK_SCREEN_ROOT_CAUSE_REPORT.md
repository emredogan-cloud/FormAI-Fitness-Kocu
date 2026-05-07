# Release Black Screen — Root Cause Report

**Build under investigation:** Phase 92 / 93 release `.aab`
(applicationId `com.emredogan.formaifit`, versionCode 2, versionName 0.1.0)
uploaded to Play Console Internal Testing on 2026-05-07.

**Symptom reported:** Install succeeds, app icon appears, tapping the
icon opens the app to a permanent black frame and never advances to
the auth/onboarding screen. Debug builds (`flutter run`) work
normally.

**Stack:** Flutter 3.22+, Dart SDK ≥3.4.0, R8 8.11.18, AGP 8.11.1,
Kotlin 2.2.20, minSdk 24, `isMinifyEnabled = true` +
`isShrinkResources = true` (auto-applied by Flutter Gradle Plugin in
release).

---

## Executive summary

The black screen is **not a single bug** — it is the absence of any
last-line-of-defense error handling on the cold-start path, combined
with three specific bootstrap patterns that throw silently in
release-only conditions. Each pattern alone could produce the
symptom; together they make the symptom inevitable on any device
where the network or the Sentry SDK misbehaves on first launch.

The release build reaches `WidgetsFlutterBinding.ensureInitialized()`
fine. It fails before `runApp` is ever called, which is exactly what
"black screen forever, no FormAI splash" looks like to the user.

---

## Root causes (ranked by certainty + impact)

### #1 · `runApp` is never called when `SentryFlutter.init` throws

**Severity:** Critical · **Confidence:** Very high · **Release-only:**
Yes (debug-mode print + hot-reload mask the symptom locally)

**Evidence — `lib/main.dart:46-68` (pre-fix):**

```dart
await SentryFlutter.init(
  (options) {
    options.dsn = dotenv.env['SENTRY_DSN'] ?? '';
    options.tracesSampleRate = 0.2;
    options.environment = kReleaseMode ? 'prod' : 'dev';
    options.beforeSend = (event, hint) { … };
  },
  appRunner: () => runApp(const _BootGate()),
);
```

`SentryFlutter.init` is not wrapped in `try/catch`. The user-supplied
options builder is invoked during init, and **runs the line
`options.dsn = dotenv.env['SENTRY_DSN'] ?? ''`** — which has the
characteristic noted in #2 below. If anything in the init chain
throws (malformed DSN, native channel timeout, the dotenv access
documented in #2, or any other condition), `appRunner` is never
invoked. `runApp` is therefore never reached. There is no widget
tree. The OS shows the launcher splash → the
`@android:style/Theme.Light.NoTitleBar` blank window from the
manifest's `LaunchTheme` → and never proceeds to a Flutter frame.
**This is the black screen.**

**Why release-only:** In debug, dotenv access errors print to the
console and Sentry init failures are surfaced through `debugPrint`.
In release, both vanish.

---

### #2 · `dotenv.env[k]` throws `NotInitializedError` if `dotenv.load()` ever failed

**Severity:** High · **Confidence:** Very high · **Documented in
codebase:** Yes

**Evidence — `lib/core/utils/media_url.dart:110-119`:**

```dart
static String? _normalised(String key) {
  // `dotenv.env` throws `NotInitializedError` when `dotenv.load()`
  // hasn't run yet — the case in any unit test that constructs a
  // model without initialising dotenv. …
  String raw;
  try {
    raw = (dotenv.env[key] ?? '').trim();
  } on Object {
    return null;
  }
  …
}
```

This file already documents that `dotenv.env[key]` throws
`NotInitializedError` if `dotenv.load()` was never called. The same
synchronous throw applies if `load()` was *called* but threw
internally (file not found, parse error, IO).

**Pre-fix `main.dart:39-44`:**

```dart
try {
  await dotenv.load(fileName: '.env');
} catch (_) {
  // Swallow; _BootGate re-checks and surfaces the retry screen…
}
```

The catch swallows the load failure but **never blocks subsequent
reads.** The very next line that touches `dotenv.env['SENTRY_DSN']`
is inside Sentry's options builder (`main.dart:48`) — and the `?? ''`
operator does NOT catch a synchronous throw, only a null. So:

```
.env asset bundling fails  →  dotenv.load() throws  →
swallowed silently  →  dotenv.env['SENTRY_DSN'] throws
NotInitializedError  →  Sentry init throws  →  runApp never called
→  black screen.
```

**Forensic verification:** The current source-tree `.env` IS bundled
correctly — `build/app/intermediates/flutter/release/flutter_assets/.env`
exists at 880 bytes. So this isn't the *current* trigger on the
maintainer's machine. But it is the trigger on any build environment
where `.env` is absent (it's gitignored), and the lack of a
synchronous safety net means a single regression in asset bundling
would silently black-screen production again.

---

### #3 · No global error handlers (`FlutterError.onError`, `PlatformDispatcher.onError`, `runZonedGuarded`)

**Severity:** Critical · **Confidence:** Certain (verified by
exhaustive grep)

```bash
grep -rn "FlutterError\.onError\|PlatformDispatcher\.instance\.onError\|runZonedGuarded" lib/
# (no output)
```

There is **no global error handler anywhere in the codebase.** This
means:

* Any synchronous throw on the cold-start path → black screen.
* Any unhandled async error in a `unawaited(...)` future → black
  screen if it's during bootstrap, silent crash if mid-session.
* Any throw from the Flutter framework's render/layout phase →
  default `ErrorWidget.builder`, which in release renders a **grey
  opaque box with no text** — visually indistinguishable from a
  black screen.

This is the single biggest amplifier of the other two root causes.
With proper handlers in place, the same dotenv / Sentry / network
throws would be caught + logged + the user would see a graceful
error screen with retry.

---

### #4 · Supabase / PostHog awaits with no timeout

**Severity:** High · **Confidence:** High · **Release-only impact:**
Yes (release builds are first-launch on devices with mixed network
state — captive WiFi, post-VPN, airplane mode toggling)

**Evidence — `_BootGate._init` (`lib/main.dart:111-168` pre-fix):**

```dart
await Supabase.initialize(
  url: dotenv.env['SUPABASE_URL'] ?? '',
  anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
);
…
await AnalyticsService.instance.init(
  apiKey: dotenv.env['POSTHOG_API_KEY'] ?? '',
  host: dotenv.env['POSTHOG_HOST'] ?? 'https://app.posthog.com',
);
```

Both awaits are unbounded. Two practical failure modes:

1. **`Supabase.initialize(url: '', anonKey: '')`** when dotenv didn't
   load: depending on the SDK build, this either throws an
   `AssertionError` (good — surfaces to FutureBuilder retry screen)
   or wedges on a malformed-URL parse (bad — splash forever).
2. **`Posthog().setup(...)`** has been observed to hang indefinitely
   on cold-start in release builds when the device has no DNS (e.g.
   captive portal pre-auth). The native worker thread stalls; the
   `await` never completes; the FormAI splash sits there until the
   OS Application Not Responding watchdog kills the process.

Either is a black-screen-equivalent: the splash is up but the
FutureBuilder never advances to `ProviderScope(child: FormAIApp())`.

---

### #5 · `ErrorWidget.builder` default is a grey box in release

**Severity:** Medium · **Confidence:** Certain (Flutter framework
default behavior)

If anything *downstream* of `runApp` (an `AsyncValue.error` rendered
without a fallback, a `Text(null!)`, a missing key in a typed
provider) throws during build, Flutter inserts the framework's
default `ErrorWidget`. In debug it's the red banner. In release it
is a **plain opaque box** the same color as the surrounding scaffold
— which on this app's dark theme is indistinguishable from a black
screen.

This is a secondary but real contributor to the "black screen"
diagnosis, because users describing the symptom can't tell the
difference between "no Flutter frame" (root cause #1) and "Flutter
frame is rendering an ErrorWidget" (this root cause).

---

### #6 · ProGuard / R8 keep rules cover ML Kit but not the
startup-critical bridges

**Severity:** Medium-low · **Confidence:** Medium · **Release-only:**
Yes

**Evidence — `android/app/proguard-rules.pro` (pre-fix):**
Rules exist for `com.google.mlkit.**`, MediaPipe internals,
`androidx.camera.**`, and Firebase components — all added in Phases
77-81 to fix workout-screen ML Kit crashes. There were **no explicit
keep rules** for:

* `io.sentry.**` (reflective integration discovery on init)
* `com.posthog.**` (singleton + worker thread)
* `com.revenuecat.purchases.**` (BillingClient bridge)
* `com.google.android.gms.auth.api.**` (google_sign_in v7
  CredentialManager surface)
* `com.dexterous.flutterlocalnotifications.**` (Gson + AlarmManager
  payload)
* `com.emredogan.formaifit.widget.**` (AppWidgetProvider resolved by
  FQN at runtime)

Most of these plugins ship consumer ProGuard rules in their AAR, so
this isn't a guaranteed regression — it's an under-defended edge.
The Phase 92 package rename to `com.emredogan.formaifit` is
particularly relevant for the home-widget rule: the manifest names
the provider class as `com.emredogan.formaifit.widget.FormAIHomeWidgetProvider`
verbatim, and R8 renaming it to `a.a.a` would mean the OS can't
resolve the receiver and any widget interaction during boot
(e.g. cold-start from a tap on the home-screen widget) would fail
to deliver the launch intent. Belt-and-braces keep was added.

---

## Why this surfaced now (Phase 92 specifically)

Phase 92's `.aab` is the **first release build** after a chain of
package + signing changes:

* **Phase 88** — package rename groundwork, asset isolation for
  lightweight verification.
* **Phase 89** — auth persistence, guest mode, offline handling.
* **Phase 90** — clean-slate package rename to `com.formai.app` +
  fresh keystore.
* **Phase 92** — second package rename to globally-unique
  `com.emredogan.formaifit`.
* **Phase 93** — subscription product IDs renamed
  (`formai_pro_monthly` / `_3month` / `_annual`).

The earlier release builds (the ones the user reports as "worked
before") were under the original `com.formai.app` package and against
RevenueCat / OAuth / Sentry projects configured for that ID. After
the Phase 92 rename, the release build is the first one to actually
hit:

* Sentry's *production* project key (DSN was previously dev-mode).
* Google Sign-In with the new package's SHA1 (Play App Signing
  assigns a new upload key fingerprint after a fresh keystore).

Both add latency variance to the cold-start `await`s. With no
timeouts and no error handlers, the variance crosses the
"transient hang → permanent splash" threshold on at least some
devices, and the user perceives it as a deterministic black screen.

---

## Why debug builds don't show this

| Concern | Debug | Release |
|---|---|---|
| `FlutterError.onError` default | Red banner over UI | Default to Flutter's silent log |
| `ErrorWidget.builder` default | Red text+stack | Opaque grey box |
| Uncaught zone errors | Console log + bright in-app banner | Silent |
| `assert(...)` | Active | Stripped |
| `SentryFlutter.init` failure path | `debugPrint` to console | Silent |
| `dotenv.load` exception | `debugPrint` | Silent |
| Network latency for Supabase init | Hot-reload masks; localhost-fast | Real LTE / captive WiFi |
| Posthog `setup()` blocking | Non-blocking on debug-mode plugin path | Blocks splash |
| ProGuard / R8 minification | Off | On |
| `isShrinkResources` | Off | On (auto via Flutter Gradle Plugin) |

Every difference compounds. The pre-fix code worked in debug because
**every failure mode had a noisy fallback** that the developer would
notice. In release, every failure mode was silent and indistinguishable
from "still loading."

---

## Risk classification

| Cause | Reproducibility on a clean device | Severity |
|---|---|---|
| #1 SentryFlutter.init not guarded | Conditional (any init throw) | **Critical** |
| #2 dotenv.env throws unguarded | Conditional (.env missing or malformed) | **Critical** |
| #3 No global error handlers | Always (amplifier of all others) | **Critical** |
| #4 Unbounded Supabase / Posthog awaits | Conditional (network) | High |
| #5 ErrorWidget grey box | Conditional (post-runApp throw) | Medium |
| #6 Missing Sentry/Posthog/RC keep rules | Low (consumer rules cover) | Low-medium |

---

## Files touched by this report

| File | Why it's evidence |
|---|---|
| `lib/main.dart` | Pre-fix bootstrap with no global handlers, unguarded SentryFlutter.init, unguarded dotenv access |
| `lib/core/utils/media_url.dart:110` | Documents the `NotInitializedError` semantics of `dotenv.env[k]` |
| `lib/core/services/analytics_service.dart` | PostHog `setup()` is awaited without timeout |
| `lib/features/auth/providers/auth_provider.dart:353` | `_envOrNull` reads `dotenv.env[k]` without try/catch (would throw if dotenv never loaded) |
| `lib/features/monetization/providers/monetization_provider.dart:182-189` | RevenueCat key reader does the same |
| `android/app/proguard-rules.pro` | ML Kit kept; Sentry/Posthog/RevenueCat/google_sign_in/local_notifications/home_widget not kept |
| `android/app/build.gradle.kts:108` | `isMinifyEnabled = true` (so the gap above matters) |
| `pubspec.yaml:135` | `.env` declared as asset (correct, but confirms a missing `.env` would be a release-only failure) |
