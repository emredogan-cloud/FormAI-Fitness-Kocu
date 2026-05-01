# FormAI — Full Project Report

> **Audience.** This document is written for an AI reader (Gemini).
> A human developer (the project owner) will relay Gemini's suggestions back
> to a second AI (Claude Code), which will convert them into executable
> prompts. Section **11. Gemini Instructions** and **12. Collaboration
> Protocol** are the critical briefings — read those carefully before
> responding to any request.
>
> **Report date.** Generated 2026-04-19, scanning the `main` branch at commit
> `962ca64`. All numbers, file paths, and dependency versions below are
> read directly off the current working tree.

---

## 1. Project Overview

**Project name.** FormAI (historical internal name: `sixpack_ai`; `pubspec.yaml` still uses that package identifier, but user-facing launcher label and `CFBundleName` were renamed to "FormAI" in Phase 25).

**Tagline / description.** "SixPack AI — 30 Günde Karın Kası. AI-powered fitness coaching." (from `pubspec.yaml`).

**What it is.** A Turkish-language mobile fitness app (Flutter) that uses the front-facing camera + Google ML Kit pose detection to analyze form in real time, count reps / validate posture, and coach the user with Turkish text-to-speech. It ships a 30-day program plus 20 regional workout plans (Core, Chest, Back, Shoulders, Arms, Legs, Cardio). It monetizes via a 3-tier paywall (RevenueCat SDK wired, UX implemented, no live products yet).

**Core purpose.** Replace the "phone propped on a bottle, eyeballing reps, no form feedback" gym experience with an on-device AI coach: BlazePose landmarks → per-exercise angle math → rep counting + posture warnings → Turkish voice coaching.

**Target users.** Turkish-speaking at-home fitness users, ages ~18–50, who want structured programs with form correction. Copy is exclusively in Turkish, designs are feminine- and masculine-inclusive (gender-specific before/after imagery in the paywall).

**Current development stage.**
- **28+ development phases** completed over ~4 days (see `git log --oneline`).
- **29 Dart files**, **12,002 LOC** in `lib/`.
- Feature-complete for the primary user journey: onboarding → prediction → paywall → dashboard → plan detail → AI camera workout → completion. Every screen renders; every BAŞLA routes.
- **17 bespoke pose analyzers** for 17 distinct movement patterns (crunch, plank, leg raise, Russian twist, mountain climber, bicycle crunch, flutter kick, push-up, bench press, chest fly, squat, pull-up, biceps curl, shoulder press, lateral raise, jumping jack, burpee state-machine).
- **41 exercises** with full Turkish metadata (name, description, shortTip, startCommand, category, reps/sets/duration).
- **Supabase** backend connected and authenticated (anonymous + email); `user_progress` table with RLS exists.
- **Not production-ready** — see sections 6, 8, 10. Primary gaps: zero real test coverage, RevenueCat has no live entitlements, iOS artifacts are mostly stock scaffolding, debug APK is the only shipped build target.

---

## 2. Tech Stack (Detected)

### Frontend
| Layer | Choice | Version (pubspec) |
|---|---|---|
| Language | Dart | `>= 3.4.0 < 4.0.0` |
| SDK | Flutter | `>= 3.22.0` |
| State management | Riverpod | `flutter_riverpod: ^3.3.1` — hand-written, no codegen |
| Routing | GoRouter | `go_router: ^17.2.1` |
| Camera | `camera` | `^0.12.0+1` |
| On-device ML | Google ML Kit Pose Detection (BlazePose) | `google_mlkit_pose_detection: ^0.14.1` |
| TTS | `flutter_tts` | `^4.0.2` (Turkish `tr-TR` default, `en-US` fallback) |
| Video playback | `video_player` | `^2.8.6` |
| Permissions | `permission_handler` | `^12.0.1` |
| Env loading | `flutter_dotenv` | `^6.0.0` |

### Backend
- **Supabase** (`supabase_flutter: ^2.5.6`) — PostgreSQL + GoTrue + RLS.
  - Real `SUPABASE_URL` + `SUPABASE_ANON_KEY` live in `.env` (gitignored).
  - One migration: `supabase/migrations/001_initial_schema.sql` — a `user_progress` table keyed by `(user_id, day_number)` with an `updated_at` trigger and row-level security policy restricting each user to their own rows.
- **Anonymous sign-in** is the default auth path after onboarding (`Supabase.instance.client.auth.signInAnonymously()` in `_OnboardingScreenState._finish()`).
- **RevenueCat** (`purchases_flutter: ^8.1.1`) — SDK added to dependencies; no store-side product configuration; paywall UI is a simulated purchase (shows a SnackBar + closes).

### Database
- Single Postgres table `public.user_progress` (Supabase):
  - `id uuid PK`
  - `user_id uuid FK → auth.users ON DELETE CASCADE`
  - `day_number int 1-30`
  - `is_completed bool`
  - `completed_at timestamptz`
  - `created_at`, `updated_at timestamptz` (trigger-maintained)
  - Unique `(user_id, day_number)`, index on `user_id`
  - RLS enforces per-user isolation.
- Local persistence: **`shared_preferences`** for first-run flag (`sixpack.is_first_time`), `sixpack.goal`, `sixpack.user_metrics`, and completed-day set (`sixpack.completed_days`).

### Infrastructure
- No dedicated infra. Supabase is managed SaaS.
- App icon generation via `flutter_launcher_icons: ^0.14.1` (dev dep) writes to every Android mipmap density + the full iOS `AppIcon.appiconset`.

### DevOps / CI-CD
- **GitHub Actions workflow**: `.github/workflows/flutter_ci.yml`.
  - Triggers on push / PR to `main`, `staging`, `feature/*`.
  - Steps: checkout → Java 17 → Flutter stable → `flutter pub get` → `dart format --set-exit-if-changed .` → create dummy `.env` → `flutter analyze` → `flutter build apk --debug`.
  - **No tests run in CI** (there's only one trivial `test/widget_test.dart` placeholder).
  - **No release builds**, no signing, no Play/App Store upload steps.

### AI integrations
1. **Google ML Kit Pose Detection** (on-device, offline, no network). See `lib/features/workout/services/pose_detector_service.dart` (24 LOC — thin wrapper).
2. **Python miner** (`exercise_miner.py`, gitignored): RapidAPI ExerciseDB attempted; due to `gifUrl` being removed from the free tier, pivoted to the open `yuhonas/free-exercise-db` GitHub dataset. 26 exercise still-image JPGs live in `assets/videos/`.
3. **No LLM integration** in runtime code. All Turkish copy is hand-authored constants in `workout_repository.dart` and `audio_feedback.dart`.

---

## 3. Architecture Analysis

### High-level architecture

```
┌────────────────────────────────────────────────────────────────┐
│                         Flutter app                            │
│                                                                │
│  main.dart ──► dotenv ──► Supabase.initialize                  │
│           ──► SharedPreferences ──► ProviderScope              │
│           ──► MaterialApp.router(appRouterProvider)            │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                 GoRouter (app_router.dart)               │  │
│  │  / (dashboard) · /onboarding · /auth · /workout          │  │
│  │  /paywall · /prediction · /plan-detail                   │  │
│  │  Redirect rules: isFirstTime → onboarding;               │  │
│  │                   user == null → auth;                   │  │
│  │                   /onboarding → /prediction (anon auth)  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                │
│  State: Riverpod providers                                     │
│    appPreferencesProvider (sync)                               │
│    authStateProvider (stream from Supabase)                    │
│    authRefreshListenableProvider (wires into GoRouter)         │
│    wizardProvider (onboarding form state)                      │
│    workoutSessionProvider (AsyncNotifier, the workout FSM)     │
│    workoutPlansProvider (static catalogue)                     │
│                                                                │
│  Feature modules (lib/features/…)                              │
│    auth · onboarding · home (dashboard) · workout · monetization│
│                                                                │
│  Services                                                      │
│    PoseDetectorService (ML Kit wrapper)                        │
│    AudioFeedback (TTS + language fallback + smoke test)        │
│    analyzerFor(exercise) → PoseAnalyzer switch                 │
│                                                                │
│  Data                                                          │
│    WorkoutRepository: SharedPreferences + Supabase merge       │
│    AppPreferences (SharedPreferences wrapper)                  │
└──────────────────┬─────────────────────────────────────────────┘
                   │
       ┌───────────┴─────────────┐
       ▼                         ▼
┌──────────────┐         ┌──────────────────┐
│  Supabase    │         │  Google ML Kit   │
│  (auth + DB) │         │  (on-device)     │
└──────────────┘         └──────────────────┘
```

### Key design patterns

1. **Feature-first folder layout** under `lib/features/{feature}/{presentation,providers,data,models,services}`. Shared code lives in `lib/core/`.
2. **Riverpod providers as the single source of truth** — no manual `InheritedWidget`, no bloc. `AsyncNotifierProvider` for mutable session state, `Provider` for static catalogues and Listenables.
3. **Go-router redirect funnel** centralises the onboarding/auth/paywall decision tree (`lib/core/routing/app_router.dart`).
4. **Strategy pattern for pose analysis**: `PoseAnalyzer` abstract in `pose_analyzer.dart`; concrete analyzers (CrunchAnalyzer, SquatAnalyzer, BurpeeAnalyzer, …); `analyzerFor(exercise)` factory routes by `exercise.id`.
5. **Explicit State Machine** for workouts: `WorkoutSessionState` boolean grid (`isResting`, `isPreparing`, `isSessionComplete`) driven by `WorkoutSessionNotifier`. Timers (`_restTimer`, `_prepTimer`) + transition flag (`_restPrecedesExerciseChange`) schedule lifecycle events.
6. **Ad-hoc vs scheduled workouts**: synthetic `WorkoutDay(dayNumber: 0, exercises)` lets the camera screen play any plan's exercise list without polluting the 30-day program completion ledger (see `initializeWorkout` in `workout_provider.dart` and the `isAdHoc` branch in `completeCurrentExercise`).
7. **Adaptive media widget**: `ExerciseGuidePlayer` inspects the file extension of `videoAsset` and dispatches to either `Image.asset` or `VideoPlayerController.asset`, with a neon fallback tile on any error.
8. **Throttling everywhere**: `AudioFeedback.speak()` dedupes identical phrases within 3 s; `CrunchAnalyzer` debounces posture warnings to once per 15 s; `BurpeeAnalyzer` caps its mid-rep cue at once per 8 s.

### Folder structure (actual tree)

```
lib/
├── main.dart                                (40 LOC — app bootstrap)
├── core/
│   ├── routing/
│   │   └── app_router.dart                  (GoRouter + redirect rules)
│   ├── services/
│   │   └── app_preferences.dart             (SharedPreferences wrapper)
│   └── utils/
│       ├── angle_calculator.dart            (shoulder-hip-knee math)
│       └── audio_feedback.dart              (TTS engine + TR/EN fallback)
├── shared/                                  (empty — reserved for future shared widgets)
└── features/
    ├── auth/
    │   ├── presentation/auth_screen.dart
    │   └── providers/auth_provider.dart     (authStateProvider, currentUserProvider, refreshListenable)
    ├── onboarding/
    │   ├── presentation/
    │   │   ├── onboarding_screen.dart       (9-step wizard, 1,594 LOC)
    │   │   └── prediction_screen.dart       (12-week future-self hook, 756 LOC)
    │   └── providers/wizard_provider.dart   (Gender, Physique, GoalPhysique, ActivityLevel enums + state)
    ├── home/
    │   └── presentation/dashboard_screen.dart   (1,676 LOC — 3 tabs)
    ├── monetization/
    │   └── presentation/paywall_screen.dart     (3-tier plan picker + gender hero)
    └── workout/
        ├── data/workout_repository.dart         (1,162 LOC — 41 exercises + 20 plans + Supabase sync)
        ├── models/
        │   ├── exercise_model.dart              (Exercise + ExerciseCategory + ExerciseType)
        │   ├── workout_day_model.dart           (WorkoutDay)
        │   └── workout_plan_model.dart          (WorkoutPlan)
        ├── providers/workout_provider.dart      (376 LOC — WorkoutSessionNotifier)
        ├── services/
        │   ├── pose_analyzer.dart               (abstract base)
        │   ├── pose_detector_service.dart       (ML Kit wrapper)
        │   ├── crunch_analyzer.dart             (crunch state machine + form warning)
        │   ├── core_analyzers.dart              (6 core analyzers)
        │   ├── chest_analyzers.dart             (3 chest analyzers)
        │   ├── back_legs_analyzers.dart         (Squat, PullUp)
        │   ├── shoulders_arms_cardio_analyzers.dart (5 analyzers incl. Burpee FSM)
        │   └── analyzer_factory.dart            (switch on exercise.id)
        └── presentation/
            ├── workout_camera_screen.dart       (1,536 LOC — camera + overlays + control panel)
            ├── plan_detail_screen.dart          (923 LOC — program view + plan view)
            ├── pose_painter.dart                (skeleton overlay on camera)
            └── widgets/exercise_guide_player.dart (adaptive image/video PIP)
```

Top-level non-Dart directories:

```
android/        — Flutter default + custom AndroidManifest (camera + internet + TTS queries)
ios/            — Stock scaffolding + Info.plist with CFBundleDisplayName = "FormAI"
assets/videos/  — 3 legacy MP4 demos + 26 mined JPGs + README.md
photos/         — 27 WebP onboarding/paywall/dashboard images + app_icon.png
docs/           — 7 folders of reference photography (Core, Göğüs, Sırt, Bacak, Kol, Omuz, Kardiyo & Full Body)
supabase/migrations/ — 001_initial_schema.sql (user_progress table + RLS)
.github/workflows/ — flutter_ci.yml
macos/ linux/ web/ windows/  — Stock `flutter create` scaffolding, unused
```

### Data flow (frontend → backend → DB)

1. **App boot** (`main.dart`): load `.env` → `Supabase.initialize(url, anonKey)` → load `SharedPreferences` → inject into `ProviderScope` overrides → mount `FormAIApp`.
2. **Router decision**: `appRouterProvider` reads `appPreferencesProvider.isFirstTime` and `Supabase.instance.client.auth.currentUser` to route first-run users to `/onboarding`, unauthenticated users to `/auth`, etc.
3. **Onboarding completion**: `completeOnboarding(goal: ...)` flips `is_first_time`; `signInAnonymously()` creates a Supabase session; router auto-redirects `/onboarding → /prediction`.
4. **Workout start**: dashboard hero card pushes `/plan-detail` (30-day view) or a plan tile pushes `/plan-detail` with `extra: WorkoutPlan`. `PLANI BAŞLAT` calls `WorkoutSessionNotifier.initializeWorkout(plan.exercises)` then `context.push('/workout')`.
5. **Workout loop** (`workout_camera_screen.dart`):
   - Camera stream → `PoseDetectorService.detectPose(InputImage)` → `Pose` landmarks.
   - Current `PoseAnalyzer` (swapped on `exerciseChanged`) produces a `CrunchResult` per frame: reps, state, formWarning, pacingFeedback, contextualCue.
   - Frame is skipped while `isResting` or `isPreparing`.
   - `formWarning` → `AudioFeedback.speak` (3 s dedupe).
   - On `repJustCompleted`: `setCurrentReps`; if target reached, `completeCurrentExercise` advances the state machine.
6. **Completion persistence**: real program days (`day.dayNumber > 0`) hit `WorkoutRepository.markDayCompleted` which upserts to Supabase `user_progress` AND saves locally; ad-hoc plans (`dayNumber == 0`) persist nothing.
7. **On next app launch**: `_completedDays` merges local (SharedPreferences) + remote (Supabase SELECT where `is_completed = true AND user_id = auth.uid()`), re-syncs local cache.

---

## 4. Current Features

Listed in user-flow order. Every item below is a real, compiled, runnable feature that `dart analyze lib/` passes.

### 4.1 Onboarding wizard (9 steps)
- **Where:** `lib/features/onboarding/presentation/onboarding_screen.dart` (1,594 LOC).
- **Step 1 (Welcome).** Full-bleed `photos/ilkkarşılamaanaekranarkaplanı.webp` background + dark gradient + `ShaderMask` Turkish headline + neon-glow BAŞLA CTA.
- **Step 2 (Coach intro).** `photos/merhababenseninkişiselyapayzekakoçunumyeniarkaplan.webp` background + `_PulsingCoachAvatar` with `photos/kişiselyapayzekakoçfoto.webp` in a pulsing neon ring.
- **Step 3 (Gender).** `_PhotoOptionCard` ×3 (Kadın/Erkek/Diğer) filling the screen with `Expanded`; Kadın/Erkek show local gender photos; Diğer shows a decorative neon gradient panel so all three cards are visually balanced.
- **Step 4 (Age).** `ListWheelScrollView` age picker.
- **Step 5 (Body metrics).** Dual `_WheelColumn` height/weight pickers.
- **Step 6 (Current physique).** 3 full-height photo cards with local artwork.
- **Step 7 (Target physique).** 3 full-height photo cards (Sıkılaşmak / Hacim / Sadece Six-Pack) with local artwork.
- **Step 8 (Activity level).** 3 full-height photo cards (Masa Başı / Hafif / Çok Aktif).
- **Step 9 (Illusion).** Multi-metric animated card ("Hedefin / Senin Hakkında / Form Durumu / Yaşam Tarzı / Plan Kurulumu" with overlapping progress windows over 8.5 s) + live BMI / daily calorie / muscle-% bubbles. On complete → frictionless Supabase anonymous sign-in → router redirects to `/prediction`.

### 4.2 Prediction screen ("Özel Planın Hazır")
- **Where:** `lib/features/onboarding/presentation/prediction_screen.dart` (756 LOC).
- Hero card with gradient shader title + coach illustration + `Hedef / Süre / Zorluk` rows (populated from `wizardProvider`).
- Two stat pills: `25-40 dakika / egzersiz` and `4 egzersiz / hafta` with week-check visualization.
- Pulsing neon-gradient date card showing `today + 84 days` formatted in Turkish month names (e.g., "14 Temmuz 2026").
- Plan checklist (5 items: Egzersiz kılavuzları, Gerçek zamanlı form analizi, Sesli koç motivasyonu, İnteraktif 30 günlük takvim, Kişisel kalori ve ağırlık takibi).
- Pulsing "Planımı Göster" CTA → `/paywall`.

### 4.3 Paywall with gender-aware hero
- **Where:** `lib/features/monetization/presentation/paywall_screen.dart`.
- `ConsumerStatefulWidget` reads `wizardProvider.gender`. Male/Female → side-by-side today/30-day composite from `photos/kişiselleştirilmiş*.webp` with centred glowing arrow + "30 Günlük Değişimin!" ribbon. Other/null → stylised silhouette fallback.
- 3-tier plan picker (`_Plan.monthly / yearly / quarterly`) with yearly highlighted + strikethrough decoy pricing.
- CTA copy: "₺0,00 karşılığında dene" (Phase 18 "sunk-cost" psychology).
- `_simulatePurchase()` currently shows a SnackBar and closes — **RevenueCat is wired as a dependency but no products are configured.**

### 4.4 Dashboard — Antrenman tab
- **Where:** `lib/features/home/presentation/dashboard_screen.dart` (1,676 LOC).
- **Header:** FormAI wordmark + PRO button + `_FlameStreakBadge` (streak count derived from consecutive completed days).
- **Weekly Goal card** (`_WeeklyGoalCard`): Monday-anchored 7-bubble strip with today highlighted neon-purple; coach speech bubble with TR motivational line.
- **Günlük Meydan Okuma hero** (`_ChallengeHeroCard`): purple-blue gradient, `photos/günlükmeydanokumayenifoto.webp`, day number, progress bar, white BAŞLA pill → `/plan-detail` (program mode, no extra).
- **Sınırlarını Zorla** (`_PushLimitsStrip`): 4 horizontal full-bleed photo cards (Belirgin Karın Kasları HIIT, Daha Güçlü Şekil, Demir Altı Paket Gücü, Atletik Core Kontrolü) with a dark bottom-to-top gradient for text legibility. Whole card + pill both push `/plan-detail` with the corresponding `WorkoutRepository.pushLimits*` plan attached.
- **Bölgeler chip row** (`_CategoryChipsRow`): 7 chips (Core / Göğüs / Sırt / Omuz / Kol / Bacak / Kardiyo). Selected chip gets a neon-accent label + underline with glow.
- **Regional plan list** (`_RegionalPlansList`): `shrinkWrap: true` + `NeverScrollableScrollPhysics()` inside the outer `ListView` — filters the 20 plans from `workoutPlansProvider` by selected `ExerciseCategory`. Each `_PlanTile` pushes `/plan-detail` with the plan.

### 4.5 Dashboard — Gelişim tab (placeholder)
- Two stat tiles (streak + completed out of 30) + a glowing "Detaylı Raporlar Yakında" card.

### 4.6 Dashboard — Profil tab
- Avatar header (email or "Misafir Kullanıcı").
- 4 stat tiles (KİLO / SERİ / BOY / TAMAMLANAN).
- Settings tiles: FormAI Premium → `/paywall`; Sesli Koç Testi → `AudioFeedback().testAudio()` smoke test; Bildirimler (yakında toast); Gizlilik (yakında toast); Çıkış Yap → Supabase sign-out.

### 4.7 Plan detail screen (two modes)
- **Where:** `lib/features/workout/presentation/plan_detail_screen.dart` (923 LOC).
- **Program mode** (no `extra`): `SliverAppBar` hero + sticky `{N} gün kaldı` + 30 day tiles. Active day gets a neon-purple `_ActiveDayCard` with "DEVAM ET" pill. Days 4/11/18/25 render as `_StandardDayCard` with `Icons.local_cafe` (rest days). Future days lock until unlocked by completing earlier ones.
- **Plan mode** (`extra: WorkoutPlan`): hero with `plan.image` + `plan.title`; sticky summary `{exercises.length} egzersiz · {durationMinutes} Dk · {level}`; `PLANI BAŞLAT` CTA → `WorkoutSessionNotifier.initializeWorkout(plan.exercises)` → `context.push('/workout')`. Below the CTA: list of `_ExerciseTile` (`set × reps` or `set × sn`). Empty-exercise plans (Kol / coming-soon) render a `_ComingSoonNote`.

### 4.8 Workout camera screen
- **Where:** `lib/features/workout/presentation/workout_camera_screen.dart` (1,536 LOC).
- **Boot:** requests camera permission → picks front-facing camera → starts `ImageStream` with the right format for each platform (NV21 Android / BGRA8888 iOS).
- **State machine view:** `_buildSession` branches to `_RestOverlay`, `_PreparationOverlay`, or the split camera/panel layout depending on `session.isResting` / `session.isPreparing`.
- **Camera section (`_buildCameraSection`):** live `CameraPreview` + `PosePainter` skeleton + top `_ExerciseProgressBar` + back button + `_PipPanel` (tiny exercise demo video/image using `ExerciseGuidePlayer`) + bottom form warning + `_LiveTipPill` (lightbulb icon + `exercise.shortTip`).
- **Bottom control panel:** set indicator, metric (reps or `mm:ss` countdown), exercise name, prev / play-pause / next buttons.
- **Preparation overlay:** "HAZIRLAN!" badge + exercise name + `exercise.description` + 140 px pulsing 3-2-1 countdown; at 0 the analyzer is unblocked and a big green "BAŞLA" sigil briefly appears.
- **Rest overlay:** `mm:ss` countdown + upcoming exercise + set label + "GEÇ" (skip) button.
- **Session-complete overlay:** medal icon + day number + "Tamam" button.

### 4.9 Voice coach (`AudioFeedback`)
- **Where:** `lib/core/utils/audio_feedback.dart`.
- Android: probes `getLanguages()`; if `tr-TR` isn't installed, emits a loud console warning and falls back to `en-US`.
- iOS: `setIosAudioCategory(playback, [allowBluetooth, allowBluetoothA2DP, mixWithOthers, defaultToSpeaker], voicePrompt)` so the ringer switch can't mute the coach.
- Phrase-level 3 s dedupe (same phrase within 3 s is skipped).
- `testAudio()` manual smoke test (wired into the Profil tab).
- Lifecycle announcements (spoken by the camera screen's ref.listen):
  - Session complete → "Antrenman tamamlandı! Harika bir iş çıkardın."
  - Rest start → "Harika! Şimdi {N} saniye dinlenme."
  - Prep start → "Sıradaki hareket: {name}. {description}" (Phase 26).
- Pacing feedback emitted by analyzers after each counted rep (rep < 1.5 s → "Biraz yavaşla"; rep > 4.5 s → "Hadi, pes etme!"; throttled to 7 s).
- Milestone coaching by the camera screen: `reps == target - 2` → "Son iki tekrar, sık dişini!"; `reps == target/2` (target ≥ 4) → "Yarıladın! Aynen böyle devam et."
- Contextual cues from analyzers (e.g., Burpee step-2: "Şimdi aşağı in ve plank pozisyonu al." — throttled 8 s).
- Posture warnings: `CrunchAnalyzer` debounces "Boynunu düz tut!" to once per 15 s.

### 4.10 Pose analyzers (17 concrete + 1 base)
- **Base:** `pose_analyzer.dart` — `abstract class PoseAnalyzer { CrunchResult analyze(Pose); void reset(); }`.
- **Shared result:** `CrunchResult` (in `crunch_analyzer.dart`): `reps, state, torsoAngle, neckAngle, formWarning, repJustCompleted, pacingFeedback, contextualCue`.
- **Factory:** `analyzerFor(exercise)` in `analyzer_factory.dart` — a switch on `exercise.id` returning a fresh analyzer. Fallback: `CrunchAnalyzer()`.
- **Concrete analyzers & heuristics:**
  | Analyzer | File | Pose maths | Counts |
  |---|---|---|---|
  | CrunchAnalyzer | `crunch_analyzer.dart` | shoulder-hip-knee angle | DOWN > 140° → UP < 90° |
  | PlankAnalyzer | `core_analyzers.dart` | shoulder-hip-ankle | No reps; form warning when angle < 155° |
  | LegRaiseAnalyzer | `core_analyzers.dart` | shoulder-hip-ankle | DOWN > 150° → UP < 110° |
  | RussianTwistAnalyzer | `core_analyzers.dart` | shoulder-mid x offset vs hip-mid x | Count on L↔R commits |
  | MountainClimberAnalyzer | `core_analyzers.dart` | knee→same-side-shoulder distance | Count on side alternation |
  | BicycleCrunchAnalyzer | `core_analyzers.dart` | opposite elbow↔knee distance | Count on pair alternation |
  | FlutterKickAnalyzer | `core_analyzers.dart` | left vs right ankle y delta | Count on y-dominance swap |
  | PushUpAnalyzer | `chest_analyzers.dart` | shoulder-elbow-wrist | DOWN < 95° → UP > 160° |
  | BenchPressAnalyzer | `chest_analyzers.dart` | extends PushUp, tighter ROM | DOWN < 100° → UP > 155° |
  | ChestFlyAnalyzer | `chest_analyzers.dart` | wrist gap / shoulder width | OPEN > 1.4 → CLOSED < 0.5 |
  | SquatAnalyzer | `back_legs_analyzers.dart` | hip-knee-ankle | DOWN < 100° → UP > 165° |
  | PullUpAnalyzer | `back_legs_analyzers.dart` | shoulder-elbow-wrist (inverted semantics) | DOWN > 150° → UP < 80° |
  | BicepsCurlAnalyzer | `shoulders_arms_cardio_analyzers.dart` | shoulder-elbow-wrist | DOWN > 150° → UP < 50° |
  | ShoulderPressAnalyzer | `shoulders_arms_cardio_analyzers.dart` | wrist-y vs shoulder-y / shoulder-width | + partial-rep form warning |
  | LateralRaiseAnalyzer | `shoulders_arms_cardio_analyzers.dart` | elbow-shoulder-hip angle | UP > 75° → DOWN < 25° |
  | JumpingJackAnalyzer | `shoulders_arms_cardio_analyzers.dart` | ankle spread AND wrists overhead | OPEN/CLOSE alternation |
  | BurpeeAnalyzer | `shoulders_arms_cardio_analyzers.dart` | self-calibrating shoulder y state machine | STANDING→DOWN→STANDING |
- All analyzers apply a `minRepInterval` filter to kill jitter-driven false positives.

### 4.11 Exercise catalogue (41 exercises)
- **Where:** `lib/features/workout/data/workout_repository.dart` (1,162 LOC).
- Each `const Exercise` carries: `id, name, type (repBased|timeBased), targetReps, targetDurationInSeconds, sets, restDurationInSeconds, category, startCommand, description, shortTip, videoAsset`.
- Split by category:
  - Core (9): crunch, situp, plank, leg_raise, hanging_leg_raise, russian_twist, mountain_climber, bicycle_crunch, flutter_kick
  - Chest (6): push_up, incline_push_up, decline_push_up, chest_dip, bench_press, chest_fly
  - Legs (6): squat, lunge, bulgarian_split_squat, leg_press, calf_raise (timeBased), wall_sit (timeBased)
  - Back (5): pull_up, chin_up, lat_pulldown, barbell_row, superman (timeBased)
  - Shoulders (5): shoulder_press, lateral_raise, front_raise, arnold_press, pike_push_up
  - Arms (5): biceps_curl, hammer_curl, triceps_dip, triceps_pushdown, close_grip_push_up
  - Cardio / Full Body (5): burpee, jumping_jack (timeBased), high_knees (timeBased), jump_squat, skipping_rope (timeBased)
- 26 of these have a `videoAsset` wired to a mined JPG in `assets/videos/{id}.jpg`; `burpee`, `jumping_jack`, and several rarer movements still have `videoAsset: null` → fallback tile.

### 4.12 Workout plans (20 total)
- **Where:** `WorkoutRepository.allPlans` + `WorkoutRepository.pushLimitsAbsHiit/StrongerCore/IronPack/AthleticCore` (static consts).
- 2 Core: "Çelik Gibi Karın", "Atletik Core".
- 4 Göğüs (spec-named): "Dambıl Hızlı Göğüs Yapma", "Göğüs Aktivasyonu ve Büyüme", "Tam Göğüs Büyümesi ve Patlaması", "Göğüs Yağ Yakma Temel Planı".
- 2 Sırt: "Geniş V-Taper Sırt", "Duruş Düzeltici Temel Sırt".
- 3 Omuz: "Dev Omuzlar", "V-Tipi Omuz Şekillendirme", "Power Omuz Patlaması".
- 3 Kol: "Çelik Kollar", "Patlayıcı Kol Süper Setleri", "Hızlı Tonlama Kolları".
- 4 Bacak: "Büyük ve Güçlü Quadriceps Şekli", "Bacak Gücü Artışı Günü", "Alt Vücut Kardiyo ve Güç", "Elit Bacak Şekillendirme".
- 3 Kardiyo: "Yağ Yakıcı Kardiyo", "Tam Vücut Patlama", "Hızlı Sabah Kardiyosu".
- 4 Push-Limits specials (surfaced on the Sınırlarını Zorla dashboard strip): `pushLimitsAbsHiit, pushLimitsStrongerCore, pushLimitsIronPack, pushLimitsAthleticCore` — also appear in the Core filter.

### 4.13 30-day static program
- 7 days currently populated in `_staticProgram`. Days 8-30 don't exist yet → plan detail shows them as "Yakında" locked tiles.

### 4.14 Asset management
- **App icon** generated via `flutter_launcher_icons` from `photos/app_icon.png` (square 1024 px derived from `ilkkarşılamaanaekranarkaplanı.webp` via ImageMagick). Both Android `mipmap-*` densities and iOS `AppIcon.appiconset` are tracked in git.
- **Onboarding & paywall WebPs** in `photos/` (27 files, 3.6 MB total after Phase 23.1 compression — was 101 MB of PNGs).
- **Exercise demos** in `assets/videos/` (26 JPGs mined from `yuhonas/free-exercise-db` + 3 legacy MP4s + README placeholder).
- **Reference photography** in `docs/<TR category>/` (7 category folders, hundreds of files, long base64-ish filenames).
- **Python miner**: `exercise_miner.py` (gitignored) pulls from free-exercise-db's JSON manifest; falls back to (paid) RapidAPI when the free tier is restored.

### 4.15 Persistence & sync
- **Local (SharedPreferences):** first-run flag, goal enum, user metrics JSON, completed-day set.
- **Remote (Supabase):** `user_progress` rows upserted on day completion; on app launch `_completedDays()` merges local ∪ remote (RLS-scoped to current user) and re-saves to local cache.

### 4.16 CI/CD
- GitHub Actions job `Analyze & Build` on every push / PR: `dart format` gate, `flutter analyze`, debug APK build. No tests run.

---

## 5. Code Quality Review

### Strengths
1. **Consistent feature-first layout.** Zero cross-feature imports except through `core/`. Each feature owns its own presentation / providers / data.
2. **Hand-written Riverpod is clean.** Providers are small, explicit, and composable. `AsyncNotifier` for mutable session; `Provider` for catalogue + Listenable adapter for GoRouter.
3. **Strategy + Factory are well-applied.** New analyzers drop in with one case in `analyzer_factory.dart` plus a class. The widget layer doesn't need changes.
4. **Graceful degradation is everywhere.** `ExerciseGuidePlayer.errorBuilder`, the `_FallbackTile`, `Image.network/asset` error builders, `AudioFeedback` try/catch around every TTS call, `_resolveImage` helper, `initializeWorkout` null-exercise guard.
5. **Throttling discipline.** Every TTS path has explicit cooldowns (3 s phrase, 7 s pacing, 8 s contextual, 15 s posture). Pose frames are skipped during rest / prep.
6. **i18n-aware copy.** All user-facing text is Turkish; no hardcoded English polluting the UI. Turkish-named assets (with `ç/ş/ğ/ı/ö/ü` and spaces) are correctly quoted in `pubspec.yaml`.
7. **Formatting / analysis gate.** CI enforces `dart format --set-exit-if-changed` and `flutter analyze`. The codebase passes cleanly with `flutter_lints ^6.0.0` + `prefer_single_quotes` + `avoid_print`.

### Weaknesses
1. **Giant screens.** `dashboard_screen.dart` (1,676), `onboarding_screen.dart` (1,594), `workout_camera_screen.dart` (1,536) each host 15+ private widget classes. They compile, but jumping around is painful.
2. **Deeply nested widget trees.** `dashboard_screen.dart` has Column→Expanded→ListView→Row→Stack→Positioned trees that are hard to read.
3. **`WorkoutSessionNotifier` is doing too much.** It owns the session state machine, two timers, repository sync, ad-hoc day plumbing, rest-vs-prep transitions. 376 LOC and growing.
4. **Analyzer result class is crunch-specific.** `CrunchResult` has `torsoAngle`, `neckAngle` fields that 90% of analyzers populate with null. Should be renamed `RepAnalysisResult` or become a sealed type per movement pattern.
5. **Repository is a monolith.** 1,162 LOC of static const exercises + plans + Supabase sync logic. Splitting exercises/plans from the repository (into pure data files) would let the sync logic shrink.
6. **Zero real tests.** `test/widget_test.dart` is the default `2+2=4` placeholder. Zero coverage for analyzers (which are pure state machines — perfect test targets), repository, or provider logic.
7. **Hard-coded Turkish strings in logic.** TTS phrases, milestone thresholds, debounce windows are magic numbers/strings scattered across 6+ files. No `lib/l10n/` or centralised strings table.
8. **Mutable state in the camera widget.** `_analyzer`, `_workoutTimer`, `_secondsRemaining`, `_wasResting`, `_wasPreparing`, `_activeExerciseId`, `_activeSet` are all fields of `_WorkoutCameraScreenState`. Easy to accidentally desync with the provider-owned state.
9. **Empty `lib/shared/` folder.** Placeholder left over from initial scaffold — either delete or populate.

### Anti-patterns observed
1. **Partial state persistence on resume.** `didChangeAppLifecycleState` disposes the camera on `inactive` but doesn't pause the workout timer or TTS. A phone call during plank would silently let the plank timer drain.
2. **Silent `catch (_)`** in `pose_detector_service.dart` (transient detection failures get swallowed). Fine pragmatically, but hides real decoder problems.
3. **Magic `dayNumber: 0` sentinel** for ad-hoc plans — works but isn't typed. A sum type `WorkoutDay.program(int dayNumber) | WorkoutDay.adHoc()` would be clearer.
4. **Dead `startCommand` field** on `Exercise` — was the original Phase 16 announcement string, superseded by `description` in Phase 26 but kept for fallback. Every exercise has BOTH fields; one is dead code.
5. **Filesystem-unsafe filenames** in `photos/` (space in `kişiselleştirilmiş planda30.günERKEK.webp`) — referenced verbatim in Dart. Works today, but one typo away from bundle mismatch.

### Maintainability score: **6 / 10**
Strong architectural foundation and consistent patterns, but the top three screens are approaching unmaintainable length and there's zero automated regression protection for the complex workout FSM and pose analyzers. A refactor pass splitting the big screens into per-section files + a test suite for the analyzers would move this to an 8.

---

## 6. Security Analysis

### Auth system
- **Primary:** Supabase `signInAnonymously()` triggered at the end of onboarding. No password, no email confirmation, no MFA.
- **Secondary:** `AuthScreen` supports email sign-in (legacy fallback). Not extensively tested; invoked only when anonymous auth fails.
- **Session persistence:** Supabase stores the JWT in platform-appropriate secure storage (Keychain on iOS, EncryptedSharedPreferences on Android) via `supabase_flutter`'s built-in handling.
- **Router guard:** `app_router.dart` redirects `user == null` to `/auth`. Combined with RLS, this blocks unauthenticated `user_progress` access.
- **Row Level Security:** `supabase/migrations/001_initial_schema.sql` enables RLS on `user_progress` and restricts to `user_id = auth.uid()` (policies not shown in the 40-line read, but are part of that file per the commit log).

### Potential vulnerabilities
1. **Anonymous auth is permissive by default.** Every onboarded user gets a full Supabase session. If the project scales, operator must set rate limits / captcha on the `signInAnonymously` endpoint in the Supabase dashboard.
2. **No email verification path for real accounts.** Users that upgrade from anonymous → email have no confirmation flow surfaced in `auth_screen.dart`.
3. **API key embedded in gitignored Python script.** `exercise_miner.py` carries a RapidAPI key. It's gitignored (`git check-ignore` confirms), but if the file is ever sent over a non-encrypted channel or accidentally committed via `git add -f`, the key leaks. Rotate the key once it's no longer useful.
4. **`.env` contents live in `dotenv` at runtime**, which means the Supabase anon key is extractable from any APK with `apktool`. The anon key is designed to be public-ish (RLS protects data), but the principle stands — assume anyone can read it.
5. **No CSRF / replay concerns** (it's a mobile client, not a web app).
6. **Camera permission is requested; mic is not** (good — we only record pose, not audio).

### Misconfigurations
1. **Debug APKs are the only CI artifact.** Debug builds don't strip symbols and ship with `debuggable=true` in the manifest. Fine for CI, but no release pipeline exists yet.
2. **`android:usesCleartextTraffic`** is Flutter default (not set, so false in release). OK.
3. **No Android network security config** — if Supabase ever moves to a regional proxy, this will matter.
4. **No iOS ATS exceptions** — all image hosts are HTTPS (Unsplash, GitHub raw), so no ATS override needed.
5. **No obfuscation.** Dart code ships as AOT-compiled snapshots but without `--obfuscate --split-debug-info`. Production release should enable both.
6. **`.env.example` is thin** (only 4 keys — SUPABASE_URL, SUPABASE_ANON_KEY, REVENUECAT_APPLE_KEY, REVENUECAT_GOOGLE_KEY). `.env` itself must never be committed; it isn't, per `.gitignore`.

### Overall security risk: **Medium**
The app correctly uses Supabase RLS for data isolation and doesn't store sensitive user data on-device. The chief risks are operational (abuse of anonymous auth, unrotated RapidAPI key) rather than architectural. A production release would need: email verification flow, rate-limited anon auth, release builds with obfuscation + symbol stripping, and a production-grade `.env` rotation policy.

---

## 7. Performance Analysis

### Bottlenecks

1. **Camera stream pipeline on mid-range Android.**
   `CameraPreview` at `ResolutionPreset.medium` (~720×480) → ML Kit BlazePose on every frame → `PoseAnalyzer.analyze(pose)`. `_onCameraImage` debounces with `_isBusy`, so only one frame is in flight at a time, but on slower devices the effective frame rate can drop to 10-12 fps.

2. **`Image.asset` first load.** The new Phase-27 JPGs are small (~60 KB each), but the photos/ WebPs can be 150-250 KB each. First render on a cold start will cause noticeable jank on older devices; precaching via `precacheImage` in `initState` would help.

3. **Riverpod `ref.listen` fires often.** Every `setCurrentReps` update re-runs the camera screen's listener. That's cheap (just variable comparisons), but TTS and `_audio.speak` calls — even no-op'd by the dedupe — allocate strings every frame. Batching via a coalesced state would reduce allocations.

4. **TTS awaitSpeakCompletion(true).** Each `_audio.speak` awaits until the phrase finishes. If two calls fire back-to-back (e.g., rep-completion + form-warning), the second will queue. Our throttles keep this rare, but under latency spikes the coach can feel laggy.

### Inefficiencies

1. **`workoutPlansProvider` returns a new list every read.** It's just `WorkoutRepository.allPlans` (static const list) — no wasted work — but the provider would benefit from being `select`-friendly if we add per-category filtering beyond what the dashboard already does.

2. **String concatenation in hot paths.** `analyze(Pose pose)` allocates a new `CrunchResult` object per frame (~30×/s). Cheap in Dart, but a `const` result or object pool would eliminate GC pressure for the 60 s of a plank.

3. **`CustomPaint` pose painter repaints on every frame even when identical.** No `shouldRepaint` guard uses a hash — it always returns `true`.

4. **`analyzerFor(exercise)` allocates a new analyzer on every exercise change.** This is deliberate (clean state) but the old analyzer's `_lastRepTime / _lastFeedbackTime / _lastPostureWarning` fields get garbage-collected. Fine for 41 exercises, but a pool keyed by exercise.id would be cheaper on long sessions.

### Scalability concerns

1. **Static `allPlans` list.** Doesn't scale past ~100 plans before the filter sweep on every dashboard rebuild becomes noticeable. Mitigation: group by category at provider level and memoize.

2. **30-day program is hardcoded.** Adding programmatic day-generation (e.g., weekly deload, branched difficulty) will require replacing `_staticProgram` with a generator or JSON manifest.

3. **Supabase `user_progress` doesn't store which *plan* was completed** — only `day_number`. Ad-hoc plan completions persist nothing. If we want streak-per-plan stats, the table schema must grow an optional `plan_id`.

4. **Assets are shipped in-bundle (3.6 MB photos + 8.5 MB videos + docs/ folders)** — APK sizes are growing. A Firebase-Storage or CDN-hosted asset pipeline would let the client download on first use and keep initial install small.

---

## 8. Missing Features / Gaps

### Critical gaps
1. **Only 7 of 30 days are populated in the static program.** Users completing day 7 hit a wall.
2. **No live RevenueCat products.** Paywall UI is complete but `_simulatePurchase()` just closes the screen.
3. **No test coverage.** `test/widget_test.dart` is the default placeholder. Zero pose-analyzer tests, zero repository tests.
4. **Gelişim (Progress) tab is a placeholder.** Streak + completed count only; no graphs, no history, no per-body-part analytics.
5. **No way to resume a partially-completed day.** Exiting the camera screen mid-workout resets to day 1 set 1.
6. **No notifications.** Settings tile says "Yakında". There's no `flutter_local_notifications`, no FCM integration, no reminder scheduling.
7. **No account upgrade flow.** Users that onboard anonymously can't attach an email later — the Profil tab only has "Çıkış Yap".

### Desirable but unimplemented
8. **Video demos for every exercise.** 15 of 41 exercises don't even have a JPG.
9. **Search in Bölgeler.** Icon is there (`Icons.search_rounded` in the top-right of the tab); onTap is no-op.
10. **Plan detail exercise tiles aren't tappable** (just chevrons for show).
11. **Weekly calendar view.** The date bubbles show the current week but tapping a day does nothing.
12. **No deep links.** Paywall, plan detail, and workout aren't reachable from an external URL.
13. **No logging / analytics.** `debugPrint` everywhere; no Sentry/Crashlytics/PostHog.
14. **No app state restoration** on process death (e.g., user starts a plank, gets a phone call, the OS kills the app → comes back to day 1).
15. **Hanging Leg Raise / Wall Sit / Superman / Calf Raise** use `PlankAnalyzer` as a fallback (no bespoke pose check).
16. **`burpee` and `jumping_jack` have no demo image** (free-exercise-db doesn't carry them); the PIP slot shows the `_FallbackTile` on those screens.

---

## 9. Improvement Opportunities

### Quick wins (minutes to hours)
1. **Split the mega-screens** (`dashboard_screen.dart`, `onboarding_screen.dart`, `workout_camera_screen.dart`) into per-section files under their feature folder. No logic change; pure file-level refactor.
2. **Delete `lib/shared/`** (empty) or add a `README.md` explaining what belongs there.
3. **Remove the `startCommand` field** (superseded by `description` + `shortTip`). Every exercise has both; dropping `startCommand` saves ~40 lines in the repository and one fallback branch in the camera screen.
4. **Add `precacheImage` calls** in the dashboard and plan-detail `initState` for the hero images (kills first-render jank).
5. **Add `shouldRepaint` to `PosePainter`** based on landmark hash — avoids repaint when pose hasn't changed.
6. **Populate days 8-30** with variations of existing exercises.
7. **Wire the "Daha Güçlü Şekil" / "Atletik Core" etc. snackbar-only cards to `/plan-detail`.** Some legacy widgets still show a snackbar.
8. **README.md**: currently 1 LOC. Write a ~100-line getting-started section (Flutter version, env setup, `supabase/migrations` apply, running the miner script, screenshots).

### Medium improvements (day-scale)
9. **Extract a `l10n/tr.dart` strings table** for the ~60+ Turkish phrases scattered across analyzers and screens. Makes future English translation a drop-in.
10. **Introduce `RepAnalysisResult` (sealed class)** replacing `CrunchResult` — variant per movement category (angle-based, distance-based, state-machine). Drops nullable fields.
11. **Test the pose analyzers.** They're pure state machines operating on synthetic `Pose` fixtures. Unit coverage > 80% is realistic.
12. **Split `WorkoutSessionNotifier` into sub-notifiers** (session-state + timer-controller + repository-sync) or at least extract the rest-vs-prep transition logic into a dedicated `_WorkoutLifecycle` class.
13. **Implement "resume mid-workout"** by persisting `{currentDay, currentExerciseIndex, currentSet, currentReps}` to SharedPreferences on every `setCurrentReps` and restoring on app start.
14. **Wire real RevenueCat products.** 3 product IDs (monthly/quarterly/yearly) + entitlement gate on camera screen + restore purchases path.
15. **Populate the Gelişim tab.** Simple per-day completion bar chart + streak heatmap from Supabase.
16. **`flutter_local_notifications` for the "Bildirimler"** settings tile — daily workout reminder at a user-chosen time.
17. **Crashlytics / Sentry** wired up with a sampling rate. `debugPrint` lines become `logger.d/i/w/e`.

### Advanced / architectural upgrades
18. **Move exercise + plan catalogue out of Dart into JSON** (bundled as an asset, remotely override-able via Supabase Storage). Lets non-engineers edit copy and ship without an app update.
19. **Per-user program generator** — replace the 7-day static program with a generator that reads `wizardProvider` (level, goal, metrics) and produces a 30-day plan tailored to the user.
20. **Server-side pose evaluation fallback** — for device families where ML Kit is unreliable (very old Androids), offload pose detection to a hosted endpoint. Only triggered if on-device detection returns < 0.3 likelihood across > N frames.
21. **Realtime coaching via an LLM**. Claude API or Gemini API called with the last 30 s of rep timings + form warnings → bespoke motivational line. Would need careful cost management and offline fallback.
22. **Plan editor** — let users clone a plan and tweak sets/reps. Requires a `user_plans` table in Supabase.
23. **Multi-user / social features** — friend leaderboards, shared plans. Requires a `friendships` table and realtime channels.
24. **Apple Health / Google Fit integration** — upload completed workouts as HKWorkout entries.
25. **Offline mode with Isar or Drift** — stop assuming Supabase is reachable; queue writes locally and sync on reconnect.

---

## 10. DevOps & Deployment Status

### Current state
- **CI:** `.github/workflows/flutter_ci.yml` gates every push / PR on `format + analyze + debug APK build`. ~5-7 minute runs on GitHub-hosted runners.
- **Branches:** `main` (protected? unknown from repo inspection). Workflow also listens on `staging` and `feature/*` — implying a planned three-tier branching model, but no staging builds currently exist.
- **Platforms scaffolded:** android ✓, ios ✓ (stock + app icon + CFBundleName), macos (unused stock), linux (unused stock), windows (unused stock), web (unused stock).
- **Android:** `AndroidManifest.xml` declares CAMERA + INTERNET + the two `<queries>` intents for PROCESS_TEXT and TTS_SERVICE. `android:label="FormAI"`, `android:icon="@mipmap/launcher_icon"`.
- **iOS:** `Info.plist` has `CFBundleDisplayName = FormAI`, `CFBundleName = FormAI`. No camera usage string! This will crash on first camera request.
- **Env:** `.env` holds real Supabase keys (gitignored). `.env.example` documents the 4 required keys.
- **Launcher icons:** regenerated by `flutter pub run flutter_launcher_icons` from `photos/app_icon.png`. Both Android densities and the iOS icon set are committed.

### Missing for production
1. **iOS `NSCameraUsageDescription`** in `Info.plist`. App will be rejected / crash-on-launch without it.
2. **Release-build CI job.** The current workflow only builds `--debug`. A `--release` job with code signing (fastlane or `flutter build apk --release --obfuscate`) is needed.
3. **Play Console + App Store Connect scaffolding.** No metadata, no screenshots, no store listing copy.
4. **Crash reporting.** Crashlytics / Sentry setup not done.
5. **Analytics.** No Mixpanel / PostHog / Firebase Analytics. Product decisions currently rely on user screenshots over WhatsApp.
6. **Feature flags.** No LaunchDarkly / GrowthBook / Remote Config. Every experiment requires an app update.
7. **Rate limiting on Supabase.** The Supabase dashboard should enforce per-IP rate limits on `signInAnonymously` to prevent abuse.
8. **A staging Supabase project.** `.env` points to a single project; no environment split.
9. **Automated screenshot tests** (e.g., Golden) for the dashboard + onboarding flows.
10. **pubspec.lock** — `.gitignore` currently excludes `pubspec.lock`. This is *wrong* for an app (it's right for a library). Every environment resolves dependencies independently → non-reproducible builds.

### Deployment readiness: **~45 %**
Feature-complete for an internal demo. Not ready for public launch. Biggest blockers in order: iOS camera usage string, release signing + store listings, zero test coverage, no crash reporting.

---

## 11. Gemini Instructions (CRITICAL SECTION)

**Hello Gemini. Read this whole section before responding to the user.**

### Your role

You are the **collaborative senior-engineer advisor** for this project. The human operator (the project owner) will bring you prompts about FormAI — mostly "what should we build next", "what's the best way to do X", "review this design", or "this is broken, what's the fix?". You won't be writing code directly into the repo — instead, your output will be relayed to a second AI (Claude Code) that handles the actual file edits and commits.

### How your output is consumed

1. **The user asks you a question.**
2. **You respond** with analysis, proposals, trade-offs.
3. **The user relays your response to Claude Code**, which converts it into a step-by-step executable prompt (files to touch, exact edits, tests, commit message).
4. **Claude Code executes** the prompt, edits the repo, commits, pushes, and reports back to the user.
5. **The user brings back any follow-ups to you**, and the cycle repeats.

This means **your output is an intermediate design artefact**, not a deliverable. Optimize for clarity + completeness Claude Code can execute from, not for human aesthetics.

### What Gemini should do on every request

1. **Analyze the request against this report.** Cross-reference Sections 4 (current features), 8 (gaps), and 9 (opportunities) — the user's ask usually touches one of them.
2. **Think like a senior engineer.** Consider:
   - Data model implications (does this need a new Supabase table / column?).
   - State-management impact (new provider? change to an existing notifier?).
   - Thread-safety (camera / TTS / timers run on different isolates).
   - Graceful degradation (offline? camera denied? TTS unavailable? asset missing?).
   - Test strategy (what should be covered, where).
   - Migration plan if existing behaviour changes.
3. **Propose a concrete implementation**, not just a concept. For a feature request, that means: which files to create/edit, which classes to add, which providers to wire, which routes to register, which assets to drop in, approximately where the logic plugs into the existing architecture documented in Section 3.
4. **Surface trade-offs explicitly.** "Option A costs X but gains Y; Option B is simpler but misses Z." Let the user pick.
5. **Stay within the existing tech stack** unless there's a compelling reason to add a dependency. This project already ships with 11 runtime deps — each new one adds bundle size, versioning risk, and platform complexity.
6. **Flag missing context.** If the user's request is ambiguous (e.g., "make the dashboard better"), ask up to 3 clarifying questions before proposing a solution.
7. **Respect the project's existing voice.** Dark + neon-purple aesthetic. Turkish copy with sentence-case titles and short, direct prose. Code comments in English. Analyzer logic uses explicit state machines, not reactive streams.

### What Gemini should NOT do

1. **Don't paste code ready for `patch`-style application** — Claude Code will handle the exact edits. Your job is to describe *what* to change and *why*, down to file paths and widget names, but not to produce a diff.
2. **Don't suggest framework changes** (swapping Riverpod for Bloc, GoRouter for Navigator 2.0 directly, etc.) unless the user explicitly asks for an architecture review.
3. **Don't hallucinate features**. If you don't see something in this report, assume it doesn't exist. When in doubt, mark it "not verified; confirm with the user".
4. **Don't write vague answers** ("maybe try implementing it with a provider"). Name the exact provider, its type, its dependencies, and where it would be read.
5. **Don't ignore the Turkish UX.** Every user-facing string should be Turkish or explicitly flagged as "localize later".
6. **Don't skip the throttle/debounce question.** The app has a strict contract: TTS is throttled, pose frames are skipped during non-active states. New logic that speaks or reacts to pose must declare its own cooldown.

### Preferred response shape

Give every answer this skeleton (adapt sections as needed):

```
## Understanding
(1-3 sentences restating what the user is asking, and which section of the project it touches.)

## Proposed approach
(The solution, at the level of "in file X, add class Y that does Z; register provider P; route R".)

## Trade-offs
(Bulleted list: Option A vs B vs C, or risks and mitigations.)

## Data model / state changes
(New tables, new state fields, migrations. If none, say "None.")

## UX copy
(Turkish strings Claude Code should use, if the feature surfaces any.)

## Tests & verification
(How we'll know this works — manual test plan, unit test names, golden test candidate.)

## Open questions for the user
(Anything you couldn't resolve without more input.)
```

### Anti-hallucination guardrails
- The project uses **Flutter/Dart**. Not React Native, not Kotlin Multiplatform. Don't suggest Swift-specific or Java-specific patterns.
- **State management is Riverpod 3.x, hand-written** (no riverpod_annotation, no codegen). Suggest providers in that idiom.
- **Routing is GoRouter 17.x**. Redirect logic lives in a single `redirect` closure in `app_router.dart`.
- **Auth is Supabase.** Not Firebase Auth.
- **On-device ML is Google ML Kit BlazePose.** Not MediaPipe, not TensorFlow Lite directly.
- If the user asks about "the paywall screen" or similar, it lives at `lib/features/monetization/presentation/paywall_screen.dart`.
- When unsure about a current-state detail, ask the user to run `dart analyze lib/` or `ls {path}` and report back, rather than guessing.

---

## 12. Collaboration Protocol

### The loop

```
┌────────┐    1. Prompt      ┌──────────┐
│  User  │ ─────────────────►│  Gemini  │
│        │                    │ (you)    │
└────┬───┘                    └─────┬────┘
     │                              │ 2. Structured design response
     │                              │    (per skeleton in §11)
     │◄─────────────────────────────┘
     │
     │ 3. User relays Gemini's response
     │    (pasting verbatim or summarised)
     ▼
┌──────────────┐     4. "Gold-standard prompt"     ┌──────────────┐
│  Claude Code │ ────────────────────────────────► │  Repository  │
│  (executor)  │    - file edits                   │   (main)     │
│              │    - tests                        │              │
│              │    - commit + push                │              │
└──────────────┘                                    └──────────────┘
       │
       │ 5. Claude Code reports
       │    what changed + links
       ▼
┌────────┐
│  User  │  Reviews diff. If something's off, goes back to step 1.
└────────┘
```

### Rules per step

**Step 1 — User asks Gemini.** The user's prompt will usually reference:
- A section of this report ("see §8 gap #3").
- A screenshot.
- A file path or class name.
- A natural-language description of desired behaviour.

If the user forgets to say which file or feature is affected, **Gemini asks before designing**. Do not invent context.

**Step 2 — Gemini responds.** Use the response skeleton from §11. Optimise for:
- **Precision.** File paths, class names, method names, provider names — named explicitly.
- **Completeness.** A second AI (Claude Code) must be able to execute this without going back to you.
- **Checklist format** where possible. "1. Create X. 2. Edit Y line Z. 3. Add test T."
- **No code blocks over ~30 lines.** Describe the code at a level Claude Code can implement from.

**Step 3 — User relays.** The user copies your response into a new Claude Code session.

**Step 4 — Claude Code converts to an executable prompt.** Claude will typically reformat your design into:
- A task list (`TaskCreate` entries).
- A set of file-read calls to verify current state.
- A set of `Edit` / `Write` calls.
- A format + commit + push at the end.

If your response is ambiguous, Claude will fall back to its own judgement — which may diverge from your intent. **The more precise you were in step 2, the closer the result matches what you designed.**

**Step 5 — Claude reports back.** The user will see a summary of the diff. If something's wrong, they'll loop back to step 1 with "Gemini, that didn't work because …".

### Contract between Gemini and Claude Code

- **Gemini owns design.** What to build, why, what the state/data model should look like, where it fits in the architecture, what the trade-offs are.
- **Claude Code owns execution.** Which exact edits to make, which lines to touch, which tests to run, how to split work into tasks, how to commit/push.
- **The user owns product direction.** Priorities, UX tone, which option to pick among trade-offs you present.

Don't try to do Claude's job (writing exact diffs). Don't expect Claude to do yours (making architectural judgement calls from vague inputs).

### Version & commit conventions

- Commits follow **Conventional Commits** lite: `feat:`, `fix:`, `refactor:`, `chore:`. The user will specify the exact message in step 3, so you don't need to.
- Branching: the CI listens to `main`, `staging`, `feature/*`. Most current work lands directly on `main`. Don't assume feature branches exist.
- The project uses Turkish in the UI but **English in code + commit messages + report text**.

---

## 13. Final Summary

### Overall project status
FormAI is an ambitious, architecturally-clean, UI-rich Flutter fitness app that is **feature-complete for the primary user journey** (onboarding → prediction → paywall → dashboard → plan detail → AI camera workout → completion) but not production-ready. The engineering foundation is strong: consistent feature-first layout, hand-written Riverpod, a factory-dispatched pose analyzer strategy, and aggressive defensive coding against camera/network/TTS failures. The delivery gaps are operational: zero automated tests, placeholder RevenueCat, only 7/30 program days populated, missing iOS camera usage string, debug-only CI.

### Key risks (ordered by blast radius)
1. **iOS camera usage string is missing** — the app crashes on first workout launch on iOS. (5-min fix.)
2. **Zero test coverage** for the pose-analyzer state machines — any refactor of `WorkoutSessionNotifier` or `analyzer_factory.dart` is one-shot, with no regression net. (Day-scale investment.)
3. **No release build pipeline + no obfuscation** — ready-to-ship builds don't exist yet.
4. **RevenueCat is SDK-only; no products / entitlements are wired** — the paywall is UX theatre.
5. **Static program is 7 of 30 days** — core engagement story falls apart at day 8.
6. **`pubspec.lock` is gitignored** — non-reproducible builds across developers / CI.
7. **No crash reporting** — post-launch issues invisible.

### Priority next steps (1-week sprint proposal)

| # | Task | Effort | Impact |
|---|---|---|---|
| 1 | Add `NSCameraUsageDescription` to `ios/Runner/Info.plist`. | 5 min | Unblocks iOS launch. |
| 2 | Un-gitignore `pubspec.lock`. | 2 min | Reproducible builds. |
| 3 | Unit tests for all 17 pose analyzers using synthetic `Pose` fixtures. | 1-2 days | Regression net for the riskiest code. |
| 4 | Populate days 8-30 of the static program. | 3-4 hours | Users can complete the program. |
| 5 | Wire real RevenueCat products (3 IDs, entitlement gate on camera screen, restore purchases). | 1 day | Monetisation actually works. |
| 6 | Add Sentry + a minimal event stream (Mixpanel or PostHog). | 3 hours | Visibility into production. |
| 7 | Release-build CI job with obfuscation + split-debug-info. | 3 hours | Store-ready artifacts. |
| 8 | Split `dashboard_screen.dart`, `workout_camera_screen.dart`, `onboarding_screen.dart` into per-section files. | 4 hours | Maintainability + faster future iteration. |
| 9 | README.md upgrade (env setup, migration apply, miner usage). | 1 hour | Onboard future contributors. |
| 10 | Move `_muscularPhotoUrl` / fallback Unsplash strings into a single `lib/core/utils/placeholder_images.dart`. | 30 min | One source of truth. |

With tasks 1-7 done, the project moves from "feature-complete internal demo" to "soft-launchable beta on TestFlight + Play Internal Testing".

---

**End of report.** Last updated 2026-04-19 against commit `962ca64` on `main`. Regenerate this file whenever architecture, tech-stack, or feature set meaningfully shifts — or ask Claude Code to do it via prompt: _"Regenerate PROJECT_FULL_REPORT.md from scratch based on the current working tree."_
