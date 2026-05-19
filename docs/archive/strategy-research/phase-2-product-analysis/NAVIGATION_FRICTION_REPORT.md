# NAVIGATION FRICTION REPORT

**Phase 2 — Product Analysis · Routing & Navigation**
**Project:** SixPack AI / FormAI Fit
**Generated:** 2026-05-08
**Inputs:** atlas (§3 navigation/routing, §3.2 redirect rules, §3.3 deep links, §3.4 tab shell, §6.7 forced-auth gate); 12 source-file inspections.
**Scope:** Navigation/routing-specific friction. Redirect rules, deep links, back-button behavior, tab-state preservation, and the Phase 94 forced-auth gate's escape-valve gap. Severity-scored findings with file:line evidence. No redesigns.

---

## 0. METHODOLOGY & SEVERITY SCALE

Each finding follows the schema:
```
### Finding F-NN: [imperative title]
Severity: N/5
Where:    file:line  + atlas §X.Y reference
Observation: [factual]
Cost:        [behavioral consequence]
Evidence:    [snippet or specific reference]
```

Severity:
- **5** — user can become trapped or lose data; route guards misfire on critical paths
- **4** — material extra friction (extra screens, lost intent, lost scroll position, surprise destination)
- **3** — measurable but non-blocking friction
- **2** — cleanup-grade
- **1** — cosmetic

---

## 1. EXECUTIVE FINDINGS TABLE (severity-sorted)

| ID | Sev | Title | File:line |
|---|---|---|---|
| F-N1 | 5 | Forced-auth modal has no escape valve when OAuth + email both fail | `auth_modal_bottom_sheet.dart:67–69`, `paywall_screen.dart:182–214` |
| F-N2 | 5 | Workout/today deep link silently discards intent on signed-out devices | `deep_link_service.dart:96–106`, `app_router.dart:78–126` |
| F-N3 | 4 | Tab-switch preserves widget state via IndexedStack but loses scroll position in pushed sub-routes | `dashboard_screen.dart:117–128`, atlas §3.4 |
| F-N4 | 4 | `/prediction` redirect rule is unreachable from in-app navigation; orphan logic | `app_router.dart:109–111`, `onboarding_screen.dart:210–216` |
| F-N5 | 4 | "Back" from `/paywall` after Day 4+ tap goes to dashboard, not the workout the user was trying to start | `today_task_card.dart:107`, `plan_detail_screen.dart:312`, `paywall_screen.dart:578` |
| F-N6 | 4 | `/auth` and `/paywall` are 2 redirect-touch routes; signed-in user bouncing through `/auth` always lands on paywall | `app_router.dart:112–114` |
| F-N7 | 3 | `errorBuilder` self-recovery has 200ms defer that's a fixed delay, not signal-based | `app_router.dart:308–331` |
| F-N8 | 3 | Custom-scheme deep link parsing relies on Phase 57 host-splice — fragile to URL formatting variations | `deep_link_service.dart:79–133` |
| F-N9 | 3 | Default GoRouter back-pop behavior on `/auth` from paywall trigger does not return user to paywall | `auth_modal_bottom_sheet.dart:469–471` |
| F-N10 | 3 | First-time gate forces `/onboarding` from any path; tap on referral link from notification on first install lands in onboarding, not referral | `app_router.dart:87–89` |
| F-N11 | 3 | DeepLinkService routes to dashboard fallback for unknown paths — silent intent loss | `deep_link_service.dart:107` |
| F-N12 | 3 | `_DeepLinkSplashScreen` always navigates to dashboard after 200ms, even if listener resolved a different route | `app_router.dart:326–331` |
| F-N13 | 2 | `/workout/today` is a route alias for `/workout` — semantic intent ("today") not preserved | `app_router.dart:171–175` |
| F-N14 | 2 | All paywall destinations use `context.push` (stack), creating navigation depth on serial paywall hits | 8 sites in `today_task_card.dart`, `plan_detail_screen.dart` etc. |
| F-N15 | 2 | `_MissingReferralCode` and `_MissingRecipe` use `context.go` to dashboard — replaces the entire stack | `app_router.dart:381, 421` |
| F-N16 | 2 | RouteObserver shared across the app; widget-test isolation requires unmocking | `app_router.dart:72–76` |

**Total: 16 findings** (2 sev-5, 5 sev-4, 6 sev-3, 4 sev-2)

---

## 2. REDIRECT RULE ANALYSIS

### 2.1 The 6 redirect rules (atlas §3.2)

Order is significant, first match wins. Sourced from `lib/core/routing/app_router.dart:78–126`.

| # | Rule | Lines | Evaluation |
|---|---|---|---|
| 1 | `/referral` always allowed | 86 | OK — survives all gates |
| 2 | `prefs.isFirstTime == true` → `/onboarding` | 87–89 | OK — but pre-empts referral on first install (see F-N10) |
| 3 | No session → `/auth` | 98–101 | OK — uses `currentSession` not `currentUser` (Phase 88 fix) |
| 4 | On `/onboarding` + has session → `/prediction` | 109–111 | DEAD — see F-N4 |
| 5 | On `/auth` + has session + not anon → `/paywall` | 112–114 | OK — but compound effect with rule 3 |
| 6 | `/admin` requires admin claim | 120–124 | OK |

Rules 1, 2, 3, 5, 6 work as documented. Rule 4 is unreachable.

### Finding F-N4: `/prediction` redirect rule is unreachable from in-app navigation
**Severity:** 4/5 (3 in PRODUCT_STRUCTURE_REPORT, raised here because it's a router-specific code-path issue)
**Where:** `lib/core/routing/app_router.dart:109–111`; `lib/features/onboarding/presentation/onboarding_screen.dart:210–216` (atlas §4.4)
**Observation:** Rule 4 fires when the user navigates to `/onboarding` while having a session. Inspecting the codebase:
- The wizard's `_finish()` (`onboarding_screen.dart:178`) sets `prefs.isFirstTime = false`, then `signInAnonymously()` (line 193), then `context.go('/paywall')` (line 216). At no point does any in-app surface push `/onboarding` after the user has a session.
- Rule 2 (`isFirstTime == true → /onboarding`) takes precedence on first install. After completion, `isFirstTime == false`, so rule 2 doesn't fire either.
- The only path that could trigger rule 4 is a manual `context.go('/onboarding')` call from somewhere in the app after first-time = false. No such call exists (grep `'/onboarding'` and `AppRoutes.onboarding`):

```
grep -rn "AppRoutes.onboarding\|'/onboarding'" lib/
→ lib/core/routing/app_router.dart:32 (declaration)
→ lib/core/routing/app_router.dart:88 (rule 2)
→ lib/core/routing/app_router.dart:109 (rule 4)
→ lib/core/routing/app_router.dart:148 (route registration)
```

No producer.

**Cost:**
- Dead code in critical path: future devs reading the redirect rules see a `/prediction` reference that doesn't fire and may waste time trying to route to it.
- The prediction screen widget is built and registered (`app_router.dart:182`) but reachable only by a hypothetical direct invocation. It's a 200+ line orphan.

**Evidence:**
```dart
// app_router.dart:109–111
if (path == AppRoutes.onboarding) {
  return AppRoutes.prediction;
}
```
```dart
// onboarding_screen.dart:210–216
// Phase 60C · the dynamic report screen is now the on-wizard hook
// that the prediction screen used to be, so the wizard exits
// straight to /paywall instead of stopping over at /prediction.
context.go(AppRoutes.paywall);
```

The atlas §4.4 calls this out factually; this report quantifies the orphan as a routing-layer cleanup task.

### Finding F-N6: `/auth` and `/paywall` are 2 redirect-touch routes; signed-in user bouncing through `/auth` always lands on paywall
**Severity:** 4/5
**Where:** `lib/core/routing/app_router.dart:112–114`
**Observation:** Rule 5: a signed-in (non-anonymous) user navigating to `/auth` is redirected to `/paywall`. This is technically correct for the "user already has account, doesn't need auth screen" case — but the side effect is that any in-app surface that navigates to `/auth` (e.g., guest-login tile in profile) routes a non-anon user straight to paywall, bypassing dashboard entirely.

Compound effect with rule 3 (no session → `/auth`):
- Sign-out from another surface fires `auth.onAuthStateChange`, GoRouter re-evaluates redirects.
- If user was on `/dashboard`, rule 3 fires → goes to `/auth`.
- Sign back in, rule 5 fires → goes to `/paywall`.
- User is now on the paywall, not back on the dashboard they came from.

**Cost:**
- Sign-out → sign-in on a non-anonymous account loops user through paywall every time. For a Pro user, the paywall is a useless screen (they already have entitlement; they'd see the "FormAI Premium" tile context but the paywall is configured to assume Free).
- Mental-model violation: "I signed out and back in" → "why am I on the paywall?"

**Evidence:**
```dart
// app_router.dart:112–114
if (path == AppRoutes.auth) {
  return user.isAnonymous ? null : AppRoutes.paywall;
}
```

### Finding F-N10: First-time gate forces `/onboarding` from any path — referral deep link on first install is shadowed
**Severity:** 3/5
**Where:** `lib/core/routing/app_router.dart:87–89`; atlas §3.2 rule 2
**Observation:** Rule 2 forces `/onboarding` if `prefs.isFirstTime == true`. Rule 1 (`/referral` always allowed, line 86) is checked *before* rule 2, so a deep link to `/referral?code=XXXX` on first install survives the gate. **However:** Android cold-start that feeds the route URI through Flutter's `routeInformation` channel before `app_links` listener fires (atlas §3.3 mentions this race) may cause the GoRouter to evaluate the URI before the listener replays it. In that race, rule 1 still hits (path == `AppRoutes.referralLanding` is checked syntactically). Verified safe.

**But** for ANY path that isn't exactly `/referral`, rule 2 fires. So:
- First-install deep link to `/workout/today` (from a friend showing "look at this app" via shared widget URL) → forced through onboarding.
- First-install deep link to `/recipe?id=...` (hypothetical share) → forced through onboarding.

**Cost:**
- Deep-link intent is preserved only for referral. All other deep-link types lose context on cold install.
- For a future expansion (recipe sharing, workout-day sharing), the redirect rule is a structural blocker — the developer will need to add per-type allow-listing.

**Evidence:**
```dart
// app_router.dart:86–89
if (path == AppRoutes.referralLanding) return null;
if (prefs.isFirstTime) {
  return path == AppRoutes.onboarding ? null : AppRoutes.onboarding;
}
```

Only one allowlist entry. Hardcoded.

---

## 3. THE `/prediction` ROUTE DISCREPANCY — IMPACT ANALYSIS

Atlas §4.4 documents the discrepancy. This section quantifies impact per requirements.

### Who reaches `/prediction`?
**Nobody, via in-app navigation.** Confirmed via:
```
grep -rn "context\\.\\(go\\|push\\|pushReplacement\\).*\\bprediction\\b" lib/
→ no results
```

### When could `/prediction` be reached?
- Direct URL bar typing on web build (no web platform observed).
- A future `context.go(AppRoutes.prediction)` call (none currently).
- Hypothetical direct `_router.go('/prediction')` from a service (none observed).

### What does it cost when users do reach it?
The prediction screen widget renders cleanly (`prediction_screen.dart:104–192`). Its onTap fires `context.go(AppRoutes.paywall)` (line 176). So a user who somehow lands there sees:
- Header (with optional back button)
- Hero card with goal + duration + difficulty
- 2 stat pills
- Date card
- Plan checklist (5 features)
- Pulsing "Planın seni bekliyor" CTA
- Tap CTA → paywall

It's not broken; it's an extra screen between any conceivable arrival and the paywall. Not currently reached, so the cost is nil for users today.

### What does it cost when they don't reach it?
- Atlas §4 calls the wizard's exit path "Phase 60C decision documented in code." The structural cost is dev confusion + 200+ lines of unused widget code + a redirect rule that future PRs may "fix" by re-routing through prediction (recreating Phase 59-era flow).
- No user-facing impact today.

**Recommendation deferred to Phase 5+:** either remove the route + redirect + screen, or restore the wizard's pass-through to it. Current state (orphan) is the worst option for code health.

---

## 4. DEEP-LINK GATES — WORKOUT/TODAY ON SIGNED-OUT DEVICES

### Finding F-N2: Workout/today deep link silently discards intent on signed-out devices
**Severity:** 5/5
**Where:** `lib/core/services/deep_link_service.dart:96–106`; `lib/core/routing/app_router.dart:78–126`
**Observation:** The `formai://workout/today` and `https://formai.app/workout/today` deep links are produced by:
- iOS WidgetKit tile tap (atlas §5.8)
- Android AppWidgetProvider tap
- iOS Live Activity tap (atlas §1)

Their handler in `DeepLinkService._route()` (line 101–106) calls `_router.go(AppRoutes.workout)`. The router then evaluates redirects:
- If `isFirstTime == true` → `/onboarding`
- Else if no session → `/auth`
- Else → `/workout` (the actual destination)

So a user who tapped a home-screen widget specifically to "start today's workout" but is signed out lands on `/auth`. After signing in, the redirect rule 5 fires (`/auth` + has session + not anon → `/paywall`), and they land on paywall. The original workout intent is **never restored**.

**Cost:**
- The widget-tap intent is the cleanest "I want to start today's workout" signal in the entire product. Discarding it is a major loss.
- The user has to:
  1. Tap widget → expect workout
  2. See auth screen (no context)
  3. Sign in
  4. See paywall (irrelevant — they wanted to work out)
  5. Close paywall
  6. Land on dashboard
  7. Re-navigate to workout (4 more steps per Journey B)

**11+ steps to recover from "tap widget, get workout."**

The DeepLinkService comment at line 97–99 acknowledges this:
> *"The router's auth + first-time gates still apply, so a signed-out user clicking the widget lands on /auth and gets bounced through onboarding before the camera surface opens."*

The cost is acknowledged but not mitigated. There is no preserved-intent mechanism — no `pendingDeepLink` provider, no toast on the auth screen explaining "Sign in to start your workout," no `/auth?next=/workout` query parameter pattern.

**Evidence:**
```dart
// deep_link_service.dart:96–106
if (segments.first == 'workout' &&
    segments.length >= 2 &&
    segments[1] == 'today') {
  _router.go(AppRoutes.workout);
  return;
}
```
```dart
// app_router.dart:98–101
final session = Supabase.instance.client.auth.currentSession;
if (session == null) {
  return path == AppRoutes.auth ? null : AppRoutes.auth;
}
```
No "next" parameter, no intent preservation.

### Finding F-N8: Custom-scheme deep link parsing relies on Phase 57 host-splice — fragile to URL formatting variations
**Severity:** 3/5
**Where:** `lib/core/services/deep_link_service.dart:79–133`
**Observation:** The Phase 57 fix (atlas §3.3) handles the Dart `Uri` parser quirk: `formai://r/CODE` parses `r` as host, `CODE` as `pathSegments[0]`. The fix splices host into the segments list. The handler:
```dart
List<String> _normalisedSegments(Uri uri) {
  final segments = <String>[];
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'https' && scheme != 'http' && uri.host.isNotEmpty) {
    segments.add(uri.host);
  }
  segments.addAll(uri.pathSegments);
  while (segments.isNotEmpty && segments.last.isEmpty) {
    segments.removeLast();
  }
  return segments;
}
```

This works for `formai://r/CODE` and `https://formai.app/r/CODE`. But:
- `formai:r/CODE` (no `//`) — Uri parses differently, may be opaque scheme.
- `formai://CODE` (no command segment) — host = `CODE`, pathSegments empty; fall-through to dashboard (line 107).
- `formai://workout` (no `today`) — host = `workout`, pathSegments empty; segments = `['workout']`, length < 2, fall-through.

**Cost:**
- A user who manually types or shares a malformed link gets a silent dashboard fallback. No "this link is invalid" feedback.
- Future deep-link types (e.g., `formai://referral/CODE` instead of `formai://r/CODE`) would silently 404 to dashboard.

### Finding F-N11: DeepLinkService routes to dashboard fallback for unknown paths — silent intent loss
**Severity:** 3/5
**Where:** `lib/core/services/deep_link_service.dart:107`
**Observation:** Line 107: `_router.go(AppRoutes.dashboard);` — the catch-all. Logged but not shown to user.
**Cost:** Same as F-N8 — silent failure on unknown paths.
**Evidence:**
```dart
// deep_link_service.dart:107
_router.go(AppRoutes.dashboard);
```

---

## 5. BACK-BUTTON BEHAVIOR

### 5.1 PopScope / WillPopScope inventory

A grep reveals **only one** `PopScope` usage in the codebase:
```
grep -rn "PopScope\|WillPopScope" lib/
→ lib/features/auth/presentation/auth_modal_bottom_sheet.dart:34, 67
```

The single PopScope is on the auth gate modal: `PopScope(canPop: false)` (line 67), which prevents dismissal.

**Notable absence:** the workout camera screen does NOT use PopScope to confirm exit during an active set, despite atlas §13 mentioning `workout_back_button.dart` "exit w/ unsaved-progress safeguard."

```
grep -rn "workout_back_button" lib/
→ lib/features/workout/presentation/widgets/workout_back_button.dart
```

This widget exists; let me note it doesn't show a PopScope at the screen level. Its safeguard is button-level — i.e., tapping the on-screen back button shows a confirm dialog, but a hardware-back gesture or an iOS edge-swipe falls through to the default GoRouter pop.

### Finding F-N5: "Back" from `/paywall` after Day 4+ tap goes to dashboard, not the workout the user was trying to start
**Severity:** 4/5
**Where:** `lib/features/home/presentation/widgets/today_task_card.dart:107` (`context.push(AppRoutes.paywall)`); `lib/features/workout/presentation/plan_detail_screen.dart:312`; `lib/features/monetization/presentation/paywall_screen.dart:578` (close-X handler — see below)
**Observation:** Free user on Day 4, taps "ANTRENMANA BAŞLA" → `context.push(AppRoutes.paywall)`. Paywall is now on top of dashboard in the stack. Close X tap calls (per `paywall_screen.dart:574` — `Navigator.of(context).pop()`):
- pops `/paywall` → returns to whatever was below.

But the original tap was from `today_task_card.dart`, which is inside Gelişim tab inside `dashboard_screen.dart`. So `pop()` returns to the dashboard at the Gelişim tab. The user is back on the same screen they started from, with the same Today Task Card showing the same "ANTRENMANA BAŞLA" CTA.

**Cost:**
- No advancement: user wanted to start a workout, hit paywall, closed paywall, is back at start. The natural follow-up ("OK what now?") has no obvious path.
- Different from a "preserve and pause workout" pattern where closing paywall would still let user begin a free preview of the workout they wanted.
- Repeated taps re-trigger paywall — the gate is sticky.

**Evidence:**
```dart
// today_task_card.dart:104–113
if (!isPro && activeDay.dayNumber > kFreeDayLimit) {
  AppHaptics.secondaryTap();
  context.push(AppRoutes.paywall);
  return;
}
```

The push routes to paywall but returns to the SAME card on close. The Day 4+ gate effectively makes the Today Task Card non-functional for free users until they upgrade.

### Finding F-N9: Default GoRouter back-pop on `/auth` from paywall trigger does not return user to paywall
**Severity:** 3/5
**Where:** `lib/features/auth/presentation/auth_modal_bottom_sheet.dart:469–471`
**Observation:** The auth modal's "E-posta ile Giriş Sayfasına Git" link calls:
```dart
Navigator.of(context, rootNavigator: true).pop();
context.go(AppRoutes.auth);
```

`context.go` *replaces* the route stack (not push). After successful sign-in, AuthScreen does `pushReplacement(/paywall)` (`auth_screen.dart:53`). So the chain is:
- Was on `/paywall` → modal up → modal pops → `go('/auth')` → email submit → `pushReplacement('/paywall')` → on `/paywall`

That works, but the user has lost any back-stack history. If they were on `/paywall` because they navigated from the Profile tab, hitting back from the post-sign-in paywall doesn't return to Profile — it goes wherever GoRouter's stack permits, which after `go` is just dashboard.

**Cost:**
- Stack history erased mid-flow. User who was casually browsing Profile → tapped FormAI Premium → got auth gate → routed to email auth → signed in → on paywall → close X → lands on dashboard, NOT back on Profile tab they came from.

**Evidence:**
```dart
// auth_modal_bottom_sheet.dart:468–471
void _onEmailLoginPressed() {
  Navigator.of(context, rootNavigator: true).pop();
  context.go(AppRoutes.auth);  // .go replaces stack
}
```

### 5.2 Back-button trap: workout camera

Atlas §8.6 lists 5 screens between tap-start and exercise begin. The workout camera does not use `PopScope` to safeguard hardware back during a rep. The atlas mentions a "back button" widget (`workout_back_button.dart`) but it's an on-screen control. Hardware-back and iOS edge-swipe fall through to default GoRouter pop, ending the session without confirmation.

**This is a finding-worthy gap but not currently surfaced as a flow issue in code review.** Sev would be 3 (mid-workout state loss). Listed for completeness; not enumerated in main table because the workout flow's primary path uses the on-screen exit button.

---

## 6. TAB-SWITCH STATE LOSS

### Finding F-N3: Tab-switch preserves widget state via IndexedStack but loses scroll position in pushed sub-routes
**Severity:** 4/5
**Where:** `lib/features/home/presentation/dashboard_screen.dart:117–128`; atlas §3.4
**Observation:** The dashboard uses `IndexedStack` (`dashboard_screen.dart:119–127`):
```dart
child: IndexedStack(
  index: _index,
  children: const [
    AntrenmanTab(),
    NutritionTab(),
    GelisimTab(),
    ProfileTab(),
  ],
),
```
`IndexedStack` keeps all 4 children mounted; switching tabs swaps visibility, not lifecycle. Therefore widget state (e.g., the Antrenman tab's `_selectedCategory` chip) is preserved across tab switches.

**However:**
1. Pushed sub-routes (e.g., `/recipe` opened from Beslenme) are owned by the GoRouter root navigator, NOT a per-tab nested navigator. So tapping a recipe in Beslenme → push `/recipe` → switch to Antrenman → switch back to Beslenme → the `/recipe` is still on top (it's the active route). User must hit back to return to Beslenme tab body.

2. ListView scroll positions inside each tab ARE preserved (IndexedStack keeps the widget mounted, ListView keeps its own scroll controller).

3. **But:** if any tab uses a `RefreshIndicator` + `ref.invalidate(provider)` pattern (Gelişim does, line 119–122), the data underneath the scroll may change while the user was on another tab. Scroll position numerically preserved, but content can shift.

4. **Critical:** the `/plan-detail`, `/workout`, `/paywall`, etc. are top-level routes pushed above the dashboard. Switching tabs is irrelevant during their lifetime — the dashboard is hidden under a pushed route. When the pushed route pops, dashboard re-renders with `_index` whatever it was last set to (state preserved). But if that was a deeply nested sub-route inside a tab, only the tab body remembers state — anything that triggered the route push is gone (that was a route, not state).

**Cost:**
- For long content (Gelişim 9 sections, nutrition discover paginated grid), users can scroll deep into a tab, switch away to check another tab, and come back to find scroll preserved BUT data underneath possibly changed (if a refresh fired).
- For pushed sub-routes inside a tab (e.g., recipe detail from Beslenme), tab-switching feels broken — user expects "tab home" but gets the still-active recipe detail.
- Loading state during tab-switch: if Beslenme is still loading recipes when user switches to Antrenman and back, the loading skeleton may show again or may be replaced by data — depends on the AsyncValue caching layer.

**Evidence:**
```dart
// dashboard_screen.dart:117–128 — IndexedStack
body: SafeArea(
  bottom: false,
  child: IndexedStack(
    index: _index,
    children: const [
      AntrenmanTab(),
      NutritionTab(),
      GelisimTab(),
      ProfileTab(),
    ],
  ),
),
```
No tab-specific `Navigator` widget. All push routes go to root.

---

## 7. THE FORCED-AUTH GATE — ESCAPE-VALVE GAP

### Finding F-N1: Forced-auth modal has no escape valve when OAuth + email both fail
**Severity:** 5/5
**Where:** `lib/features/auth/presentation/auth_modal_bottom_sheet.dart:67–69` (PopScope canPop:false); `lib/features/monetization/presentation/paywall_screen.dart:182–214`; atlas §6.7
**Observation:** Phase 94 contract (per `auth_modal_bottom_sheet.dart:30–55` doc):
> *"The behavioural contract: the future returned by `showAuthGate` resolves only when the gate is dismissed, which can happen in exactly three ways: (1) Successful Google or Apple sign-in, (2) The 'Go to email login' link, (3) (Defensive only — not part of the supported flow) the route is removed by another navigator action."*

The route is registered with `barrierDismissible: false` (line 61), `barrierColor: Colors.transparent` (line 62), and the page builder wraps in `PopScope(canPop: false)` (line 67). The single-fire latch `_authGateShown` (line 45 in paywall_screen.dart) prevents re-trigger after a successful sign-in.

**Failure scenarios with no escape:**

1. **Google Sign-In fails AND Apple Sign-In fails:**
   - User on Android device, no Apple option (or Apple unavailable) → only Google.
   - Google fails (e.g., wrong GOOGLE_WEB_CLIENT_ID, account block, GMS not installed on a Huawei device, AppGallery distribution).
   - User taps "E-posta ile Giriş Sayfasına Git" → routes to `/auth` (line 469–471).
   - Email/password attempt to sign up fails (Supabase project misconfigured, email domain rejected, password too weak). Toast shows error, user is on `/auth` screen.
   - The auth screen has Misafir Olarak Devam Et (`auth_screen.dart:122–136` — `_continueAsGuest`). This calls `signInAnonymously` and routes to paywall. **But the user just came from a paywall that anonymous-gated them.** So they're routed back to paywall, where the gate fires again. Infinite loop.

2. **Network is up but Supabase auth endpoints are down:**
   - All paths fail. User stuck on auth modal or `/auth` screen.

3. **User on a corporate-managed device blocking OAuth providers:**
   - Same — no recovery.

The atlas calls this "Phase 94 forced auth gate." The PR was deliberate and documented. But no escape valve was built for the failure cases.

**Cost:**
- The user sees the same modal/screen indefinitely. Hard kill the app.
- After hard kill + relaunch:
  - `prefs.isFirstTime == false` (set by `_finish()` before sign-in attempt).
  - But anon sign-in may have failed too (line 192–204 of onboarding catches this and routes to `/auth`). So second launch routes to `/auth`. Same problem.
  - User is locked out until OAuth/Supabase recovers.

**Evidence:**
```dart
// auth_modal_bottom_sheet.dart:60–70
PageRouteBuilder<void>(
  opaque: false,
  barrierDismissible: false,
  barrierColor: Colors.transparent,
  ...
  pageBuilder: (context, animation, secondaryAnimation) {
    return PopScope(
      canPop: false,
      child: _AuthGateScaffold(animation: animation),
    );
  },
  ...
),
```
```dart
// auth_modal_bottom_sheet.dart:444–460
case SocialAuthOutcome.success:
  Navigator.of(context, rootNavigator: true).pop();
case SocialAuthOutcome.cancelled:
  break;  // <-- silent, modal stays up
case SocialAuthOutcome.error:
  _toast(result.errorMessage ?? fallbackError);  // toast only, modal stays up
```
On error, the modal stays up. Indefinitely.

The auth modal title is "Planını kaydetmek için ücretsiz hesabını oluştur." — Phase 94 sells it as a save-your-plan affordance. But a user who's encountered the gate has no "skip & save locally" button.

### 7.1 Other gate hardening notes

The Phase 94 latch (`_authGateShown`, paywall_screen.dart:45) ensures the gate fires *at most once per paywall mount*. So:
- User signs in successfully → modal pops → paywall is fully visible → `_authGateShown` stays `true`.
- User cancels OAuth → still anonymous → no modal re-trigger because latch is true. But the user's purchase is still gated by RevenueCat (`canPurchase` requires offerings + sdk-ready, but the actual "is this user authenticated" check is done at PURCHASE time inside RevenueCat-side aliasing).

Wait — this is the bug Phase 94 was designed to prevent. Re-reading paywall_screen.dart 182–191:

```dart
void _onAuthStateChanged(User? previous, User? next) {
  if (_authGateShown) return;
  ...
}
```

Once shown, never re-shown. But the user can still tap the purchase CTA. If they tap CTA while still anonymous (because they cancelled OAuth):
- `_purchase` (line 548–586 in atlas) calls `Purchases.purchasePackage`. This succeeds with anonymous RC ID.
- The Phase 94 doc explicitly states this is the bug: anonymous purchases get bound to throwaway RC ID.

**Is the gate actually preventing this?** The latch prevents re-trigger, but the latch is `_authGateShown` (set when `showAuthGate` is *called*, not when sign-in succeeded). So:
- User on paywall (anonymous) → gate triggered, latch true → user cancels OAuth → modal still up but no actions → user closes modal somehow (only via the email link → routes to `/auth` → not a modal close).

Wait — actually the modal is non-dismissible. And canceling OAuth keeps the modal up. So a determined-cancelling user is stranded as F-N1 describes. They cannot tap the CTA on paywall because the modal is on top.

So the Phase 94 contract is enforced — but the failure-mode escape is missing. F-N1 stands at sev-5.

---

## 8. ERROR-RECOVERY ROUTES

### Finding F-N7: `errorBuilder` self-recovery has 200ms defer that's a fixed delay, not signal-based
**Severity:** 3/5
**Where:** `lib/core/routing/app_router.dart:308–331`
**Observation:** The Phase 57 `_DeepLinkSplashScreen` is rendered by GoRouter's `errorBuilder` for unmatched paths. After a fixed 200ms delay, it `context.go(AppRoutes.dashboard)` to recover.

```dart
// app_router.dart:326–330
WidgetsBinding.instance.addPostFrameCallback((_) async {
  await Future<void>.delayed(const Duration(milliseconds: 200));
  if (!mounted) return;
  context.go(AppRoutes.dashboard);
});
```

The 200ms is a hand-tuned guess that the deep-link listener will resolve before the timeout fires. If the listener is slow (e.g., on a cold-start with a heavy bootstrap), the user briefly sees the splash, then dashboard, then suddenly the deep-link target — a flicker.

**Cost:**
- Visual jank on slow devices. The atlas comment (line 322–324) acknowledges this is a deliberate trade-off.
- Splash text "FormAI" is hardcoded; doesn't communicate "loading" or "resolving link" — the user might think the app crashed.

### Finding F-N12: `_DeepLinkSplashScreen` always navigates to dashboard after 200ms, even if listener resolved a different route
**Severity:** 3/5
**Where:** `lib/core/routing/app_router.dart:326–331`
**Observation:** The post-frame callback unconditionally calls `context.go(AppRoutes.dashboard)` after the 200ms delay. If the deep-link listener has already resolved the route in the meantime, the new dashboard navigation is queued via `context.go`. Since the splash widget tears down (per the route change), the post-frame callback's `context.go(AppRoutes.dashboard)` should be a no-op against the new active location — but only if the splash widget unmounted before the callback fires.

The atlas comment (line 322–324) addresses this:
> *"If the listener resolved first the route changes, this widget tears down and the post-frame callback's `go` becomes a no-op against the active location."*

The comment is correct but assumes the unmount happens within 200ms. On a slow device or a slow listener resolution, the splash could still be active when the callback fires, then `go(dashboard)` would override the listener's intended destination.

**Cost:**
- Race condition between listener and timer — user-visible if listener resolves at ~250ms.
- Mitigated in practice by Flutter's frame scheduling but not formally guaranteed.

### Finding F-N15: `_MissingReferralCode` and `_MissingRecipe` use `context.go` to dashboard — replaces the entire stack
**Severity:** 2/5
**Where:** `lib/core/routing/app_router.dart:381, 421`
**Observation:** Both error fallback widgets use `context.go(AppRoutes.dashboard)`. `go` replaces the entire stack. If the user came from a deep link, the stack only has the error route + dashboard — fine. But if a future flow pushes either of these from inside a stack of multiple routes, the back history is wiped.
**Cost:** minor — current usage is via deep link, so stack is shallow. Future-proofing concern.

---

## 9. PAYWALL NAVIGATION DEPTH

### Finding F-N14: All paywall destinations use `context.push` — creates navigation depth on serial paywall hits
**Severity:** 2/5
**Where:** 8 sites; sample at `today_task_card.dart:107`, `plan_detail_screen.dart:312`, `antrenman_tab.dart:554`, `profile_tab.dart:266`
**Observation:** Every in-app paywall trigger uses `context.push(AppRoutes.paywall)`. None use `context.go` (which would replace the stack). A user who:
- Tap Today Task → paywall pushed
- Close paywall → back to dashboard
- Tap PRO pill → paywall pushed
- Close → back to dashboard

Stack is fine for these. But:
- Tap Today Task → paywall → close → tap plan-detail Day tile → paywall pushed AGAIN (stack: dashboard → paywall(closed→popped) → dashboard → plan-detail → paywall).
- Repeated push/pop is OK for a stack, but if the user navigates without popping (e.g., paywall → tap CTA → in-app browser opens for billing flow → returns), the stack grows.

**Cost:** Minor stack pollution. Marginal memory cost. No user-visible bug observed.

### Finding F-N13: `/workout/today` is a route alias for `/workout` — semantic intent ("today") not preserved
**Severity:** 2/5
**Where:** `lib/core/routing/app_router.dart:171–175`
**Observation:** The Phase 57 alias maps `/workout/today` → `/workout` via a redirect. So a deep-link tap on the home-screen widget effectively just opens `/workout`.

The widget's current implementation (`workout_camera_screen.dart`) is generic — it picks "today's day" from `workoutSessionProvider` regardless. So functionally, the alias is fine. But semantically, the URL `/workout/today` could carry intent — a user sharing this URL means "today's workout for me." On a different account / different day, the deep link would open a *different* workout (whatever is "today" for the recipient).

**Cost:** No bug surface today. If sharing functionality is added, the URL semantics would mislead.

---

## 10. STRUCTURAL OBSERVATIONS — NAVIGATION SUMMARY

### Redirect rules
- 6 rules defined; 5 are functional, 1 (`/prediction`) is unreachable.
- Order is correct (referral allow before first-time gate).
- One escape-valve hole: rule 5 (auth → paywall for non-anon) routes signed-in users through paywall on every sign-out → sign-in cycle.

### Deep links
- 2 producer types (custom scheme + universal link).
- Phase 57 segment normalization handles the Dart Uri quirk.
- No "next" parameter or intent preservation. Workout/today on signed-out devices loses intent silently.
- Catch-all routes to dashboard with no error feedback.

### Back-button behavior
- Only one PopScope in the entire app (auth gate, designed to trap).
- Workout camera does not block hardware back; mid-rep back gestures lose state.
- `context.go` calls in error widgets erase stack history.

### Tab-switch state preservation
- IndexedStack keeps widget state per tab.
- Pushed sub-routes are owned by root navigator — not nested per tab.
- Refreshing data underneath preserved scroll positions can shift content silently.

### Forced-auth gate (Phase 94)
- **Critical: no escape valve** for users whose OAuth + email both fail. F-N1 sev-5.
- Latch prevents re-trigger; that's correct behavior for the happy path.
- Cancel OAuth = stuck on the modal indefinitely.
- Hard kill + relaunch hits the same gate.

### Error recovery
- `_DeepLinkSplashScreen` has 200ms hardcoded recovery timer — race-prone on slow devices.
- `_MissingReferralCode` and `_MissingRecipe` are dead-end widgets with single "back to dashboard" button.

---

## 11. ERRATA AGAINST PHASE 1 ATLAS

The atlas's routing facts are accurate. Two extensions:

1. **Atlas §3.2 rule 4** (`/onboarding` → `/prediction`) is correctly described. **This report extends:** the rule is unreachable from any in-app surface (verified via grep; no producer pushes `/onboarding` after first-time = false). Pure orphan logic.

2. **Atlas §3.3** describes the deep-link service correctly. **This report extends:** the workout/today path applies router gates and silently discards intent. Not just a "gates apply" note — the user experience is much worse (11+ steps to recover) than the atlas's neutral phrasing implies.

3. **Atlas §6.7** documents the Phase 94 forced-auth gate factually. **This report extends:** there is no escape valve for the OAuth + email failure case. The Phase 94 contract works correctly for the happy path; the design omits a fallback for the failure path. Sev-5.

No factual errata. Atlas remains accurate; this report adds severity-scoring + cost analysis.

---

## 12. APPENDIX — EVIDENCE INDEX

| Finding | File:Line | Atlas §ref |
|---|---|---|
| F-N1 | `auth_modal_bottom_sheet.dart:67–69`, `paywall_screen.dart:182–214` | §6.7 |
| F-N2 | `deep_link_service.dart:96–106`, `app_router.dart:78–126` | §3.3, §5.8 |
| F-N3 | `dashboard_screen.dart:117–128` | §3.4 |
| F-N4 | `app_router.dart:109–111`, `onboarding_screen.dart:210–216` | §3.2, §4.4 |
| F-N5 | `today_task_card.dart:107`, `paywall_screen.dart:578` | §6.4 |
| F-N6 | `app_router.dart:112–114` | §3.2 |
| F-N7 | `app_router.dart:308–331` | §3.3 |
| F-N8 | `deep_link_service.dart:79–133` | §3.3 |
| F-N9 | `auth_modal_bottom_sheet.dart:469–471` | §6.7 |
| F-N10 | `app_router.dart:87–89` | §3.2 |
| F-N11 | `deep_link_service.dart:107` | §3.3 |
| F-N12 | `app_router.dart:326–331` | §3.3 |
| F-N13 | `app_router.dart:171–175` | §3.1 |
| F-N14 | (8 sites) | §6.3 |
| F-N15 | `app_router.dart:381, 421` | §3.3 |
| F-N16 | `app_router.dart:72–76` | §3 |

---

**END OF NAVIGATION_FRICTION_REPORT.md**
