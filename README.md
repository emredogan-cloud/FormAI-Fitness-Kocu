<div align="center">

# SixPack AI · FormAI

**An AI-powered, camera-driven fitness coach. Built in Flutter, served from Supabase, deployed across iOS and Android.**

[![Flutter](https://img.shields.io/badge/Flutter-3.22%2B-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.4%2B-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Postgres%20%2B%20Edge-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com)
[![Riverpod](https://img.shields.io/badge/Riverpod-3.x-1A73E8)](https://riverpod.dev)
[![ML Kit](https://img.shields.io/badge/Google%20ML%20Kit-BlazePose-4285F4?logo=google&logoColor=white)](https://developers.google.com/ml-kit/vision/pose-detection)
[![RevenueCat](https://img.shields.io/badge/RevenueCat-Subscriptions-FF6B6B)](https://www.revenuecat.com)
[![Terraform](https://img.shields.io/badge/Infra-Terraform%20%2B%20AWS-7B42BC?logo=terraform&logoColor=white)](https://www.terraform.io)
[![CI](https://img.shields.io/badge/CI-GitHub%20Actions-2088FF?logo=githubactions&logoColor=white)](.github/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

</div>

---

## Overview

**SixPack AI** (marketed as **FormAI**) is a cross-platform mobile fitness application that pairs a 30-day personalised training programme with **on-device, camera-based pose analysis** for live rep counting and form correction. The app ships from a single Flutter codebase to iOS and Android, with Turkish-language onboarding, a Supabase-backed content catalogue, RevenueCat-managed subscriptions, and native home-screen widgets / iOS Live Activities for the active session.

The project is engineered for production: a four-layer release-build error guard catches every class of bootstrap failure, every user table is RLS-gated end-to-end, observability is wired through Sentry and PostHog with KVKK/GDPR consent and PII scrubbing, and the build pipeline is tuned to produce arm64-only debug APKs in ~7 s of warm incremental build time.

> **Status — pre-launch.** ~61 KLOC of Dart across 177 source files, organised feature-first under `lib/`. The 138-exercise catalogue is modelled, seeded, and routed through 8 specialised pose analyzers.

---

## Highlights

| Capability | What it actually does |
|---|---|
| **On-device pose AI** | Google ML Kit BlazePose feeds a per-exercise `PoseAnalyzer` (Crunch, Plank, LegRaise, RussianTwist, BicycleCrunch, MountainClimber, FlutterKick, SilentHold). Counts reps, scores form, and triggers TR voice cues in real time. |
| **30-day adaptive plan** | A pure-Dart `WorkoutGeneratorService` builds the schedule from onboarding answers (goal, equipment, body feeling, difficulty). Cached in `SharedPreferences`, regenerated on profile change. |
| **Subscription + entitlements** | RevenueCat client-side, mirrored to Postgres via a Deno Supabase Edge Function. RLS-protected `pro_entitlements` is the server-side source of truth. |
| **Native engagement surfaces** | iOS WidgetKit bundle, Android `AppWidgetProvider`, iOS Live Activities + Dynamic Island for the in-progress workout. Flutter owns lifecycle; native code owns presentation. |
| **Observability** | Sentry crash + breadcrumbs (PII-scrubbed `beforeSend`), PostHog typed event facade, App Tracking Transparency, KVKK/GDPR consent gate before any event fires. |
| **Resilient bootstrap** | `runZonedGuarded` + `FlutterError.onError` + `PlatformDispatcher.onError` + a branded `ErrorWidget.builder`. Guarantees `runApp` is reached even when every dependency below it is broken. |
| **Content ops pipeline** | Web-only `/admin` route gated by Supabase `app_metadata.role = 'admin'`. Live recipe + exercise CRUD with image upload to Supabase Storage, no mobile redeploy needed. |
| **Viral loop** | Share-to-story PNG renderer (1080×1920 / 1080×1080), referral codes, badge unlocks, weekly retrospective card, year-in-review. |

---

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                  Flutter Client (iOS + Android)              │
│                                                              │
│  Presentation  ─── Material 3, GoRouter 17, theme-mode-aware │
│       ▲                                                      │
│       │  ref.watch                                           │
│       ▼                                                      │
│  Providers     ─── Riverpod 3.x (Notifier / AsyncNotifier)   │
│       ▲                                                      │
│       ▼                                                      │
│  Domain        ─── WorkoutGenerator, NutritionCalculator,    │
│                    NextBestMeal, PoseAnalyzer hierarchy      │
│       ▲                                                      │
│       ▼                                                      │
│  Data          ─── Repositories (Supabase + SharedPrefs)     │
│                                                              │
└──────────────────────────────────────────────────────────────┘
            │             │              │             │
            ▼             ▼              ▼             ▼
   ┌────────────┐ ┌─────────────┐ ┌──────────────┐ ┌─────────┐
   │  Supabase  │ │ RevenueCat  │ │ Sentry +     │ │ AWS S3  │
   │  Postgres  │ │   IAP / RC  │ │ PostHog SaaS │ │ +       │
   │  Auth/Stor │ │   Webhook   │ │              │ │ CloudFr │
   │  Edge Fns  │ │  → Postgres │ │              │ │ (Legal) │
   └────────────┘ └─────────────┘ └──────────────┘ └─────────┘
            │
            ▼
   ┌────────────────────────────────────────┐
   │ Native extensions                      │
   │  • Kotlin AppWidgetProvider (Android)  │
   │  • SwiftUI Widget Bundle (iOS)         │
   │  • SwiftUI Live Activity (Dynamic Isl.)│
   └────────────────────────────────────────┘
```

### Layered conventions inside `lib/`

Feature-first directories (`auth`, `onboarding`, `workout`, `nutrition`, `progress`, `monetization`, `referral`, `feedback`, `admin`, `home`), each repeating the same internal slices:

```
features/<feature>/
├── data/              # Repositories, Supabase adapters, local cache
├── domain/            # Pure Dart services & value objects (no Flutter)
├── models/            # Plain data classes
├── providers/         # Riverpod providers (state + invalidation)
├── services/          # Feature-scoped services (e.g. pose analyzers)
└── presentation/      # Screens + widgets, watches providers only
```

Cross-cutting concerns live in `lib/core/` (routing, theme, motion primitives, services, widgets, utils).

### Cold-start sequence

`main.dart` boots through a `_BootGate` widget in a fixed order so a single missing dependency cannot black-screen the app:

1. Portrait-lock system chrome
2. Install global error handlers (`FlutterError`, `PlatformDispatcher`, `ErrorWidget.builder`)
3. Load `.env` (tolerated to fail — `dotenvLoaded` flag rides through to the boot UI)
4. `SentryFlutter.init` wrapped in a try/catch around the options builder
5. `SharedPreferences.getInstance()`
6. `Supabase.initialize` (8 s timeout)
7. PostHog (`AnalyticsService.init`, 5 s timeout)
8. Native bridges: `WidgetSyncService`, `WorkoutLiveActivityService`
9. RevenueCat is **deferred** to the post-auth path so the splash never blocks on a platform-channel handshake.

---

## Tech Stack

**Mobile client**
- Flutter 3.22+ / Dart 3.4+
- Riverpod 3.3.1 (state) · GoRouter 17.2.1 (navigation)
- Material 3 with theme-mode persistence
- Cached network image + flutter_cache_manager for media

**On-device AI / camera**
- `camera` 0.12 · `google_mlkit_pose_detection` 0.14
- 8 rule-based pose analyzers, 138-exercise catalogue
- `flutter_tts` for Turkish voice coaching
- `wakelock_plus` to hold the screen during sessions

**Backend & data**
- Supabase Postgres (4 migrations + 14 SQL patches)
- Row-Level Security on every user table
- Supabase Storage buckets (`exercises`, `recipes_images`, `exercises_media`)
- Deno Edge Function for the RevenueCat webhook
- Optional CDN rewrite via `CDN_BASE_URL`

**Authentication**
- Supabase Auth — email/password, Google Sign-In, Sign in with Apple
- Admin role via `app_metadata.role = 'admin'` JWT claim

**Monetization**
- RevenueCat (`purchases_flutter` 8.1) with three SKUs: `formai_pro_monthly`, `formai_pro_3month`, `formai_pro_annual`
- Server-side mirror table (`pro_entitlements`) for RLS-gated Pro endpoints

**Observability**
- Sentry (`sentry_flutter` 9.6, traces sample 0.2, PII-scrubbed `beforeSend`)
- PostHog (`posthog_flutter` 5.3) behind a typed facade — no string-event call sites
- App Tracking Transparency for iOS 14.5+

**Native extensions**
- `home_widget` 0.7 → Kotlin `AppWidgetProvider` + SwiftUI `WidgetBundle`
- `live_activities` 2.4 → SwiftUI Live Activity (Dynamic Island)
- App Group `group.app.formai.shared` bridges Dart ↔ Swift on iOS

**Infrastructure**
- Terraform-managed AWS S3 + CloudFront for legal page hosting
- GitHub Actions for CI (format / analyze / test + Android APK build)

---

## Project Structure

```
SixPack-AI/
├── lib/
│   ├── main.dart                        # _BootGate + FormAIApp shell
│   ├── core/
│   │   ├── routing/                     # GoRouter + auth/admin/age gates
│   │   ├── services/                    # Analytics, deep links, notifications,
│   │   │                                #   live activity, widget sync, share
│   │   ├── theme/                       # Material 3 + theme-mode provider
│   │   ├── motion/                      # Hand-coded animation primitives
│   │   ├── widgets/                     # Skeleton loaders, branded fallbacks
│   │   └── utils/                       # Logger, haptics, helpers
│   ├── features/
│   │   ├── auth/                        # Email + OAuth + session listener
│   │   ├── onboarding/                  # Cinematic 5-act wizard + AI engine
│   │   ├── workout/
│   │   │   ├── services/                # 8 pose analyzers + factory
│   │   │   ├── domain/                  # WorkoutGeneratorService
│   │   │   └── presentation/            # Camera screen + pose painter
│   │   ├── nutrition/                   # Recipes, macros, next-best-meal
│   │   ├── progress/                    # Calendar, badges, year-in-review
│   │   ├── monetization/                # Paywall, churn survey, RC client
│   │   ├── referral/                    # Referral codes + redeem flow
│   │   ├── feedback/                    # In-app feedback service
│   │   ├── admin/                       # Web-only CRUD dashboard
│   │   └── home/                        # Dashboard tabs
│   └── scripts/                         # Dev-time Dart utilities
│
├── android/
│   └── app/src/main/kotlin/…/widget/    # AppWidgetProvider (home-screen tile)
├── ios/
│   ├── FormAIWidget/                    # SwiftUI WidgetKit bundle
│   └── FormAILiveActivity/              # SwiftUI Live Activity / Dynamic Island
│
├── supabase/
│   ├── migrations/                      # 4 numbered migrations (RLS-first)
│   ├── functions/revenuecat-webhook/    # Deno edge function
│   └── sql/                             # Seed + backfill patches
│
├── terraform/
│   └── legal_pages/                     # S3 + CloudFront for terms/privacy
│
├── web/public/                          # terms.html + privacy.html (legal)
├── scripts/                             # dev-run.sh, dev-attach.sh, diagnostics
├── docs/                                # Architecture, ops, roadmap, audits
├── photos/                              # Onboarding + exercise WebP assets
├── test/ + integration_test/            # Unit + on-device E2E
└── .github/workflows/                   # ci.yml + flutter_ci.yml
```

---

## Local Development Setup

**Prerequisites**

| Tool | Version |
|---|---|
| Flutter SDK | 3.22.0 or later (Dart ≥ 3.4) |
| Android SDK | API 34 / NDK 25, Java 17 (Temurin) |
| Xcode | 15+ for iOS / Live Activities |
| Supabase CLI | Latest, for migrations + Edge Functions |
| Terraform | ≥ 1.5 (only if deploying legal pages infra) |
| Deno | ≥ 1.40 (only if iterating on Edge Functions) |

**1 · Clone and install dependencies**

```bash
git clone https://github.com/emredogan-cloud/SixPack-AI-30-Gunde-Karin-Kasi.git
cd SixPack-AI-30-Gunde-Karin-Kasi
flutter pub get
```

**2 · Configure environment**

```bash
cp .env.example .env
# Fill in SUPABASE_URL, SUPABASE_ANON_KEY, RevenueCat keys, etc.
```

`.env` is loaded by `flutter_dotenv` at boot and bundled as a Flutter asset. A blank `.env` is tolerated — Supabase calls will fail soft and the boot screen surfaces the configuration error.

**3 · Apply Supabase schema (optional — only if you own a Supabase project)**

```bash
supabase link --project-ref <your-ref>
supabase db push                      # applies supabase/migrations/*.sql
supabase functions deploy revenuecat-webhook
supabase secrets set REVENUECAT_WEBHOOK_SECRET=<shared-secret>
```

**4 · Run on device**

```bash
# Fast dev cycle (arm64-only debug APK, hot-reload attached)
scripts/dev-run.sh

# Reconnect to an already-installed build without reinstalling
scripts/dev-attach.sh

# iOS
open ios/Runner.xcworkspace
```

The `dev-run.sh` wrapper builds `--split-per-abi --target-platform android-arm64` for a 203 MB APK (≈37 % smaller than the universal APK), disables MIUI Play Protect verification on the device for the install window, and re-enables it afterwards. Warm incremental builds land in ≈7 s.

---

## Environment Variables

| Variable | Purpose | Required |
|---|---|---|
| `SUPABASE_URL` | Project URL (`https://<ref>.supabase.co`) | Yes |
| `SUPABASE_ANON_KEY` | Public anon JWT | Yes |
| `REVENUECAT_IOS_KEY` | RC public iOS SDK key | iOS only |
| `REVENUECAT_ANDROID_KEY` | RC public Android SDK key | Android only |
| `SENTRY_DSN` | Sentry crash-reporting DSN | Production |
| `POSTHOG_API_KEY` | PostHog write key | Production |
| `POSTHOG_HOST` | EU or US endpoint | Production |
| `CDN_BASE_URL` | Optional CDN that fronts Supabase Storage. Falls back to Supabase public URLs when empty. | No |

Edge Function secrets (set via `supabase secrets set`):

| Variable | Purpose |
|---|---|
| `REVENUECAT_WEBHOOK_SECRET` | Shared secret matching the RC dashboard Authorization header |
| `SUPABASE_SERVICE_ROLE_KEY` | Service-role JWT — used only inside the Edge Function, never shipped client-side |

---

## Build & Deployment

### Android

```bash
flutter build apk --release --split-per-abi --target-platform android-arm64
flutter build appbundle --release
```

ProGuard / R8 keeps are configured for Supabase + kotlinx-serialization. The release build signs with `android/app/upload-keystore.jks`; the keystore password lives in `android/key.properties` (gitignored).

### iOS

Open `ios/Runner.xcworkspace` in Xcode. The workspace contains three targets:

- **Runner** — the Flutter shell
- **FormAIWidget** — SwiftUI WidgetKit bundle
- **FormAILiveActivity** — Dynamic Island Live Activity

All three share the App Group `group.app.formai.shared` for the home-widget bridge.

### Web (admin only)

```bash
flutter build web --release
```

The web build exposes only the `/admin` route — the mobile-only screens are guarded by a platform check. Host the output behind any static host that can enforce HTTPS + a Supabase admin-claim CORS allowlist.

### Supabase Edge Functions

```bash
supabase functions deploy revenuecat-webhook
```

### Legal pages (Terraform)

```bash
cd terraform/legal_pages
terraform init
terraform apply
```

Provisions an S3 bucket + CloudFront distribution serving `web/public/terms.html` and `web/public/privacy.html` with TLS terminated on the default `*.cloudfront.net` cert. CloudFront prices at `PriceClass_100` (NA + EU edges only).

---

## Infrastructure

| Component | Where | Notes |
|---|---|---|
| App database | Supabase Postgres | 4 migrations (`user_progress`, `user_metrics`, `pro_entitlements`, `admin_storage_rls`) |
| RLS | All user tables | `auth.uid() = user_id` policies; admin role via JWT claim |
| Object storage | Supabase Storage | Buckets: `exercises`, `recipes_images`, `exercises_media` |
| Server-side IAP | Deno Edge Function | RevenueCat webhook → `pro_entitlements` upsert with replay protection (`last_event_id`) |
| Legal hosting | AWS S3 + CloudFront | Terraform-managed; HTTPS-only, 5-minute cache |
| CI | GitHub Actions | Format / analyze / test on every PR; APK build on push |

---

## Security

- **No secrets in source.** `.env`, GCP service-account JSON, signing keystores, and the upload cert are all gitignored. The Python miner script that embeds a RapidAPI key is explicitly excluded from version control.
- **RLS-first.** Every user-scoped table enables RLS and ships with `select_own / insert_own / update_own / delete_own` policies before its first row is inserted.
- **Server-side entitlements.** Subscription state is mirrored from RevenueCat into Postgres by a service-role Edge Function. The client never trusts itself on Pro gating — RLS-protected endpoints check `pro_entitlements`.
- **PII scrubbing on observability.** Sentry's `beforeSend` nulls `user.email`, `user.ipAddress`, and `user.data`. Events default to anonymous.
- **KVKK / GDPR consent gate** sits between age verification and onboarding. No PostHog event fires and no Sentry crash forwards until the user has explicitly opted in.
- **Predictive back gesture** + system-back guards (`PopScope`) prevent accidental loss of wizard progress.
- **ML Kit availability probe** at runtime — pose detection degrades to a non-camera workout flow on forks without Google Play Services.
- **Network security config** on Android pins HTTPS-only for production endpoints.

---

## Performance Optimisations

- **Build pipeline** — `--split-per-abi --target-platform android-arm64` cuts APK size 37 % and saves a matching slice of dexopt time on every install. Gradle JVM tuned to `-Xmx4G` after Phase 117 caught a 4.9 GB swap regression.
- **Bootstrap budget** — Supabase init capped at 8 s, PostHog at 5 s. RevenueCat init is deferred until after first auth.
- **Image cache** — `cached_network_image` everywhere; `flutter_cache_manager` promoted to a direct dep so exercise videos share the disk cache.
- **Asset hygiene** — non-recursive `photos/` asset declaration; reference imagery routed to `docs/reference-imagery/` to keep the APK lean (caught a 4.6 MB regression in Phase 127).
- **Skeleton loaders** — `shimmer`-driven placeholders replaced spinners across recipe grids, the 30-day grid, and plan-detail lists.
- **Pose detector stream mode** — single allocation per session; portrait-lock prevents the tensor re-alloc that previously froze low-end devices on rotation.

---

## CI/CD

Two GitHub Actions workflows under `.github/workflows/`:

- **`ci.yml`** — runs on every push to `main` and every PR. Steps: setup Flutter, install deps, create empty `.env`, `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test`.
- **`flutter_ci.yml`** — broader trigger (`main`, `staging`, `feature/*`). Adds a `flutter build apk --debug` smoke build on top of the analyze + format gate.

CI never has access to production secrets — a blank `.env` is created in-job so the analyzer is satisfied without leaking real keys.

---

## Testing Strategy

| Layer | Where | What it covers |
|---|---|---|
| Unit | `test/` | Pure-Dart services (generator, calculator, analyzers) |
| Widget | `test/` | Critical screen rendering + provider wiring |
| Integration | `integration_test/` | On-device end-to-end flows (camera-mocked) |
| Manual smoke | `scripts/dev-run.sh release` | Pre-commit release sanity check |

Run the full suite with `flutter test` (CI does the same). For on-device runs, `flutter test integration_test/`.

---

## Roadmap

The launch backlog is tracked in `docs/MASTER_LAUNCH_ROADMAP.md`. The current pre-launch checklist covers:

- Production RevenueCat dashboard wiring and product approval
- Sentry + PostHog production DSNs + EU project routing
- Supabase production SQL apply + storage policy verification
- Hosted privacy/terms URLs propagated to Play Console + App Store Connect
- Localization pass for English-market expansion (currently TR-only)
- Optional Rive-backed living-coach avatar (interface already adapter-shaped — see `LivingCoachAvatar` docstring)

---

## Contributing

This repository is part of a personal portfolio and is not currently accepting external contributions. For licensing or commercial inquiries, contact via the email in [`pubspec.yaml`](pubspec.yaml).

Engineering guidelines that apply to every diff land in [`CLAUDE.md`](CLAUDE.md): think before coding, simplicity first, surgical changes, goal-driven execution.

---

## License

Released under the [MIT License](LICENSE).

---

<div align="center">

**Built by [Emre Doğan](https://github.com/emredogan-cloud)** — Cloud Architecture · SaaS Engineering · Mobile · AI Systems

</div>
