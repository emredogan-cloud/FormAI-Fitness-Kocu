# SixPack AI — Project Audit Report

**Project:** SixPack AI · 30 Günde Karın Kası
**Version in pubspec:** `0.1.0+1`
**Audited at commit:** `324a429`
**Audit date:** 2026-04-16
**Reviewer role:** Senior Software Architect / Senior Flutter Developer / DevOps

> Scope: an end-to-end review of everything in the repo — what works, what's stubbed,
> and what is a production risk. No sugar-coating. Ordered so a lead can pick this up
> cold and know where to start.

---

## 1. Full Project Analysis

### 1.1 Repository layout

```
SixPack-AI:30-Günde-Karın-Kası/
├── .env                         # Real Supabase creds — gitignored, never committed
├── .env.example                 # Template with SUPABASE_* and REVENUECAT_* keys
├── .gitignore                   # .env, build/, .dart_tool/, platform junk, secrets
├── .github/workflows/
│   └── flutter_ci.yml           # GitHub Actions: format + analyze + debug APK build
├── README.md                    # 33 B placeholder (no content)
├── analysis_options.yaml        # flutter_lints preset + single/double quote rule
├── pubspec.yaml                 # 11 runtime + 2 dev dependencies
├── pubspec.lock                 # gitignored (regenerates per environment)
├── assets/
│   └── videos/
│       └── README.md            # Placeholder; real .mp4 files are NOT shipped yet
├── supabase/migrations/
│   └── 001_initial_schema.sql   # user_progress table + RLS policies
├── android/  ios/  macos/  linux/  windows/  web/
│                                # Stock `flutter create` scaffolding + camera perms
├── test/widget_test.dart        # Trivial placeholder (2+2=4 smoke test)
└── lib/
    ├── main.dart                # Boot: dotenv → Supabase → SharedPreferences → router
    ├── core/
    │   ├── routing/app_router.dart
    │   ├── services/app_preferences.dart
    │   └── utils/
    │       ├── angle_calculator.dart
    │       └── audio_feedback.dart          # flutter_tts wrapper
    └── features/
        ├── auth/
        │   ├── presentation/auth_screen.dart
        │   └── providers/auth_provider.dart
        ├── home/
        │   └── presentation/dashboard_screen.dart
        ├── monetization/
        │   └── presentation/paywall_screen.dart
        ├── onboarding/
        │   └── presentation/onboarding_screen.dart
        └── workout/
            ├── data/workout_repository.dart   # SharedPrefs + Supabase
            ├── models/{exercise_model,workout_day_model}.dart
            ├── providers/workout_provider.dart
            ├── services/{pose_detector_service,crunch_analyzer}.dart
            └── presentation/
                ├── pose_painter.dart
                ├── workout_camera_screen.dart
                └── widgets/exercise_guide_player.dart
```

**Totals:** 19 Dart files · 3,405 LOC (lib/) · ~244 KB of application source.

### 1.2 Technology stack

| Layer             | Choice                          | Status                                    |
|-------------------|---------------------------------|-------------------------------------------|
| Language / SDK    | Dart 3.11 · Flutter 3.41 stable | Pinned via `environment` in `pubspec.yaml` |
| State management  | Riverpod 3.x (hand-written)     | No code generation (`riverpod_annotation`) |
| Routing           | `go_router` 17.x                | Declarative, Riverpod-owned                |
| Backend (auth+db) | Supabase (PostgreSQL + GoTrue)  | Live project, creds in `.env`              |
| On-device AI      | Google ML Kit Pose Detection    | BlazePose model under the hood             |
| Camera            | `camera` 0.12.x                 | NV21 (Android) / BGRA8888 (iOS)            |
| TTS               | `flutter_tts` 4.x               | Turkish (`tr-TR`) default                  |
| Storage (local)   | `shared_preferences` 2.x        | Completed-day set + first-run flag         |
| IAP / subs        | `purchases_flutter` 8.x         | Installed but **not initialized**          |
| Video             | `video_player` 2.x              | Wired to asset paths; no real clips        |
| Config            | `flutter_dotenv` 6.x            | `.env` bundled as Flutter asset            |
| Permissions       | `permission_handler` 12.x       | Camera only                                 |

### 1.3 Dependency posture

`flutter pub outdated` at audit time reports **9 packages** with newer versions that
are incompatible with current constraints (`analyzer`, `meta`, `test`, `vector_math`,
etc.). These are transitive; none are blockers. Worth a scheduled bump in the next
dependency-hygiene sweep.

---

## 2. Architecture Documentation

### 2.1 High-level pattern

Feature-first layered architecture. Each feature is a self-contained module with its
own `presentation/ · providers/ · services/ · data/ · models/` sub-tree (when needed).
The `core/` package hosts cross-cutting concerns (routing, prefs, math utils, TTS).

```
┌──────────────────────────── presentation ─────────────────────────────┐
│ DashboardScreen ▸ OnboardingScreen ▸ AuthScreen ▸ WorkoutCameraScreen │
│                              PaywallScreen                            │
└─────────────────────────┬──────────────────────────────────────────────┘
                          │ ref.watch / ref.read
┌─────────────────────────▼──────────────────────────────────────────────┐
│                          providers (Riverpod)                          │
│  workoutSessionProvider · authStateProvider · currentUserProvider      │
│  appPreferencesProvider · appRouterProvider · authRefreshListenable    │
└─────────────────────────┬──────────────────────────────────────────────┘
                          │
┌───────────────────┬─────▼──────────────────┬─────────────────────────┐
│   services        │       data             │     external            │
│ PoseDetector,     │ WorkoutRepository      │ Supabase client         │
│ CrunchAnalyzer,   │ AppPreferences         │ SharedPreferences       │
│ AudioFeedback     │                        │ ML Kit / Camera plugin  │
└───────────────────┴────────────────────────┴─────────────────────────┘
```

### 2.2 Layer responsibilities

- **models/** — plain immutable Dart classes with `==`, `hashCode`, and `copyWith`.
  No `freezed` / codegen. Explicit and small.
- **data/** — `WorkoutRepository` is the only data-access class. It wraps
  `SharedPreferences` for local state and `SupabaseClient` for cloud sync. Failures to
  reach Supabase fall back to local state silently (intentional for offline
  tolerance).
- **services/** — side-effecting but stateless-ish helpers:
  `PoseDetectorService` (owns an ML Kit `PoseDetector`), `CrunchAnalyzer` (rep state
  machine), `AudioFeedback` (TTS wrapper with per-phrase cooldown).
- **providers/** — Riverpod providers expose state and orchestrate services.
- **presentation/** — `ConsumerWidget` / `ConsumerStatefulWidget` screens; no
  business logic lives here beyond UI composition.

### 2.3 State management (Riverpod 3)

Hand-written `AsyncNotifier` / `Provider` / `StreamProvider`. No code-gen is
configured. All providers are declared at top level and reachable via imports.

| Provider                        | Kind                         | Owns                                                     |
|---------------------------------|------------------------------|----------------------------------------------------------|
| `sharedPreferencesProvider`     | `Provider<SharedPreferences>` | Override injected in `main()` before `runApp()`          |
| `appPreferencesProvider`        | `Provider<AppPreferences>`   | First-run flag + goal                                    |
| `workoutSessionProvider`        | `AsyncNotifierProvider`      | 30-day program, active day/exercise, current reps        |
| `authStateProvider`             | `StreamProvider<AuthState>`  | `onAuthStateChange` stream                               |
| `currentUserProvider`           | `Provider<User?>`            | Derived from auth stream                                  |
| `authRefreshListenableProvider` | `Provider<Listenable>`       | Feeds `GoRouter.refreshListenable`                       |
| `appRouterProvider`             | `Provider<GoRouter>`         | Declarative routes + redirect                            |

**Why no codegen?** Deliberate — the project is small enough that hand-written
`extends AsyncNotifier<T>` is more transparent and avoids a `build_runner` step in CI.

### 2.4 Routing (`go_router`)

```
  /               DashboardScreen
  /onboarding     OnboardingScreen          (first-run only)
  /auth           AuthScreen                (unauthenticated only)
  /workout        WorkoutCameraScreen       (camera-heavy)
  /paywall        PaywallScreen             (modal-ish)
```

A single shared `redirect(path)` closure is called from both `initialLocation`
(at router construction) and the live `redirect` callback. Order:

1. `prefs.isFirstTime` → force `/onboarding`.
2. `currentUser == null` → force `/auth`.
3. Authenticated + onboarded → keep user off `/auth` and `/onboarding`.
4. Otherwise pass-through.

`authRefreshListenableProvider` emits a `ChangeNotifier.notifyListeners()` on every
Supabase auth event so the router re-runs `redirect` without being torn down and
rebuilt. Clean, but relies on the Listenable's subscription surviving for the app
lifetime — see §7 for RevenueCat gap.

### 2.5 Dependency flow (read top-down)

```
main.dart
 └─ dotenv.load → Supabase.initialize → SharedPreferences.getInstance
     └─ ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: SixPackApp)

SixPackApp (ConsumerWidget)
 └─ ref.watch(appRouterProvider)
     └─ MaterialApp.router
          └─ renders one of: Dashboard / Onboarding / Auth / Workout / Paywall
```

No circular imports; no God-objects; no service locators other than Riverpod.

---

## 3. Feature Inventory

### 3.1 Onboarding (first-run "AI body scan" illusion)

**What it does.** On cold launch, if `sixpack.is_first_time` is unset/true, the
router forces `/onboarding`. Three-step flow:

1. **Hedefini Seç** — three cards (Sıkılaşmak / Hacim Kazanmak / Sadece Six-Pack).
   Selection is required before DEVAM enables.
2. **AI Vücut Taraması** — decorative panel with corner cross-hairs, a muted
   `Icons.accessibility_new` silhouette, and an animated scan line moving
   top↔bottom via `AnimationController(duration: 2 s)..repeat(reverse: true)`.
3. **Processing** — `CircularProgressIndicator` + cross-fading phrases
   ("Vücut oranları analiz ediliyor…" → "Program Hazır!"). `Timer.periodic(1.1 s)`
   drives the sequence.

At the end: `appPreferences.completeOnboarding(goal: _goalId)` flips the flag and
persists the goal, then `context.go('/')` → redirect kicks in.

**Files.** `lib/features/onboarding/presentation/onboarding_screen.dart` (single file,
~650 LOC including helper widgets).

**Honest note.** The "AI" in this step is 100 % theatre — no camera, no scan, no
model inference. It exists to create perceived value before the paywall opportunity.

### 3.2 Auth (email/password + anonymous)

**What it does.** Email + password form with real-time validation, mode toggle
(sign-in / sign-up), and a "Misafir Olarak Devam Et" outlined button.

- `signInWithPassword(email, password)`
- `signUp(email, password)` — if Supabase returns no session, surfaces an
  email-confirmation SnackBar.
- `signInAnonymously()`

All three catch `AuthException` separately from generic errors and surface both as
red floating SnackBars. Busy state disables inputs and swaps the CTA for a spinner.

**Files.** `lib/features/auth/presentation/auth_screen.dart`,
`lib/features/auth/providers/auth_provider.dart`.

**Honest notes.**
- No "forgot password" flow.
- No OAuth (Apple / Google) even though those convert much better on fitness apps.
- Anonymous users are real Supabase users, but there's no UI to later convert
  an anonymous identity to a permanent account (Supabase supports linking).
- No logout UI — Supabase session persists indefinitely until the app is
  reinstalled.

### 3.3 Dashboard (home / 30-day grid)

**What it does.** Reads `workoutSessionProvider`, renders:
- App title with neon glow.
- `_ProButton` (gold-glowing "👑 PRO" pill) → `context.push('/paywall')`.
- `_StreakBadge` (🔥 + number + "gün") — naive implementation (§12).
- Progress bar (`completed / 30`).
- "BUGÜNÜN ANTRENMANI" hero card listing the next incomplete day and exercises
  with a BAŞLA CTA.
- A 5×6 `SliverGrid` of 30 day tiles. Each tile:
  - Completed → green border + tint + check_circle.
  - Next/available → 2 px neon-cyan border + glow.
  - Locked (day > 3, not in mocked program) → white12 border + lock_outline,
    tap disabled.

**Tap.** Calls `workoutSessionProvider.notifier.startDay(n)` then
`context.push('/workout')`.

**Files.** `lib/features/home/presentation/dashboard_screen.dart` (~520 LOC, all
sub-widgets private to the file).

### 3.4 Workout camera (live pose + skeleton + rep counter)

**What it does.** The screen ties together five subsystems:

1. `Permission.camera.request()`.
2. `availableCameras()` → prefer front; fall back to first camera.
3. `CameraController(ResolutionPreset.medium, enableAudio: false,
   imageFormatGroup: Android ? nv21 : bgra8888)`.
4. `startImageStream(_onCameraImage)` — throttled by an `_isBusy` flag.
5. Per frame: `CameraImage → InputImage → PoseDetector.processImage`.
6. Pose → `CrunchAnalyzer.analyze()`:
   - `CrunchResult` with reps, state (`down/up/unknown`), torso angle, neck
     angle, form warning, and `repJustCompleted`.
7. On `repJustCompleted`: pushes to provider + compares with `targetReps`; calls
   `completeCurrentExercise()` + `_analyzer.reset()` when hit.
8. Form warnings fire TTS ("Boynunu düz tut!") with per-phrase 3-second cooldown.
9. UI:
   - `CameraPreview` underlay.
   - `PosePainter` overlay.
   - Circular neon back button (top-left) + Day / Exercise / State pills.
   - `ExerciseGuidePlayer` (top-right, 130×95) with "ÖRNEK" label.
   - 96-pt neon rep counter ("`X / Y`") bottom-center.
   - Red glowing form-warning banner (conditional).
   - "Gün N Tamam!" full-screen overlay on session completion with a neon
     "Tamam" button that acknowledges + exits.

**Lifecycle.** `didChangeAppLifecycleState` disposes the controller on inactive
and re-starts on resumed. `dispose()` tears down camera, detector, and audio.

**Files.** `workout_camera_screen.dart` (~580 LOC),
`pose_painter.dart`, `pose_detector_service.dart`, `crunch_analyzer.dart`,
`widgets/exercise_guide_player.dart`.

### 3.5 Workout engine (program + persistence)

**What it does.** `WorkoutSessionNotifier extends AsyncNotifier<WorkoutSessionState>`:

- `build()` → loads `SharedPreferences` + optionally Supabase, auto-picks the
  first incomplete day as active.
- `setCurrentReps(n)` — mirrors the analyzer into provider state.
- `startDay(n)` — resets indices and starts a specific day.
- `completeCurrentExercise()` — advances through the day's exercise list; on the
  final exercise, marks the day complete (upsert to Supabase + prefs) and flips
  `isSessionComplete`.
- `acknowledgeSessionComplete()` — clears the overlay flag.
- `resetProgress()` — nukes local prefs (but not Supabase rows).

**Files.** `workout_provider.dart` (~145 LOC), `workout_repository.dart` (~130 LOC),
`exercise_model.dart`, `workout_day_model.dart`.

**Honest note.** Only days 1–3 are seeded; days 4–30 display in the dashboard grid
as locked tiles. See §12.

### 3.6 Exercise guide video player

**What it does.** `ExerciseGuidePlayer` takes `assetPath` + `exerciseName`:
- `VideoPlayerController.asset(path)` → `initialize` → `setLooping(true)` →
  `setVolume(0)` → `play()`.
- `didUpdateWidget` disposes + re-initializes on path change (swaps when the
  active exercise changes).
- `try/catch` around `initialize()` switches to a neon-bordered fallback tile
  with `Icons.fitness_center` and "Video Yükleniyor…" text.

**Files.** `lib/features/workout/presentation/widgets/exercise_guide_player.dart`.

**Honest note.** There are **no real `.mp4` files** shipped yet. Every exercise
currently renders the fallback tile. The `assets/videos/` folder has only a
`README.md`.

### 3.7 Paywall

**What it does.** Premium dark UI, gold crown hero, three neon feature rows,
two selectable plans (Aylık 79 TL / Yıllık 349 TL with a gold %60 İNDİRİM badge),
primary gold CTA. Purchase is **simulated**: a SnackBar ("Satın alma simüle
edildi") and a 900 ms auto-dismiss.

**Files.** `lib/features/monetization/presentation/paywall_screen.dart`.

**Honest note.** `purchases_flutter` is declared but never imported or initialized.
This is genuinely a marketing mock right now, not a monetization system.

---

## 4. AI System Analysis

### 4.1 Which "MediaPipe"?

The original brief referred to "MediaPipe"; the actual integration uses
**Google ML Kit Pose Detection** (`google_mlkit_pose_detection` ^0.14.1). Under the
hood both Android and iOS use the BlazePose model (originally from MediaPipe),
so this is consistent with the brief's intent.

### 4.2 Pipeline

```
camera plugin                                 ML Kit                  CrunchAnalyzer
─────────────                                 ──────                  ──────────────
CameraImage ──► _toInputImage() ──► InputImage ──► processImage ──► Pose ──► analyze
   (nv21/bgra)    (+rotation +                          │            │
                   format guards)                  Future<List<Pose>>│
                                                                     ▼
                                                             setState(reps, ...)
```

### 4.3 Rotation handling

`_toInputImage` computes `InputImageRotation` differently per platform:

- **iOS** → `camera.sensorOrientation` directly.
- **Android** → composes device orientation with sensor orientation; for the
  front camera it **adds** (`(sensor + device) % 360`), for the back camera it
  **subtracts** (`(sensor - device + 360) % 360`). Mirroring correction in the
  painter (next section) handles the left-right flip.

Format is locked to **NV21** on Android and **BGRA8888** on iOS — any other format
returns `null` and the frame is dropped.

### 4.4 Landmark projection (`PosePainter`)

`PosePainter` accepts the pose, the original image `Size`, rotation, and lens
direction. For each landmark:

```dart
scaleX = canvasSize.width  / imageSize.width
scaleY = canvasSize.height / imageSize.height
x = landmark.x * scaleX
if (cameraLensDirection == CameraLensDirection.front) {
  x = canvasSize.width - x    // mirror the front-camera view
}
y = landmark.y * scaleY
```

Connection list is hand-curated (arms, shoulders, torso, hips, legs, feet). Each
bone is drawn twice — a blurred cyan glow (`MaskFilter.blur`) and a sharp stroke
— then joints are drawn as filled green circles with a white ring.

### 4.5 Angle calculator

```dart
static double between(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
  final radians =
      atan2(c.y - b.y, c.x - b.x) - atan2(a.y - b.y, a.x - b.x);
  var degrees = (radians * 180 / pi).abs();
  if (degrees > 180) degrees = 360 - degrees;
  return degrees;
}
```

`atan2` is preferred over `acos(dot / (|BA|·|BC|))` because it's numerically stable
near 0° and 180° where `acos` loses precision. Return is always in `[0, 180]`.

### 4.6 Rep-counting state machine (crunch)

`CrunchAnalyzer` is deliberately small:

- Picks the higher-likelihood of the left/right shoulder, hip, knee, ear — so
  partial visibility doesn't kill tracking.
- Torso angle = `angle(shoulder, hip, knee)`.
- Thresholds: `down > 140°`, `up < 90°`. Default state is `unknown`.
- Transition `down → up` increments `reps` and sets `repJustCompleted = true`.
- Neck check runs only when `state == up`: `angle(ear, shoulder, hip) < 120°`
  emits the form warning `"Boynunu düz tut!"`.

### 4.7 Performance posture

| Concern             | Mitigation                                                         |
|---------------------|--------------------------------------------------------------------|
| Frame backpressure  | `_isBusy` flag drops frames while ML Kit is processing the last    |
| Resolution          | `ResolutionPreset.medium` — decent skeleton quality, lower CPU     |
| Format              | Single-plane formats (nv21/bgra8888) avoid plane-copy overhead     |
| TTS spam            | `AudioFeedback.speak()` per-phrase 3-s cooldown                    |
| UI repaints         | `PosePainter.shouldRepaint` compares pose/size/rotation/lens       |
| Lifecycle           | Camera disposed on `AppLifecycleState.inactive`, re-init on resume |

**Honest notes.**
- No FPS counter or telemetry — we can't prove frame rate in the field.
- The busy flag silently drops frames; on low-end devices this may feel laggy
  but we have no metrics to confirm.
- `PoseDetectorService` holds a single detector instance for the screen's
  lifetime. Correct per ML Kit docs.

---

## 5. State Management Analysis

### 5.1 Global vs local

| Scope  | Example                                                                 |
|--------|-------------------------------------------------------------------------|
| Global | `workoutSessionProvider`, auth providers, router, prefs                 |
| Local  | Camera controller, `CrunchAnalyzer._reps`, `AudioFeedback._lastPhrase`  |

The analyzer owns the live rep count; the provider mirrors it for rendering
elsewhere and to gate `completeCurrentExercise`. This double-accounting is a
conscious trade-off: the analyzer is a fast local source, the provider is the
persistence/navigation anchor.

### 5.2 Reactivity gotchas

- `workoutSessionProvider` is **not** autoDispose; state survives when the user
  pops `/workout` back to `/`, which is what we want.
- `appRouterProvider` rebuilds on `appPreferencesProvider` changes. Since prefs
  only change via explicit `completeOnboarding`, this happens once per install.
- The auth listenable is deliberately decoupled from `appRouterProvider` (the
  router watches it as a `Listenable` via `refreshListenable`, not through Riverpod),
  so login/logout **refreshes redirect** without **rebuilding the router**.

### 5.3 Data flow for a rep

```
CameraImage
  → _toInputImage                (frame-rate bound, Platform-specific)
  → PoseDetectorService.detectPose   (ML Kit, off main isolate)
  → CrunchAnalyzer.analyze           (cheap trig + state machine)
  → CrunchResult.repJustCompleted ──► setState(local) + notifier.setCurrentReps
                                   └─► compare reps >= target
                                       └─► notifier.completeCurrentExercise
                                           └─► WorkoutRepository.markDayCompleted
                                               ├─► SharedPreferences.setStringList
                                               └─► Supabase.from('user_progress').upsert
```

---

## 6. Data Storage

### 6.1 Keys in `SharedPreferences`

| Key                         | Type          | Written by                         | Purpose                                |
|-----------------------------|---------------|------------------------------------|----------------------------------------|
| `sixpack.is_first_time`     | `bool`        | `AppPreferences.completeOnboarding`| First-run gate                         |
| `sixpack.goal`              | `String?`     | `AppPreferences.completeOnboarding`| Selected onboarding goal (tone/bulk/sixpack) |
| `sixpack.completed_days`    | `List<String>`| `WorkoutRepository`                | Union of completed day numbers         |

### 6.2 What is *not* persisted locally

- The user's **streak** (re-derived from `completed_days` each load; naive — see §12).
- **Active session state** (day/exercise indices, current reps). If the user
  kills the app mid-workout, they start the day over. Acceptable for now.
- **Goal display** — persisted but never read anywhere (no profile/settings
  screen consumes it yet).
- **Purchase entitlements** — no subscription state, ever.

---

## 7. Backend Status

### 7.1 Supabase integration

- **Initialization** — `main.dart`: `Supabase.initialize(url, anonKey)` from
  `.env`. Real keys are present in the local `.env` (gitignored).
- **Auth** — GoTrue wired end-to-end: email/password, sign-up (with
  email-confirmation handling), anonymous sign-in. Session persists.
- **Database** — `user_progress` with RLS policies scoped to `auth.uid() = user_id`.
  CRUD is used:
  - `SELECT day_number WHERE user_id = ? AND is_completed = true`
  - `UPSERT` on `(user_id, day_number)` with `completed_at = now()` (UTC).

### 7.2 Schema (ready to apply)

```
supabase/migrations/001_initial_schema.sql
```

- `pgcrypto` extension.
- `user_progress`: uuid PK, uuid FK to `auth.users` with `on delete cascade`,
  `day_number` (1..30 CHECK), `is_completed`, `completed_at`, `created_at`,
  `updated_at`, `UNIQUE(user_id, day_number)`.
- `set_updated_at()` trigger on UPDATE.
- RLS enabled with idempotent drops + three policies (select/insert/update) — no
  DELETE policy on purpose.

### 7.3 What's missing

- **The migration has not been applied automatically.** If the Supabase project
  hasn't had it run manually (SQL editor or `supabase db push`), every write
  from the client silently no-ops (error swallowed).
- **No profile table.** Goal, streak snapshots, subscription tier, and display
  name have nowhere to live on the server.
- **No realtime subscriptions.** Two devices for the same user don't sync live.
- **No edge functions / server-side enforcement.** The 30-day program is still
  a client-side constant; if we ever charge, we need server-enforced entitlements.

---

## 8. CI/CD & DevOps

### 8.1 Git

- Single branch (`main`); no `staging`, no `develop`, no feature branches today.
- No tags.
- Single remote (`origin` on GitHub under `emredogan-cloud/SixPack-AI-30-Gunde-Karin-Kasi`).
- 13 commits, conventional prefixes (`feat:`, `chore:`, `ci:`).

### 8.2 GitHub Actions

`.github/workflows/flutter_ci.yml` runs on pushes and PRs to `main`, `staging`,
`feature/*`:

1. Checkout (`v4`)
2. Setup Java 17 (Temurin)
3. Setup Flutter stable (`subosito/flutter-action@v2`) with cache
4. `flutter pub get`
5. `dart format --set-exit-if-changed .`
6. `touch .env` (so dotenv asset bundling doesn't fail)
7. `flutter analyze`
8. `flutter build apk --debug`

**What's missing.**

- **No tests step.** `flutter test` is never invoked in CI. The only test file is
  the placeholder `2+2=4`, but adding it would at least fail fast on import
  regressions.
- **No iOS build.** The CI is Android-only; iOS regressions could land unseen.
- **No artifact upload.** The built APK goes to the build cache and is discarded.
- **No lint gate on warnings** — info-level issues slip through silently (today
  there are none, but nothing enforces that).
- **No release pipeline.** No signed APK/AAB, no App Store / Play Store deploy,
  no versioning automation.
- **No branch protection rules** declared in code (handled in GitHub UI — unknown).
- **No Dependabot / Renovate.**

---

## 9. Performance Analysis

### 9.1 Hot path: camera + pose + render

Frame cadence on a typical phone at `ResolutionPreset.medium` is ~30 fps. ML Kit
on-device inference for BlazePose is 25–50 ms on mid-range Android, <20 ms on
modern iPhones. With the `_isBusy` guard we effectively process every frame on
fast devices and skip every other frame on slow ones — acceptable.

**Known hotspots.**

- `setState` is called inside `_processImage` on every successful frame → the
  entire `Stack` rebuilds. The children are mostly `const`, but `CustomPaint`
  repaints because the `PosePainter` instance is recreated each build. Mitigated
  by `shouldRepaint` returning true only when pose/size/rotation/lens changes.
- `ExerciseGuidePlayer` holds a `VideoPlayerController`; on slow devices two
  simultaneous GPU consumers (camera preview + video player) may contend for
  texture memory. Fallback tile is cheap, so until real clips ship this is
  theoretical.

### 9.2 Battery / thermals

- Camera + inference + TTS is genuinely expensive; a 10–20 minute session will
  noticeably warm the phone.
- Nothing currently caps session length or throttles on thermal events.
- No wake-lock management — the screen may dim mid-workout (Android) because
  we never call `Wakelock.enable()`. **This is a real UX bug.**

### 9.3 Startup

- `await dotenv.load` + `await Supabase.initialize` + `await SharedPreferences.getInstance`
  all run serially before `runApp`. Empirically this is ~200–400 ms on a cold
  start. No splash screen — the first paint is the router's destination screen,
  which may briefly flash a loading indicator.

---

## 10. Security

### 10.1 Secrets

- `.env` is **gitignored** and has never been committed
  (`git log --all -- .env` returns nothing).
- The Supabase URL and **anon key** are stored in `.env` and bundled as a Flutter
  asset at build time. The anon key is by design public-safe (its power is
  bounded by RLS), but:
  - Anyone who unzips the APK can extract it. Expected. Still, RLS is the only
    thing preventing abuse — if a policy is ever misconfigured, the anon key
    becomes a cross-tenant read key.
- RevenueCat keys in `.env.example` are placeholders today.

### 10.2 Auth

- Email/password flows rely on Supabase's built-in rate limits / password
  rules; no client-side rate limiting.
- Password minimum is **6 characters** (Supabase default minimum, matched in
  client-side validation). Should be 8+ for production.
- No 2FA, no device-trust, no re-auth for sensitive actions.
- Anonymous users are full `auth.users` rows — they can write to
  `user_progress` under their own uid. This is intentional but means abandoned
  anonymous accounts accumulate in `auth.users` forever. No cleanup job exists.

### 10.3 Row-level security

- RLS is enabled on `user_progress` with `auth.uid() = user_id` on SELECT /
  INSERT / UPDATE. No DELETE policy: progress is append-only, intentional.
- **Untested.** No integration test exercises RLS. A misconfigured policy would
  not be caught by CI.

### 10.4 Other

- No certificate pinning for the Supabase endpoint.
- No jailbreak / root detection.
- No app-attestation (Play Integrity / App Attest) — relevant if we ever move
  purchase validation server-side.
- Camera permission is requested at use, not preemptively — good.
- TTS locale is hardcoded `tr-TR`; if unavailable the stream may throw silently
  on first `speak()`. Logged nowhere.

---

## 11. Code Quality

### 11.1 Strengths

- **Clean architecture discipline.** Every feature sits in its own folder with
  clear layers. No Dart file reaches across a feature's boundary.
- **Deterministic providers.** Overrides are used instead of globals for prefs;
  `SupabaseClient` is injected with a default. Testable in principle.
- **Modern Flutter idioms.** No `withOpacity` left in the codebase — all
  migrated to `withValues(alpha:)`. All `MaterialApp.router`. Uses records
  (`(value, icon)`) in onboarding / paywall.
- **No `// TODO` landmines.** No dead code. No `print` statements. `flutter
  analyze` exits clean with zero issues.
- **Small files.** Longest non-trivial file is 650 LOC (onboarding); most are
  <200.

### 11.2 Technical debt

- **Duplicated palette.** `Color(0xFF00F0FF)` and `Color(0xFFFFD166)` are
  declared as `static const _neon` in at least six files. A `core/theme` module
  should own these.
- **Turkish + English string mix.** User-facing Turkish, debug errors ("Camera
  setup failed: $e") in English. No localization via `intl` — shipping beyond
  Turkey needs an l10n pass.
- **No shared button widget.** The neon filled button recipe is inlined in 5+
  places with subtle variations.
- **Pose-to-canvas projection** lives inside `PosePainter` but is also
  effectively duplicated by the camera-preview's built-in rotation handling.
  If either side of the mirror logic changes, both need updating.
- **Tests.** One trivial placeholder test. Zero unit tests for
  `AngleCalculator`, `CrunchAnalyzer`, `WorkoutRepository`. These are the
  highest-leverage things to cover.
- **Error sinks.** Several `catch (_) { }` blocks (pose processing, TTS, Supabase
  upsert) swallow errors silently. Correct for UX resilience, bad for
  observability.

### 11.3 Modularity score

Feature isolation is genuinely good — you could delete `features/monetization`
today and the app would still run. The only shared piece is `core/`. A move to
separate Dart packages (`package:core`, `package:feature_workout`, …) would
require minimal refactoring.

---

## 12. Missing Parts & Risks 🚨

Ordered by severity. A ✅ next to a gap means it has a workaround in place.

### 12.1 Critical (blocks launch)

1. **Only 3 days of program exist** for a product called *30 Günde Karın Kası*.
   Days 4–30 render as locked tiles. This is an immediate credibility killer.
2. **Only the crunch analyzer exists.** `Plank` and `Bacak Kaldırma` are declared
   in the repository but there is no state machine for plank hold-time, no
   counter for leg raises. Start those exercises and the rep counter stays at 0.
3. **No timer for time-based exercises.** `Exercise.targetDurationInSeconds` is
   a field with no consumer.
4. **No real video assets.** Every `ExerciseGuidePlayer` renders the fallback
   tile today. ✅ Graceful fallback is wired.
5. **Paywall is theatre.** `purchases_flutter` is installed and never imported.
   Tapping "BAŞLA" shows a SnackBar. Revenue today = 0 by design.
6. **Supabase migration must be applied manually.** If someone ships before
   running `001_initial_schema.sql`, completion writes silently fail.

### 12.2 High

7. **No wake-lock.** Screen dims during a workout. Real UX bug. (Android mainly.)
8. **No logout UI.** Once logged in you stay logged in unless the app is
   reinstalled.
9. **Streak is wrong.** `_computeStreak` returns `1` when zero days are done
   and starts from day 1, not from today. Should be "consecutive days including
   today" with a calendar check.
10. **No forgot-password flow.**
11. **No tests in CI.** `flutter test` is never run; the one test file is a
    placeholder.
12. **No crash / error telemetry.** A Supabase outage, a TTS exception, or a
    pose-processing crash is invisible to us.
13. **Anonymous user migration not exposed.** A guest who logs in later starts
    over — their progress isn't migrated.

### 12.3 Medium

14. **No localization.** Turkish is hardcoded; TTS locale hardcoded.
15. **No theme layer.** Palette duplicated across files.
16. **iOS not built in CI.**
17. **No signed release pipeline.**
18. **Dashboard doesn't refresh on resume.** If a user's progress changes on
    another device, the dashboard shows stale data until the app restarts.
19. **`test/widget_test.dart` asserts 2+2=4.** At best, a placeholder; at worst,
    a reviewer blocker.
20. **9 transitive deps have newer versions.** Not blockers; schedule a bump.

### 12.4 Low

21. **README.md is 33 bytes.** No onboarding for contributors.
22. **macOS/Linux/Web/Windows platform folders exist** from `flutter create .`
    but are untested and never shipped. Delete or support them.
23. **No rate-limit / backoff** on Supabase queries; a rapid-fire completion
    would hit the defaults.
24. **No haptic feedback** on rep completion or day completion — low-hanging UX fruit.

---

## 13. Next Steps (Priority-Ordered)

The three clusters below are how I would actually sequence the next two sprints.

### Sprint A — Make it a product (1–2 weeks)

1. **Seed the full 30-day program.** Even if it's hand-authored today, the app
   needs 30 meaningful days in `workout_repository.dart`. Move the seed to a
   JSON asset (`assets/program/default_plan.json`) so content can ship without
   an app update later.
2. **Build `PlankAnalyzer` and `LegRaiseAnalyzer`.** Mirror `CrunchAnalyzer`'s
   shape. For plank, compute angle(ankle, hip, shoulder) ± tolerance and
   accumulate seconds-held via a `Ticker`.
3. **Wire the exercise timer.** Promote `CrunchAnalyzer` and friends behind a
   shared `ExerciseAnalyzer` interface with two subclasses: rep-based,
   time-based. Let the camera screen pick by `ExerciseType`.
4. **Ship at least one real video per exercise id** (`crunch_demo.mp4`,
   `plank_demo.mp4`, `leg_raise_demo.mp4`). Target <1 MB each.
5. **Apply the Supabase migration** against every environment (dev / prod).
   Add a tiny startup check that `SELECT 1 FROM user_progress` succeeds and
   logs a big red warning if not.
6. **Add `Wakelock`** while `/workout` is on screen. Removes the dim-mid-set bug.

### Sprint B — Trust & safety (3–5 days)

7. **Unit tests.** At minimum:
   - `AngleCalculator.between` (corner cases: colinear, reflex, 180°, negative).
   - `CrunchAnalyzer` state transitions using crafted `Pose` fixtures.
   - `WorkoutRepository` with an in-memory `SharedPreferences` and a mocked
     `SupabaseClient`.
8. **Add `flutter test` to CI**, plus an iOS analyze step (no need to build).
9. **Add Sentry (or Crashlytics)** for captured exceptions. Replace the silent
   `catch (_) {}` blocks with `Sentry.captureException(e, stackTrace: st)`.
10. **Logout flow + password reset** in `AuthScreen` and a simple profile drawer
    off the dashboard.
11. **Streak fix.** Use a stored "last completed date" + calendar math.

### Sprint C — Monetization & polish (1 week)

12. **Wire RevenueCat.** `Purchases.configure` in `main.dart` under a feature
    flag (`dotenv.env['REVENUECAT_APPLE_KEY']`/Google). Replace the simulated
    purchase in `PaywallScreen` with `Purchases.purchasePackage(...)`. Gate
    `/workout` access to entitled users (except for a preview day).
13. **Central theme + component kit.** Move neon colors, button styles,
    paddings into `core/theme` and refactor usages.
14. **Localization (`intl` + `.arb`).** English parity is worth ~2×
    addressable market.
15. **Anonymous → email migration** via `supabase.auth.updateUser(email:...)`
    so guests can save progress.
16. **Signed release pipeline.** A `release.yml` that builds, signs, and uploads
    to Play Internal Testing on tag pushes.
17. **Haptic feedback** (`HapticFeedback.lightImpact()`) on rep, heavy on day
    complete.

### Out of scope for now (but worth tracking)

- Social: leaderboards, friend challenges — require a new schema + edge
  functions.
- Nutrition: the brand implies aesthetics-first training; pairing a macro
  tracker doubles ARPU but also doubles the app.
- Desktop/web targets: platform folders exist, the pose pipeline doesn't.
  Delete them until there's a reason.

---

## Appendix A — File Inventory (lib/)

| File | LOC | Role |
|------|----:|------|
| `main.dart` | 52 | App boot + Riverpod overrides |
| `core/routing/app_router.dart` | 72 | Routes + redirect |
| `core/services/app_preferences.dart` | 37 | First-run + goal persistence |
| `core/utils/angle_calculator.dart` | 18 | atan2 angle helper |
| `core/utils/audio_feedback.dart` | 47 | flutter_tts wrapper w/ cooldown |
| `features/auth/presentation/auth_screen.dart` | 310 | Email + anonymous UI |
| `features/auth/providers/auth_provider.dart` | 33 | Auth stream + listenable |
| `features/home/presentation/dashboard_screen.dart` | 522 | 30-day grid + PRO pill |
| `features/monetization/presentation/paywall_screen.dart` | 333 | Simulated paywall |
| `features/onboarding/presentation/onboarding_screen.dart` | 648 | 3-step flow |
| `features/workout/data/workout_repository.dart` | 128 | SharedPrefs + Supabase |
| `features/workout/models/exercise_model.dart` | 42 | Exercise DTO |
| `features/workout/models/workout_day_model.dart` | 44 | Day DTO |
| `features/workout/presentation/pose_painter.dart` | 105 | Skeleton renderer |
| `features/workout/presentation/widgets/exercise_guide_player.dart` | 148 | Video + fallback |
| `features/workout/presentation/workout_camera_screen.dart` | 583 | Camera + ML Kit glue |
| `features/workout/providers/workout_provider.dart` | 144 | Session state machine |
| `features/workout/services/crunch_analyzer.dart` | 115 | Rep counter |
| `features/workout/services/pose_detector_service.dart` | 24 | ML Kit wrapper |
| **Total** | **3,405** | |

---

## Appendix B — Commit History

```
324a429 feat: sync workout progress to supabase and integrate revenuecat paywall UI
d35bde5 feat: implement supabase auth UI, riverpod auth state, and create initial SQL schema
afb7a16 feat: integrate offline video player infrastructure and exercise guide UI
e9e685a feat: add onboarding body scan illusion, first-time launch logic, and fix CI env issue
5155ae5 feat: implement go_router and home dashboard with 30-day grid
c25ce98 chore: fix dart format issues
c354f66 feat: build workout engine with riverpod, shared_preferences, and mock 30-day program
87dac6c feat: add angle math, crunch rep counter, TTS feedback, and fix CI pipeline dart format
5941682 feat: implement real-time camera preview and AI pose skeleton painter
fdca105 feat: add camera, mlkit dependencies and setup platform permissions for AI core
ede1b2d chore: initialize flutter clean architecture, add dependencies and setup supabase
2d8ed66 ci: setup github actions pipeline for flutter lint and build
bb605bb first commit
```

---

*End of report.*
