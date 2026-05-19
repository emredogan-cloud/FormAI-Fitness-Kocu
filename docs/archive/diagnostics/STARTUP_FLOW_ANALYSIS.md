# Startup Flow Analysis — FormAI / SixPack AI (post-Phase-94 fix)

End-to-end map of what runs between "user taps the launcher icon" and
"user sees the dashboard / auth screen", with every awaitable that
can stall or throw flagged.

This is the post-fix flow. The pre-fix flow was identical from the
OS through `WidgetsFlutterBinding.ensureInitialized` and then
diverged: any throw past that point produced a black screen instead
of a UI.

---

## Phase 0 · OS launcher → Android process attached

```
Tap icon  →  Android launcher dispatches Intent to
             com.emredogan.formaifit/.MainActivity  →
             zygote forks process  →  loads classes via DexClassLoader
             (R8 minified + shrunk in release)  →
             AppComponentFactory.instantiateActivity('MainActivity')  →
             FlutterActivity.onCreate.
```

While this runs, Android shows the **launch theme**:

* `android/app/src/main/res/values/styles.xml` ·
  `LaunchTheme` parent `Theme.Light.NoTitleBar`, windowBackground
  `@drawable/launch_background`.
* `launch_background.xml` · solid white (or
  `?android:colorBackground` in dark mode).

This is the FIRST surface a user sees. A black screen here would
mean either the OS hasn't started Android, or the user is already
in dark mode with no further frame swap.

**Failure modes possible at this stage:**

* DEX loader can't resolve `MainActivity` class (R8 over-stripped).
  Mitigated by `@Keep` + the manifest's literal class reference.
* Manifest merger fail (would prevent install — not the symptom).

**Status post-fix:** unchanged. Not a contributor to the black screen.

---

## Phase 1 · Flutter engine boot (still pre-Dart)

```
FlutterActivity.onCreate
  →  FlutterEngineGroup.createAndRunDefaultEngine
  →  loadDartEntrypoint("main")  →  AOT snapshot mapped from
     assets/flutter_assets/{vm,isolate}_snapshot_data
  →  attach to PlatformView surface
```

The `meta-data` declaration in the manifest:
```xml
<meta-data android:name="io.flutter.embedding.android.NormalTheme"
           android:resource="@style/NormalTheme" />
```

…asks Flutter to swap to `NormalTheme` once the first frame is
ready. This is the famous "Flutter splash → app first frame" hand-off.
**If Dart never paints a frame, the theme never swaps, and the user
stares at the launch background indefinitely** — the literal "black
screen" symptom on dark mode (which uses
`@android:style/Theme.Black.NoTitleBar` from the
`values-night/styles.xml` variant).

This is exactly what happens when `runApp` is never called.

**Failure modes:**

* Snapshot mismatch (debug-mode artefacts uploaded to release track):
  engine throws `Failed to load AOT snapshot`. Visible only in
  `adb logcat -s flutter:V`.
* Flutter engine SO crashes during native init: native crash, would
  show `tombstone` in logcat.

**Status post-fix:** unchanged. Confirmed working — the user reports
"app installs fine," which implies the engine boots.

---

## Phase 2 · `main()` cold start (Dart side)

This is where the black screen *was originally* introduced. The new
flow:

```
[2.1]  await runZonedGuarded(...)
[2.2]    WidgetsFlutterBinding.ensureInitialized()
[2.3]    FlutterError.onError              ← installed
[2.4]    PlatformDispatcher.instance.onError ← installed
[2.5]    ErrorWidget.builder               ← installed (renders BootSplash)
[2.6]    SystemChrome.setPreferredOrientations(portrait*)
[2.7]    try { dotenv.load('.env') } → dotenvLoaded flag
[2.8]    try {
           SentryFlutter.init(options, appRunner: () {
             bootedViaSentry = true
             runApp(_BootGate(dotenvLoaded: dotenvLoaded))
           })
         } catch (sentry init failed)
[2.9]    if (!bootedViaSentry) runApp(_BootGate(dotenvLoaded: dotenvLoaded))
```

**Critical invariant introduced by Phase 94:**

> By the time `main()` returns, `runApp(_BootGate(...))` has been
> called **exactly once**, regardless of whether dotenv loaded or
> Sentry initialised.

**Risk surface remaining at this phase:**

| Step | Awaitable? | Worst case | Mitigation |
|---|---|---|---|
| 2.2 | No | Engine itself broken | N/A — outside our control |
| 2.6 | Yes (platform channel) | Hangs on broken Android orientation service | Acceptable: caught by zone guard, runApp still reached because we don't `await` past it |
| 2.7 | Yes (asset read + parse) | Throws → caught | Flag set to false, surfaced in 4.x |
| 2.8 | Yes (native channel) | Throws → caught and `runApp` falls through to 2.9 | Try/catch + `bootedViaSentry` |
| 2.9 | Sync (`runApp` itself) | None | N/A |

**Note on step 2.6:** `SystemChrome.setPreferredOrientations` is
`await`ed. In the unlikely event that platform channels are dead
(Android in a very weird state, e.g. headless service test
harness), this could hang. Wrapping in `runZonedGuarded` does NOT
unblock the await — `runZonedGuarded` catches throws, not hangs.
This is acceptable because the same kind of total-platform-channel
failure would also have prevented installation; it's not a real
black-screen vector. If we wanted absolute paranoia, we'd add a
2-second timeout here too.

---

## Phase 3 · `_BootGate` mount + `_init()` future

```
_BootGate.build  →  FutureBuilder<SharedPreferences>(future: _init(), …)
                    │
                    ├─ snapshot.connectionState == waiting
                    │  └─ _BootSplash (FormAI wordmark, neon cyan)
                    ├─ snapshot.hasError
                    │  └─ _BootErrorScreen(isConfigError: …)
                    └─ snapshot.hasData
                       └─ ProviderScope(child: FormAIApp())
```

`_init()` body (post-fix):

```
[3.1]  if (!widget.dotenvLoaded) throw _MissingConfigurationError()
[3.2]  if SUPABASE_URL or SUPABASE_ANON_KEY empty
       → throw _MissingConfigurationError()
[3.3]  await SharedPreferences.getInstance()
[3.4]  Supabase.initialize(...)
       .timeout(const Duration(seconds: 8))     ← bounded
[3.5]  Supabase.instance.client.auth.onAuthStateChange.listen(...)
       (anonymous-recovery flag persistence)
[3.6]  if currentSession == null && was_anonymous == true
       → signInAnonymously()  (anon recovery)
[3.7]  await AnalyticsService.instance.init(...)
       .timeout(Duration(seconds: 5), onTimeout: log warning)  ← bounded
[3.8]  unawaited(WidgetSyncService.instance.init())
[3.9]  unawaited(WorkoutLiveActivityService.instance.init())
[3.10] return prefs
```

**Risk surface, with mitigations:**

| Step | Risk | Mitigation |
|---|---|---|
| 3.1, 3.2 | Config error throws synchronously | `FutureBuilder` catches + shows config-error screen |
| 3.3 | SharedPreferences platform-channel hang | None today; could add timeout. Low risk — read on every Android session. |
| 3.4 | Supabase init hang on captive WiFi | **8-second timeout** → TimeoutException → retry screen |
| 3.5 | StreamSubscription throw on listen | Caught by enclosing try/catch |
| 3.6 | signInAnonymously failure | Wrapped in inner try/catch — non-fatal, falls through to /auth |
| 3.7 | PostHog setup hang in release | **5-second timeout** → log + continue (non-fatal) |
| 3.8 | HomeWidget.setAppGroupId hang | `unawaited` — never blocks. Inner try/catch in service. |
| 3.9 | LiveActivities init failure | `unawaited` + iOS-only. Cannot black-screen Android. |

**ProviderScope construction (after `prefs` is ready):**

```
ProviderScope(
  overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  child: FormAIApp(),
)
```

---

## Phase 4 · `FormAIApp` build + GoRouter resolve

```
FormAIApp.build
  → ref.watch(widgetSyncListenerProvider)   ← listener wiring
  → ref.watch(smartReminderListenerProvider) ← listener wiring
  → ref.watch(appRouterProvider)             ← GoRouter creation
  → ref.watch(themeModeProvider)             ← read SharedPreferences
  → MaterialApp.router(...)
```

**Risk surface — this is the new "if anything goes wrong it's a
silent splash" zone post-fix, since `runApp` has already been called
and a Flutter frame is rendering.**

| Concern | Reality |
|---|---|
| `widgetSyncListenerProvider` triggers `workoutSessionProvider.future` | The listener is `ref.listen`-based — it does NOT block the build. `workoutSessionProvider` is awaited lazily by consumers. |
| `smartReminderListenerProvider` chains into `consumedMacrosProvider` → `dailyMenuProvider` → `recipesProvider.future` | Same — it's a listener, not a sync read. The first `recipesProvider.future` await happens off the build thread when the listener fires. |
| `appRouterProvider`'s `redirect()` reads `Supabase.instance.client.auth.currentSession` synchronously at GoRouter creation | Safe — by Phase 3.4, Supabase is initialized. The Phase 88 fix already sets `auth.was_anonymous` correctly. |

The agent investigation initially flagged the listener providers as
"may block render"; closer reading shows they only `ref.listen` and
`fireImmediately: true` schedules a microtask, not a sync read. They
do not block the FormAIApp build.

---

## Phase 5 · GoRouter dispatch → first matched route

```
GoRouter.initialLocation = redirect('/') ?? '/'
                         (computed once at construction)
  →  if isFirstTime → '/onboarding'
  →  elif session == null → '/auth'
  →  else → '/'  (DashboardScreen)
```

**First-paint route:**

* Fresh install (no `sixpack.is_first_time` set): `/onboarding`.
* Returning user signed out: `/auth`.
* Returning user signed in: `/` (dashboard).

The dashboard, auth, and onboarding screens have their own
`AsyncValue.error` fallbacks — they will not throw at build. If a
provider underneath throws, an error tile is shown rather than the
whole tree exploding.

---

## Initialization dependency graph

```
WidgetsFlutterBinding
       │
       v
FlutterError.onError + PlatformDispatcher.onError + ErrorWidget.builder
       │
       v
SystemChrome.setPreferredOrientations
       │
       v
dotenv.load('.env')        →  dotenvLoaded flag
       │
       v
SentryFlutter.init  ────────►  appRunner triggers runApp(_BootGate)
       │
       (try/catch wraps; if it throws or never calls appRunner,
       fallback line below runs)
       │
       v
runApp(_BootGate)  ←──── ALWAYS called by end of main()

       _BootGate._init()  ───────────────────────────────┐
              │                                           │
              v                                           │
        config check (dotenvLoaded + SUPABASE_*)          │
              │                                           │
              ├── throws _MissingConfigurationError ──┐   │
              │                                       │   │
              v                                       v   v
        SharedPreferences.getInstance()          _BootErrorScreen
              │
              v
        Supabase.initialize (timeout 8s)
              │
              v
        anonymous-recovery (best effort)
              │
              v
        AnalyticsService.init (timeout 5s, non-fatal)
              │
              v
        WidgetSyncService.init / LiveActivities.init (unawaited)
              │
              v
        return prefs   →   ProviderScope(child: FormAIApp())
                                 │
                                 v
                         GoRouter resolve  →  first route paint
```

---

## Risky startup points (post-fix)

Ranked by remaining residual risk:

### 1. `Supabase.initialize` 8-second timeout (medium)

If the device's TLS handshake to `xtvqhnjamwvmfcsahzxv.supabase.co`
takes longer than 8 s on first cold start, the user lands on the
config-error screen instead of waiting. This is a deliberate
trade-off — better a clear retry screen than an indefinite splash —
but on slow LTE / 3G this could be a UX regression. Acceptable for
launch; revisit if Sentry shows >X% of cold-starts hitting the
timeout.

### 2. `SharedPreferences.getInstance()` is unbounded (low)

Hasn't been observed to hang in practice. Could be wrapped in a
timeout if needed, but it's a synchronous Android API on the platform
side and extremely fast.

### 3. `auth.signInAnonymously` on cold-start recovery path (low)

Awaited inside `_init`. If Supabase is reachable (Step 3.4 succeeded)
this almost always resolves quickly. If Supabase is healthy but the
anon-sign-in endpoint is rate-limited, we currently propagate the
error — could add a timeout. Acceptable for now.

### 4. `dotenv.load` parse error (low)

Wrapped in try/catch. The `.env` is a stable file — risk only if a
future change accidentally introduces a quote or syntax error.

### 5. `SystemChrome.setPreferredOrientations` (very low)

Awaited; could hang in a deeply-broken Android. Not seen in practice.

---

## What is NOT a startup risk anymore

* **dotenv asset missing** — caught at `_init` step 3.1 → config-error
  screen.
* **Sentry init throws** — caught at `main()` step 2.8, `runApp` falls
  through to 2.9.
* **PostHog setup hangs** — bounded by 5-s timeout, non-fatal.
* **Any uncaught Future error in bootstrap** — captured by
  `runZonedGuarded`.
* **Any sync framework error** — captured by `FlutterError.onError`.
* **Any platform-dispatcher error** — captured by
  `PlatformDispatcher.instance.onError`.
* **Any widget-build crash** — `ErrorWidget.builder` renders the
  FormAI splash instead of a grey opaque box.
