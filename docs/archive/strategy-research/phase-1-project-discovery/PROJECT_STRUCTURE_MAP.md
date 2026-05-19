# PROJECT STRUCTURE MAP

**Phase 1 — Project Discovery**
**Project:** SixPack AI / FormAI Fit (`pubspec name: sixpack_ai`, version `0.1.0+5`)
**Tagline (TR):** "30 Günde Karın Kası — AI-powered fitness coaching"
**Generated:** 2026-05-08
**Status:** Structural atlas. Factual only. No strategy, no recommendations, no redesigns. Strategy work begins in Phase 2+.

---

## 0. HOW TO READ THIS DOCUMENT

This is the **canonical map** of what exists in the codebase today. Every downstream agent (Phases 2–7) treats this as ground truth and references file paths from here. If a Phase 2+ agent claims a screen, widget, or flow exists, it must trace back to a section here. Anything not here was not observed.

Conventions:
- File paths are absolute under `/home/emre/Downloads/SixPack-AI/`. The leading prefix is omitted in references; e.g. `lib/main.dart:46` means `/home/emre/Downloads/SixPack-AI/lib/main.dart` line 46.
- "Phase NN" tags throughout the codebase (e.g. Phase 49, Phase 53, Phase 94, Phase 95) refer to the user's internal release-iteration log, not Flutter SDK versions.
- Friction Observations are **factual** ("9 cards before scroll", "primary CTA below 4 widgets"). Whether each is a problem is decided in Phase 2+.

---

## 1. STACK SNAPSHOT

| Layer | Choice | Version | Source |
|---|---|---|---|
| Framework | Flutter | ≥3.22 | `pubspec.yaml:8` |
| Language | Dart | ≥3.4 <4.0 | `pubspec.yaml:7` |
| State | flutter_riverpod | 3.3.1 | `pubspec.yaml:16` |
| Routing | go_router | 17.2.1 | `pubspec.yaml:22` |
| Backend / Auth | supabase_flutter | 2.5.6 | `pubspec.yaml:19` |
| Subscriptions | purchases_flutter (RevenueCat) | 8.1.1 | `pubspec.yaml:42` |
| Crash reporting | sentry_flutter | 9.6.0 | `pubspec.yaml:52` |
| Analytics | posthog_flutter | 5.3.0 | `pubspec.yaml:53` |
| iOS ATT prompt | app_tracking_transparency | 2.0.6 | `pubspec.yaml:54` |
| Camera + ML | camera 0.12 + google_mlkit_pose_detection 0.14.1 | — | `pubspec.yaml:28-29` |
| Voice feedback | flutter_tts | 4.0.2 | `pubspec.yaml:33` |
| Local persistence | shared_preferences | 2.2.2 | `pubspec.yaml:36` |
| Image cache | cached_network_image 3.4.1 + flutter_cache_manager 3.4.1 | — | `pubspec.yaml:47, 78` |
| Skeleton loaders | shimmer | 3.0.0 | `pubspec.yaml:65` (Phase 49) |
| OAuth | google_sign_in 7.2 + sign_in_with_apple 7.0.1 | — | `pubspec.yaml:57-58` |
| Notifications | flutter_local_notifications 21.0 + timezone 0.11 | — | `pubspec.yaml:43-44` |
| Sharing / deep links | share_plus 13.1 + path_provider 2.1.5 + app_links 6.3.2 | — | `pubspec.yaml:90-92` (Phase 54) |
| Home-screen widgets | home_widget 0.7 | — | `pubspec.yaml:103` (Phase 55) |
| iOS Live Activities | live_activities 2.4.1 | — | `pubspec.yaml:108` (Phase 55) |
| Connectivity | connectivity_plus | 6.0.5 | `pubspec.yaml:117` (Phase 89) |

**Native bridges present:**
- `ios/FormAIWidget/` — WidgetKit home-screen tile (Swift)
- `ios/FormAILiveActivity/` — Dynamic Island / Live Activity Widget Extension (SwiftUI)
- `android/app/src/main/kotlin/.../widget/` — AppWidgetProvider (Kotlin)

**Top-level repo layout:**
```
.
├── android/         iOS, macOS, linux, windows, web (multi-platform)
├── assets/          (declared; mostly empty — photos/ holds the real assets)
├── photos/          51 root .webp + app_icon.png
│   ├── meals/       298 .webp recipe images
│   └── workouts/    32 .webp plan thumbnails
├── Beslenme-Photos/ 15 .jpeg supplementary meal references (legacy)
├── lib/
│   ├── main.dart    Entry point (Phase 94 4-layer error guards)
│   ├── core/        Shared infra (router, theme, services, widgets)
│   ├── features/    11 feature modules (admin, auth, feedback, home,
│   │                monetization, nutrition, onboarding, progress,
│   │                referral, workout)
│   └── scripts/
├── supabase/        DB schema + migrations
├── terraform/       Infra as code
├── integration_test/ E2E tests (Phase 44 QA harness)
├── test/            Unit / widget tests
├── docs/            5 strategy docs (already produced)
├── asosystem/       Web admin panel (TS/Vite/Tailwind, separate stack)
└── reports/         (this directory — created Phase 1)
```

---

## 2. APP BOOTSTRAP — ENTRY SEQUENCE

**File:** `lib/main.dart` (lines 46–141 main fn, 184–394 _BootGate)

The bootstrap implements the Phase 94 release-resilience layer (auto-memory: `project_phase_94_release_resilience.md`). Four protective layers wrap every async + sync error path:

1. **`runZonedGuarded`** (line ~50) — catches async errors escaping framework (futures, microtasks).
2. **`FlutterError.onError` + `PlatformDispatcher.onError`** — sync framework + platform errors.
3. **Custom `ErrorWidget.builder`** — branded splash on widget crashes (replaces grey-box default).
4. **`_BootGate`** (lines 184–394) — serialized FutureBuilder wrapper around three init steps.

**Serialized init steps inside _BootGate:**

| Step | Operation | Timeout | Failure mode | Source |
|---|---|---|---|---|
| 1 | `.env` load via `flutter_dotenv` | none | logged, non-fatal (`_envSafe` helper) | lines 89–96 |
| 2 | `Supabase.initialize` | **8 s** | error screen → retry | lines 243–296 |
| 2a | Anonymous user recovery | — | if `auth.was_anonymous` flag set + no session, signs in fresh anon | lines 273–296 |
| 3 | PostHog init | **5 s** | logged, non-fatal (would otherwise hang on DNS-less networks) | lines 312–328 |
| (deferred) | RevenueCat | — | NOT awaited at boot — initialized lazily on onboarding-finish or sign-in | lines 330–337 |

**Sentry init** is wrapped in its own try/catch, runs alongside the gates (auto-memory note).

**Output of _BootGate FutureBuilder:**
- Loading → branded splash
- Error → screen with two messages: "retry" or "install latest build" (lines 364–377)
- Success → `FormAIApp` (line 389)

**`FormAIApp` (line 389+)** is the root MaterialApp.router with `appRouterProvider` injected.

---

## 3. NAVIGATION & ROUTING

**Router file:** `lib/core/routing/app_router.dart` (~350 lines)
**Owner:** `appRouterProvider` (Riverpod, includes global `RouteObserver` post-Phase-48.1)
**Refresh trigger:** `authRefreshListenableProvider` (`lib/features/auth/providers/auth_provider.dart:58–67`) — watches `Supabase.instance.client.auth.onAuthStateChange` and notifies GoRouter on every login/logout/refresh. Router re-evaluates redirects without tearing down.

### 3.1 Named routes (`AppRoutes` class, lines 29–67)

| Name | Path | Widget | File |
|---|---|---|---|
| `dashboard` | `/` | DashboardScreen | `lib/features/home/presentation/dashboard_screen.dart` |
| `onboarding` | `/onboarding` | OnboardingScreen | `lib/features/onboarding/presentation/onboarding_screen.dart` |
| `auth` | `/auth` | AuthScreen | `lib/features/auth/presentation/auth_screen.dart` |
| `workout` | `/workout` | WorkoutCameraScreen | `lib/features/workout/presentation/workout_camera_screen.dart` |
| `workoutToday` | `/workout/today` | (redirects to `/workout`) | — |
| `paywall` | `/paywall` | PaywallScreen | `lib/features/monetization/presentation/paywall_screen.dart` |
| `prediction` | `/prediction` | PredictionScreen | `lib/features/onboarding/presentation/prediction_screen.dart` |
| `planDetail` | `/plan-detail` | PlanDetailScreen | `lib/features/workout/presentation/plan_detail_screen.dart` |
| `accountSettings` | `/account-settings` | AccountSettingsScreen | `lib/features/home/presentation/account_settings_screen.dart` |
| `recipeDetail` | `/recipe` | RecipeDetailScreen | `lib/features/nutrition/presentation/recipe_detail_screen.dart` |
| `nutritionCategory` | `/nutrition/category/:type` | CategoryRecipesScreen | `lib/features/nutrition/presentation/category_recipes_screen.dart` |
| `progressCalendar` | `/progress/calendar` | CalendarScreen | `lib/features/progress/presentation/calendar_screen.dart` |
| `progressSuggestions` | `/progress/suggestions` | SuggestionsScreen | `lib/features/progress/presentation/suggestions_screen.dart` |
| `progressBadges` | `/progress/badges` | BadgesScreen | `lib/features/progress/presentation/badges_screen.dart` |
| `nutritionDiscover` | `/nutrition/discover` | DiscoverRecipesScreen | `lib/features/nutrition/presentation/discover_recipes_screen.dart` |
| `nutritionFavorites` | `/nutrition/favorites` | FavoritesScreen | `lib/features/nutrition/presentation/favorites_screen.dart` |
| `admin` | `/admin` | AdminDashboardScreen | `lib/features/admin/presentation/admin_dashboard_screen.dart` |
| `referralLanding` | `/referral` | ReferralLandingScreen | `lib/features/referral/presentation/referral_landing_screen.dart` |

**Total: 18 named routes.**

### 3.2 Redirect rules (lines 78–126, evaluated on every navigation)

Order is significant — first match wins:

1. **Referral landing** (line 86) — `/referral` always allowed; survives all gates so deep-link redemption works pre-auth.
2. **First-time check** (lines 87–89) — if `prefs.isFirstTime == true`, force `/onboarding` except when already there.
3. **Session check** (lines 98–101) — if `Supabase.instance.client.auth.currentSession == null`, redirect to `/auth`. Gate uses `currentSession` (persisted Hive token cache), not `currentUser`, so cached-but-expired sessions stay in-app (Phase 88).
4. **Post-onboarding redirect** (lines 109–111) — on `/onboarding` AND has session → `/prediction` (defined route, but exit currently goes directly to `/paywall`; see §4 for the discrepancy).
5. **Auth screen redirect** (lines 112–114) — on `/auth` AND has session AND not anonymous → `/paywall`. Anonymous users may stay on `/auth` to upgrade.
6. **Admin gate** (lines 120–124) — `/admin` requires `app_metadata.role == 'admin'`; otherwise → `/dashboard`.

### 3.3 Deep links (`lib/core/services/deep_link_service.dart`)

**Schemes:** `formai://` (custom) + `https://formai.app/` (web/universal links).
**Cold start:** `getInitialAppLink()` (line 36) — replayed after router's first redirect pass.
**Warm start:** `uriLinkStream` (lines 47–56).
**Dispatch (lines 90–107):**
- `formai://r/<code>` or `https://formai.app/r/<code>` → `/referral?code=<code>` (survives auth + onboarding gates).
- `formai://workout/today` or `https://formai.app/workout/today` → `/workout` (gates apply).
- Unknown → `/` fallback.
- Phase 57 normalization (lines 122–133) splices custom-scheme host (`formai`) into pathSegments alongside web-app segments.

**Error recovery:** `app_router.dart:140, 308–350` — `errorBuilder` renders `_DeepLinkSplashScreen` on unmatched paths and self-recovers by deferring `context.go(dashboard)` ~200 ms so the link listener has time to resolve first.

### 3.4 Tab shell (`dashboard_screen.dart:206–270`)

`DashboardScreen` uses `IndexedStack` with 4 tabs + bottom nav.

| # | Label (TR) | English | Icon (off → on) | Widget | File |
|---|---|---|---|---|---|
| 0 | Antrenman | Workout | fitness_center_outlined → fitness_center | AntrenmanTab | `lib/features/home/presentation/widgets/antrenman_tab.dart` |
| 1 | Beslenme | Nutrition | restaurant_outlined → restaurant | NutritionTab | `lib/features/nutrition/presentation/nutrition_tab.dart` |
| 2 | Gelişim | Progress | insights_outlined → insights | **GelisimTab** | `lib/features/home/presentation/widgets/gelisim_tab.dart` |
| 3 | Profil | Profile | person_outline → person | ProfileTab | `lib/features/home/presentation/widgets/profile_tab.dart` |

**Default tab on launch:** index 0 (Antrenman).
**Badge celebration logic** (lines 98–173) — unlock dialogs only fire when current tab is Gelişim AND dashboard is the topmost route. Off-tab unlocks queue in `unlockedBadgesProvider \ celebratedBadgesProvider` until user lands on Gelişim. Uses `RouteAware` to defer celebrations while pushed routes (e.g., workout result overlay) cover dashboard.

---

## 4. ONBOARDING FLOW

**File:** `lib/features/onboarding/presentation/onboarding_screen.dart`
**State:** `wizardProvider` Riverpod `Notifier<WizardState>` (`lib/features/onboarding/providers/wizard_provider.dart`)
**Persistence:** SharedPreferences (`AppPreferences`) — keys: `sixpack.is_first_time`, `sixpack.user_metrics`, `sixpack.goal`.

### 4.1 Main flow — 12 steps, linear, no branching

| # | Widget | Question / Purpose | Interaction | Bundled asset |
|---|---|---|---|---|
| 1 | `_WelcomeStep` | Hook: "Vücudunu Yapay Zeka ile Şekillendir" | staggered fade-in (1.5 s), CTA "BAŞLA" | `photos/ilkkarşılamaanaekranarkaplanı.webp` |
| 2 | `_CoachIntroStep` | Coach typewriter: "Merhaba! Ben senin kişisel yapay zeka koçunum…" | typewriter @ 28 ms/char (~4 s), tap-to-skip; CTA enabled only after reveal | `merhababenseninkişiselyapayzekakoçunumyeniarkaplan.webp`, `kişiselyapayzekakoçfoto.webp` (avatar) |
| 3 | `_GenderStep` | "Cinsiyetin?" — Kadın / Erkek / Diğer | tap card → 1.5 s feedback banner → auto-advance | `cinsiyetseçimikadın.webp`, `cinsiyetseçimierkek.webp` |
| 4 | `_GoalStep` | "Hedefin ne?" — Göbek eritmek / Kas yapmak / Daha fit görünmek / Güçlenmek | tap → "🔥 Harika seçim!…" → auto-advance | `hedefinneSıkılaşmak.webp`, `hedefinneHacimKazanmak.webp`, `hedefinneSadeceSix-Pack.webp`, `hedef_guclenmek.webp` |
| 5 | `_ExperienceStep` (hybrid) | "Daha önce spor yaptın mı?" — 3 cards OR free-text | card → auto-advance; text → manual "DEVAM ET" | none |
| 6 | `_DailyMinutesStep` | "Günde ne kadar zaman ayırabilirsin?" — 10–15 / 20–30 / 45+ min | tap → 1.5 s feedback → auto-advance | none |
| 7 | `_ActivityStep` (hybrid) | "Günlük aktiviten?" — Masa başı / Hafif hareketli / Çok aktif OR text | card or text | `günlükaktivitenmasabaşı.webp`, `günlükaktivitenhafifhareketli.webp`, `günlükaktivitenneÇokAktif.webp` |
| 8 | `_PhysicalDataStep` | "Vücut bilgilerin" — three CupertinoPicker wheels | scroll wheels (age 18–80, height 120–220, weight 30–200) → tap "DEVAM" → 1.5 s "Metabolizmanı hesaplıyorum…" labor-illusion overlay → advance | none |
| 9 | `_PainPointStep` (hybrid) | "Seni en çok zorlayan ne?" — Motivasyon / Süreklilik / Ne yapacağımı bilmiyorum / Diyet OR text | card or text | none |
| 10 | `_AnalysisIllusionStep` | Cycles 5 phrases ("Vücudun analiz ediliyor…" → "Sana özel plan oluşturuluyor…") | rotating sweep gradient + counter-rotating sparkle, 1.2 s/phrase × 6 s; no input | generated graphics |
| 11 | `_DynamicReportStep` | "Kişisel AI Raporun" — generated assessment (BMI + daily kcal + multi-paragraph "AI DEĞERLENDİRMESİ" + 92 % confidence bar) | fade-in (1.4 s), copy from `AiPersonalizationEngine.generateReport()` | `kişiselyapayzekakoçfoto.webp` |
| 12 | `_PrePaywallSummaryStep` | "Bu plan sana özel oluşturuldu." — summary card (goal/duration/difficulty/weekly count) + 92 % trust bar | fade-in (900 ms), trust bar animates 1.1 s; CTA "PLANIMI GÖR" → `_finish()` | none |

**Progress header** (counts only steps 3–10): "N soru kaldı" → "Neredeyse bitti!".

### 4.2 Data collected (`WizardState` schema)

**Demographics (BMR/TDEE inputs):** `gender` (Female/Male/Other), `age` (18–80), `heightCm` (120–220), `weightKg` (30–200).
**Goal & program tuning:** `targetPhysique` (Tone/Bulk/SixPack — maps to token), `goal` (`belly_burn`/`muscle_gain`/`fitness_look`/`strength`), `currentPhysique` (Slim/Normal/Heavy — populated elsewhere), `activityLevel` (Sedentary/Light/Active), `dailyMinutes` (`10_15`/`20_30`/`45_plus`), `experienceLevel` (`none`/`occasional`/`regular`), `painPoint` (`motivation`/`consistency`/`no_idea`/`diet`).
**Free-text overrides** (set on hybrid steps): `activityDescription`, `experienceDescription`, `painPointDescription` — overwrite the corresponding card-token if present.

### 4.3 Deferred nutrition onboarding — 7 steps

**File:** `lib/features/nutrition/presentation/widgets/nutrition_onboarding_sheet.dart`
**Trigger:** first opening of Beslenme tab, gated by `hasCompletedNutritionPrefs`.
**Fields:** `dietPreference` (standart/vejetaryen/vegan/ketojenik), `allergies` (yok/kuruyemis/sut_urunleri/gluten), `mealFrequency` (2_ogun/3_ogun/4_ogun), `prepTime` (hizli/yavas), `nutritionGoal` (yag_yakimi/kas_kazanimi/dengeli), `waterIntake` (cok_az/orta/iyi), `tastePreference` (tatli/tuzlu/karisik).

**Total onboarding footprint: 12 critical-path + 7 deferred = 19 screens across two flows.**

### 4.4 Completion gate & exit (`_finish()` lines 165–217)

1. `appPreferencesProvider.saveUserMetrics(wizard.toJson())` → SharedPreferences `sixpack.user_metrics`.
2. `completeOnboarding(goal: targetPhysique?.name)` → sets `sixpack.is_first_time = false`.
3. Anonymous Supabase sign-in.
4. Route to `/paywall` (NOT `/prediction` — the prediction screen widget exists and the redirect rule references it, but the wizard exit bypasses it; Phase 60C decision documented in code).

### 4.5 Visual register

**Color tokens used in onboarding:** neon `#8E5BFF`, neonAccent `#4DA6FF`, neonDeep `#6A3DFF`, surface `#141028`, gradient backgrounds (black → `#1A0B3D`).
**Animations:** all native Flutter (`AnimationController`, `SlideTransition`, `FadeTransition`, custom painters for the analysis-illusion ring). No Lottie/Rive.
**Image strategy:** 10 high-res `.webp` precached on mount (in `didChangeDependencies`); missing assets fall back to neon gradient + icon placeholder, silently.

### 4.6 Structural observations (factual)

- **No autosave mid-onboarding.** State is in-memory only; killing the app between steps 1–11 returns user to step 1 on relaunch with no progress preserved. Persistence happens only at `_finish()`.
- **CupertinoPicker triple stack (step 8):** age + height + weight on one screen; dense on small devices.
- **1.5 s "Metabolizmanı hesaplıyorum…" delay** between step 8 confirmation and advance is a labor illusion (no actual computation).
- **Typewriter blocking (step 2):** CTA disabled during ~4 s reveal; `Geçmek için ekrana dokun` helper indicates skip.
- **No back button on steps 1–2.** Steps 3+ allow back nav with state preserved.
- **Gender option asymmetry:** Kadın + Erkek have illustrations; Diğer is icon-only.
- **`/prediction` route discrepancy:** route exists, redirect rule references it, but wizard exit goes directly to `/paywall`. Prediction screen is reachable via direct navigation but not the default exit path.

---

## 5. HOME / DASHBOARD SURFACES (PRIORITY)

The dashboard is the highest-priority surface per the brief. Two tabs comprise it: **Antrenman** (workout entry/discovery) and **Gelişim** (progress/analytics). Both tabs share the same scaffold in `dashboard_screen.dart`.

### 5.1 Antrenman tab — workout-focused entry

**File:** `lib/features/home/presentation/widgets/antrenman_tab.dart`

Top-to-bottom (ListView):

| Section | Lines | Content |
|---|---|---|
| 1. Header block | 152–153, ~20 px top padding | "FormAI" title + Pro button (neon) + Flame streak badge w/ count (`_AntrenmanHeader` 516–545; `_FlameStreakBadge` 589–635) |
| 2. Weekly Goal Card | 154–162, 14 px gap | "Haftalık Hedef" + 0/N completion + 7 date bubbles (Mon–Sun) + AI coach face + speech bubble (`weekly_goal_card.dart`) |
| 3. Personal program section header | 164–167, 26 px gap | "Kişisel Antrenman Programın" + tune icon |
| 4. Challenge Hero Card | 169–178, 28 px gap | Full-width 320 px tall card: bg image + gradient overlay, day number, progress bar, white "BAŞLA" button (`challenge_hero_card.dart` 12–195) |
| 5. Equipment Strip | 180–182, 28 px gap | "Ekipmanlı Egzersizler" + horizontal carousel of equipment-filtered plans (`equipment_strip.dart`) |
| 6. Region filter + cards | 184–195, 28 px gap | Category chip row (Core, Göğüs, Sırt, etc.) + dynamic ListView of regional plans + empty state (`_RegionalPlansList` 341–417) |

**Above-the-fold (first viewport):** items 1–3 + top of item 4 (Challenge Hero image + title visible, button below the fold).

**Primary CTA:** Challenge Hero "BAŞLA" — full-width white button on dark image overlay, ~240–280 px from top.

### 5.2 Gelişim tab — progress / analytics (most data-dense)

**File:** `lib/features/home/presentation/widgets/gelisim_tab.dart`
**Background:** radial gradient (dark mode: purple halo top; light mode: transparent scaffold).

Top-to-bottom (ListView lines 149–204), **9 sections**:

| # | Section | Lines | Content |
|---|---|---|---|
| 1 | Top Header | 152–156, 16 px pad | "Gelişim" + subtitle "İlerlemen bir bakışta" + streak pill (🔥 XX Günlük Seri, orange border) + share button (`_TopHeader` 370–452) |
| 2 | Program Stats Column | 158–162, 22 px gap | **Program Progress Card**: %XX / XX/30 days / animated bar / motivation copy + 72 px trophy ring. **Streak Card**: XX gün / "Serini bozma!" / 5-dot checklist + 62 px flame puck (`_ProgramStatsColumn` 515–537, `_ProgramProgressCard` 540–632, `_StreakCard` 680–795) |
| 3 | Sync / Offline / Complete gates | 169–176, 14 px gap | Skeleton shimmer (loading) / wifi-off + "TEKRAR DENE" (offline) / trophy emoji "Tebrikler!" (program complete) / **Today Task Card** (active state) |
| 3a | Today Task Card | `today_task_card.dart` 27–100 | "BUGÜNKÜ GÖREV" + dumbbell icon + "Gün XX – [Focus] + duration + level" + full-width neon-gradient CTA "ANTRENMANA BAŞLA"; Day > 3 routes to `/paywall` if not Pro |
| 4 | 30-Day Grid | 178–182, 24 px gap | "30 GÜNLÜK PROGRAM" header + "Takvimi Gör →" pill + 5×6 grid: pulsing-purple current day, green-check completed, amber rest, dim locked (`_DayGridSection` 810–852, `_DayGrid` 907–946, cell states 948–1175) |
| 5 | Three Stats Cards | 184–188, 24 px gap | **BU HAFTA** (7 gradient bars + Mon–Sun labels), **YAKILAN KALORİ** (smooth area line chart, kcal value), **ANTRENMAN** (waveform bars). All snap to current ISO week. Painters at 1357–1531. |
| 6 | Weekly Retrospective Card | 196, 22 px gap | Conditional: only renders on Sundays |
| 7 | AI Coach Card | 197, 22 px gap | "AI KÖÇ" + 45 px coach avatar (slow breathing scale) + greeting branched on streak state: ≥7 = "Şampiyon serisi devam ediyor!", streak=0 + maxStreak>0 = "Geri dönüş zamanı.", default = "Bugün hedeflerimize bir adım daha yaklaşıyoruz." + "Günlük Özet Dinle" audio button (`_AiCoachCard` 1551–1632) |
| 8 | Badges Section | 199–203, 22 px gap, 40 px bottom pad | "ROZETLERİN" + "Tümünü Gör →" + horizontal scroll of 5 hex-shaped badges (unlocked: gradient + glow; locked: dim + progress %). Examples: İlk 7 Gün, Disiplinli, Kalori Avcısı, 30 Gün Şampiyonu, HIIT Ustası (`_BadgesSection` 1894–1980, `_HexBadge` 1998–2067) |

### 5.3 Above-the-fold inventory (Gelişim, ~600 px)

1. Header (title + streak pill + share)
2. Program Progress Card (full)
3. Streak Card (full)
4. Today Task Card (full)
5. Top 2–3 rows of 30-day grid (~10–15 cells)

**Primary CTA "ANTRENMANA BAŞLA"** sits inside the Today Task Card at ~420–450 px from top — visible on first viewport on most phones, but below the day/focus/duration/level metadata block.

### 5.4 Data sources feeding home

| Provider | Source | Purpose |
|---|---|---|
| `workoutSessionProvider` | Supabase | 30-day plan + completion state |
| `workoutPlansProvider` | Supabase | Regional workout plans for category filter |
| `appPreferencesProvider` | SharedPreferences | maxStreak, userMetrics, nutrition prefs |
| `dailyMenuProvider` | Supabase | Today's nutrition plan (used by AI Coach summary) |
| `unlockedBadgesProvider` | Supabase | Real-time badge unlock set |
| `celebratedBadgesProvider` | Local state | Tracks which unlocks have been displayed |
| `macroTargetProvider` | Derived (nutrition) | Calorie target for AI Coach summary |
| `isProProvider` | RevenueCat (`monetization_provider.dart:173–177`) | Gate for Day 4+ tasks |

### 5.5 Empty states

**Day 0 (brand-new user):** sections present, but values zeroed: %0 progress, 0/30 days, 0 streak, all 5 dots empty, all 30 grid cells locked (rest days marked), stats cards minimal, AI Coach default copy, badges all locked + 0% progress.
**Offline:** `_ProgramOfflineCard` (wifi_off + "Bağlantı yok" + "TEKRAR DENE").
**Program complete:** `ProgramCompleteCard` (trophy emoji + "Tebrikler! 30 günlük programı tamamladın.").
**Loading:** Skeleton shimmer with sync icon (Gelişim); centered spinner (Antrenman) — pattern inconsistency.

### 5.6 Streak system

**Computation** (antrenman_tab.dart 200–210, gelisim_tab.dart 210–220): consecutive completed days from Day 1; breaks on first non-completed day. Rest days do NOT break streak.
**Display surfaces:** Antrenman header flame badge + Gelişim streak card (5-dot checklist, capped at 5).
**`maxStreak` watermark:** persisted in SharedPreferences; powers "comeback" AI Coach branch when current streak == 0 but maxStreak > 0.

### 5.7 Quick-start CTAs

| CTA | Label | Destination | Position | Visual | Gating |
|---|---|---|---|---|---|
| Antrenman Challenge | "BAŞLA" | `/plan-detail` | Hero card bottom | white-on-dark | Free Day 1–30 |
| Gelişim Today Task | "ANTRENMANA BAŞLA" | `/plan-detail` | Task card bottom | neon gradient | Day 1–3 free; Day 4+ → `/paywall` if not Pro |
| Equipment cards | chevron | `/plan-detail` | per card | gray puck | Free |
| Regional plans | chevron | `/plan-detail` | per card | gray circle | Free |

### 5.8 Home-screen widget bridge

**`WidgetSyncService`** (Phase 55) pushes 8 keys to iOS UserDefaults App Group + Android SharedPreferences: `task_name`, `subtitle`, `progress_percent`, `streak_count`, `completed_days`, `total_days`, `deep_link`, `timestamp`. Then rings WidgetKit / AppWidgetProvider update hooks.
**Native UIs:** `ios/FormAIWidget/` (SwiftUI), `android/app/src/main/kotlin/.../widget/` (Kotlin AppWidgetProvider).

### 5.9 Structural observations (factual)

- **Gelişim has 9 stacked sections.** All visible on a single tab.
- **Primary CTA buried behind metadata.** "ANTRENMANA BAŞLA" sits at ~420–450 px, below day/focus/duration/level descriptors.
- **Paywall gate decision at CTA tap.** Day 4+ users discover the gate by tapping; no pre-warning indicator on the CTA itself.
- **Antrenman vs Gelişim role overlap.** Both tabs offer workout entry. Antrenman emphasizes weekly goal + equipment filters; Gelişim emphasizes today's task + program progress.
- **Badge celebrations only fire on Gelişim.** Off-tab unlocks delay until user lands on Gelişim. No alert/visual signal that celebrations are pending.
- **Loading state UX inconsistency.** Gelişim reserves height with skeleton; Antrenman uses centered spinner.
- **Home-widget data drift risk.** WidgetSyncService is one-way; no in-app indicator of widget out-of-sync state.

---

## 6. MONETIZATION & PAYWALL FLOW

**Provider:** `lib/features/monetization/providers/monetization_provider.dart` (~239 lines)
**Screen:** `lib/features/monetization/presentation/paywall_screen.dart` (1601 lines)
**Auth modal:** `lib/features/auth/presentation/auth_modal_bottom_sheet.dart` (Phase 94 forced auth gate)

### 6.1 Plans & products

| Plan | RC package | RC product ID (auto-memory) | Position | Card height | Marketing |
|---|---|---|---|---|---|
| Monthly | `offerings.current.monthly` | `formai_pro_monthly` | left | 180 px | fallback ₺249,99 |
| Annual | `offerings.current.annual` | `formai_pro_annual` | center, **default** | 220 px | "POPÜLER" badge, 7-day trial inline badge, fallback ₺999,99, decoy "₺2.999,99 idi" strikethrough (line 1158, hardcoded) |
| 3-month | `offerings.current.threeMonth` | `formai_pro_3month` | right | 180 px | fallback ₺499,99 |

(Auto-memory note: old `_quarterly`/`_yearly` IDs are dead.)

**Entitlement ID:** `'FormAI Pro'` (case-sensitive, must match RC dashboard exactly, line 16).
**Default selection:** annual (line 36 `_selected = _Plan.yearly`).

### 6.2 Paywall layout (top-to-bottom)

| Element | Lines | Notes |
|---|---|---|
| Close X (top-right) | 315–319 | transparent circle |
| Hero section | 283 | gender-personalized: M/F = before/after composite + "30 Günlük Değişimin!" ribbon (786–901); Other/null = animated silhouette + radial gradient (971–1043) |
| Hero copy | 721–739 | "Kişiselleştirilmiş planınızı alın!" + subtitle |
| Social proof pill | 755–782 | "🔥 10.000+ kişi kullanıyor" |
| Plan cards row | 325–366 | 3-card grid, 230 px tall row |
| Skeleton price slots | 1196–1200 | shimmer while RC offerings load |
| "Şimdi ödeme yok!" green chip | 1433–1498 | between cards and CTA |
| Primary CTA | 368–464 | "₺0,00 karşılığında dene" + arrow, neon gradient; disabled until `_purchasesConfigured && offerings?.current != null` (line 244) |
| Restore button | 485–536 | text-only, spinner |
| Sandbox button | 467–482 | `kDebugMode` only — "[DEV] Premium'u Aç (Sandbox)" |
| Legal footer | 1500–1576 | 10.5pt grey, 0.55 alpha; ToS + Privacy links |

**Phase 95 dynamic pricing:** `package.storeProduct.priceString` is locale-formatted (₺ for tr-TR), populated from RC; skeleton until fetch resolves; fallback prices used only when fetch resolves with null package (RC misconfigured).

### 6.3 Paywall triggers — every entry point

| Trigger | File:Line | Context |
|---|---|---|
| Post-email-login | `auth_screen.dart:51–53` | `pushReplacement(paywall)` |
| Post-OAuth | `auth_screen.dart:176` | controller alias |
| Post-onboarding | `prediction_screen.dart:176` | "Planın seni bekliyor" pulsing CTA |
| Today Task card (Day 4+) | `today_task_card.dart:107` | `if (!isPro && day > kFreeDayLimit)` |
| Plan-detail day tile (Day 4+) | `plan_detail_screen.dart:312` | `_onDayTap` when `isLocked` |
| Regional / equipment plan cards | `plan_detail_screen.dart:1089` | "PRO İLE KİLİDİ AÇ" |
| Profile settings tile | `profile_tab.dart:266` | "FormAI Premium" |
| Antrenman PRO badge | `antrenman_tab.dart:554` | header pill |

**Analytics:** `paywallViewed()` fired on mount (line 72).

### 6.4 Gating logic

- **Free day limit:** `AppConstants.freeDayLimit = 3` (`app_constants.dart:30`). Day 1–3 free; Day 4–30 require Pro.
- **Ad-hoc plans:** Regional/equipment plans entirely Pro-gated. Exercise list dimmed to 35 % opacity when locked (`plan_detail_screen.dart:918`); CTA text swaps "PLANI BAŞLAT" → "PRO İLE KİLİDİ AÇ" with lock icon (1131–1138).
- **Debug override:** SharedPreferences flag `sixpack.monetization.dev_pro_override` — sandbox button sets it; bypasses RC entirely (lines 306–309).
- **`isProProvider`** (lines 173–177):
  ```dart
  final isProProvider = Provider<bool>((ref) {
    final snapshot = ref.watch(subscriptionProvider).value;
    if (snapshot == null) return false;
    return snapshot.isDeveloperOverride || snapshot.isPro;
  });
  ```

### 6.5 Trial mechanics

- Hardcoded UI copy: "7 gün ücretsiz dene" (yearly card inline badge + footer disclosure 1554–1556).
- Trial NOT modeled in app code — assumed configured via RevenueCat / store dashboards.
- Auto-converts after trial ends per store rules.

### 6.6 Purchase flow (`_purchase()` lines 548–586)

1. User taps CTA → fetch package for selected plan (550–551).
2. Validate non-null package; toast on null (553–559).
3. `_busy = true`, CTA → spinner (562).
4. `Purchases.purchasePackage(package)` (563).
5. Check entitlements for `'FormAI Pro'` (`monetization_provider.dart:104`).
6. Update `subscriptionProvider` notifier `isPro: true` (line 106).
7. Analytics: `purchaseSucceeded(productId: ...)` (108).
8. Outcomes: success → "Premium aktif edildi!" toast → 600 ms delay → close (570–573); cancel → silent; not-entitled → "Ödeme tamamlandı ama Premium henüz aktifleşmedi…" + suggest restore (577–582); error → "Satın alma başarısız oldu…" (584).
9. **On close**, RC alias call: if user authenticated, `aliasRevenueCatWithCurrentUser()` (650–664) links RC customer ID to Supabase UUID.

### 6.7 Phase 94 forced-auth gate

- Anonymous users on paywall are intercepted before purchase by `auth_modal_bottom_sheet.dart`.
- Bottom sheet is **non-dismissible** (`barrierDismissible: false`, line 61).
- Single-fire latch `_authGateShown` (line 45) prevents re-trigger on state re-emissions.

### 6.8 Restore (`_restore()` lines 588–606)

`Purchases.restorePurchases()` → check entitlements → update provider → toast (restored / nothing / error). Disabled until `_purchasesConfigured && offerings?.current != null`.

### 6.9 Structural observations (factual)

- **Three actionable surfaces above fold:** primary CTA (line 292), restore link (294), close X (top-right).
- **Double-gating on CTA:** disabled if `_purchasesConfigured == false` OR `offerings?.current == null`.
- **Phase 96 first-click race fix:** connectivity listener re-fetches offerings on offline → online transition (150–163).
- **Yearly card is 220 px vs 180 px** for monthly/quarterly — visual prioritization beyond the badge.
- **Decoy reference price** (₺2.999,99 strikethrough) on yearly is hardcoded marketing copy, not derived from a real prior price.
- **Footer fine print** is 10.5pt at 0.55 alpha — small target for legal disclosure inspection.
- **Regional-plan teaser dimming** is 35 % on the exercise list while header/CTA stay 100 % — visible-but-blurred upsell pattern.
- **600 ms post-purchase delay** before close lets async RC alias call complete before navigation.

---

## 7. DESIGN SYSTEM & VISUAL REGISTER

### 7.1 Color palette (`lib/core/theme/app_colors.dart`)

**Brand neons:**
| Token | Hex | Usage |
|---|---|---|
| `neon` | `#8E5BFF` | primary purple — borders, focus, primary CTAs |
| `neonAccent` | `#4DA6FF` | blue-violet — workout accents, badge halos, gradient pairs |
| `neonDeep` | `#6A3DFF` | deeper purple — vertical gradient bottom stops, AI coach avatar rings |
| `cyberCyan` | `#00F0FF` | bright cyan — workout camera HUD, post-workout trophy overlay |
| `neonGreen` | `#39FF14` | bright neon — progress CTAs, on-track macro bars |

**Semantic (lines 42–73):** `success #22C55E`, `danger #FF4D6D`, `orange #F97316`, `orangeOnLight #B45309` (Phase 53 WCAG AA), `amber #FFBA4D`, `pink #FF4DDB`.
**Macro bars (lines 75–84):** `protein #4DA6FF` (= neonAccent), `carbs #FF4DDB` (= pink), `fat #EAFF00`.
**Dark surfaces (lines 86–102):** `darkBg #0B0B12`, `surface #0F0F14`, `surfaceBorder #1E1E26`, `inactive #1C1C24`.
**Light surfaces (Phase 53, lines 104–130):** `lightBg #F7F8FA`, `lightSurface #FFFFFF`, `lightSurfaceBorder #E2E5EA`, `lightTextPrimary #111118`, `lightTextSecondary #565B66` (5.07:1 contrast on lightSurface).

### 7.2 Typography

**Source:** system fonts (no Google Fonts imports). Material 3 ColorScheme.fromSeed seeds defaults.
**Hierarchy:** body white-on-dark / charcoal-on-light; metadata 0.55 alpha on dark; share-template captions are explicit pixel sizes (36–72 px headers @ weights 800–900, letter-spacing 2–8 px).
**Conventions:** all-caps Turkish labels for dashboard sections ("PROGRAMIMIN", "GÜN", "SERİ", "YENİ ROZET", "BUGÜNKÜ GÖREV", "ROZETLERİN", "BU HAFTA", "YAKILAN KALORİ").

**Standard toast typography snippet** (`top_toast.dart:140–144`):
```dart
TextStyle(
  color: widget.foreground,
  fontSize: 13,
  fontWeight: FontWeight.w800,
  letterSpacing: 0.2,
)
```

### 7.3 Spacing & sizing tokens

**Padding patterns:** `EdgeInsets.fromLTRB(20, 16, 20, 18)` (compact card), 12/14/16/18–20 px standard, 24 px full-screen centering.
**Radius:** 6 px skeleton lines, 8 px small, 12–14 px cards/buttons/exercise rows, 16–18 px large surfaces, 999 px pill toasts.
**Gap/spacing:** 8–10 (tight columns), 12 (standard separators), 16–24 (padding blocks).
**Elevation/blur:** `blurRadius 18–24` for neon halos; `spreadRadius 0.5–1` for soft shadows.
**Shimmer period:** 1400 ms.

### 7.4 Shared widget inventory (`lib/core/widgets/`)

| Widget | File | Purpose |
|---|---|---|
| `SkeletonBox` | `skeleton_loader.dart:32` | rounded shimmer rect; w/h/radius configurable |
| `SkeletonLine` | `skeleton_loader.dart:62` | text-line placeholder, 0.7 widthFactor for ragged-right |
| `RecipeGridSkeleton` | `skeleton_loader.dart:89` | 2-col, 6 cards default, 252 px mainAxisExtent |
| `DayGridSkeleton` | `skeleton_loader.dart:152` | 5×6 muted squares matching Gelişim grid |
| `ExerciseListSkeleton` | `skeleton_loader.dart:176` | stack of 64 px placeholder rows for plan-detail |
| `BrandedMediaFallback` | `branded_media_fallback.dart:16` | purple-blue gradient + "F" mark / "FormAI" wordmark fallback for broken images |
| `ErrorCard` | `error_card.dart:6` | cyan-bordered error surface w/ optional retry; compact / full-screen modes |
| `TopToast` | `top_toast.dart:13` | top-anchored notification; slide + fade; replaces previous toast |
| `CachedImage` | `cached_image.dart` | network image w/ disk + memory cache (Phase 40) |
| `ShareProgressTemplate` | `share_templates.dart:39` | 1080×1920 (story) / 1080×1080 (square) off-screen progress badge |
| `ShareBadgeTemplate` | `share_templates.dart:106` | off-screen badge unlock share card |

### 7.5 Visual register cues (snippets, code-only, no editorial)

**Brand-mark gradient (`branded_media_fallback.dart:31–34, 89–96`):**
```dart
static const Color _bgTop = Color(0xFF221145);
static const Color _bgBottom = Color(0xFF0D0622);
static const Color _accent = Color(0xFF8E5BFF);
static const Color _accentSecondary = Color(0xFF4DA6FF);

gradient: const LinearGradient(
  colors: [_accent, _accentSecondary],
  begin: Alignment.topLeft, end: Alignment.bottomRight,
)
```

**Error-card neon glow (`error_card.dart:34–38`):**
```dart
boxShadow: [BoxShadow(color: _neon.withValues(alpha: 0.18), blurRadius: 18)]
```

**SnackBar neon hairline (`app_theme.dart:75–97, 141–164`):**
```dart
shape: RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(14),
  side: BorderSide(color: AppColors.neon.withValues(alpha: 0.45), width: 1),
)
```

**Share-template radial glow orbs (`share_templates.dart:213–230`):**
```dart
gradient: RadialGradient(
  colors: [color.withValues(alpha: 0.45), Colors.transparent],
)
```

### 7.6 Iconography

**Material Icons only** (`flutter/material.dart`). No Cupertino, no custom SVGs in core widgets/theme. UI is Material 3.

### 7.7 Animations

**No Lottie / Rive files** detected in repo. All animations are native Flutter:
- `AnimationController` + `Tween` + `SlideTransition` / `FadeTransition` (toasts, sheets, fades)
- Custom painters (analysis-illusion sweep ring, area chart, waveform bars)
- `shimmer` package for skeleton sweeps (1400 ms)
- `BackdropFilter` for occasional blur (paywall auth modal backdrop)

### 7.8 Asset inventory

**`/photos/` (root) — 51 files (.webp + 1 PNG):**
- `app_icon.png` (1.38 MB)
- Onboarding hero / coach: `ilkkarşılamaanaekranarkaplanı.webp`, `merhababenseninkişiselyapayzekakoçunumyeniarkaplan.webp`, `kişiselyapayzekakoçfoto.webp`
- Plan hero (gender variants): `kişiselleştirilmişplanda30.günERKEK.webp`, `…KADIN.webp`
- Allergies (4): `allergy_dairy.webp`, `allergy_gluten.webp`, `allergy_nuts.webp`, `allergy_none.webp`
- Diet (4): `diet_keto.webp`, `diet_vegan.webp`, `diet_vegetarian.webp`, `diet_standard.webp`
- Water (3): `water_high.webp`, `water_medium.webp`, `water_low.webp`
- Meal frequency (3): `meals_2.webp`, `meals_3.webp`, `meals_4.webp`
- Gender (3): `cinsiyetseçimierkek.webp`, `cinsiyetseçimikadın.webp`, `cinsiyet_diger.webp`
- Goal (4): `hedef_guclenmek.webp`, `hedefinneHacimKazanmak.webp`, `hedefinneSıkılaşmak.webp`, `hedefinneSadeceSix-Pack.webp`
- Activity (3): `günlükaktivitenmasabaşı.webp`, `günlükaktivitenhafifhareketli.webp`, `günlükaktivitenneÇokAktif.webp`
- Filenames are **Turkish**, naming reflects domain context.

**`/photos/meals/` — 298 .webp recipes** (Phase 69, ~280 KB each VP8 WebP). Naming: `[ingredient]_[dish].webp` (e.g. `acili_domates_corbasi`, `avokadolu_tam_bugday_tost`, `bonfileli_burrito`).

**`/photos/workouts/` — 32 .webp plan thumbnails** (Phase 70, ~95 KB each). Naming: `[muscle_group]_[goal/type].webp` (e.g. `arms_explosive_super`, `core_steel_abs`, `chest_full_growth_burst`).

**`/Beslenme-Photos/` — 15 .jpeg supplementary meal references** (legacy folder, not referenced in pubspec assets — appears unused at runtime).

**`asosystem/` — separate web admin panel** (TS / Vite / Tailwind, NOT a Flutter dependency). Contains ASO screenshot prompts (`prompts/screenshot_*.txt`) but no bundled store screenshots.

**No dedicated `Screenshots/` directory or root-level marketing imagery** detected for App Store / Play Store listings.

---

## 8. WORKOUT FLOW & POSE DETECTION

**Module:** `lib/features/workout/`
**Structure:** `presentation/`, `data/`, `domain/services/`, `models/`, `providers/`, `services/`

### 8.1 Screens

- `workout_camera_screen.dart` — live camera feed + ML Kit pose detection + rep counting + voice TTS feedback during exercise.
- `plan_detail_screen.dart` — 30-day program overview, hero image by muscle group, day-by-day breakdown, Pro gating.
- `pose_painter.dart` — canvas overlay rendering detected pose landmarks (neon cyan skeleton).

### 8.2 Notable widgets

- `exercise_guide_player.dart` — video demo + Turkish instructions, "HAZIRLAN!" prep overlay
- `rest_overlay.dart` / `preparation_overlay.dart` / `session_complete_overlay.dart` — inter-exercise UI
- `workout_control_panel.dart` — rep counter, timer, form warnings ("diz bükülü tut")
- `workout_back_button.dart` — exit w/ unsaved-progress safeguard

### 8.3 Data flow

- Reads from Supabase `exercises` table (catalog of 41 movements, cached locally via SharedPreferences — Phase 50A migration from static literals).
- `WorkoutRepository` — plan generation (ML algorithm balances difficulty/muscle groups), completion tracking, offline fallback (stub 30 rest days).
- Providers: `workoutPlansProvider` (regional templates), `equipmentPlansProvider`, `workoutSessionProvider` (active day/rep state).
- Models: `Exercise` (rep/time-based, sets, difficulty, targetMuscle), `WorkoutDay`, `WorkoutPlan`.

### 8.4 Services

- `PoseDetectorService` — wraps ML Kit BlazePose. Streaming mode @ ~15 FPS (66 ms throttle interval) + single-flight gate to prevent thermal throttling / OOM on mid-range devices.
- `PoseAnalyzer` + exercise-specific subclasses (`CrunchAnalyzer`, `ChestAnalyzer`, etc.) — form validation + rep detection.
- `AnalyzerFactory` — dispatches to correct analyzer by exercise type. (~16 analyzer services total.)

### 8.5 Voice feedback

- `flutter_tts` integrated into `WorkoutCameraScreen`.
- Coach speaks exercise descriptions at start + form warnings during reps.
- Form warnings debounced per occurrence to avoid haptic spam during sustained bad posture.

### 8.6 Workout flow span

5 distinct screens between tap-start and exercise begin: prep countdown (3 s) → camera feed → per-set rest/resume → session completion overlay → return to dashboard.

---

## 9. PROGRESS, NUTRITION, AUTH, REFERRAL, FEEDBACK, ADMIN

### 9.1 Progress (`lib/features/progress/`)

- **Screens:** `badges_screen.dart` (12+ achievement badges: first_step, disciplined, halfway, 30-day_victory, calorie_hunter, etc.), `calendar_screen.dart` (30-day program calendar), `suggestions_screen.dart` (3 contextual AI Coach tips).
- **Widgets:** `badge_unlock_dialog.dart`, `weekly_retrospective_card.dart`.
- **Data:** reads `workoutSessionProvider` + `appPreferencesProvider`. `badgeUnlocksProvider` is an immutable Set<String>; diffs previous→next to fire celebrations.
- **Calendar cell states:** COMPLETED (green check), ACTIVE (pulsing neon ring), REST (amber coffee), UPCOMING (dim), OUT_OF_PROGRAM (grey).
- **Note:** badge predicates duplicated between `gelisim_tab.dart` and `badges_screen.dart` — not centralized.

### 9.2 Nutrition (`lib/features/nutrition/`)

- **Structure:** `presentation/`, `data/`, `domain/` (models + services), `providers/`.
- **Screens:** `nutrition_tab.dart` (collapsible hero: calorie ring + macro bars + AI insight + next-best-meal CTA), `recipe_detail_screen.dart`, `discover_recipes_screen.dart` (paginated 2-col grid), `category_recipes_screen.dart` (breakfast/lunch/dinner/snack/dessert + "Pratik & Ekonomik" budget tag), `favorites_screen.dart` (saved recipes + shopping-list export — Phase 56 Lite).
- **Widgets:** `meal_plan_timeline.dart` (accordion: breakfast → lunch → dinner → snack), `next_best_meal_card.dart`, `ai_insight_banner.dart`, `nutrition_onboarding_sheet.dart`, `recipe_tags.dart`.
- **Data:** Supabase `recipes` table; `NutritionRepository` cursor-paginates 20/page (Phase 48). Providers: `nutritionRepositoryProvider`, `recipesProvider`, `filterChipsProvider`, `dailyMenuProvider`, `favorite_recipes_provider`, `nutritionCalculatorProvider`. Models: `Recipe`, `PlannedMeal`, `MacroTarget`, `DailyMealSlot`. Services: `NutritionCalculatorService`, `NextBestMealService`.
- **Macro ring palette:** green on-track, amber low, red over.

### 9.3 Auth (`lib/features/auth/`)

- **Screens:** `auth_screen.dart` (email/password + mode toggle + Google/Apple OAuth), `auth_modal_bottom_sheet.dart` (Phase 94 forced-auth gate before paywall purchase, non-dismissible).
- **Data:** Supabase auth (email/password, Google Sign-In, Sign in with Apple PKCE).
- **Providers:** `authStateProvider` (streams Supabase auth state), `currentUserProvider`, `isAdminProvider` (reads `app_metadata.role == 'admin'` JWT claim — Phase 50B).
- **Anon → real upgrade:** triggers `Purchases.logIn` to sync RevenueCat identity.
- **Password reset:** assumed Supabase standard flow (no custom UI surfaced in code review).

### 9.4 Referral (`lib/features/referral/`)

- **Screen:** `referral_landing_screen.dart` (Phase 54 deep-link handler).
- **Service:** `ReferralService` — 6-char code from 32-char alphabet `23456789ABCDEFGHJKMNPQRSTUVWXYZ` (excludes lookalikes 0/O/1/I/L); ~1.07 B possible codes.
- **`getOrCreateCode()`:** generates locally → persists to SharedPreferences + Supabase `user_metrics.referral_code`; retries on UNIQUE collision.
- **`redeem(code)`:** calls Supabase `redeem_referral` RPC; errors map to enum (invalidFormat, invalidCode, selfReferral, alreadyRedeemed, notAuthenticated, network).
- **Two roles for landing screen:** (1) pre-auth pitch "1 ay ücretsiz Pro", (2) post-auth auto-redeem or "already redeemed".
- **Code persistence trick:** stashed in SharedPreferences pre-auth; auto-redeemed at end of onboarding once user has a real `auth.uid()`.

### 9.5 Feedback (`lib/features/feedback/`)

- **Screen:** `feedback_sheet.dart` (bottom sheet with subject dropdown — bug/suggestion/question — + message textarea + submit).
- **Service:** `FeedbackService` dual-transport fallback: (1) Supabase `feedback` table insert (user_id, subject, message, app_version, platform, os_version), (2) `mailto:` fallback if Supabase fails.
- Transport enum (`supabase` / `mailto`) returned to UI for toast wording ("Mesajın iletildi." vs "Mail uygulaman açıldı.").
- Device context auto-stamped: PackageInfo + Platform + OS version.

### 9.6 Admin (`lib/features/admin/`)

- **Screen:** `admin_dashboard_screen.dart` (Phase 50B/50D) — responsive: permanent sidebar (≥600 px) or hamburger Drawer (<600 px). Sections: dashboard / recipes / exercises.
- **Widgets:** `admin_exercise_form.dart`, `admin_recipe_form.dart`.
- **Access control:** route `/admin` gated by `isAdminProvider` (JWT claim); router redirect bounces non-admins to `/dashboard`. Defensive re-check on widget build for mid-flight claim loss.

---

## 10. CROSS-CUTTING DATA & INFRA

### 10.1 Supabase tables (referenced in code)

| Table | Reader / Writer | Purpose |
|---|---|---|
| `exercises` | `WorkoutRepository` | exercise catalog (Phase 50A migration from literals) |
| `recipes` | `NutritionRepository` | meal database (298 photos in `/photos/meals/`) |
| `user_progress` | `workoutSessionProvider` | per-day workout completion |
| `user_metrics` | `appPreferencesProvider` mirror, `ReferralService` | onboarding metrics + referral_code |
| `feedback` | `FeedbackService` | user submissions |
| Badge unlocks | `unlockedBadgesProvider` | real-time unlock set (table name not surfaced in this map) |

### 10.2 Provider ecosystem (Riverpod 3.3)

- `appRouterProvider` owns go_router + global RouteObserver (Phase 48.1).
- `authStateProvider` streams Supabase auth state; `currentUserProvider` derived.
- `appPreferencesProvider` = SharedPreferences-backed cache (completed days, plans, preferences, referral codes).
- `subscriptionProvider` + `isProProvider` (RevenueCat).
- `workoutSessionProvider`, `workoutPlansProvider`, `equipmentPlansProvider`.
- `nutritionRepositoryProvider`, `recipesProvider`, `dailyMenuProvider`, `macroTargetProvider`, `favorite_recipes_provider`.
- `unlockedBadgesProvider`, `celebratedBadgesProvider`.
- `connectivityProvider` (Phase 89, from `connectivity_plus`).

### 10.3 Services

- `AnalyticsService` (PostHog) — milestone events: paywall_viewed, purchase_succeeded, referral_redeemed, feedback_submit, badge_unlock.
- `ConnectivityService` (Phase 89) — checked before auth/nutrition network calls; offline fallback for workout (stub 30-day rest plan if catalog empty).
- `WidgetSyncService` — pushes 8-key payload to home-screen widget (iOS UserDefaults App Group + Android SharedPreferences).
- `DeepLinkService` — Phase 54 + Phase 57 normalization.
- `PoseDetectorService`, `PoseAnalyzer` (+ ~16 subclasses).

### 10.4 Local storage keys (SharedPreferences)

| Key | Type | Purpose |
|---|---|---|
| `sixpack.is_first_time` | bool | onboarding gate |
| `sixpack.user_metrics` | JSON | wizard.toJson() snapshot |
| `sixpack.goal` | string | targetPhysique.name |
| `sixpack.monetization.dev_pro_override` | bool | debug-only Pro unlock |
| `auth.was_anonymous` | bool | recovery flag for lost anon sessions |
| (referral code) | string | local copy of user's referral_code |
| (max streak) | int | watermark for "comeback" coach copy |
| `hasCompletedNutritionPrefs` | bool | gates nutrition onboarding sheet |

---

## 11. CONFIGURATION & OBSERVABILITY

### 11.1 Environment

- `.env` loaded via `flutter_dotenv` — bundled as asset (`pubspec.yaml:135`), `_envSafe()` helper logs missing keys non-fatally.
- `.env.example` present at repo root (placeholder template).

### 11.2 Crash reporting / analytics

- **Sentry** — `sentry_flutter 9.6` with try/catch around `SentryFlutter.init` (Phase 94 resilience). Captures async + sync framework + platform errors via the four bootstrap layers.
- **PostHog** — `posthog_flutter 5.3` with 5 s init timeout. Funnel + churn events via `AnalyticsService`.
- **iOS ATT** — `app_tracking_transparency 2.0.6` for the 14.5+ tracking prompt.

### 11.3 Build / release tooling

- Android keystore: regenerated Phase 90 (`upload-cert.pem` at root).
- Package rename: Phase 90 → `com.formai.app`, Phase 92 → `com.emredogan.formaifit` (globally unique).
- `change_app_package_name` package available for further renames.
- Launcher icons: `flutter_launcher_icons 0.14.1`, source `photos/app_icon.png`.

### 11.4 Existing root-level reports (NOT generated by this Phase 1 — pre-existing)

- `STARTUP_FLOW_ANALYSIS.md` — bootstrap analysis (Phase 94 era).
- `RELEASE_BLACK_SCREEN_ROOT_CAUSE_REPORT.md` — black-screen incident root cause.
- `RELEASE_FIXES_APPLIED.md` — fix log.
- `RELEASE_HARDENING_CHECKLIST.md` — release checklist.
- `ASO_VISUAL_MASTERPLAN.md` (88 KB) — App Store Optimization visual masterplan.
- `GOOGLE_PLAY_MASTERPLAN_TR.md` (64 KB) — Google Play release masterplan (Turkish).
- `PROGRESS_SECTION_MASTERPLAN.md` (97 KB) — Gelişim section deep-dive.
- `docs/` contents: `AI_CONTEXT_REPORT.md`, `MASTER_LAUNCH_ROADMAP.md`, `MONETIZATION_LAUNCH_GUIDE.md`, `PROJECT_DOCUMENTATION.md`, `ROADMAP.md`.

These pre-existing docs are user-facing strategy + release artifacts, NOT UX research output. The `/reports/` tree is the new, distinct UX intelligence output produced by this multi-agent system and intended to coexist with them.

---

## 12. STRUCTURAL OBSERVATIONS — CONSOLIDATED

These are factual-only notes surfaced by the discovery pass. Each is a candidate for downstream-phase analysis but is not itself a recommendation.

### Bootstrap & resilience
- 4-layer error guard + Sentry try/catch + 8 s/5 s init timeouts is the user's Phase 94 release-resilience contract; do not unwrap (auto-memory pin).
- RevenueCat is intentionally deferred until onboarding-finish or sign-in.
- Anonymous user recovery silently creates a new anon ID if the prior session was wiped beyond refresh — old user's RLS-locked rows become orphaned. Acceptable per the user's design but a structural reality.

### Navigation
- 18 named routes; gates layered as referral-allow → first-time → session → post-onboarding → post-auth → admin.
- Deep links survive auth/onboarding gates only for referral redemption; workout/today applies gates.
- `errorBuilder` self-recovers unmatched paths to dashboard with 200 ms defer.

### Onboarding
- 12-step linear flow with 3 hybrid steps (card-or-text).
- No mid-flow autosave; persistence only at `_finish()`.
- `/prediction` route exists but is bypassed by current exit (goes directly to `/paywall`).
- 19 total screens including the 7-step deferred nutrition sheet.

### Dashboard
- Gelişim has 9 stacked sections; primary CTA at ~420–450 px (below day-metadata block).
- Antrenman + Gelişim both offer workout entry — role overlap.
- Free-tier paywall gate at Day 4+ is decided at CTA tap, not signaled pre-tap.
- Badge celebrations only fire on Gelişim — off-tab unlocks delay until user lands there.
- Loading state UX inconsistent (skeleton vs centered spinner).

### Monetization
- 3 plans (monthly, 3-month, annual); annual default + highlighted + 7-day trial badge.
- 7 paywall trigger surfaces.
- Forced-auth gate (Phase 94, non-dismissible bottom sheet) blocks anon RC purchases.
- Decoy "₺2.999,99 idi" reference price on annual is hardcoded marketing copy.
- Footer fine print: 10.5pt @ 0.55 alpha.

### Design system
- Cyber/neon palette over near-black surfaces; light mode added Phase 53 with WCAG AA tweaks.
- Material Icons exclusively; system fonts; no Lottie/Rive.
- 51 root + 298 meal + 32 workout = 381 .webp assets; filenames Turkish.
- `Beslenme-Photos/` legacy folder (15 .jpeg) appears unreferenced at runtime.
- No bundled store-listing screenshots in repo (asosystem/ has prompt files only).

### Workout
- Pose detection at ~15 FPS w/ thermal-throttle guard.
- 5 screens between tap-start and exercise begin.
- ~16 exercise-specific analyzer services dispatched via factory.

### Cross-cutting
- Badge predicates duplicated between Gelişim tab + badges screen.
- Streak resets to 0 on first non-completed non-rest day; `maxStreak` watermark powers comeback messaging.
- Home-widget data bridge is one-way (no in-app out-of-sync indicator).

---

## 13. FILE INVENTORY (key paths only)

### Core infrastructure
- `lib/main.dart` — bootstrap (Phase 94 4-layer guards)
- `lib/core/routing/app_router.dart` — go_router + redirects (~350 lines)
- `lib/core/services/deep_link_service.dart` — formai:// + https://formai.app/
- `lib/core/services/connectivity_service.dart` — Phase 89
- `lib/core/services/widget_sync_service.dart` — home-widget bridge
- `lib/core/services/analytics_service.dart` — PostHog wrapper
- `lib/core/theme/app_colors.dart` — palette (Phase 53 light mode)
- `lib/core/theme/app_theme.dart` — Material 3 ThemeData
- `lib/core/widgets/skeleton_loader.dart` — Phase 49 shimmer primitives
- `lib/core/widgets/branded_media_fallback.dart`
- `lib/core/widgets/error_card.dart`
- `lib/core/widgets/top_toast.dart`
- `lib/core/widgets/cached_image.dart` — Phase 40
- `lib/core/widgets/share_templates.dart` — Phase 54

### Features (top-level)
- `lib/features/onboarding/presentation/onboarding_screen.dart` (12 steps)
- `lib/features/onboarding/presentation/prediction_screen.dart`
- `lib/features/onboarding/providers/wizard_provider.dart`
- `lib/features/auth/presentation/auth_screen.dart`
- `lib/features/auth/presentation/auth_modal_bottom_sheet.dart` (Phase 94)
- `lib/features/auth/providers/auth_provider.dart`
- `lib/features/home/presentation/dashboard_screen.dart` (4-tab IndexedStack)
- `lib/features/home/presentation/widgets/antrenman_tab.dart`
- `lib/features/home/presentation/widgets/gelisim_tab.dart` (priority surface, ~2000+ lines)
- `lib/features/home/presentation/widgets/profile_tab.dart`
- `lib/features/home/presentation/widgets/today_task_card.dart`
- `lib/features/home/presentation/widgets/weekly_goal_card.dart`
- `lib/features/home/presentation/widgets/challenge_hero_card.dart`
- `lib/features/home/presentation/widgets/equipment_strip.dart`
- `lib/features/home/presentation/account_settings_screen.dart`
- `lib/features/monetization/presentation/paywall_screen.dart` (1601 lines)
- `lib/features/monetization/providers/monetization_provider.dart` (~239 lines)
- `lib/features/workout/presentation/workout_camera_screen.dart`
- `lib/features/workout/presentation/plan_detail_screen.dart`
- `lib/features/workout/presentation/pose_painter.dart`
- `lib/features/workout/data/workout_repository.dart`
- `lib/features/workout/providers/workout_provider.dart`
- `lib/features/workout/services/pose_detector_service.dart`
- `lib/features/nutrition/presentation/nutrition_tab.dart`
- `lib/features/nutrition/presentation/recipe_detail_screen.dart`
- `lib/features/nutrition/presentation/discover_recipes_screen.dart`
- `lib/features/nutrition/presentation/category_recipes_screen.dart`
- `lib/features/nutrition/presentation/favorites_screen.dart`
- `lib/features/nutrition/presentation/widgets/nutrition_onboarding_sheet.dart`
- `lib/features/nutrition/data/nutrition_repository.dart`
- `lib/features/progress/presentation/badges_screen.dart`
- `lib/features/progress/presentation/calendar_screen.dart`
- `lib/features/progress/presentation/suggestions_screen.dart`
- `lib/features/progress/presentation/widgets/badge_unlock_dialog.dart`
- `lib/features/progress/presentation/widgets/weekly_retrospective_card.dart`
- `lib/features/referral/presentation/referral_landing_screen.dart`
- `lib/features/referral/services/referral_service.dart`
- `lib/features/feedback/presentation/feedback_sheet.dart`
- `lib/features/feedback/services/feedback_service.dart`
- `lib/features/admin/presentation/admin_dashboard_screen.dart`
- `lib/features/admin/presentation/widgets/admin_exercise_form.dart`
- `lib/features/admin/presentation/widgets/admin_recipe_form.dart`

---

## 14. SCOPE FOR NEXT PHASES

This map is the foundation. Downstream phases will use it as follows:

| Phase | Agents | Surfaces of focus | Inputs from this map |
|---|---|---|---|
| 2. Product Analysis | Product Structure Analyzer + Visual UI Analyzer | full app | §3, §5, §7 |
| 3. Psychology | User Psychology Agent + Fitness Behavior Science Agent | onboarding, dashboard, streak system, paywall trial | §4, §5.6–5.7, §6.5 |
| 4. Market Intelligence | Competitor Intelligence Agent | external (Freeletics, Hevy, Fitbod, Centr, BetterMe, NTC, etc.) | (no internal map needed) |
| 5. UX Optimization | Data-Driven UX Agent + Mobile UX Agent + Dashboard Intelligence Agent (priority) | priority on §5 (Gelişim tab) | §5, §6 |
| 6. Feasibility | Implementation Validator | mapped against Flutter stack | §1, §10, §11 |
| 7. Final Synthesis | Final Strategy Synthesizer | merge all | all |

Phase 1 is **complete and locked**. No further structural mapping in subsequent phases unless a discrepancy with this document is discovered — in which case the discrepancy is reported back here as an erratum.

---

## 15. ERRATA — Discrepancies surfaced by downstream phases

This section is appended as later phases discover claims here that need correction or extension. Each erratum has a source (which phase report flagged it).

### Phase 2 — Product Structure Analyzer

- **E-1.** §3.2 (redirect rule 4) and §4.4 describe `/prediction` as "bypassed" by the wizard exit. Phase 2 grep extends this: `/prediction` is **fully orphan** — no in-app surface routes to it; the rule itself is dormant. Detail: `reports/phase-2-product-analysis/PRODUCT_STRUCTURE_REPORT.md`.
- **E-2.** §6.3 lists **7 paywall trigger surfaces**. Correct count is **8** — post-OAuth path is structurally distinct from post-email-login (different code path in `auth_screen.dart`). Detail: `PRODUCT_STRUCTURE_REPORT.md`, `USER_FLOW_ANALYSIS.md`.
- **E-3.** §5.6 says streak is displayed in **2 places**. Actual count is **4**: Antrenman flame badge, Gelişim header pill, Gelişim Streak Card, Profile stats tile — with **2 duplicate `_streakOf` helpers** in code (DRY violation).

### Phase 2 — Visual UI Analyzer

- **E-4.** Brand-purple drift: §7.1 documents `neon = #8E5BFF` as canonical. Reality has **two purples**: `#8E5BFF` (token) **and** `#8B5CF6` (Tailwind purple-500), the latter inlined as a hex literal in 5 high-traffic files (Gelişim, Today Task, Calendar, Suggestions, Badges). Token compliance ratio measured at **~36%** (88 `AppColors.*` refs vs 158+ matching hex literals). Detail: `VISUAL_UI_REPORT.md`, `DESIGN_CONSISTENCY_REPORT.md`.
- **E-5.** §7.1 lists `neonAccent` and `orangeOnLight` as live tokens; both are **dead tokens** (no callers).
- **E-6.** §7.6 claims "Material Icons exclusively." Contradicted: an emoji-based icon system is also in use (paywall + onboarding feedback banners use emoji glyphs as iconography).
- **E-7.** §5.3 places Gelişim primary CTA at "~420–450 px from top." Measured value is **~470–520 px** (atlas underestimated by ~50 px).
- **E-8.** §7 omits the unshared `_SoftCard` widget — repeatedly redefined in dashboard surfaces instead of being lifted to `lib/core/widgets/`.
- **E-9.** §7.1 attributes cyber-cyan only to "workout camera HUD, post-workout trophy overlay." Auth screens (sign-in / sign-up) use cyber-cyan as the primary brand color, not neon purple — design language drift at the conversion gate.
- **E-10.** §6.2 paywall hero (Other/null gender path) uses `Icons.accessibility_new` (Material wheelchair icon) as the hero illustration. Atlas described it as "animated silhouette + radial gradient" — accurate at structural level, but the silhouette is the wheelchair-accessibility glyph, not a custom asset.
- **E-11.** Type system: 31 distinct `fontSize` values across the codebase, 509 inline `TextStyle` definitions, exactly 1 use of `Theme.of(context).textTheme.*`. No coherent type scale.
- **E-12.** Light-mode parity (Phase 53) breaks: 195 hardcoded `Colors.white*` references + 7 `Colors.black` Scaffolds — these don't switch with theme.

### Phase 3 — User Psychology + Fitness Behavior Science

- **E-13.** **Brand-engine contradiction.** §4 atlas treats "30 günde karın kası" as the program promise. `lib/features/onboarding/services/ai_personalization_engine.dart:14–17, 77, 226–234` actually projects "12 Hafta" / "12 haftada" in the generated AI report, and downstream estimated-results copy. Two different program durations ship in the same app. Detail: `reports/phase-3-psychology/USER_PSYCHOLOGY_REPORT.md` P-02/P-25 cluster, `FITNESS_BEHAVIOR_REPORT.md` B-06.
- **E-14.** Streak count: atlas §5.6 said 2 surfaces; erratum E-3 raised to 4; Phase 3 raises to **5** — adds the home-screen widget (atlas §5.8), the most public guilt signal.
- **E-15.** §4.2 lists `experienceLevel` (`none`/`occasional`/`regular`) and `targetPhysique` (Tone/Bulk/SixPack) as wizard fields persisted to `WizardState`. Phase 3 grep finds these fields are **collected but not consumed** by the workout-plan generator — every user receives a `tone, beginner` plan regardless of inputs. `targetPhysique` is also never explicitly set during the wizard (only via `goal` token). Atlas implies the generator uses these inputs; it does not. Detail: `FITNESS_BEHAVIOR_REPORT.md` B-01/B-05.
- **E-16.** Phase 2 F-02 framed the Day-4 paywall as the friction point. Phase 3 corrects the day arithmetic: Day 4 is a scheduled **rest** day, so the gate first fires on Day 5. The compounding factor is that the 48h streak-warning notification, the rest-day blank, and the paywall converge across Days 4–5. `lib/core/services/notification_service.dart:299–331`. Detail: `MOTIVATION_DECAY_ANALYSIS.md`.
- **E-17.** Atlas §5.6 says `maxStreak` "powers comeback messaging." Phase 3 finds it is consumed by **exactly one** surface — a single AI Coach copy branch — and is otherwise invisible to the user despite being the most emotionally-loaded value in SharedPreferences. Detail: `EMOTIONAL_DESIGN_STRATEGY.md`.
- **E-18.** Pose detection (atlas §8) has **no audio-only fallback**. The camera path is mandatory, which excludes body-image-anxious users, post-partum users, and shared-living-space users. Detail: `FITNESS_BEHAVIOR_REPORT.md` B-03.

### Phase 4 — Competitor Intelligence

- **E-19.** **Decoy reference price is a compliance risk, not a UX preference.** Atlas §6.1 + Phase 2 finding P-08 noted the hardcoded "₺2.999,99 idi" strikethrough on the yearly paywall card. Phase 4 escalates this: BetterMe was ASA-flagged in 2024 for the same shape of misleading-discount claim, and EU Omnibus + App Store / Google Play guidelines require that "was" prices reflect a real prior charged price during a documented reference window. Treat removal as compliance, not taste. Detail: `reports/phase-4-market-intelligence/COMPETITOR_WEAKNESSES.md` ERRATA-CM-1.
- **E-20.** **Cycle-awareness is not a differentiator in TR.** Phase 3 floated cycle-aware programming as a possible blue-ocean play. Phase 4 confirms BetterMe ships this in TR with ~55 K weekly actives — it is **table stakes**, not whitespace. The Phase 5+ framing should be "match BetterMe's cycle awareness *plus* the stack BetterMe lacks (camera form coaching, honest AI, beginner Day 1)." Detail: `MARKET_GAP_ANALYSIS.md` MG-1.
- **E-21.** **The "30 günde karın kası" tagline is structurally limiting** vs FormAI's actual capabilities. Phase 4's six blue-ocean territories describe a broader product: a Turkish AI fitness coach for everyone — beginner-first, audio-or-camera, with Day 31+ continuity, in a quiet cohort. Marketing-positioning Phase 5+ work should consider broadening framing without losing the SixPack hook. Detail: `BLUE_OCEAN_OPPORTUNITIES.md`.
- **E-22.** **Gymshark Training removed Android support in 2025** (now iOS-only). Atlas didn't track this — temporary structural reduction in TR Android competitive pressure. Detail: `COMPETITOR_MATRIX.md` per-app profile.

---

**END OF PROJECT_STRUCTURE_MAP.md** (originally written 2026-05-08; errata appended through 2026-05-09 from Phase 2 + Phase 3 + Phase 4 reports)
