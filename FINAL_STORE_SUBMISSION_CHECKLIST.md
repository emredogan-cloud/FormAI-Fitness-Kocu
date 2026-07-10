# FINAL STORE SUBMISSION CHECKLIST — FormAI (Fitness Koçu)

**Date:** 2026-07-10 · **Repo baseline:** branch `prisk/phase-1-tests` @ `a9a8f4e` — re-verified today: `flutter analyze` 0 issues · **293/293 tests pass** · line coverage ~28.7% · Flutter 3.41.9 (stable, 2026-04-29) · version `1.0.0+13` · TR-only locale.
**Companion doc:** `FINAL_STORE_SUBMISSION_ROADMAP.md` (execution phases referencing the IDs below).

**Status legend**
- ✅ **COMPLETE** — implemented and verified in this repo (evidence cited).
- 🔧 **IMPROVEMENT** — works/passes today but should be improved before or shortly after submission.
- ⛔ **BLOCKER** — will prevent submission, cause rejection, or make a shipped feature dishonest. Must be resolved.
- 🌐 **EXTERNAL** — cannot be completed inside this repo/machine: requires macOS/Xcode, store consoles, prod DB, physical devices, legal counsel, or a user decision.
- 🔎 **VERIFY** suffix — the item is believed fine but must be confirmed by the stated method (device test, console screen, or official page) before submission.

**Grounding rules** — every item below is grounded in (a) the current App Review Guidelines / Play policy center (Play facts verified against official pages on 2026-07-10; Apple facts from stable guideline text, with date-sensitive items explicitly marked VERIFY), and (b) this repository at `a9a8f4e` with `file:line` evidence. Locally verified today: analyze/tests, **16 KB ELF alignment of the release AAB (PASS)**, and the **merged release manifest** permission set.

---

## 0. EXECUTIVE SUMMARY

**Android (Google Play):** near-ready. targetSdk 36 already exceeds the Aug 31 2026 API-36 deadline; 16 KB page-size compliance **verified locally today (PASS)**; signing, R8, permissions, deletion flow, paywall disclosures, consent flow are in place. Remaining work is a small set of code fixes (mic permission strip, backup rules, notification icon), listing-asset refresh, and console/process work (12-tester closed-testing gate is the calendar critical path if the account is personal).

**iOS (App Store):** structurally behind. The iOS project has **never been built** — no Podfile/`pod install`, entitlements and privacy manifest not wired into the Xcode project, Google Sign-In iOS config missing, widget/Live-Activity Swift sources have no targets, stock white launch screen, deployment target 13.0 too low for ML Kit. All of this needs a macOS/Xcode environment (🌐). Code-side flows (paywall, deletion, consent, SIWA UI) are already iOS-aware.

**Blocker inventory (must clear before first submission):**

| ID | Blocker | Store | Where |
|---|---|---|---|
| A2 | Strip merged `RECORD_AUDIO` (mic) from release manifest | Play (+Apple honesty) | code, trivial |
| I1 | Create Podfile + run `pod install`; first iOS build | Apple | 🌐 macOS |
| I2 | Raise iOS deployment target (13.0 → ≥ 15.5 for ML Kit pods) | Apple | code + macOS |
| I3 | Wire `Runner.entitlements` (Sign in with Apple ⇒ guideline 4.8, App Groups) | Apple | 🌐 Xcode |
| I4 | Bundle `PrivacyInfo.xcprivacy` into the app (currently not in build phase) | Apple | 🌐 Xcode |
| I5 | Google Sign-In iOS config (`GIDClientID` + reversed URL scheme + `GOOGLE_IOS_CLIENT_ID`) | Apple | code + console |
| I6 | Decide + execute: widget/Live-Activity extension targets or descope for v1 | Apple | 🌐 Xcode / decision |
| P3 | Reconcile support/DSR mailbox (`support@formai.app` vs `formaisupport@proton.me`) | Both | user decision + policy edit |
| P13 | Remove GCP service-account private key from disk; rotate it | Both (security) | local + GCP console |
| LG1 | Legal-entity name/address on privacy/terms pages (KVKK Art.10 + store trader info) | Both | user/legal |
| GP-set | Play Console setup incl. Data safety, Health apps declaration, IARC, closed-testing gate | Play | 🌐 console |
| AS-set | ASC setup incl. Paid Apps agreement, subscription products with first binary, App Privacy, new age rating | Apple | 🌐 console |
| X1 | Apply migrations 006 (delete_user) + 007 (referrals) to prod Supabase; verify delete round-trip | Both | 🌐 prod DB |

Everything else below is ✅ COMPLETE (with evidence) or 🔧 IMPROVEMENT (won't block, will improve approval odds/quality).

---

## 1. BUILD & PLATFORM — ANDROID

### [A1] Target/compile SDK 36 (Android 16) — ✅ COMPLETE
- **What/why:** Play requires new apps/updates to target API ≥ 35 today and **API ≥ 36 by Aug 31, 2026** (verified 2026-07-10, developer.android.com/google/play/requirements/target-sdk + policy 11926878). Submitting below target kills visibility and blocks updates after the deadline.
- **State:** `targetSdk = compileSdk = 36` via Flutter 3.41.9 defaults (`android/app/build.gradle.kts:32,61`); minSdk 24; NDK 28.2; AGP 8.11.1; Kotlin 2.2.20; Gradle 8.14. Already beyond the deadline requirement.
- **Verify:** `grep -A2 targetSdk android/app/build.gradle.kts` + merged manifest check (done 2026-07-10).

### [A2] Strip plugin-merged `RECORD_AUDIO` — ⛔ BLOCKER (trivial fix)
- **What/why:** The **merged release manifest** (verified locally 2026-07-10) contains `RECORD_AUDIO`, injected by `camera_android_camerax` — but the app records **no audio** (`enableAudio: false`, `workout_camera_screen.dart:297`; no iOS mic string by design). A mic permission on a pose-analysis app invites Play Data-safety mismatch enforcement and Apple minimal-data scrutiny, and it is dishonest to users.
- **Play impact:** Data safety form would otherwise have to declare microphone/audio collection it doesn't do; mismatch between declared data and observed permission surface is a top rejection/removal cause (policy 10787469).
- **Apple impact:** none directly (iOS side already clean), but keep parity.
- **Fix:** `<uses-permission android:name="android.permission.RECORD_AUDIO" tools:node="remove"/>` in `android/app/src/main/AndroidManifest.xml`; rebuild; re-grep merged manifest.
- **Also observed in merged manifest (lower risk, tidy in same pass):** `FOREGROUND_SERVICE` (no FGS exists — remove), uncapped `READ_EXTERNAL_STORAGE` (inert at target 33+, optional remove), `WRITE_EXTERNAL_STORAGE` maxSdk=28 (inert, leave), `USE_BIOMETRIC`/`USE_FINGERPRINT` (normal-level, from google_sign_in v7 CredentialManager — **leave**, removing can break credential UI), `VIBRATE`/`WAKE_LOCK` (legitimately used). `READ_MEDIA_IMAGES/VIDEO` **absent** → Play Photo & Video Permissions policy N/A (verified).

### [A3] 16 KB page-size compliance — ✅ COMPLETE (verified 2026-07-10)
- **What/why:** Mandatory since Nov 1, 2025 for new apps/updates targeting Android 15+; extension window expired May 31, 2026. ML Kit pose (`libxeno_native.so`) was a known ecosystem risk (googlesamples/mlkit#961).
- **State:** Extracted `build/app/outputs/bundle/release/app-release.aab` (built Jul 9) and ran `readelf -lW` on all arm64 libs: **every LOAD segment Align ≥ 0x4000** — `libapp.so`/`libflutter.so` 0x10000, `libxeno_native.so` (ML Kit) 0x4000, Sentry/CameraX/JNI libs 0x4000. AGP 8.11.1 ≥ required 8.5.1.
- **Verify (repeat on every release build):** `for so in base/lib/arm64-v8a/*.so; do readelf -lW $so | awk '$1=="LOAD"{print $NF}'; done` — all ≥ 0x4000; Play Console app-bundle explorer must show no 16 KB warning.

### [A4] Release signing — ✅ COMPLETE core / 🔧 IMPROVEMENT hygiene / 🌐 enrollment
- **State:** Real upload keystore + `key.properties` exist on disk, both gitignored and untracked (verified via `git ls-files` / `check-ignore`); release build falls back to debug signing with a loud CI warning when absent (`release.yml:72-77`).
- **Improvements:** keystore/key passwords are `formai123` — regenerate or at least change passwords before the key becomes load-bearing; back the keystore up off-machine (losing an upload key is recoverable only via Play's key-upgrade process).
- **External:** Play App Signing enrollment happens at first AAB upload (required flow for new apps). Root `upload-cert.pem` is a public cert (benign) suggesting prior preparation — confirm which console app record it belongs to.

### [A5] R8 / resource shrink / ProGuard rules — ✅ COMPLETE
- `isMinifyEnabled = true`, Flutter-default resource shrink, `proguard-rules.pro` (163 lines) with keep rules for ML Kit/MediaPipe, CameraX, Sentry, PostHog, RevenueCat, google_sign_in v7, FLN/Gson, home_widget, Supabase/kotlinx-serialization (`android/app/proguard-rules.pro:21-159`). Unused 6 MB `pose-detection-accurate` model excluded (`build.gradle.kts:155-157`).
- **Verify:** release smoke test on device (R8-stripped builds are where reflection bugs appear); mapping.txt ships inside the AAB automatically (AGP bundle metadata).

### [A6] Edge-to-edge at targetSdk 36 — 🔧 IMPROVEMENT · VERIFY on device
- **What/why:** Android 15+ force-enables edge-to-edge for target ≥ 35; the app sets no `SystemUiOverlayStyle`/insets handling anywhere except one `AnnotatedRegion` in `dashboard_screen.dart:265`; no opt-out attribute (correct — opt-out dies with target 36 anyway). Flutter 3.41 handles insets by default; `SafeArea` used in 27 files.
- **Risk:** status/nav-bar contrast and content underlap on Android 15/16 devices, especially camera screen and onboarding.
- **Verify:** manual pass on an Android 15/16 phone (or emulator API 35/36): every screen's top/bottom content vs system bars; gesture-nav interference on the workout screen. 🌐 device.

### [A7] `allowBackup` / data-extraction rules — 🔧 IMPROVEMENT
- **What/why:** `android:allowBackup` unset → defaults **true**: SharedPreferences (consent flags, on-device body metrics JSON, streak state) lands in Google auto-backup unencrypted-at-app-level. Not a store blocker, but a privacy-posture mismatch with the "on-device only" story.
- **Fix:** either `android:allowBackup="false"` or ship `android:dataExtractionRules` (+ legacy `fullBackupContent`) excluding `sixpack.user_metrics` and auth-adjacent keys.

### [A8] Notification small icon — 🔧 IMPROVEMENT (visible quality bug)
- FLN default icon points at the full-color `@mipmap/launcher_icon` (`AndroidManifest.xml:125-127` + acknowledged TODO at 117-124) → renders as a **white blob** in the Android 13+ status bar for the two shipping notifications (daily reminder 19:00, streak warning).
- **Fix:** add a proper alpha-only `drawable/ic_stat_formai` and point the FLN default + both channel payloads at it. Verify on device API 33+.

### [A9] Adaptive + themed launcher icon — 🔧 IMPROVEMENT
- Only legacy square mipmaps exist; **no `mipmap-anydpi-v26` adaptive icon**, no Android 13 monochrome layer (`pubspec.yaml:231-236` config lacks `adaptive_icon_*`; confirmed by icon report §4). Modern launchers letterbox/shrink the icon — looks dated next to competitors, hurts first impression & conversion, not review.
- **Fix:** add `adaptive_icon_background`/`adaptive_icon_foreground` (+ `monochrome`) to flutter_launcher_icons config and regenerate.

### [A10] Splash screens — ✅ COMPLETE (functional) / 🔧 polish optional
- Branded dark `#0A0612` `launch_background` + day/night styles present (`values/styles.xml`, `values-night/styles.xml`, `colors.xml`); Flutter `_BootSplash` continues the brand (purple wordmark). Android 12+ shows the OS-default icon-on-color splash — acceptable; a custom `windowSplashScreenAnimatedIcon` is optional polish.

### [A11] Deep links / App Links — ✅ COMPLETE for v1
- `formai://` scheme registered + routed (`AndroidManifest.xml:60-65`, `deep_link_service.dart:91-93`); `https://formai.app` filter present with `autoVerify="false"` (chooser behavior) pending a hosted `assetlinks.json` — deliberate, non-blocking. Widget deep-link `formai://workout/today` works.

### [A12] Home-screen widget — ✅ COMPLETE (Android)
- Full `AppWidgetProvider` implementation, RemoteViews-safe layout, preview, deep link (`FormAIHomeWidgetProvider.kt`, `form_ai_widget_info.xml`). TR-hardcoded strings — consistent with TR-only launch.

### [A13] Network security — ✅ COMPLETE
- `usesCleartextTraffic="false"` + `network_security_config.xml` (system anchors only); no ATS-style exceptions anywhere.

### [A14] `adi-registration.properties` bundled asset — 🔎 VERIFY
- A tracked 29-byte opaque token bundled into every APK (`android/app/src/main/assets/`, commit `9750fb3` "Play Console ownership verification"). Nothing references it at runtime. Confirm it's a legitimate Play verification artifact for THIS console account; otherwise delete before release.

### [A15] Camera `uses-feature` implicit `required=true` — ✅ acceptable (decision noted)
- `android.hardware.camera.any` merges from the camera plugin without `required="false"` → camera-less devices can't install. Acceptable for a form-coaching app; flip to `required="false"` only if you want tablets/Chromebooks without cameras to install for plans/nutrition.

---

## 2. BUILD & PLATFORM — iOS

### [I1] CocoaPods never run / iOS never built — ⛔ BLOCKER · 🌐 APPLE ENV
- **State:** **No `ios/Podfile`, no `Podfile.lock`, no `Pods/`**; `Runner.xcworkspace` has no Pods reference; `Generated.xcconfig` is stale (0.1.0+8) and pins a Linux Flutter root. The iOS app has never compiled.
- **Why:** everything else iOS-side is theoretical until `pod install` + first build succeed on macOS with current Xcode (see I10).
- **Verify:** `flutter build ipa` succeeds on macOS; Podfile.lock committed.

### [I2] iOS deployment target 13.0 too low — ⛔ BLOCKER (small change, verify on mac)
- `IPHONEOS_DEPLOYMENT_TARGET = 13.0` (`project.pbxproj:353,479,530`); GoogleMLKit PoseDetection pods require ≥ 15.5 (current pods commonly 15.5+). Raise Podfile `platform :ios` + pbxproj to **15.5 or 16.0** and let `pod install` arbitrate.

### [I3] Entitlements not wired (Sign in with Apple / App Groups) — ⛔ BLOCKER · 🌐 Xcode
- `Runner.entitlements` (SIWA + `group.app.formai.shared`) and `FormAIWidget.entitlements` exist **but no `CODE_SIGN_ENTITLEMENTS` reference exists in the pbxproj** → capabilities are OFF in any real build. The SIWA button (`auth_screen.dart:408`) would fail at runtime.
- **Apple impact:** Guideline **4.8 (Login Services)** — because Google sign-in is offered, an equivalent privacy-focused option (SIWA qualifies) must exist **and work**. A dead SIWA button is a 2.1 completeness rejection too.
- **Fix:** on macOS, attach entitlements to the Runner target (+ enable capabilities on the App ID in the developer portal), then live-test Apple sign-in against Supabase (requires Supabase Apple provider config — see AS7/X3).

### [I4] Privacy manifest not bundled — ⛔ BLOCKER · 🌐 Xcode
- `ios/Runner/PrivacyInfo.xcprivacy` is well-formed (NSPrivacyTracking=false; collected types EmailAddress/HealthFitness/UserID linked-not-tracking; required-reason APIs UserDefaults CA92.1, FileTimestamp 3B52.1) **but is not in the Resources build phase** → won't ship. Apple enforces privacy manifests / required-reason APIs at upload (ITMS-91053 class rejections) since May 2024.
- **Fix:** add to Runner Resources in Xcode; current plugin pods ship their own manifests (another reason I1/pod versions must be current).

### [I5] Google Sign-In iOS config missing — ⛔ BLOCKER
- No `GIDClientID` in Info.plist, no reversed-client-id URL scheme, `GOOGLE_IOS_CLIENT_ID` absent from `.env` (present only in `.env.example`). The Google button renders on iOS and would fail.
- **Fix:** create an iOS OAuth client in Google Cloud for bundle id `com.emredogan.formai`, add `GIDClientID` + reversed scheme to Info.plist, populate `GOOGLE_IOS_CLIENT_ID`, register in Supabase Google provider. (Or hide the Google button on iOS at launch — inferior: SIWA-only iOS is allowed, but parity is better.)

### [I6] Widget + Live Activity extension targets don't exist — ⛔ BLOCKER **or** descope decision
- Complete, production-quality Swift sources exist (`ios/FormAIWidget/*`, `ios/FormAILiveActivity/*`) but **no extension targets in the pbxproj** — features are silently dead on iOS while `NSSupportsLiveActivities=true` is declared and Dart calls `live_activities`/`home_widget` at runtime.
- **Options:** (a) add the two targets in Xcode (extension bundle IDs `com.emredogan.formai.FormAIWidget`, App Group, provisioning) — ~½ day on mac; or (b) **descope for v1**: remove `NSSupportsLiveActivities` keys and gate Dart calls, ship iOS without widget/LA. Either resolves the honesty problem; (a) preserves a differentiator.

### [I7] Launch screen is stock white Flutter — 🔧 IMPROVEMENT (near-blocker for quality)
- `LaunchScreen.storyboard` = white background + 1×1 placeholder `LaunchImage` — a white flash into a dark-first app (Android got the branded `#0A0612` treatment; iOS did not). Fix storyboard background to `#0A0612` + brand mark. (Guideline 2.1 won't reject a white launch screen, but it reads unfinished.)

### [I8] `ITSAppUsesNonExemptEncryption` — 🔧 IMPROVEMENT (one line)
- Not declared → every upload triggers the export-compliance questionnaire. App uses only standard HTTPS/platform crypto → add `ITSAppUsesNonExemptEncryption=false` to Info.plist. 🔎 VERIFY the current ASC encryption questions at first upload (France self-classification no longer needed for exempt mass-market HTTPS-only apps — confirm on the ASC screen).

### [I9] iPad: `TARGETED_DEVICE_FAMILY = "1,2"` — 🔧 IMPROVEMENT + decision
- The project claims **iPhone + iPad**, but there are zero tablet layouts (UX audit §3), portrait-only design, and no iPad screenshots. Shipping "1,2" obligates working iPad UX + **13" iPad screenshots** in ASC and invites iPad-specific review (a classic Flutter rejection source).
- **Recommendation:** set `TARGETED_DEVICE_FAMILY = 1` (iPhone-only; iPad users still get iPhone-compatibility mode without iPad screenshots/review burden). Revisit real iPad support post-launch.

### [I10] Xcode 26 / iOS 26 SDK upload gate — 🌐 EXTERNAL · 🔎 VERIFY
- Apple's annual rule: since ~late-April 2026 uploads must be built with the iOS 26 SDK/Xcode 26 (pattern confirmed every year; exact current gate must be read off the ASC upload error/notice page when building). Flutter 3.41.9 (Apr 2026 stable) is the right vintage — **verify `flutter doctor` against installed Xcode on the mac**, upgrade Flutter if the build complains.

### [I11] iOS permission strings — ✅ COMPLETE / 🔧 two defensive additions
- `NSCameraUsageDescription` present, Turkish, accurate (`Info.plist:48-49`); mic + ATT strings deliberately absent (correct — no audio, no tracking). ✅
- 🔧 `image_picker_ios` compiles in (admin-web feature) with **no photo-library strings**; modern PHPicker needs none for picking, but add `NSPhotoLibraryUsageDescription` defensively or confirm no iOS code path can invoke it. When the Podfile is created, add the `permission_handler` `GCC_PREPROCESSOR_DEFINITIONS` macro block so unused permission APIs are compiled out (avoids "why does your binary reference X" review questions).

### [I12] iOS localization declaration — 🔧 IMPROVEMENT
- `CFBundleDevelopmentRegion` resolves to `en`; no `CFBundleLocalizations`, no `tr.lproj`/`InfoPlist.strings`. App is 100% Turkish. Declare `CFBundleLocalizations = [tr]` (+ localize the camera string via InfoPlist.strings) so the App Store and iOS settings represent the app's language truthfully; set ASC primary language = Turkish (see AS3).

### [I13] Signing identity/team — 🌐 EXTERNAL
- `DEVELOPMENT_TEAM` unset; legacy `iPhone Developer` identity strings in pbxproj. Configure automatic signing with the real team on macOS; extensions (if kept, I6) need their own provisioning.

### [I14] App icons (iOS) — ✅ COMPLETE
- Full `AppIcon.appiconset` incl. 1024 marketing icon, **no alpha** (`remove_alpha_ios: true`). Nothing to do.

### [I15] Desktop/web scaffolds — ✅ non-issue for stores
- `macos/`, `windows/`, `linux/` are untouched scaffolds still named `sixpack_ai`/`com.example.*` — not shipped. `web/` is the admin panel + hosts legal HTML (deployed via Terraform). Leave; do not include in release scope.

---

## 3. PRIVACY & DATA PROTECTION

### [P1] Privacy policy + Terms hosted and reachable — ✅ COMPLETE
- Live at `https://d2srybp77lgcpy.cloudfront.net/privacy.html` / `terms.html` (Terraform-applied S3+CloudFront, state serial 9; sources `web/public/*.html`). Linked in-app: paywall footer, consent screen, onboarding (`legal_urls.dart:17-20` et al). Both stores require a working privacy-policy URL in listing + in-app.
- 🔧 Optional: front with `formai.app/privacy` custom domain later for brand trust; CloudFront URL is policy-compliant as-is.

### [P2] In-app consent (analytics/crash, opt-in, default OFF) — ✅ COMPLETE
- `consent_screen.dart:42-43` both toggles default false; PostHog disabled until opt-in (`analytics_service.dart:46`), Sentry `beforeSend` drops events until granted + scrubs IP/email (`main.dart:120-135`). Router forces age-gate → consent → onboarding (`app_router.dart:110-120`). This exceeds both stores' consent norms and matches KVKK açık-rıza posture for analytics.

### [P3] Support/DSR mailbox mismatch — ⛔ BLOCKER (decision) · USER
- In-app support: `support@formai.app` (`legal_urls.dart:25`); hosted policies' data-rights contact: `formaisupport@proton.me` (`privacy.html:288,294,307`, `terms.html:241`). Pick ONE monitored mailbox, update the other surface, and use it consistently in Play Console + ASC support fields. (Deletion requests landing in an unmonitored box = KVKK/GDPR breach risk and store-review credibility hit.)

### [P4] Privacy-policy accuracy fixes — 🔧 IMPROVEMENT (do before console forms)
- `privacy.html:278` claims body metrics are "deleted alongside your account" implying server-side storage; reality: weight/height/age/goal **never leave the device** (`app_preferences.dart:258`; no Supabase writes — verified). Reword to state on-device storage (it's a *stronger* privacy story). Console privacy forms must match the policy text, so fix wording first.
- Add legal-entity block (see LG1) in the same edit.

### [P5] Account deletion — in-app + web channel — ✅ COMPLETE / one gap 🔧
- In-app: Account Settings → typed `DELETE` + confirm → `delete_user` RPC (SECURITY DEFINER, self-only) cascading 7 tables → `Purchases.logOut()` → signOut → `SharedPreferences.clear()` (`account_settings_screen.dart`, `auth_provider.dart:380-418`, `006_delete_user.sql`). Meets Apple 5.1.1(v) (true deletion, no support-call gate) and Play's in-app requirement.
- Web channel (Play requires a URL): `privacy.html:288` documents in-app path + email fallback for uninstalled users — use this URL in the Data safety form.
- 🔧 Gap: `user_videos` storage objects aren't cascaded (feature dormant — no client writes exist today). Add storage purge to the RPC before the video feature ever ships.
- 🌐 **X1:** 006/007 must be applied to **prod** Supabase and the delete round-trip verified there (currently only in migrations).

### [P6] Data inventory (what actually leaves the device) — ✅ COMPLETE (documented here for the forms)
- Supabase: email/auth identity, `user_progress` (day_number, completed), `user_metrics` (referral code), `feedback` (subject/message/app version/platform), `pro_entitlements` (webhook-written). **No body metrics, no camera frames, no pose coordinates server-side** (verified across repos/services).
- PostHog (opt-in): funnel events with IDs/counts, no PII properties. Sentry (opt-in): crashes, IP/email scrubbed, no session replay, `sendDefaultPii` unset (default false). RevenueCat: purchase receipts/entitlements keyed to Supabase UUID.
- **This mapping is the single source for GP4 (Data safety) and AS5 (App Privacy) — keep them consistent.**

### [P7] Android backup exposure — 🔧 IMPROVEMENT — see A7 (same fix).

### [P8] On-device ML disclosure — ✅ COMPLETE
- Pre-permission dialog "Cihazında Analiz — görüntüler kaydedilmez ve hiçbir sunucuya gönderilmez" shown before the OS camera prompt, acknowledged once per account (`workout_camera_screen.dart:239-267`, `app_preferences.dart:318-324`). Truthful (verified no frame upload paths).

### [P9] App Tracking Transparency — ✅ COMPLETE (correctly absent)
- No tracking, no ads: ATT API and `NSUserTrackingUsageDescription` deliberately removed; `PrivacyInfo.xcprivacy` declares `NSPrivacyTracking=false`, no tracking domains. Consistent story — do not re-introduce ATT.

### [P10] Sentry/PostHog privacy config — ✅ COMPLETE
- Consent-gated, scrubbed, replay off (see P2/P6). Declare them honestly as Diagnostics/Analytics in both consoles' forms.

### [P11] RLS as the mobile security boundary — ✅ COMPLETE
- All user tables have owner-scoped RLS (migrations 001/002/003/005/007); storage `user_videos` scoped to `${uid}/`; admin buckets role-gated; anon key is client-public by design with server-side gating; `.env` bundles only client-public keys, enforced by `tool/check_env_no_secrets.sh` + CI secret-scan + gitleaks.

### [P12] Anonymous/guest data — ✅ COMPLETE
- Guest = Supabase anonymous session; purchase blocked behind auth-gate so RC identity is aliased to a real account; sign-out wipes PII, preserves device-level keys. Honest anon→email upgrade copy.

### [P13] Secrets on disk — ⛔ BLOCKER (security hygiene, not store-visible)
- `formai-494015-f262599d264a.json` at repo root **is a live GCP service-account private key** (gitignored/untracked but physically present; the older P-Risk doc's "removed from disk + rotated" claim is false on "removed"). **Action:** delete from disk, rotate the key in GCP IAM, store any needed replacement outside the repo tree.
- `.git/config` remote URL embeds a GitHub PAT — rotate + switch to credential helper (USER; already on the ledger).
- Tracked tree re-verified clean today: no tracked *.pem/p12/jks/service-account JSON anywhere.

### [P14] EU DSA trader status — 🌐 EXTERNAL (only if distributing in EEA)
- Both stores block EEA distribution without a verified trader declaration (name/address/email/phone published on the listing). **Decision:** launch Turkey(+non-EEA) first and skip DSA, or complete trader verification in both consoles. Turkey itself imposes no extra store gate (verified for Play 2026-07-10).

---

## 4. AUTH & ACCOUNT

### [AC1] Provider matrix — ✅ COMPLETE (code) / iOS runtime gated on I3/I5
- Email+password (verification link flow), Google, Apple (iOS-only button), anonymous guest; password reset dialog + `resetPasswordForEmail` (`auth_provider.dart:515-537`). Offline pre-check on sign-in buttons.

### [AC2] Sign in with Apple ⇒ Guideline 4.8 — ✅ code / ⛔ runtime (= I3) / 🌐 console
- Because Google login ships, Apple requires an equivalent privacy-focused option: SIWA is implemented UI+flow-side; it becomes real only after entitlement wiring (I3), Apple provider config in Supabase (Services ID + key) 🌐, and a live device test.

### [AC3] Raw English error leak — 🔧 IMPROVEMENT
- Email-auth failures toast Supabase's English `AuthException.message`; unexpected errors toast `"Beklenmedik hata: $e"` (`auth_screen.dart:151-153`). Map the common cases (wrong password, user exists, rate limit) to Turkish; keep raw detail in logs only. Small, high-polish-value fix; also removes odd-language screenshots from review.

### [AC4] Supabase production auth config — 🌐 EXTERNAL
- Default Supabase SMTP is rate-limited and not production-grade: configure custom SMTP + sender domain for signup/reset emails; confirm reset/verification deep-link redirect URLs for the mobile app; set Site URL. Verify Google provider (web client id already in `.env`) and add Apple provider (AS7).

### [AC5] Reviewer/demo account — 🌐 EXTERNAL prep (required)
- Both consoles need working review credentials (ASC App Review Information; Play "App access" + pre-launch-report test credentials). The codebase already supports a **reviewer role** (`isProProvider` honors it — `monetization_provider.dart:208-213`): create a dedicated `reviewer@…` Supabase account, grant the role (Pro visible without purchase), document steps. Include a note that camera form-analysis needs a human in frame + provide a short demo video link in review notes (standard practice for camera-dependent apps).

### [AC6] Account deletion — see P5. ✅ code / 🌐 prod apply.

---

## 5. MONETIZATION & SUBSCRIPTIONS

### [M1] In-app paywall disclosures — ✅ COMPLETE (test-covered)
- Live localized `storeProduct.priceString`, billing period, trial copy bound strictly to a real `introductoryPrice` (zero-price check), auto-renewal disclosure sentence, cancel-anytime, Restore Purchases button, tappable Privacy + Terms links (`paywall_screen.dart` — `_LegalFooter:1690-1797`, `_buildRestoreButton:683`, `_freeTrialOf:38-42`). Paywall tests re-verified green today. This satisfies Apple 3.1.2 in-app requirements and Play subscriptions policy (clear price/frequency pre-purchase, no hidden trial conversion).

### [M2] Hardcoded fallback prices — 🔧 IMPROVEMENT (review-risk)
- `₺249,99/₺999,99/₺499,99` render only when RC offerings load **fails** (`paywall_screen.dart:1348-1358`). If store prices ever differ, that path shows wrong prices (Apple 2.3.x metadata-accuracy exposure; Play misleading-pricing exposure). Replace fallback numbers with a price-less error state + retry ("Fiyatlar yüklenemedi").

### [M3] Play Billing Library version — 🔧 IMPROVEMENT (deadline-driven)
- Verified 2026-07-10: BL7 acceptable until **Aug 31, 2026**; BL8+ required after. `purchases_flutter 8.1.1` → purchases-android 8.x → **BL7**; `purchases_flutter ≥ 9` → BL8. First submission on BL7 works, but the first post-Aug-31 update would be blocked → **upgrade to purchases_flutter 9.x/latest before launch** (change log review + full paywall/purchase regression, incl. the 293-test suite and a sandbox purchase).

### [M4] RevenueCat product/entitlement config — 🌐 EXTERNAL (must match code exactly)
- Code expects entitlement **`FormAI Pro`** (with space — `monetization_provider.dart:17`), offering `current` with `monthly`/`threeMonth`/`annual` packages; product ids referenced in SQL: `formai_pro_monthly`, `formai_pro_3month`, `formai_pro_annual`. Configure in RC + both consoles; attach intro trial only where intended (code renders whatever the store says — good).
- RC webhook (`supabase/functions/revenuecat-webhook`) → deploy to prod, set its auth secret in RC dashboard, smoke a sandbox event end-to-end into `pro_entitlements`.

### [M5] Apple subscription setup — 🌐 EXTERNAL
- Paid Apps / Agreements-Tax-Banking must be Active before review; create subscription group + 3 auto-renewables with TR pricing; **first-time rule: select the subscription products to be reviewed WITH the first binary submission** (products stuck "Waiting for Review" unsubmitted = classic first-app rejection); metadata must include a Terms of Use (EULA) link — standard Apple EULA is acceptable, link it in the App Description field + privacy policy URL field.

### [M6] Google subscription setup — 🌐 EXTERNAL
- Create the 3 subs + base plans/offers in Play Console; ensure benefit lines contain no price/trial text (Play policy — verified); complete the in-app-purchases declaration. Confirm cancel/manage flows: app already deep-links to `play.google.com/store/account/subscriptions` (`profile_tab.dart:496-498`) ✅.

### [M7] Restore & entitlement edge cases — ✅ COMPLETE
- Typed purchase outcomes incl. `pending` (deferred/parental approval) with distinct TR toasts; Pro-user paywall re-entry crash-proofed (test-covered); anonymous purchase blocked pre-alias; Restore button present.

### [M8] Free-tier honesty — ✅ COMPLETE
- Free = 5 of 30 days + gated premium surfaces, honestly labeled; sample plan tagged "Örnek plan"; decoy pricing/fake counts removed in Phase 0 (commit ledger).

---

## 6. HEALTH, AI & CONTENT POLICY

### [H1] Medical/exercise disclaimers — ✅ COMPLETE
- Consent screen (pre-collection, doctor-consult wording), nutrition tab header ("tıbbi tavsiye yerine geçmez"), results-vary line on paywall (`consent_screen.dart:166-169`, `nutrition_tab.dart:141-143`, `paywall_screen.dart:950`). Overclaim grep (tedavi/garanti/kesin sonuç) clean.

### [H2] "AI" branding accuracy — 🔧 IMPROVEMENT (metadata discipline)
- No cloud LLM exists (verified — zero LLM/network-inference references); "AI" = on-device ML Kit pose + rule-based analyzers + deterministic personalization. Play Misleading-Claims + Apple 2.3.1 apply to **store listing copy**: describe as "yapay zekâ destekli hareket/form analizi (cihaz üzerinde)" and avoid implying generative/chat capabilities. Update the May-era listing drafts accordingly (L4).

### [H3] Play AI-Generated Content policy — ✅ N/A (verified 2026-07-10)
- Policy covers apps that *generate* content (chatbots/text-to-image). Rule-based CV + TTS is out of scope → no in-app AI-content reporting requirement.

### [H4] Play Health apps declaration — 🌐 EXTERNAL (required)
- Since Aug 31, 2024 **all** apps complete the Health-apps declaration; FormAI declares **"Activity and Fitness"** (+ consider "Nutrition and Weight Management" for the nutrition module). Obligations it triggers — privacy policy in console+in-app ✅, prominent consent ✅, no unneeded permissions (A2 fix), no misleading health claims ✅. Health Connect rules N/A (not integrated).

### [H5] Apple health rules (5.1.3 / 1.4) — ✅ COMPLETE as-built
- No HealthKit, no server-side health data, no ads on health data, no dosage/medical-device claims; disclaimers present. Nothing to declare beyond App Privacy types (AS5).

### [H6] Age ratings — 🌐 EXTERNAL (both consoles)
- **Apple:** the reworked rating system (tiers incl. 13+/16+/18+, expanded questionnaire; compliance deadline for existing apps was Jan 31, 2026) applies at first submission — answer the new health/fitness & user-account questions truthfully; app's own 18+ gate is stricter than any computed rating (you may set a higher age if desired). 🔎 read the live questionnaire in ASC.
- **Play:** IARC questionnaire mandatory; declare Target Audience = 18+ and optionally enable Restrict Minor Access; ads = none.
- In-app 18+ gate is enforced pre-consent (`age_gate_screen.dart:35,88-91`) ✅ and stronger than either store's requirement — keep listing metadata consistent (no child-appealing assets).

### [H7] UGC — ✅ N/A
- No user-generated public content surfaces ship (referral codes and local share images only) → UGC moderation policies not triggered on either store.

---

## 7. STABILITY, PERFORMANCE & OBSERVABILITY

### [S1] Global error containment — ✅ COMPLETE
- `runZonedGuarded` + `FlutterError.onError`/`PlatformDispatcher.onError` → Sentry + custom branded `ErrorWidget.builder` (no grey/black screen), failure-tolerant Sentry init, dotenv-failure and Supabase-timeout boot screens with retry (`main.dart:55-157,301,536-553`), router `errorBuilder` with self-recovery.

### [S2] Offline behavior — ✅ COMPLETE core / 🔧 one gap
- Fail-fast connectivity gating on sign-in, camera entry, paywall, catalogue fetches; offline cold start lands on a branded retry screen (8s cap), anon-recovery avoids bogus auth redirects; LQIP/cached images keep grids visible offline; offline workout allowed with informational snackbar.
- 🔧 [S2b] Data-layer Supabase calls have **no `.timeout()`** (only 2 timeouts app-wide, both at boot) → captive-portal/half-open connections spin ~30 s before erroring. Wrap repository reads with ~10 s timeouts mapped to the existing `ErrorCard` states.

### [S3] Crash reporting — ✅ wired / 🔧 symbols
- Sentry 9.6.0 live behind consent. 🔧 Release builds run **without `--obfuscate --split-debug-info`** and no Sentry symbol upload (no sentry-cli/Dart-plugin config) → obfuscation decision + readable native/Dart stacks: enable `--obfuscate --split-debug-info` in `release.yml` and add Sentry symbol upload (Sentry Dart Plugin), or consciously ship non-obfuscated Dart (R8 already covers Kotlin/Java). Play: R8 `mapping.txt` ships inside the AAB automatically; upload Flutter native debug symbols to Play for readable ANR/native crashes (warning-only, recommended).

### [S4] Performance on device — 🌐 EXTERNAL (physical-device pass)
- Camera+ML+TTS session: 15-FPS throttle exists; verify sustained-session thermals/battery on a mid-tier Android phone; cold start ≤ ~2 s on mid-tier; Android vitals watchlist post-launch: ANR < 0.47%, user-perceived crash < 1.09% (bad-behavior thresholds).
- Wakelock correctly scoped to the workout screen (enable in init, disable on dispose/pause) ✅ code-side.

### [S5] App size — ✅ acceptable / monitor
- AAB 110.8 MB → per-device download much smaller (arm64 libs ~33 MB + assets); accurate-pose model already excluded; LQIP/asset hygiene done. No store limit risk. Track with `--analyze-size` per release.

### [S6] In-app review prompt compliance — ✅ COMPLETE
- Native `in_app_review` API, one-shot per install, Pro+3-workouts gate, no incentives/gating (`rating_moment_service.dart:42-53,102-104`) — within Apple/Google prompt policies.

### [S7] ANR/lifecycle robustness — ✅ COMPLETE code-side · 🔎 device verify
- Camera stream stop→dispose→null on background, resume re-init, `ref.mounted` guards, PopScope traps on camera/wizard/gates. Verify call-interrupt + backgrounding on device (external ledger).

### [S8] Monitoring readiness for rollout — 🌐 EXTERNAL
- Pre-launch: Sentry alert rules (new fatal issue, crash-rate spike), RC dashboards, Play vitals + ASC metrics access on the phone. Define halt criteria (see roadmap Phase 7).

---

## 8. UX COMPLETENESS & ACCESSIBILITY

### [U1] TR-only localization posture — ✅ COMPLETE (honest) / 🔧 two leaks
- `supportedLocales: [tr]` matches reality (~1,316 TR strings; ARB scaffold intentionally dormant). 🔧 Fix the two English leaks: `auth_modal_bottom_sheet.dart:341,382` ("Continue with Google/Apple" → TR parity with `auth_screen.dart:589,695`).

### [U2] Dark + light themes — ✅ COMPLETE
- M3, both themes, system-default + persisted user toggle, WCAG-checked light palette entries; bespoke dark-styled widgets in light mode are documented/deliberate. Store screenshots should present the dark hero look (L3).

### [U3] Text scaling & overflow — 🔧 IMPROVEMENT
- No `textScaler` clamp and 224 `Row(`s vs 164 `Flexible/Expanded` → large-font Turkish strings can overflow. Add a global clamp (e.g. 1.0–1.3) via `MaterialApp.builder` + spot-fix top journeys (auth, onboarding, paywall, dashboard cards). Also add missing `intl`-based Turkish date/number formatting only where user-visible numbers matter (prices already come formatted from the store).

### [U4] Accessibility (TalkBack/VoiceOver) — 🔧 IMPROVEMENT / 🌐 device pass
- Current surface: 7 `Semantics` usages in 3 files, **0 `semanticLabel`**, 44 unlabeled images, tooltips in 2 files, reduce-motion honored in 5/12 motion primitives. Not a launch blocker on either store, but: label the core journey (bottom nav, primary CTAs, paywall plans, camera controls), extend reduce-motion to the remaining 7 primitives, fix sub-48dp tap targets (`consent_screen.dart:228`, `meal_plan_timeline.dart:803`). Screen-reader smoke pass on device is on the external ledger. (Apple's Accessibility Nutrition Labels: optional to declare — 🔎 verify current ASC status; declare only what's true.)

### [U5] Loading/empty/error states — ✅ pattern-complete / 🔧 coverage
- `ErrorCard`(retry) on 9 screens, skeletons on 4, branded media fallbacks, no raw exception text in UI (verified). 🔧 36 bare spinners remain + silent `.valueOrNull` fallbacks in 5 providers — upgrade the top-traffic ones (dashboard tabs, paywall, plan detail) to skeleton/ErrorCard; add pull-to-refresh where lists can stale (currently 2 screens).

### [U6] Camera UX completeness — ✅ strong / 🔧 one gap
- Permission rationale → OS prompt → denied/permanently-denied recovery (settings deep-link) → ML-unavailable graceful path → interruption-safe lifecycle → confirm-exit trap. 🔧 Add a small **visual** "kadraja gir / tüm vücudun görünmeli" overlay when no pose is detected for N seconds (currently audio-only cue — silent for muted phones).

### [U7] Brand consistency at boot — 🔧 IMPROVEMENT
- Residual old-cyan `0xFF00F0FF` in `_DeepLinkSplashScreen` (`app_router.dart:409-413`), `ErrorCard`, `_PermissionCard` vs brand purple `0xFF8E5BFF` used by boot splash/wordmark. Unify (tiny diff, screenshot-visible).

### [U8] Tablets / orientation — ✅ decision-consistent
- Portrait-locked phone app; Android: phone-only screenshots are sufficient to publish (tablet shots only affect tablet promotion eligibility — verified); iOS: resolve via I9 (device family). No landscape support is acceptable and consistent (camera screen handles sensor rotation metadata correctly).

### [U9] Navigation & deep links — ✅ COMPLETE
- 20-route inventory with guarded ordering (age→consent→onboarding→auth→paywall), referral/workout deep links cold+warm, missing-arg fallbacks, back-trap coverage. Deep-link QA on device is listed in Q-matrix.

### [U10] Polish — ✅ COMPLETE
- Haptics (97 sites), motion system, celebrations, in-app feedback with version stamping, in-app review moment. No action.

---

## 9. STORE LISTING ASSETS & METADATA

### [L1] App icons — ✅ COMPLETE (both bundles + Play 512)
- Launcher icons generated from `tool/app_icon.png`; Play listing icon `photos/APP_ICON_512.png` (512×512 RGB, verified) via `tool/format_play_store_assets.py`. iOS set complete (I14). 🔧 adaptive/monochrome = A9.

### [L2] Feature graphic — ✅ COMPLETE (asset exists) · 🔎 refresh check
- `asosystem/play_store_ready/feature_graphic_1024x500.png` present (required by Play — verified still required 2026-07-10).

### [L3] Screenshots — 🔧 IMPROVEMENT (regenerate against current UI)
- 9 finished Play screenshots + App Store renders exist (`asosystem/play_store_ready/`, `asosystem/exports/verify/{playstore,appstore}/` + zips) — but they were produced in the **May UI era**; since then paywall copy, social-proof, streak/XP surfaces and branding changed materially. Play/Apple metadata policy requires screenshots to reflect the actual app → re-render the affected frames with the current build (asosystem pipeline + `format_play_store_assets.py` already automate sizing). Apple sizes: provide the current required iPhone size set (6.9-inch class; ASC auto-scales where permitted — 🔎 confirm exact required sets on the upload screen; no iPad set if I9 → iPhone-only).

### [L4] Listing copy (TR) — 🔧 IMPROVEMENT
- Rich drafts exist (`GOOGLE_PLAY_MASTERPLAN_TR.md` §2: short-desc candidates ≤80 chars, long-desc, TR/EN keyword sets) but are **SixPack-AI-era**: rebrand to FormAI, align claims with H2 (on-device AI form analysis, no generative promises), remove any outcome quantification (consistent with the in-app honesty pass). Prepare: Play short (80) + full (4000) descriptions; ASC name (30), subtitle (30), keywords (100), description, promotional text. Primary language: Turkish (both consoles); no EN listing at v1 unless distribution demands it.

### [L5] Preview videos — ✅ optional — skip for v1 (add post-launch for conversion).

### [L6] Store-visible URLs — ✅ ready
- Privacy policy URL (P1), web deletion channel anchor (P5), support email (P3 decision), marketing URL optional (`formai.app` when live).

---

## 10. RELEASE ENGINEERING & CI/CD

### [R1] CI of record — ✅ COMPLETE
- `ci.yml`: format-gate, secret-guard, analyze, tests+coverage artifact, debug APK, emulator integration test. `secret-scan.yml`: gitleaks full-history + env-guard. Branch protection via PR to main (PAT rotation pending — LG3/USER).

### [R2] Release workflow — 🔧 IMPROVEMENT
- `release.yml` builds release AAB+APK from injected client-public `.env`, warns loudly on debug signing, uploads artifacts; **Play-upload step scaffolded but commented out**. Actions: add keystore secrets + enable the `r0adkll/upload-google-play` step to `internal` track; add `--obfuscate --split-debug-info` + Sentry symbol upload (S3); keep `if-no-files-found: error`.

### [R3] Test suite state — ✅ COMPLETE for launch scope
- 293 tests green (unit + widget across 38 files incl. paywall disclosure tests, analyzer golden-frame suites, streak calculator); integration test is an honest mocked harness (CI-safe). Device E2E stays on the external ledger — do not fake it.

### [R4] Repo hygiene — 🔧 IMPROVEMENT
- Untrack `logs.txt` (24k-line committed device log; add explicit ignore), replace LICENSE (currently MIT © Supabase template — wrong holder for a proprietary store app), refresh stale README sections (CI names, 7 migrations, bucket names), decide fate of untracked June audit docs (commit-or-archive), commit `formai_mission.txt` decision left to user.

### [R5] Versioning — ✅ COMPLETE
- Single source `pubspec.yaml: 1.0.0+13` → Android versionCode/Name + iOS `FLUTTER_BUILD_NAME/NUMBER`. Bump `+14` for the first store artifact; keep marketing 1.0.0.

### [R6] Store artifact definition — ✅ ready pending A2 rebuild
- Ship **AAB** to Play (App Signing) and **IPA via Xcode/`flutter build ipa`** to ASC. Re-run the 16 KB check (A3) + `--analyze-size` on the final artifacts.

---

## 11. CONSOLE OPERATIONS — GOOGLE PLAY (all 🌐 EXTERNAL)

| ID | Task | Notes / grounding |
|---|---|---|
| GP1 | Confirm account type & testing gate | Personal accounts created after 2023-11-13: **closed test with ≥12 testers for 14 continuous days**, then "Apply for production" (review ≤ ~7 days) — verified 2026-07-10 (answer/14151465). **This is the calendar critical path — start closed testing as early as possible.** |
| GP2 | Create app record (`com.emredogan.formaifit`), TR default language | Managed publishing ON for controlled go-live. |
| GP3 | Play App Signing enrollment + upload first AAB to Internal testing | A4; verify 16 KB/no warnings in bundle explorer. |
| GP4 | **Data safety form** from P6 mapping | Collected: Personal info (email, user IDs), Fitness info (workout completion), App activity (PostHog, optional/opt-in), Crash logs+Diagnostics (Sentry, opt-in), Purchase history (RC). On-device body metrics/camera = **not collected** (never leaves device — official on-device exemption). Deletion mechanism: in-app + P5 URL. Encryption in transit: yes. |
| GP5 | **Health apps declaration** = Activity & Fitness (+Nutrition) | H4. |
| GP6 | Content rating (IARC) questionnaire | Fitness app, no UGC, no ads, data collection = yes; expect Everyone/3+ class outcome; in-app 18+ gate is our own stricter policy. |
| GP7 | Target audience 18+ (+ optionally Restrict Minor Access), Ads = none | H6. |
| GP8 | App access: provide reviewer credentials (AC5) + pre-launch-report test account | answer/9842757. |
| GP9 | Store listing: L1–L4 assets + copy; privacy URL | Feature graphic required. |
| GP10 | Subscriptions: create 3 subs/base plans (+intro offer if desired), no price/trial text in benefit lines | M6. |
| GP11 | Countries: Turkey first; skip EEA unless P14 trader done | P14. |
| GP12 | Rollout mechanics | Internal → Closed (GP1 gate) → (optional Open) → Production staged 10%→20%→50%→100% with halt criteria (S8); staged rollout applies to updates/open/closed, first production publish is 100% by design. |

---

## 12. CONSOLE OPERATIONS — APP STORE CONNECT (all 🌐 EXTERNAL)

| ID | Task | Notes / grounding |
|---|---|---|
| AS1 | Apple Developer Program membership + team on the mac | I13. |
| AS2 | Agreements: **Paid Applications** active (banking/tax) before review | M5 — subscriptions won't pass without it. |
| AS3 | App record: bundle `com.emredogan.formai`, **primary language Turkish**, category Health & Fitness | I12. |
| AS4 | Subscription group + 3 auto-renewables (TR pricing, optional intro trial), **submit products WITH the first binary** | M5 first-app rule. |
| AS5 | **App Privacy labels** from P6 | Declare: Contact Info (email) linked; Health & Fitness (workout completion) linked; Identifiers (user ID) linked; Purchases linked; Usage Data (opt-in analytics) — check current taxonomy on the form; Diagnostics (opt-in crash) — "not linked" only if truly de-identified, Sentry scrubbing helps but IDs exist → declare linked to be safe. No Tracking (P9). |
| AS6 | **Age rating** — complete the current (post-2025 rework) questionnaire | H6 🔎. |
| AS7 | Sign in with Apple service config: App ID capability, Services ID, key → Supabase Apple provider | AC2/I3. |
| AS8 | App Review Information: reviewer account (AC5), contact info, notes incl. camera demo video link + "all analysis on-device" statement | Preempts 2.1 completeness questions. |
| AS9 | Export compliance: `ITSAppUsesNonExemptEncryption=false` (I8), answer the questionnaire | 🔎 verify current France/self-classification prompts on the form. |
| AS10 | Screenshots (L3) — current required iPhone set; iPad none if I9 executed | 🔎 confirm required size classes at upload. |
| AS11 | EULA: link Apple standard EULA + privacy policy in metadata | M5/3.1.2. |
| AS12 | TestFlight: internal testers immediately after first upload; external group (Beta App Review ~1 day) for wider beta | Roadmap Phase 6. |
| AS13 | DSA trader declaration only if EEA distribution (else exclude EEA territories) | P14. |

---

## 13. LEGAL (KVKK / GDPR / CONSUMER)

### [LG1] Veri sorumlusu identity on policy pages — ⛔ BLOCKER · USER/legal
- KVKK Art.10 aydınlatma requires the data controller's identity; privacy/terms pages currently lack the legal-entity name/address (known ledger item). Add real name/address (sole proprietor or company) + single DSR mailbox (P3) to both HTML pages; redeploy via Terraform (5-minute apply).

### [LG2] KVKK posture — ✅ strong by architecture / 🌐 confirmations
- Because body metrics stay on-device, server-side data is limited to email/progress/feedback — the special-category (health) data exposure that would demand açık rıza + heavier KVKK duties is structurally minimized; analytics/crash are opt-in (P2) ✅.
- 🌐 Legal confirmations (counsel, not code): (a) whether workout-completion records count as health data (position: activity metadata, not özel nitelikli — document the assessment); (b) **VERBIS** registration necessity for the chosen legal entity (solo dev below employee/balance thresholds is typically exempt — confirm against current VERBIS guidance); (c) cross-border transfer basis for Supabase/Sentry/PostHog/RevenueCat under the 2024-amended Art.9 regime (standard contractual clauses / adequacy route) + sign each vendor's DPA. Mark policy text accordingly.

### [LG3] Repo/user actions — ⛔ USER (carried ledger)
- Rotate the GitHub PAT embedded in `.git/config`; then merge `prisk/phase-1-tests` → `main` so store builds cut from main.

### [LG4] Consumer/subscription law (TR) — ✅ store-mediated / verify ToS wording
- Auto-renew billing runs through Apple/Google (their cancel/refund surfaces satisfy the practical obligations); ensure ToS states renewal/cancel mechanics in Turkish (paywall already discloses in-app) — quick text check during LG1 edit.

### [LG5] LICENSE file — 🔧 IMPROVEMENT — see R4 (wrong copyright holder).

---

## 14. PHYSICAL-DEVICE QA MATRIX (🌐 EXTERNAL — final gate before each store's submission)

| ID | Scenario | Pass criteria |
|---|---|---|
| Q1 | Cold start: online, offline (airplane), captive portal | branded splash → dashboard ≤ ~2 s online; retry screen offline; no >10 s hang post-S2b |
| Q2 | Full workout with camera: grant/deny/permanently-deny permission; call interrupt; backgrounding; screen-off; low light | correct recovery paths; session resumes paused; no crash; reps/voice work; battery/thermals sane over 15 min |
| Q3 | Purchase lifecycle (sandbox/internal track): trial → subscribe → restore → manage link → cancel; Pro unlock across app | entitlement flips everywhere incl. widget; pending-state toast on deferred |
| Q4 | Account: email signup+verification mail, password reset mail deep-link back into app, Google sign-in, (iOS) Apple sign-in, guest→upgrade, sign-out wipe, **delete account round-trip on prod DB** | X1 verified; RC identity detached; re-signup clean |
| Q5 | Notifications: enable toggle → OS permission → 19:00 reminder fires (device A12+/Android 13+); streak warning after 48 h; boot-receiver after reboot | correct icon (post-A8), correct text variant, tap-through |
| Q6 | Deep links: `formai://r/CODE` cold+warm, `formai://workout/today` from widget, https chooser | land on referral/camera correctly |
| Q7 | Android 15/16 edge-to-edge sweep (A6) + dark/light + font-scale 1.3 pass on top 10 screens | no overlap/overflow/contrast breakage |
| Q8 | TalkBack (Android) / VoiceOver (iOS) smoke on core journey (U4) | navigable: auth → onboarding → dashboard → paywall |

---

## APPENDIX — verified sources (fetched 2026-07-10 unless noted)
- Play target API: developer.android.com/google/play/requirements/target-sdk · support.google.com/googleplay/android-developer/answer/11926878 (API 36 by 2026-08-31 for new apps/updates; corroborated by multiple Apr–Jun 2026 secondary sources)
- 16 KB pages: android-developers.googleblog.com (May 2025) · developer.android.com/guide/practices/page-sizes · googlesamples/mlkit#961 — **local AAB verification PASS 2026-07-10**
- Personal-account closed testing: support.google.com/googleplay/android-developer/answer/14151465 (12 testers/14 days)
- Account deletion: answer/13327111 · Data safety: answer/10787469 (on-device = not collected; SDK traffic must be declared)
- Health apps declaration: answer/14738291 (all apps since 2024-08-31) · GenAI policy scope: answer/14094294 (generation only)
- Billing deprecation: developer.android.com/google/play/billing/deprecation-faq (BL7 until 2026-08-31; BL8 after) · purchases_flutter changelog (9.0.0 → BL8)
- Photo/Video permissions: answer/14115180 (READ_MEDIA_* only — N/A here) · Listing specs: answer/9866151 (512 icon, 1024×500 feature graphic, ≥2 screenshots) · Pre-launch report: answer/9842757 · Play App Signing: answer/9842756 · DSA trader: answer/14659200
- Apple items marked 🔎 (Xcode 26 gate exact date, current screenshot size classes, accessibility-label status, live age-rating questionnaire, export-compliance prompts) must be read off the live ASC/developer.apple.com screens at execution time — Apple guideline numbers cited (2.1, 2.3, 3.1.1/3.1.2, 4.8, 5.1.1(v), 5.1.2, 5.1.3, 1.4) are stable as of the January 2026 guideline text and should be re-checked once on developer.apple.com/app-store/review/guidelines before submission.
