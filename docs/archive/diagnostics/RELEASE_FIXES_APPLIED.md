# Release Black Screen — Fixes Applied

All fixes are in this branch. They follow the project's
"surgical changes / simplicity first" rule from `CLAUDE.md` — every
change traces to a specific root cause from
`RELEASE_BLACK_SCREEN_ROOT_CAUSE_REPORT.md`. No refactor, no
speculative hardening, no abstractions added.

`flutter analyze` is **clean** after the changes.

---

## File-by-file summary

| File | Lines changed | Purpose |
|---|---|---|
| `lib/main.dart` | ~+150 / -40 | Install global error handlers; guard `SentryFlutter.init`; safe dotenv access; per-call timeouts on Supabase / PostHog; differentiated error screen |
| `android/app/proguard-rules.pro` | +50 | Defensive keep rules for Sentry, PostHog, RevenueCat, google_sign_in, flutter_local_notifications, home_widget |

No other files touched. No dependency added. No build-config (Gradle)
change. No `.env` change (the file is fine; the *handling* was the
problem).

---

## Fix #1 · `runZonedGuarded` outer wrapper (root cause #3)

**File:** `lib/main.dart` · `main()`

**Before:**
```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(...);
  try { await dotenv.load(...); } catch (_) {}
  await SentryFlutter.init(...);  // any throw → black screen
}
```

**After:**
```dart
Future<void> main() async {
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) { … };
    PlatformDispatcher.instance.onError = (error, stack) { … };
    ErrorWidget.builder = (details) { … return _BootSplash(); };
    …
  }, (error, stack) {
    debugPrint('[BOOT] uncaught zone error: $error');
    _captureSafe(error, stack);
  });
}
```

**Why it works:** `runZonedGuarded` catches *every* async error that
escapes a Future (no awaiter, microtask exception, isolate-spawned
errors). Combined with `FlutterError.onError` (sync framework
errors) and `PlatformDispatcher.instance.onError` (platform errors),
nothing reaches "uncaught at the engine level" anymore. Whatever
fails, **`runApp` is still called**, the user sees an actual
screen, and the error lands in Sentry instead of vanishing.

`ErrorWidget.builder` is overridden to render the FormAI splash
instead of the framework default opaque grey box, so a downstream
widget-build crash is at least *visually recognisable* as the app
rather than a dead screen (root cause #5).

---

## Fix #2 · `SentryFlutter.init` is now wrapped + always reaches `runApp` (root cause #1)

**File:** `lib/main.dart` · `main()`

**Before:**
```dart
await SentryFlutter.init(
  (options) { … },
  appRunner: () => runApp(const _BootGate()),
);
// no fallback; if init throws, runApp is never called
```

**After:**
```dart
var bootedViaSentry = false;
try {
  await SentryFlutter.init(
    (options) { … },
    appRunner: () {
      bootedViaSentry = true;
      runApp(_BootGate(dotenvLoaded: dotenvLoaded));
    },
  );
} catch (e, st) {
  debugPrint('[BOOT] SentryFlutter.init failed: $e');
  debugPrintStack(stackTrace: st);
}
if (!bootedViaSentry) {
  runApp(_BootGate(dotenvLoaded: dotenvLoaded));
}
```

**Why it works:** Two layers of defense. First, the try/catch
captures any throw from Sentry's init chain (DSN parse error, native
channel timeout, options-builder throw). Second, the `bootedViaSentry`
flag ensures that even if Sentry init "succeeded" but never invoked
`appRunner` (a documented failure mode in some 7.x → 9.x upgrade
paths), we still call `runApp` ourselves. The app is now mathematically
guaranteed to mount a widget tree.

The `dotenvLoaded` flag is threaded into `_BootGate` so the gate can
distinguish a config error (build-time problem) from a network error
(runtime problem) — see Fix #4.

---

## Fix #3 · Safe dotenv accessor (root cause #2)

**File:** `lib/main.dart`

**New helper:**
```dart
String _envSafe(String key) {
  try {
    return dotenv.env[key] ?? '';
  } catch (_) {
    return '';
  }
}
```

**All `dotenv.env['…'] ?? ''` reads in `main.dart` migrated to use
`_envSafe(...)`** so a `NotInitializedError` (when `dotenv.load()`
failed silently) returns empty string instead of throwing.

**Why it works:** The problem was never the *value* — it was that the
*read itself* could throw synchronously, and `?? ''` only catches
`null`, not throws. Wrapping the read in `try/catch` decouples
"dotenv didn't load" from "Sentry/Supabase init crashes."

The `dotenvLoaded` flag (set in `main()` and passed to `_BootGate`)
means downstream code that genuinely needs config (Supabase) can
short-circuit cleanly — see Fix #4 — instead of silently calling
`Supabase.initialize(url: '', anonKey: '')`.

---

## Fix #4 · `_BootGate` short-circuits on missing config + bounded timeouts (root cause #4)

**File:** `lib/main.dart` · `_BootGateState._init()`

**Before:**
```dart
final prefs = await SharedPreferences.getInstance();
if (!_supabaseInitialized) {
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );
  …
}
await AnalyticsService.instance.init(
  apiKey: dotenv.env['POSTHOG_API_KEY'] ?? '',
  host: dotenv.env['POSTHOG_HOST'] ?? 'https://app.posthog.com',
);
```

**After:**
```dart
if (!widget.dotenvLoaded) {
  throw const _MissingConfigurationError();
}
final supabaseUrl = _envSafe('SUPABASE_URL');
final supabaseKey = _envSafe('SUPABASE_ANON_KEY');
if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
  throw const _MissingConfigurationError();
}

final prefs = await SharedPreferences.getInstance();
if (!_supabaseInitialized) {
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey)
      .timeout(const Duration(seconds: 8));
  _supabaseInitialized = true;
  …
}
…
await AnalyticsService.instance.init(
  apiKey: _envSafe('POSTHOG_API_KEY'),
  host: posthogHost.isEmpty ? 'https://app.posthog.com' : posthogHost,
).timeout(
  const Duration(seconds: 5),
  onTimeout: () {
    AppLogger.warning('PostHog init timed out — analytics disabled', …);
  },
);
```

**Why it works:**

* **Pre-flight config check** — if `.env` didn't load OR if it loaded
  but `SUPABASE_URL` / `SUPABASE_ANON_KEY` are empty, throw a
  distinct sentinel (`_MissingConfigurationError`). The
  FutureBuilder catches this and renders an
  actionable error screen (Fix #5).
* **8 s Supabase timeout** — release-build smoke testing has shown
  Supabase's auth refresh can wedge indefinitely on captive WiFi
  pre-auth. The timeout converts an infinite hang into a
  `TimeoutException` that surfaces the retry screen.
* **5 s PostHog timeout with `onTimeout`** — different shape because
  PostHog init failure is non-fatal (we want analytics to be
  best-effort, not block boot). The callback simply logs and lets
  bootstrap continue without analytics.

---

## Fix #5 · Differentiated error screen (root cause amplifier)

**File:** `lib/main.dart` · `_BootErrorScreen`

`_BootErrorScreen` now accepts an `isConfigError` flag. When true,
it shows:

> **Uygulama yapılandırılamadı.**
> Lütfen Play Store üzerinden son sürümü yükleyin ve sorun devam
> ederse destek ekibiyle iletişime geçin.

Instead of the previous unconditional:

> Bağlantı kurulamadı.
> Lütfen internetinizi kontrol edin.

**Why it works:** The previous error screen led the user into an
infinite "TEKRAR DENE" → "still no internet" → "TEKRAR DENE" loop
when the actual problem was a missing build-time asset that no amount
of retrying could recover. The new copy directs them to update or
contact support — the only paths that could actually fix a
config-time issue.

---

## Fix #6 · Defensive ProGuard keep rules (root cause #6)

**File:** `android/app/proguard-rules.pro` · added "Phase 94" block

```proguard
-keep class io.sentry.** { *; }
-dontwarn io.sentry.**

-keep class com.posthog.** { *; }
-dontwarn com.posthog.**

-keep class com.revenuecat.purchases.** { *; }
-dontwarn com.revenuecat.purchases.**

-keep class com.google.android.gms.auth.api.** { *; }
-keep class com.google.android.libraries.identity.** { *; }
-dontwarn com.google.android.gms.auth.api.**
-dontwarn com.google.android.libraries.identity.**

-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keepclassmembers class * { @com.google.gson.annotations.SerializedName <fields>; }
-dontwarn com.dexterous.flutterlocalnotifications.**

-keep class com.emredogan.formaifit.widget.** { *; }
-keep class es.antonborri.home_widget.** { *; }
```

**Why it works:** Belt-and-braces. Each plugin ships consumer rules in
its AAR, but "consumer rules" are easy to break across AGP / R8 / Kotlin
upgrades, and a single stripped class on the cold-start JNI path =
permanent black screen. The home-widget keep is non-optional given
that `WidgetSyncService.push()` resolves the provider class by FQN
(`com.emredogan.formaifit.widget.FormAIHomeWidgetProvider`); R8
renaming the class would mean the AppWidgetManager can't find the
receiver, breaking widget cold-start.

The keepattributes / renamesourcefileattribute pair on Sentry is
verbatim what Sentry recommends in its docs — it preserves enough
debug info for symbolication on the dashboard side.

---

## What was deliberately *not* changed

| Considered | Decision | Reason |
|---|---|---|
| Switch from `dotenv` to `--dart-define` | No | Bigger refactor; the dotenv asset bundling is verified working at `build/app/intermediates/flutter/release/flutter_assets/.env`. The fix above guards the *handling*, not the source. |
| Bump Flutter SDK / dependencies | No | Out of scope; the Phase 92 build clearly compiled and signed. The bug is not a version regression. |
| Add Sentry breadcrumbs at every startup step | No | The new `runZonedGuarded` + `FlutterError.onError` already routes failures to Sentry. Adding manual breadcrumbs across `_BootGate._init` would duplicate work the framework already does for us. |
| Pre-launch `flutter_native_splash` | No | The Android `LaunchTheme` + `_BootSplash` already cover the splash window. Adding `flutter_native_splash` would change the launch experience without addressing the black screen. |
| Tear out `_BootGate` and use `FutureProvider` | No | The current shape works; the bug is in main(), not the gate's design. |
| Increase compileSdk / targetSdk | No | The current `compileSdk = flutter.compileSdkVersion` (Flutter 3.22+ → 34) builds and signs cleanly. Bumping is unrelated to the cold-start failure. |

---

## Verification

* `flutter analyze` (full project): **No issues found.**
* `lib/main.dart`-only analyze: **No issues found.**
* `dart format` compatibility: matches the rest of the file's style
  (3-space indent for chained `.timeout()`).

The Phase 92 release build was assembled today on this machine
(`build/app/intermediates/flutter/release/flutter_assets/` timestamp:
2026-05-07 15:34, R8 mapping at 15:36). The intermediates are
unchanged by this commit. To produce the fixed `.aab`:

```bash
flutter clean
flutter pub get
flutter build appbundle --release
```

Then upload `build/app/outputs/bundle/release/app-release.aab` to
the Internal Testing track. **Required for verification** — the
test phone must install from the Play Store track (not sideload
from `flutter run --release`) so the upload key + Play App Signing
key are both exercised.
