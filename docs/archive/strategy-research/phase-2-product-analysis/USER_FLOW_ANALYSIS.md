# USER FLOW ANALYSIS

**Phase 2 — Product Analysis · Flow Efficiency**
**Project:** SixPack AI / FormAI Fit
**Generated:** 2026-05-08
**Inputs:** atlas (§4 onboarding, §5 dashboard, §6 monetization, §8 workout, §3 routing); ~15 source-file inspections.
**Scope:** End-to-end flow analysis for 5 critical journeys. Each journey gets: tap-count, screen-count, decision points, drop-off risks, state-loss risks. Every finding severity-scored. ASCII sequence diagrams.

---

## 0. METHODOLOGY

For each journey:
- **Sequence diagram** — text-based, screen-to-screen progression.
- **Tap & screen tally** — quantified end-to-end cost.
- **Decision points** — screens where the user picks among >1 path.
- **Drop-off / state-loss risks** — identified via code evidence, severity-scored.
- **Findings** — same severity schema as PRODUCT_STRUCTURE_REPORT.md.

Severity: 5 = critical conversion blocker, 1 = cosmetic.

---

## 1. JOURNEY A — FIRST-LAUNCH → FIRST WORKOUT (cold install through Day 1 completion)

### A.0 Sequence

```
[App icon tap]
   │
   ▼
[Bootstrap — main.dart 4-layer guards + Supabase 8s + PostHog 5s]
   │ (split-second to ~8s; user sees branded splash)
   ▼
[Router redirect: prefs.isFirstTime == true → /onboarding]
   │
   ▼
[Onboarding step 1: _WelcomeStep]            ─┐
   │ (1.5s staggered fade; tap "BAŞLA")        │
   ▼                                            │
[Step 2: _CoachIntroStep]                       │
   │ (typewriter ~4s; tap-to-skip; tap CTA)    │
   ▼                                            │
[Step 3: _GenderStep]                           │
   │ (tap card → 1.5s feedback → auto-advance) │
   ▼                                            │
[Step 4: _GoalStep]                             │
   │ (tap → 1.5s → auto)                        │
   ▼                                            │ 12-step
[Step 5: _ExperienceStep]                       │ wizard
   │ (card OR text; tap or DEVAM)               │ no autosave
   ▼                                            │
[Step 6: _DailyMinutesStep]                     │
   │ (tap → 1.5s → auto)                        │
   ▼                                            │
[Step 7: _ActivityStep]                         │
   │ (card OR text)                             │
   ▼                                            │
[Step 8: _PhysicalDataStep]                     │
   │ (3 wheels — age/height/weight; tap DEVAM;  │
   │  1.5s "Metabolizmanı hesaplıyorum…")        │
   ▼                                            │
[Step 9: _PainPointStep]                        │
   │ (card OR text)                             │
   ▼                                            │
[Step 10: _AnalysisIllusionStep]                │
   │ (5 phrases × 1.2s = ~6s; no input)         │
   ▼                                            │
[Step 11: _DynamicReportStep]                   │
   │ (1.4s fade-in; tap "DEVAM")                │
   ▼                                            │
[Step 12: _PrePaywallSummaryStep]              ─┘
   │ (900ms fade; trust bar 1.1s; tap "PLANIMI GÖR")
   │
   ▼ _finish() — saves wizard, signs in anonymously,
   │            requestATTIfNeeded, configures RevenueCat,
   │            then go(/paywall)
   │
   ▼
[/paywall mounts]
   │ (Phase 94 forced-auth gate fires immediately
   │  because user is anonymous → showAuthGate(),
   │  PopScope canPop:false, barrierDismissible:false)
   │
   ▼
[Auth modal sheet — 50% screen height]
   │ Decision: Google / Apple / "E-posta ile Giriş Sayfasına Git"
   │
   │  ┌─ Google OAuth → AuthController.signInWithGoogle
   │  │  ─→ RC alias call ─→ modal pops ─→ paywall fully visible
   │  ├─ Apple OAuth → similar path
   │  └─ Email link → modal pops, context.go(/auth)
   │      ─→ AuthScreen → email/password form OR Misafir Olarak Devam Et
   │      ─→ on submit: pushReplacement(/paywall)
   │
   ▼ (anonymous→registered upgrade complete)
[/paywall fully visible]
   │ Decision: 3 plans × select / Restore / Sandbox / X close
   │ (Pro purchase NOT in this journey — user is going to home)
   │
   ▼ tap close X → context.pop() → returns to dashboard via router
   │
   ▼
[/  Dashboard, default tab Antrenman]
   │ Decision: which CTA?
   │   Option 1: Challenge Hero "BAŞLA"           → /plan-detail (30-day mode)
   │   Option 2: Tap Gelişim tab → "ANTRENMANA BAŞLA" → /plan-detail (30-day mode)
   │   Option 3: Tap an Equipment card or Regional plan → /plan-detail (regional mode)
   │
   ▼ assume Option 1 (most-prominent surface)
[/plan-detail (30-day program mode)]
   │ Renders: hero header + sticky "29 gün kaldı" + day-1 tile (active state) + 29 dim/locked tiles
   │ Decision: tap Day 1 tile (the active one)
   │
   ▼ _onDayTap → _ensureOnlineForWorkout (network check) → startDay(1) → push /workout
   │
   ▼
[/workout — WorkoutCameraScreen]
   │ HAZIRLAN! prep overlay (3s countdown)
   │ → camera feed + first exercise (ML Kit pose detection)
   │ → rest overlay between sets
   │ → exercise → rest → ... per atlas §8.6 (5 distinct screens)
   │
   ▼ on completion: SessionCompleteOverlay
   │
   ▼ tap "TAMAM" → workoutSessionProvider marks day complete
   │
   ▼
[Back to /plan-detail OR /dashboard depending on stack]
[End of Journey A]
```

### A.1 Tally

| Metric | Count |
|---|---|
| Onboarding screens (steps 1–12) | 12 |
| Onboarding required taps | 11 (step 10 has no input; tap-to-skip on step 2 optional) |
| Onboarding total elapsed time (no auto-advance skip) | ~85–120 seconds (12 screens + 1.5s × 6 feedback delays + 6s analysis + 4s typewriter + ~30s of user thinking) |
| Auth modal taps | 1 (Google) — best case |
| Paywall close tap | 1 |
| Plan-detail Day 1 tap | 1 |
| Total taps from cold install to "exercise begin" | 13–15 (including auth, paywall close, plan-detail Day 1, prep ack) |
| Total screens to "exercise begin" | 17 (12 onboarding + paywall + auth + dashboard + plan-detail + workout HAZIRLAN!) |
| Drop-off risk locations | 5+ (see findings) |
| State-loss locations | 1 critical (onboarding mid-flow) |

### A.2 Decision Points

| # | Decision | Branch count | Default | Notes |
|---|---|---|---|---|
| D1 | Step 5 Experience: card or text | 4 | none | hybrid step |
| D2 | Step 7 Activity: card or text | 4 | none | hybrid step |
| D3 | Step 9 Pain Point: card or text | 5 | none | hybrid step |
| D4 | Auth modal: Google / Apple / Email link | 3 | none | non-dismissible |
| D5 | Paywall: 3 plans × select; or Close X | 4 | annual selected | close = "skip for now" |
| D6 | Dashboard: Antrenman challenge / Gelişim Today Task / Beslenme tab / Profil tab | 4+ | Antrenman tab default | most-prominent CTA isn't the personalized one |

### A.3 Findings

#### Finding J-A1: Onboarding state lost on app interruption between steps 1–11 (atlas §4.6, F-03 in PRODUCT_STRUCTURE_REPORT)
**Severity:** 5/5
**Where:** `lib/features/onboarding/presentation/onboarding_screen.dart:165–217`
**Observation:** Wizard data persists only at `_finish()`. App killed at step 9 → relaunch lands on step 1.
**Cost:** First-time users frequently get a phone call mid-onboarding. Total restart at any interruption is unforgiving for a 12-step flow.

#### Finding J-A2: 12-step wizard shows two unskippable labor-illusion delays (steps 10 + 11 fade-in)
**Severity:** 4/5
**Where:** `lib/features/onboarding/presentation/onboarding_screen.dart` (`_AnalysisIllusionStep` ~6s; `_DynamicReportStep` 1.4s); atlas §4 step 10 + 11
**Observation:** Step 10 cycles 5 phrases × 1.2s = 6 seconds with no skip affordance. Step 11 has a 1.4s fade-in. Step 8's "Metabolizmanı hesaplıyorum…" adds a 1.5s delay between input and advance. Cumulative forced wait: ~8.9 seconds.
**Cost:**
- For a *first-time* user, the labor illusion adds perceived value ("the AI is thinking"). For a *returning* user (e.g., after onboarding restart per F-03), these screens are pure friction.
- Combined with the 1.5s feedback banners on steps 3, 4, 6, 8 (4 × 1.5 = 6s of forced waits), total wizard floor is ~15s of unavoidable wait time.

**Evidence:** atlas §4.1 step descriptions; `onboarding_screen.dart` step 10 cycles `_AnalysisIllusionStep`'s 1.2s × 5 phrases.

#### Finding J-A3: Anonymous user is force-routed through OAuth/email gate before they can SEE the paywall they came to see
**Severity:** 5/5
**Where:** `lib/features/monetization/presentation/paywall_screen.dart:182–214`; `lib/features/auth/presentation/auth_modal_bottom_sheet.dart:67–69`; PRODUCT_STRUCTURE_REPORT F-04
**Observation:** Onboarding `_finish()` does an `signInAnonymously()` then `context.go('/paywall')`. The first frame of paywall mount triggers `_onAuthStateChanged`, which schedules the auth gate. The user wanted to evaluate the paywall (the entire point of the labor-illusion onboarding); they instead get an immediate "sign up to continue" wall.
**Cost:**
- **Anchoring failure:** the dynamic report (step 11) and pre-paywall summary (step 12) prepared the user to evaluate the paywall offer. The auth modal disrupts this by demanding identification first.
- **Decision-overload:** at the moment of highest commitment intent (just finished onboarding), user must make a sign-up decision *before* the conversion decision. Two heavy choices stacked.
- **No "see prices first" path** — the modal blocks the entire paywall from view (50% of screen blurred, bottom 50% modal).

#### Finding J-A4: Paywall close X bypasses purchase decision but is below the auth gate; user can't reach it pre-auth
**Severity:** 4/5
**Where:** `lib/features/monetization/presentation/paywall_screen.dart:315–319` (close X position); `lib/features/auth/presentation/auth_modal_bottom_sheet.dart:67–69` (PopScope blocks back)
**Observation:** Atlas §6.2 places the close X "top-right, transparent circle" at lines 315–319. The auth gate sheet covers the bottom 50% of the paywall but the top half (where the close X lives) is *blurred* (sigma 14, `auth_modal_bottom_sheet.dart:113–116`) and the BackdropFilter is rendered above `Positioned(top:0, bottom:modalHeight, ...)` — the close X is technically still in the widget tree but visually obscured AND its tap target is below the BackdropFilter+ColoredBox layer. Whether the InkWell registers taps through the filter depends on Flutter's pointer-routing semantics — even if it does, the user cannot SEE the X to tap it.
**Cost:**
- A user who decides "I just want to back out" cannot. There is no escape valve documented.
- This is the critical UX issue called out in NAVIGATION_FRICTION_REPORT.md F-N1 in detail.

#### Finding J-A5: 17 screens to "exercise begin" is an exceptionally long onboarding-to-action funnel
**Severity:** 4/5
**Where:** A.1 tally
**Observation:** From cold install to first rep, the user sees 17 distinct screens (12 onboarding + auth modal + paywall + dashboard + plan-detail + workout prep). For comparison, well-tuned freemium fitness apps (Freeletics, BetterMe) typically complete a similar journey in 9–12 screens by deferring less-critical questions and shortening the labor illusion.
**Cost:**
- Each screen is a drop-off opportunity. PostHog onboarding events (atlas line in `onboarding_screen.dart:114–117`) capture step indices; without exposing actual user funnel data here we can say the abandonment risk compounds at each transition.

#### Finding J-A6: Default dashboard tab is Antrenman; the personalized "today task" lives on Gelişim — user must switch tabs to find it
**Severity:** 3/5
**Where:** `lib/features/home/presentation/dashboard_screen.dart:37` (`int _index = 0`); F-01 PRODUCT_STRUCTURE_REPORT
**Observation:** A first-time user lands on Antrenman with the Challenge Hero card. The most-personalized "BUGÜNKÜ GÖREV" card (Today Task) is on Gelişim tab — invisible until the user explores. Both lead to `/plan-detail` 30-day mode for free users on Day 1, but the personalization signal (per-day focus, level, minutes) is more visible on Gelişim.
**Cost:** Personalization invested in steps 4–10 of onboarding doesn't surface at the most-likely first-tap location.

#### Finding J-A7: Workout flow is 5 screens between tap-start and exercise begin (atlas §8.6) — adds friction every session
**Severity:** 3/5
**Where:** atlas §8.6 explicitly: "5 distinct screens between tap-start and exercise begin: prep countdown (3 s) → camera feed → per-set rest/resume → session completion overlay → return to dashboard"
**Observation:** First-launch users tap "BAŞLA" on Antrenman → land on `/plan-detail` (screen 1) → tap Day 1 tile (screen 2 in the conceptual flow) → push `/workout` → see prep countdown overlay (screen 3) → camera feed with first exercise (screen 4) → between exercises rest overlay (screen 5).
**Cost:** Every workout session inherits this friction. Compounds across 30 sessions.

---

## 2. JOURNEY B — RETURNING USER → TODAY'S WORKOUT (the canonical loop)

### B.0 Sequence

```
[App icon tap]
   │ (auth.was_anonymous flag may trigger anon recovery in main.dart 273–296)
   ▼
[Bootstrap]
   │
   ▼
[Router: not first-time + has session → /]
   │
   ▼
[Dashboard, last-used tab? NO — _index = 0 (Antrenman) on every launch]
   │
   ▼
[Antrenman tab visible]
   │ Decision: which CTA?
   │   ─→ Option 1: Challenge Hero "BAŞLA" (most prominent — 320px image card)
   │   ─→ Option 2: tap Gelişim tab → "ANTRENMANA BAŞLA" (today task card)
   │   ─→ Option 3: scroll past hero, tap Equipment / Regional plan
   │
   ▼ assume Option 1
[/plan-detail (30-day mode, since extra is null)]
   │ Sticky header: "Bugün N. gün — N gün kaldı"
   │ Day list scrolled to show active day at top
   │ Decision: tap active day tile
   │
   ▼ _onDayTap → _ensureOnlineForWorkout → startDay(N) → push /workout
   │
   ▼
[/workout HAZIRLAN! prep — 3s]
   │
   ▼
[Camera feed + exercise]
[Begin exercise]
```

### B.1 Tally

| Metric | Count |
|---|---|
| Screens from cold-launch to exercise begin | 5 (dashboard + plan-detail + 3 workout screens [prep, exercise, rest is shared screen]) |
| Taps from "Antrenman" tab visible to exercise begin | 3 (CTA → Day tile → camera screen advances itself after prep) |
| Sub-decisions | 2 (which CTA on dashboard; which day on plan-detail — but only the active one is tappable) |
| Default-path screen count | 5 |
| Optimal screen count if direct | 3 (dashboard → /workout → exercise) |
| Excess screens vs theoretical optimum | +2 |

### B.2 Decision Points

| # | Decision | Forced? | Branch count |
|---|---|---|---|
| D1 | Which entry CTA on dashboard | No | 4 (Antrenman challenge / Gelişim today / Equipment / Regional) |
| D2 | Active day on plan-detail | Yes (only one is enabled) | 1 effective |

### B.3 Findings

#### Finding J-B1: Dashboard does not remember last-used tab; cold launch always lands on Antrenman
**Severity:** 4/5
**Where:** `lib/features/home/presentation/dashboard_screen.dart:37` (`int _index = 0;`)
**Observation:** `_index` is initialized to 0 in `_DashboardScreenState`. There is no read from SharedPreferences, no restore from the previous session. A user whose habit is "open app, go to Gelişim, tap Today Task" must perform an extra tab-switch every cold launch.
**Cost:**
- For the canonical "today's workout" loop, every cold launch costs an extra tap.
- Compounds with F-01 (role overlap): users who learn to use Gelişim are punished with an Antrenman default each time.

**Evidence:**
```dart
// dashboard_screen.dart:35–37
class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with RouteAware {
  int _index = 0;
```
No `initState` SharedPreferences read. No `appPreferences.lastTab` getter exists.

#### Finding J-B2: Plan-detail is an unnecessary intermediate screen for the canonical "start today's workout" flow
**Severity:** 3/5
**Where:** `lib/features/workout/presentation/plan_detail_screen.dart:300–323` (_onDayTap)
**Observation:** From the dashboard, "BAŞLA" or "ANTRENMANA BAŞLA" both push `/plan-detail`. The plan-detail screen renders a 30-day grid; the user must find and tap the active day tile, then `_onDayTap` calls `startDay()` and pushes `/workout`. For a returning user who only wants to do today's workout, plan-detail is a context surface they already saw on the dashboard (Today Task Card metadata is the same data).
**Cost:**
- Extra screen per session.
- The "Day N – Focus, minutes, level" info is duplicated between Today Task Card and plan-detail's day-N tile.
- A direct "tap CTA → camera screen" path would save 1 screen and 1 tap; the day-grid would still be available for users who want to choose a different day.

**Evidence:**
```dart
// today_task_card.dart:113
context.push(AppRoutes.planDetail);  // not /workout directly
```
```dart
// plan_detail_screen.dart:321–323
await ref.read(workoutSessionProvider.notifier).startDay(dayNumber);
if (!context.mounted) return;
context.push(AppRoutes.workout);
```

#### Finding J-B3: Day 4+ Pro gate forces a paywall round-trip mid-flow with no return-to-workout path
**Severity:** 5/5
**Where:** `lib/features/home/presentation/widgets/today_task_card.dart:104–108`; `lib/features/workout/presentation/plan_detail_screen.dart:300–314`
**Observation:** A free user on Day 4 taps "ANTRENMANA BAŞLA" → routes to `/paywall`. If they close the paywall (X), they land back on dashboard, NOT back into the workout flow. To retry, they must re-tap the same CTA — and get the same paywall.
**Cost:**
- Day 4 is the worst possible moment for a paywall (24h gap from a 3-day streak; motivation low). Atlas §6.4 documents the gate at `kFreeDayLimit = 3`.
- The Day 1–3 free preview is the strongest conversion lever — but the actual gate moment is uncushioned.
- See PRODUCT_STRUCTURE_REPORT F-02 for the pre-tap signaling cost. Here the focus is the *flow* impact: there is no "remind me later" or "sample one rest day for free" or "share to unlock" alternative. Just paywall or stop.

#### Finding J-B4: Returning user with stale anonymous session may face anon-recovery surprise
**Severity:** 3/5
**Where:** `lib/main.dart:273–296` (`auth.was_anonymous` recovery flag, atlas §2)
**Observation:** Atlas §2 step 2a notes: "if `auth.was_anonymous` flag set + no session, signs in fresh anon." The user's previous workout history (RLS-locked to old anon UID) becomes orphaned. The atlas §12 acknowledges this as accepted design.
**Cost:**
- Returning user could lose their visible progress without warning. The dashboard renders fresh-state UI ("Day 1, 0/30, 0 streak") and there's no toast or banner indicating "we recovered your account but past data is hidden."
- For a 30-day program, this could happen mid-program — the user sees their carefully built streak vanish silently.

---

## 3. JOURNEY C — FREE USER HITS THE PAYWALL (7 trigger surfaces)

### C.0 The 7 trigger surfaces (atlas §6.3)

| # | Trigger | Friction (taps) | Pre-tap signal? | Source |
|---|---|---|---|---|
| 1 | Today Task Card (Day 4+) | 1 | None | `today_task_card.dart:107` |
| 2 | Plan-detail Day tile (Day 4+) | 2 (dashboard CTA → day tile) | Yes — locked overlay (atlas §6.4 mentions 35% opacity dim) | `plan_detail_screen.dart:312` |
| 3 | Plan-detail regional CTA (locked) | 3 (dashboard CTA → regional → CTA) | Yes — "PRO İLE KİLİDİ AÇ" copy + lock icon | `plan_detail_screen.dart:1089` |
| 4 | Plan-detail upsell card (regional, no exercises) | 3 | Yes — "PRO İLE KİLİDİ AÇ" CTA | `plan_detail_screen.dart:1342` |
| 5 | Profile tab "FormAI Premium" tile | 4 (Profil tab → scroll → tile) | Yes — "FormAI Premium" + crown icon | `profile_tab.dart:266` |
| 6 | Antrenman header "PRO" pill | 1 | Ambiguous — looks like a status badge | `antrenman_tab.dart:554` |
| 7 | Post-onboarding redirect | 0 (forced) | n/a | `onboarding_screen.dart:216` |
| 8 | Post-OAuth redirect | 0 (forced) | n/a | `auth_screen.dart:53` |

(Atlas lists 7; this enumeration adds the post-OAuth surface for completeness, making 8.)

### C.1 Lowest-friction trigger: Today Task Card

```
[Dashboard, Gelişim tab] → [Tap ANTRENMANA BAŞLA] → [/paywall]
```
- 1 tap.
- No pre-tap signal that the day is gated.

### C.2 Highest-friction trigger: Plan-detail upsell card

```
[Dashboard Antrenman tab]
  → [scroll to regional list]
  → [tap a Pro-only regional plan]
  → [/plan-detail with plan extra]
  → [scroll to bottom]
  → [tap "PRO İLE KİLİDİ AÇ" CTA]
  → [/paywall]
```
- 5 taps (assuming scroll counts as 0; otherwise 6+).
- 3 pre-tap signals (locked dim, lock icon, copy).

### C.3 Findings

#### Finding J-C1: 8 paywall surfaces with inconsistent visual chrome and signal strength
**Severity:** 4/5
**Where:** atlas §6.3 + this report's enumeration; `paywall_screen.dart:72` analytics fires `paywallViewed()` with NO `source` parameter
**Observation:** Each of the 8 trigger surfaces has different visual treatment, different copy, different friction level. There is no `source` parameter on the `paywallViewed` analytics event (atlas §6.3 explicitly notes: "If the paywall is reached from multiple surfaces we'll wire a `source` param later via a constructor arg").
**Cost:**
- **Funnel attribution failure.** Without source, the team cannot tell which surface drives conversion vs which drives bounces.
- **Inconsistent UX.** A user who hit paywall via Today Task Card (zero pre-tap signal) experiences a "surprise"; one who hit via plan-detail regional CTA was prepared (locked tile, copy, multiple signals).
- **Compounded cognitive load:** 8 places means a Free user encounters paywall reminders constantly without a single "this is THE upgrade button" surface.

**Evidence:**
```dart
// paywall_screen.dart:65–73
@override
void initState() {
  super.initState();
  AnalyticsService.instance.paywallViewed();   // no source param
  ...
}
```

#### Finding J-C2: Today Task Card surface has zero pre-tap pricing signal — paywall arrival is a surprise
**Severity:** 4/5
**Where:** `lib/features/home/presentation/widgets/today_task_card.dart:33–99` (no `isLocked` rendering); F-02 in PRODUCT_STRUCTURE_REPORT
**Observation:** The Today Task Card visual on Day 4 is identical to Day 3 — same neon-gradient CTA, same "Gün N – Focus" layout. There is no lock icon, no "PRO" badge in the corner, no greyed-out state. The user taps expecting the workout, gets the paywall.
**Cost:** see F-02. Sev-5 in PRODUCT_STRUCTURE_REPORT, sev-4 here for the flow-level surprise.

#### Finding J-C3: Antrenman "PRO" pill is the lowest-friction paywall trigger but has the weakest affordance signal
**Severity:** 3/5
**Where:** `lib/features/home/presentation/widgets/antrenman_tab.dart:548–587` (PRODUCT_STRUCTURE_REPORT F-21)
**Observation:** The "PRO" pill at the top-right of Antrenman header is a 1-tap path to paywall. But its visual reads as a status badge (crown icon + "PRO" text), not a CTA. The label "PRO" with no verb leaves it ambiguous: does it mean "you have Pro" or "tap to get Pro"?
**Cost:** Free users may avoid tapping (perceiving it as an indicator). Pro users tap by mistake (curious what their Pro means) and land on the paywall they can't act on.

---

## 4. JOURNEY D — FREE USER ATTEMPTS TO UPGRADE (paywall → forced-auth gate → purchase → close → return to home)

### D.0 Sequence (assumes user is anonymous arriving at paywall)

```
[/paywall mounts]
   │
   ▼ initState → Phase 94 _onAuthStateChanged → user.isAnonymous == true
   │            → _authGateShown = true
   │            → addPostFrameCallback → showAuthGate(context)
   │
   ▼
[Auth modal sheet covers bottom 50%]
   │ Decision: Google / Apple / Email link
   │
   ▼ Tap Google
[Native Google Sign-In sheet (Android: GMS sheet; iOS: ASAuthorization)]
   │ Decision: pick account / Cancel
   │
   ▼ tap account
[Network round-trip: Google → id token → Supabase signInWithIdToken]
[RC alias call: Purchases.logIn(supabaseUuid)]
   │
   ▼ on success
[Auth modal pops, paywall fully visible]
   │ Decision: pick a plan (3 cards) + tap CTA / Restore / X close
   │
   ▼ tap "₺0,00 karşılığında dene" (CTA)
[Purchases.purchasePackage(package) — native billing UI]
   │ Decision: confirm / cancel / device authentication
   │
   ▼ on success
[RC entitlement check 'FormAI Pro' → updates subscriptionProvider isPro:true]
[600ms delay (Phase 95) for RC alias call to complete]
[Toast "Premium aktif edildi!"]
   │
   ▼
[Paywall closes via context.pop or context.go]
   │
   ▼
[Dashboard with isPro:true]
```

### D.1 Tally

| Metric | Count |
|---|---|
| Required taps from "decided to upgrade" to "Premium active" | 4 (auth provider → confirm google → plan card → "dene" CTA) — assumes annual default already selected |
| Network round-trips | 3 (Google id-token, Supabase signInWithIdToken, RevenueCat purchase) |
| Failure points | 8 (offline at any step; OAuth cancel; OAuth error; purchase cancel; purchase error; not-entitled-after-purchase edge; RC alias failure post-purchase; 600ms delay race) |
| State the user must trust will succeed | 4 (anon→registered upgrade preserves user_id, RC alias preserves customer ID, purchase entitlement check passes, restore works if anything fails) |

### D.2 Findings

#### Finding J-D1: 4 taps + 3 network round-trips before "Premium active" — minimum, on the happy path
**Severity:** 3/5
**Where:** D.0 sequence
**Observation:** Even the minimum-friction happy path (Google sign-in already used previously, default annual plan, no errors) requires 4 deliberate taps, 3 network calls, and trust in 4 distinct successful outcomes.
**Cost:**
- Each network call is a potential timeout (atlas §2.2: Supabase 8s, PostHog 5s; RC has its own ~30s default).
- For users on slow networks (the Turkish market includes many 3G/spotty 4G regions), the minute-plus latency between "I want to upgrade" and "Premium active" is itself friction.

#### Finding J-D2: Anonymous → registered upgrade silently reorganizes user identity; user has no signal what happened
**Severity:** 4/5
**Where:** `lib/features/auth/presentation/auth_screen.dart:84–98` (`updateUser` for anon upgrade); `lib/features/auth/presentation/auth_modal_bottom_sheet.dart:444–451` (success path)
**Observation:** The auth gate's success handler simply pops the modal (`Navigator.of(context, rootNavigator: true).pop()` line 451). The auth_screen email-upgrade path shows a toast: "E-posta adresine doğrulama bağlantısı gönderildi. Hesabın yükseltildi, ilerlemen korundu." (line 94–96). But the OAuth path on the modal bottom sheet does NOT show a confirmation toast — the modal just closes, and the user is back on the paywall.
**Cost:**
- The user's mental model — "I just signed up, now I can buy" — is correct, but there's no positive confirmation. They look at the same paywall they were on before.
- For users who didn't realize they were anonymous (most), this is an invisible ceremony.

**Evidence:**
```dart
// auth_modal_bottom_sheet.dart:444–451
case SocialAuthOutcome.success:
  // RevenueCat aliasing has already happened inside
  // `AuthController.signIn{Google,Apple}` via
  // `_aliasRevenueCatToSupabaseUser`. We just close the gate;
  // the user lands back on the paywall, now authenticated.
  Navigator.of(context, rootNavigator: true).pop();
```
No toast, no banner, no "Welcome, [email]" affordance.

#### Finding J-D3: "₺0,00 karşılığında dene" CTA copy plus 7-day trial hardcoded badge create a "free now, paid later" expectation users may not parse
**Severity:** 3/5
**Where:** `lib/features/monetization/presentation/paywall_screen.dart:368–464` (CTA); atlas §6.5 (trial mechanics)
**Observation:** The CTA reads "₺0,00 karşılığında dene" (try for ₺0). The annual card has a "7 gün ücretsiz dene" badge. The fine-print legal footer at 10.5pt @ 0.55 alpha (atlas §6.2) discloses auto-conversion. Users who tap "try for ₺0" may not register that:
1. The free trial is 7 days
2. After that, ₺999,99 is charged automatically
3. They must cancel via App Store / Play Store before day 8
**Cost:**
- Refund-rate inflation. Users who didn't grasp auto-conversion request refunds in week 2.
- Sentiment risk: app reviews complaining about "hidden charges" despite the disclosure being present (just at low contrast).
- Atlas §6.9: "Decoy reference price (₺2.999,99 strikethrough) on yearly is hardcoded marketing copy, not derived from a real prior price." Combined with the obscured disclosure, the persuasion stack is heavy.

#### Finding J-D4: Purchase failure outcomes are 4 distinct branches; UX recovery is uneven
**Severity:** 3/5
**Where:** `lib/features/monetization/presentation/paywall_screen.dart:548–586` (`_purchase` outcomes); atlas §6.6
**Observation:**
- success: toast + 600ms delay + close
- cancel: silent
- not-entitled: "Ödeme tamamlandı ama Premium henüz aktifleşmedi…" + suggest restore
- error: "Satın alma başarısız oldu…"

**Cost:**
- The "not-entitled" case is the worst — user paid, got charged, sees "wait, restore" message. No clear reassurance. No timeline. No customer-support hook visible.
- Cancel is silent; user who cancels accidentally has no breadcrumb to recover.

#### Finding J-D5: Forced-auth modal has no escape valve if all OAuth providers fail
**Severity:** 5/5
**Where:** `lib/features/auth/presentation/auth_modal_bottom_sheet.dart:67–69` (PopScope canPop:false); `lib/features/auth/presentation/auth_modal_bottom_sheet.dart:425–460` (_runOAuth)
**Observation:** `_runOAuth` checks connectivity (line 435–440); if offline, shows toast and returns without modal pop. `result.outcome == error` shows toast and does not pop. The user is left looking at the same modal with the same buttons that just failed. The only escape is the email link → `/auth` → which itself can fail similarly.
**Cost:**
- Users with broken OAuth (incorrectly configured GOOGLE_WEB_CLIENT_ID, expired Apple Developer cert, regional Google account block) are stranded.
- The "E-posta ile Giriş Sayfasına Git" link routes to `/auth`, which has email/password fields — but if Supabase is unreachable, those fail too.
- No "Skip and try again later" button. No "Continue without signing up" anonymous-purchase path (intentionally — Phase 94 prevents it). But that means broken auth = broken app for first-time post-onboarding users.

This is the issue that motivates NAVIGATION_FRICTION_REPORT.md F-N1.

---

## 5. JOURNEY E — STREAK BREAK RECOVERY (user breaks streak → returns next day → "comeback" path)

### E.0 Sequence

```
[Day N: user does NOT complete workout (no exercise tap)]
   │
   ▼ next launch:
[Bootstrap → router → dashboard]
   │
   ▼
[Antrenman tab visible]
   │ Streak now reads "0" (calculation from Day 1; first non-completed non-rest day breaks)
   │ Antrenman header _FlameStreakBadge shows 0 (icon only, no count badge per antrenman_tab.dart:609–632 — count badge requires streak > 0)
   │
   ▼ (no streak indicator on Antrenman if streak == 0)
   │
   ▼ user taps Gelişim tab
   │
   ▼
[Gelişim tab visible]
   │ Top header pill: "🔥 0 Günlük Seri" (literally renders 0)
   │ Streak Card: 0 dots filled, "Serini bozma!" subtitle (gelisim_tab.dart line ~795)
   │ AI Coach card copy: "Geri dönüş zamanı. 10 dakika yeterli." (only if streak == 0 AND maxStreak > 0)
   │
   ▼ user taps "ANTRENMANA BAŞLA"
   │
   ▼ /plan-detail → tap day tile → /workout
   │
   ▼ on completion: streak = 1
```

### E.1 Tally

| Metric | Count |
|---|---|
| Comeback messaging surfaces | 1 (AI Coach card on Gelişim, conditional copy) |
| Other affordances | 0 (no banner, no notification re-engagement, no streak-recovery sheet) |
| Default tab after launch | Antrenman (streak-comeback messaging not visible there) |
| Friction to find comeback message | 1 tab-switch tap (to Gelişim) + scroll past 6 sections to AI Coach card |

### E.2 Findings

#### Finding J-E1: Comeback messaging is buried inside the AI Coach card on Gelişim — user must navigate to find it
**Severity:** 4/5
**Where:** `lib/features/home/presentation/widgets/gelisim_tab.dart:1613–1621` (the conditional copy); see also F-06 (suggestions screen orphaned)
**Observation:** The "Geri dönüş zamanı. 10 dakika yeterli." copy appears only in the AI Coach card (`gelisim_tab.dart:1617`). The user must:
1. Open app (lands on Antrenman)
2. Tap Gelişim tab
3. Scroll past 6 sections (top header, program stats, today task, day grid, weekly stats, retrospective)
4. Find AI Coach card
5. Read the line

5 user actions to surface the most important behavioral message ("come back, just 10 min").
**Cost:**
- Comeback messaging is the canonical re-engagement lever. Most fitness apps surface it on the first frame.
- Atlas §5.6: "`maxStreak` watermark powers comeback messaging" — but only via this one buried surface.

#### Finding J-E2: No notification, no banner, no sheet for streak break — comeback path is silent
**Severity:** 4/5
**Where:** No file evidence (absence of feature)
**Observation:** A grep of the codebase for streak-break notification, banner, or sheet:
```
grep -rn "comeback\|streak_broken\|streak_break\|geriDonus\|geriDönüş" lib/
→ no comeback-specific files
```
The Notification Service (atlas §10) supports "günlük hatırlatma saati" (daily reminder time) per `profile_tab.dart:188` but no streak-break-specific notification.
**Cost:**
- A user who breaks streak on Tuesday gets no Wednesday push specifically targeting comeback. They get the standard daily reminder (if configured).
- The maxStreak watermark is computed and stored (`appPreferencesProvider.maxStreak`) but used only for the AI Coach copy line, not for re-engagement.
- High-churn moment goes unrecognized.

#### Finding J-E3: Streak rendered as "0" rather than e.g. "broken" or "restart" — bare numerical zero feels like cold-start
**Severity:** 3/5
**Where:** `lib/features/home/presentation/widgets/gelisim_tab.dart:432` (`'$streak Günlük Seri'` → "0 Günlük Seri")
**Observation:** When streak resets to 0, the Gelişim header pill renders literally "🔥 0 Günlük Seri" (0-day Streak). Same on Profile tab Stats Tile: "0 gün". The user, who may have been at 12 days yesterday, sees a zero — visually equivalent to a cold-start state.
**Cost:**
- Erases the user's prior achievement signal. They don't see "Best: 12 days" or "Restart your streak — best was 12" anywhere on the surface.
- atlas §5.6 mentions `maxStreak` is persisted but the only consumer is AI Coach copy. The header pill does not surface it.

**Evidence:**
```dart
// gelisim_tab.dart:432–440
Text(
  '$streak Günlük Seri',
  style: TextStyle(
    color: scheme.onSurface,
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.3,
  ),
),
```

#### Finding J-E4: 5-dot streak checklist on Gelişim Streak Card caps visualization at 5 — masks longer streaks
**Severity:** 3/5
**Where:** atlas §5.2 §3a ("5-dot checklist (capped at 5)")
**Observation:** The Streak Card's 5-dot checklist (atlas §5.2) shows progress only to 5 days. A user at 12 days sees the same 5-dot full state as a user at 5 days. After breaking from 12 → 0, they see all 5 dots empty with the same visual as a brand-new user at day 0.
**Cost:**
- Achievement-erasure illusion at the visualization level.
- Comeback motivation suffers; the visual progress bar feels like starting over.

#### Finding J-E5: Returning user always lands on Antrenman default tab — comeback message is invisible at app open
**Severity:** 4/5
**Where:** `lib/features/home/presentation/dashboard_screen.dart:37` (cf. J-B1)
**Observation:** Comeback messaging lives on Gelişim. App opens to Antrenman. User must tab-switch to even see the message. There is no Antrenman-tab analog; the Antrenman header just renders the flame icon without the count badge when streak is 0.
**Cost:** Re-engagement path is gated by user knowing to switch tabs. First-time-back users (the at-risk segment) are most likely to bounce before finding it.

---

## 6. CROSS-JOURNEY OBSERVATIONS

### Common drop-off & state-loss summary

| Issue | Affected Journeys | Sev |
|---|---|---|
| Onboarding state loss (no autosave) | A | 5 |
| Forced-auth modal blocks paywall view & has no escape | A, D | 5 |
| Day 4+ paywall surprise + no return-to-workout path | B | 5 |
| Default tab is Antrenman regardless of last-used (cold start) | A, B, E | 4 |
| Comeback messaging is buried | E | 4 |
| Plan-detail intermediate screen for canonical workout flow | B | 3 |
| 8 paywall surfaces with no source attribution | C | 4 |
| Today Task Card no pre-tap signal at Day 4+ | B, C | 4–5 |
| Workout flow span (5 screens between tap and exercise) | A, B | 3 |
| OAuth failure = stranded user on auth modal | A, D | 5 |
| Anon recovery silently reorganizes data | B | 3 |

### State-loss locations (exhaustive)

1. **Onboarding mid-flow** (A) — sev 5. No autosave between steps 1–11.
2. **Workout mid-rep** (B) — sev 3. Atlas §13 mentions `workout_back_button.dart` "exit w/ unsaved-progress safeguard" but the safeguard is a confirm dialog, not auto-save. Killing app loses rep state.
3. **Anonymous → registered upgrade orphan** (D) — sev 4. If anon-recovery fires (auth.was_anonymous + no session), old anon UID's RLS-locked rows become inaccessible. Acceptable per atlas §12 design but a real cost.
4. **Tab-state preservation gaps** — see NAVIGATION_FRICTION_REPORT.md. IndexedStack preserves widget state per tab, but pushed sub-routes (e.g. recipe detail from Beslenme) do not preserve scroll.

---

## 7. TAP-COUNT SUMMARY

| Journey | Min taps | Typical taps | Worst-case taps |
|---|---|---|---|
| A: First-launch → first workout | 13 | 15 | 20+ (with errors / corrections) |
| B: Returning → today's workout | 3 | 4 | 6+ (if paywall hits Day 4+) |
| C: Free hits paywall | 1 (Today Task) | 2 (plan-detail tile) | 5+ (regional plan upsell path) |
| D: Free → upgrade → return | 4 | 6 | 12+ (with retry on OAuth failure) |
| E: Streak break → comeback workout | 4–5 | 5–7 | 8+ (if user looks for context first) |

---

## 8. SCREEN-COUNT SUMMARY

| Journey | Min screens | Typical screens |
|---|---|---|
| A | 17 | 18 |
| B | 5 | 6 (with prep + first rest) |
| C | 2 | 3 |
| D | 5 | 6 (paywall, native sheets, billing UI, confirm, post-purchase) |
| E | 4 | 5 |

---

## 9. ERRATA AGAINST PHASE 1 ATLAS

The atlas's flow descriptions are accurate. One extension:

- Atlas §6.3 lists 7 paywall trigger surfaces. **This report extends to 8** — adding the post-OAuth path (`auth_screen.dart:53` `pushReplacement(paywall)`). The 8th surface is documented in atlas §6.3 row 1 ("Post-email-login") but the OAuth row is implicitly merged into "Post-email-login + Post-OAuth"; in practice these are 2 distinct trigger paths from 2 different code locations. Counting nuance, not a factual error.

---

## 10. APPENDIX — JOURNEY EVIDENCE INDEX

| Journey | Key files |
|---|---|
| A | `main.dart`, `app_router.dart`, `onboarding_screen.dart`, `paywall_screen.dart`, `auth_modal_bottom_sheet.dart`, `dashboard_screen.dart`, `antrenman_tab.dart`, `plan_detail_screen.dart`, `workout_camera_screen.dart` |
| B | `dashboard_screen.dart`, `today_task_card.dart`, `plan_detail_screen.dart`, `workout_camera_screen.dart` |
| C | `today_task_card.dart`, `plan_detail_screen.dart`, `profile_tab.dart`, `antrenman_tab.dart`, `paywall_screen.dart` |
| D | `paywall_screen.dart`, `auth_modal_bottom_sheet.dart`, `auth_screen.dart`, `monetization_provider.dart`, `auth_provider.dart` |
| E | `gelisim_tab.dart`, `app_preferences.dart`, `notification_service.dart` (absence of streak-break logic) |

---

**END OF USER_FLOW_ANALYSIS.md**
