# RETENTION TRIGGER REPORT

**Phase 3 — Psychology · External + Internal Triggers**
**Project:** SixPack AI / FormAI Fit
**Generated:** 2026-05-08
**Inputs:**
- atlas (`reports/phase-1-project-discovery/PROJECT_STRUCTURE_MAP.md`) §1, §2, §5.7, §5.8, §10.3, §11
- Phase 2 USER_FLOW_ANALYSIS.md journeys A, B, E
- Phase 3 USER_PSYCHOLOGY_REPORT.md findings P-03, P-07, P-14, P-16, P-25
- Source inspection: `notification_service.dart`, `widget_sync_service.dart`, `live_activity_service.dart`, `smart_reminder_scheduler.dart`, `deep_link_service.dart`, `gelisim_tab.dart`, `today_task_card.dart`, `session_complete_overlay.dart`

**Scope:** Where does the app *trigger* a return? Where does it fail to? The Hooked Model defines two trigger classes — *external* (push, widget, calendar, friend, ad) and *internal* (the user's own emotional reflex that opens the app without a push). Mature products graduate users from external to internal triggers; immature products lean on external forever and bleed when notifications get muted.

---

## 0. METHODOLOGY

For each trigger source, the report enumerates:
- **What it does** (factual reading from source)
- **When it fires** (temporal trigger conditions)
- **What state it produces** (cognitive/emotional state on tap-through)
- **Where it succeeds, where it fails** (evidence-graded)
- **Severity finding** (numbered T-NN, same scale as USER_PSYCHOLOGY_REPORT)

Severity scale:
- **5** — actively damaging or blocking re-engagement (silent intent loss, surprise paywall on Day 4, no streak-break notification at the canonical churn moment)
- **4** — meaningful retention drag that compounds across cohorts
- **3** — measurable funnel cost or trigger-quality issue
- **2** — secondary trigger friction
- **1** — cosmetic

---

## 1. EXECUTIVE FINDINGS TABLE

| ID | Sev | Title | File:line |
|---|---|---|---|
| T-01 | 5 | Streak-warning notification fires at 48h after the **last completion**, not at risk-of-break — the user who just broke streak gets nothing | `notification_service.dart:299–331`, `workout_repository.dart:781–818` |
| T-02 | 5 | Home-screen widget tap on signed-out devices silently routes through `/auth` → `/paywall` — workout intent vaporizes | `deep_link_service.dart:96–106`, `app_router.dart:78–126`; F-13 echoed |
| T-03 | 5 | Variable-reward density is near-zero — every workout produces the same trophy + +1 streak + same badge predicates | inventory below; cf. P-22 |
| T-04 | 4 | Comeback path lives entirely in-app on a buried surface; no out-of-app comeback push, no SMS, no email | `gelisim_tab.dart:1617`, absence in notification pools |
| T-05 | 4 | Notification schedule is set-once via Profile tab — no smart time-of-day learning despite the user's `dailyMinutes` answer | `account_settings_screen.dart:248`, `onboarding_screen.dart:6` step (no scheduling derived) |
| T-06 | 4 | Live Activity (iOS Dynamic Island) only fires *during* a workout — not as a re-engagement nudge | `live_activity_service.dart` (workout-only lifecycle) |
| T-07 | 4 | Home-screen widget displays `0 gün` after streak break — the public-facing surface broadcasts the user's failure to anyone glancing at the phone | `widget_sync_service.dart:99` `saveWidgetData<int>(_kStreak, streakCount)` |
| T-08 | 4 | Variant pool is 5 loss-framed : 3 celebration-framed : 2 mixed — re-engagement copy skews toward fear | `notification_service.dart:70–123` |
| T-09 | 3 | No workout-day-of push (e.g., "Bugün Bacak Gücü günü") — the daily reminder is generic across all 30 days | variant pool examples below |
| T-10 | 3 | Recovery-recipe suggestion in `SessionCompleteOverlay` does not chain to a "log this meal" workflow — endowment moment dropped | `session_complete_overlay.dart:43–46, 89–92` |
| T-11 | 3 | The cold-start "tap notification → land on Today Task Card" path is 5 screens deep including paywall race conditions | `notification_service.dart` (no payload deep-link) + atlas §8.6 5 screens |
| T-12 | 3 | Onboarding never asks reminder time — user inherits the default 19:00 one tap deeper, after the paywall | `account_settings_screen.dart:248` `_defaultReminderTime` |
| T-13 | 3 | Paywall lacks a "remind me later / save for when I'm ready" action — users who want to evaluate without auth are forced to OAuth or close | `paywall_screen.dart:315–319` close X only escape |
| T-14 | 2 | Notification body lines are slightly long (some >70 chars) — Android notification tray collapses; iOS preview truncates | various variants in `notification_service.dart:70–123` |
| T-15 | 2 | Widget timestamp `_kUpdatedAtMs` is pushed but native UI doesn't render "X minutes ago" stale indicator — widget can show out-of-sync state without telling user | `widget_sync_service.dart:103–106` |

**Total:** 15 findings. **3 sev-5, 5 sev-4, 5 sev-3, 2 sev-2.**

---

## 2. EXTERNAL TRIGGERS — INVENTORY

### 2.1 Notification system

The app ships three distinct notification flows:

| Flow | When it fires | Variant pool | File:line |
|---|---|---|---|
| Daily reminder (smart) | User-set time of day, daily | 3 conditions × 2-3 variants each = 7 total | `notification_service.dart:217–264` |
| Streak warning | 48h after last completion | 2 variants | `notification_service.dart:299–331` |
| Live activity | During active workout | n/a — pinned UI, not push | `live_activity_service.dart` |

#### 2.1.1 Daily reminder system

**Schedule trigger:** user picks time via `account_settings_screen.dart:248` (`scheduleDailyReminder(_defaultReminderTime)` → 19:00 default) or `profile_tab.dart:420` (`showTimePicker → scheduleDailyReminder(picked)`).

**Body selection (per `SmartReminderListener`):** computes user state at scheduling time, picks variant pool:
- `noWorkout` — user hasn't trained today (3 variants)
- `workoutNoFood` — workout done, nutrition not logged (2 variants)
- `bothDone` — full day completed (3 variants)

Variants are uniform-random within the matching pool (`notification_service.dart:336–340`).

The **best** thing about this system: the 3-condition branching means the body actually reflects the user's day-end state. A user who finished both gets celebration; a user who only worked out gets a nutrition nudge; a user who didn't work out gets the urgency line.

The **catch:** the body is selected at *scheduling* time, not at *fire* time. The condition reflects "where the user was when we last re-scheduled." If a user opens the app at 09:00, doesn't work out, doesn't open the app again until 22:00, the 19:00 reminder body was set at 09:00 — under "noWorkout" — even though by the time it actually fires the user could have hit nature on a walk and not opened the app. That's tolerable.

#### 2.1.2 Variant pool composition

Counted from `notification_service.dart:70–123`:

```
_noWorkoutVariants        = 3 variants — all loss-framed
_workoutNoFoodVariants    = 2 variants — recovery framing, neutral
_bothDoneVariants         = 3 variants — celebration
_streakVariants           = 2 variants — both loss-framed (urgency)
```

Net: 5 loss-framed (3 noWorkout + 2 streak warning) : 3 celebration (bothDone) : 2 neutral-recovery (workoutNoFood). Heavy loss-framing tilt.

### Finding T-08: Variant pool skews toward loss-framing
**Severity:** 4/5
**Where:** `lib/core/services/notification_service.dart:70–123`
**Mechanism:** Loss-framing has high single-firing CTR but degrades 6-month retention (cf. P-25 in USER_PSYCHOLOGY_REPORT). A pool that's 50% loss-framed conditions the user to associate the FormAI notification with guilt/anxiety.
**Observation:** Of 10 total variants:
- "Hedeflerinden uzaklaşma" (loss)
- "Bugün antrenmanı geçersen yarın iki gün geride kalırsın" (loss + future-loss compound)
- "Seriyi kaybetmek üzeresin! ⚡" (loss)
- "Serini bozmadan bugün bir set yap" (loss-flavored neutral)
- "Antrenman Vakti! 💪" (urgency, neutral)

Only 3 of 10 are clean celebration:
- "Günü fethettin! 🏆"
- "Mükemmel bir gün 💧"
- "Devam et! ⚡"

**Cost:**
- The user opens the app most often after a guilt-framed nudge — but the *guilt* state is a poor predictor of long-tail engagement. Apps that build internal triggers (Calm, Headspace's evening cycle) avoid loss framing entirely.
- For the Turkish market, the "geride kalırsın" line has a specifically Turkish emotional weight (falling behind in school is a heavy frame). It works once and breeds resentment.
- The pool composition is a copy-only fix; the structural choice to have 3 noWorkout variants vs 1 celebration variant is the bigger signal.

**Evidence:** above, with full pool inventory at `notification_service.dart:70–123`.

#### 2.1.3 Streak warning (Phase 52)

**Trigger:** scheduled at +48h on every workout completion (`workout_repository.dart:781–818`). Cancel-and-replace on each completion so it always reflects the most recent workout.

**Body variants (`notification_service.dart:114–123`):** 2 variants, both loss-framed:
- "Seriyi kaybetmek üzeresin! ⚡ / 48 saat oldu. 10 dakikalık bir oturum momentumu kurtarır."
- "Geri dönüş zamanı 🔁 / Serini bozmadan bugün bir set yap; yarın daha da kolaylaşır."

### Finding T-01: Streak-warning fires at 48h after last completion, not at risk-of-break
**Severity:** 5/5
**Where:** `lib/core/services/notification_service.dart:299–331`; `lib/features/workout/data/workout_repository.dart:781–818` (the trigger site).
**Mechanism:** Re-engagement timing. The streak system breaks if the user misses a workout day (atlas §5.6). The "48 hours since last workout" trigger fires *after* the streak has likely already broken (depending on whether the missed day is a rest day per atlas §5.6 — rest days don't break streak; only missed *active* days do).

The intent of a streak warning is to fire *before* the break (e.g., 23 hours after the last completion, when the user is at risk of missing today's workout, not 48 hours after). The current implementation fires after the consequence has already happened.
**Observation:**
```dart
// notification_service.dart:299–301
Future<void> scheduleStreakWarning({
  Duration delay = const Duration(hours: 48),
}) async {
```
At completion of Day N, we schedule a notification for now+48h. If the user does Day N+1 within 48h, the schedule is replaced. If they don't:
- Day N completes Sunday 18:00
- Tuesday 18:00 → notification fires
- Streak broke Monday 23:59 (assuming Monday is active day) — 18 hours before the notification

The user receives "Seriyi kaybetmek üzeresin!" 18 hours after the streak already broke. The framing is wrong (it didn't almost break, it did break) and the timing is too late (rescue impossible).
**Cost:**
- The user opens the notification, lands on the app, sees streak=0 — confused why the system said "almost lost it" when it was already lost.
- The optimal trigger window for streak preservation is ~22h after last completion (last 2 hours of the day). The current 48h fire is structurally the wrong moment.
- For the canonical 30-day program, the streak warning is the highest-value retention notification. Misfiring it costs cumulative retention every cycle.

**Evidence:** above + `workout_repository.dart:781–818` shows the call site is at workout completion (`markDayCompleted`), not at risk detection.

### Finding T-04: No comeback path out of app
**Severity:** 4/5
**Where:** `gelisim_tab.dart:1617` (in-app comeback copy is the only surface); absence pattern in `notification_service.dart`.
**Mechanism:** Re-engagement coverage. A churning user is by definition not opening the app. To reach them, the system needs out-of-app channels: push, email, SMS, deep link. The current setup has *push* but the comeback variants are framed as "almost lost the streak" (T-01) — not "we miss you, here's a fresh start."
**Observation:** Search the notification system for any comeback-themed copy:
- `noWorkoutVariants` — assumes user is still active, just missed today. Loss-framed.
- `streakVariants` — assumes the streak is still rescuable. Loss-framed.
- No `cameBackVariants`. No "you've been gone 7 days, your plan is still here" pool.

A user who broke streak 7 days ago and has not opened the app since gets:
- The same daily 19:00 reminder body (whichever variant is current)
- The streak warning that already fired 48h after their last completion (long ago)
- No new copy keyed to "you've been away."

`gelisim_tab.dart:1617` shows comeback copy ("Geri dönüş zamanı. 10 dakika yeterli."), but it's *in-app* — the user has to open the app to see it.
**Cost:**
- The biggest retention lever — bringing back lapsed users — has no out-of-app touchpoint.
- For the 30-day program, every lapsed user is a future churn unless they re-enter. Without a comeback channel, the natural decay rate is the maximum decay rate.
- Compare: Duolingo emails dormant users with "Your XP has been frozen, come back to thaw it." That's an out-of-app comeback hook tied to the user's investment artifact.

**Evidence:** absence pattern in `notification_service.dart` and no email/SMS service in the codebase (grep `emailReminder` / `smsReminder` / `comebackPush` returns nothing).

### 2.2 Home-screen widget (Phase 55)

**Bridge:** `lib/core/services/widget_sync_service.dart` pushes 8 keys to platform store; native UIs read.

**Pushed payload:**
```dart
// widget_sync_service.dart:51–60
static const String _kTaskName       = 'today_task_name';
static const String _kSubtitle       = 'today_task_subtitle';
static const String _kProgressPct    = 'progress_percent';
static const String _kStreak         = 'streak_count';
static const String _kCompletedDays  = 'completed_days';
static const String _kTotalDays      = 'total_days';
static const String _kDeepLink       = 'deep_link';            // formai://workout/today
static const String _kUpdatedAtMs    = 'updated_at_ms';
```

**Update trigger:** `widgetSyncListenerProvider` listens to `workoutSessionProvider`; on every state change, computes payload and pushes.

**Tap behavior:** native widget surfaces deep link `formai://workout/today` → routes through `deep_link_service.dart:96–106`.

### Finding T-02: Home-screen widget tap on signed-out devices silently routes through auth + paywall
**Severity:** 5/5
**Where:** `lib/core/services/deep_link_service.dart:96–106`; `lib/core/routing/app_router.dart:78–126` (gates); F-13 echoed.
**Mechanism:** Intent preservation. The user's *intent* when tapping a workout widget is unambiguous: "start today's workout." The system's response should be: deliver that intent, with the smallest possible friction. The current implementation silently transforms the intent — the user lands on `/auth` (if logged out, e.g. token expired beyond refresh, or different account on a shared device, or the app got force-quit and re-installed). After signing in, redirect rule 5 (atlas §3.2) routes to `/paywall` — not back to the workout.
**Observation:**
```dart
// deep_link_service.dart:96–106
// workout/today  →  live workout camera screen. Triggered from the
// home-screen widget tap and the Live Activity tap. The router's
// auth + first-time gates still apply, so a signed-out user
// clicking the widget lands on /auth and gets bounced through
// onboarding before the camera surface opens.
if (segments.first == 'workout' &&
    segments.length >= 2 &&
    segments[1] == 'today') {
  _router.go(AppRoutes.workout);
  return;
}
```
The code comment acknowledges the cost — "clicking the widget lands on /auth and gets bounced through onboarding before the camera surface opens." There is no intent-preserving mechanism (e.g., stash `pendingIntent: workout` and replay after auth).
**Cost:**
- A user with a phone in a gym shower locker, glancing at the home screen pre-workout, taps the widget. Lands on Auth. By the time they sign in, the workout context is lost.
- For the canonical "open app to start today's workout" loop, this is the highest-friction failure mode.
- The widget's purpose is to be the fastest entry point; without intent preservation, it becomes the slowest entry point exactly when it matters most.

**Evidence:** above + the comment at lines 96–101 is the strongest signal — the team knows.

### Finding T-07: Home-screen widget displays `0 gün` after streak break
**Severity:** 4/5
**Where:** `lib/core/services/widget_sync_service.dart:99`; `:153–155`.
**Mechanism:** Public failure broadcast. The home-screen widget is the most-public surface in the entire app — visible on lock screen, on home screen, glanced at by partners/colleagues/strangers. When it broadcasts "0 gün seri" the day after a break, it broadcasts the user's failure to a public audience.
**Observation:** The widget pushes `streakCount` raw (line 99) and the subtitle template is `'%$percent · $streak gün seri'` (line 154). After a break, the widget reads "0 gün seri" — the same as a Day 0 user.
**Cost:**
- Glance-cost shame. For a user whose phone screen is visible to a partner ("how's the new workout app going?"), the public reset to zero is a social-cost amplifier.
- Removing the widget after a break is opt-out (user has to manually delete from home screen) and creates a different signal ("I deleted it"). Both options are bad.
- The widget *could* show "Best: 12, current 0" (mirror P-07's fix in main app) or hide streak entirely after a break and show "Re-start today." It does neither.

**Evidence:** above. The native widget reads `streak_count` integer directly; no "broken state" semantic exists in the protocol.

### 2.3 Live Activity (iOS Dynamic Island, Phase 55)

**Lifecycle:** `lib/core/services/live_activity_service.dart` — ActivityKit integration, fires during active workout only. Per atlas §1, this is the "rest UI between exercises" iOS-side surface.

### Finding T-06: Live Activity is workout-only — not a re-engagement nudge
**Severity:** 4/5
**Where:** `lib/core/services/live_activity_service.dart` (workout-only lifecycle, started at `startWorkout`, ended at `endWorkout`)
**Mechanism:** Surface utilization. Live Activities (iOS 16.1+) are the most premium re-engagement channel in mobile — they sit on the lock screen, persist for hours, and are tap-targeted. They're also rate-limited (Apple caps), so using them frivolously is bad. But using them only for active workouts means the surface is dark 23+ hours per day for active users and 24/24 for users between workouts.
**Observation:** Inspection of `LiveActivityService` shows the activity is started in `startWorkout` and ended in `endWorkout` (referenced from `session_complete_overlay.dart:99` — `WorkoutLiveActivityService.instance.endWorkout()`). No idle-state activity, no "tomorrow's workout" pin, no streak countdown.
**Cost:**
- A user could have a "Day 7 / 30 — Bacak Gücü tomorrow at 19:00" pinned Dynamic Island all day — that's an external trigger that lives outside the app and reinforces identity.
- The current implementation uses the surface only as in-workout chrome. Premium iOS apps (Apollo, Carrot Weather, Spotify) use Live Activities for ambient state, not just active sessions.

**Evidence:** above. Code inspection confirms no idle-state Live Activity APIs are called.

### 2.4 Daily reminder schedule

### Finding T-12: Onboarding never asks reminder time
**Severity:** 3/5
**Where:** `lib/features/home/presentation/account_settings_screen.dart:248` `scheduleDailyReminder(_defaultReminderTime)`; the wizard's 12 steps (`onboarding_screen.dart:53–66`) — no time-of-day step.
**Mechanism:** Default-bias capture. Defaults dominate behavior (Thaler & Sunstein 2008). A user who's never asked when they want the reminder gets 19:00 (the default), and the friction of changing it (Profile tab → AYARLAR section → tile → time picker) means most never do.
**Observation:** The wizard captures `dailyMinutes` (10-15 / 20-30 / 45+) but not preferred-workout-time. Reminder time is set in `account_settings_screen.dart` at default 19:00 (`_defaultReminderTime`).

The user with `dailyMinutes = '10_15'` who works night shifts gets a 19:00 reminder for a workout they'd realistically do at 06:00. The default is wrong for them, and they have to navigate Profile → AYARLAR → Bildirimler tile → time picker to fix it. Most won't.
**Cost:**
- The reminder fires at the wrong time for a non-trivial user slice. The user either ignores it (notification gets associated with "wrong time, ignore") or mutes it.
- A 13th step in the wizard ("when do you want a daily reminder?" with default 19:00) would capture this at the high-engagement moment. The atlas notes the wizard already has 12 steps; adding a 13th is a tradeoff.

**Evidence:**
```dart
// account_settings_screen.dart:248
.scheduleDailyReminder(_defaultReminderTime);
```
plus `_defaultReminderTime` defined as TimeOfDay(hour: 19, minute: 0) elsewhere in the file.

### Finding T-09: No workout-day-of push (e.g., "Bugün Bacak Gücü günü")
**Severity:** 3/5
**Where:** `notification_service.dart:70–123` — variant pools.
**Mechanism:** Personalization-in-the-channel. The user knows "Bugün Bacak Gücü" only by opening the app and reading Today Task Card. A push that surfaces today's focus muscle group is a higher-quality external trigger than a generic "Antrenman Vakti! 💪".
**Observation:** All 10 variants in the variant pools are generic. None reads "Bugün Karın Sertleştirme — 25 dk · Başlangıç" (the data the Today Task Card already has). The notification body is the same on Day 1 (Karın Sertleştirme) and Day 14 (Bacak Gücü).
**Cost:**
- The user trains the same muscle group as their notification body (because every notification body says "antrenman, antrenman") and tunes the system out as background noise.
- A workout-specific notification ("Day 14 — Bacak Gücü, 30 min") is much more likely to land as cue → routine → reward, where today's specific routine is anticipated.

**Evidence:** above + grep across `notification_service.dart` for any reference to `targetMuscle` or `dayNumber` — no result. The push system has no workout-day awareness.

### 2.5 Cold-start return path

Atlas §1 documents the bootstrap (Phase 94 4-layer error guards, Supabase 8s + PostHog 5s timeouts). Atlas §8.6: 5 screens between tap-start and exercise begin. This section adds the *retention* angle.

The user's mental sequence on a return tap (notification, widget, icon):
1. Tap (intent: "start today's workout")
2. App boot (~split-second to ~8s on first cold tap of the day)
3. Bootstrap rendering (branded splash)
4. Router redirect → dashboard (default tab Antrenman)
5. User scans for "today's workout" — has to find Gelişim tab + scroll to Today Task Card OR find Antrenman's Challenge Hero
6. Tap CTA → /plan-detail
7. Tap day tile → /workout
8. HAZIRLAN! 3s prep
9. Camera + first exercise

That's 5+ taps from intent to first rep, on top of bootstrap latency. The system has the data to render "today" instantly (atlas §5.4 lists `workoutSessionProvider`), but spreads it across multiple navigation steps.

### Finding T-11: Tap-notification → first-rep is 5 screens deep
**Severity:** 3/5
**Where:** atlas §8.6 + `notification_service.dart` (no payload deep-link)
**Mechanism:** Friction at intent fulfillment. The notification triggered the intent ("start today's workout"). Every screen between intent and first rep is an opportunity for the user to drop. 5 screens is a lot.
**Observation:**
- Notification has no `payload` field set on `zonedSchedule` calls (`notification_service.dart:237–254` — `notificationDetails` carries no `payload`). So tapping the notification opens the app at the default route.
- `_BootGate` runs Supabase init (8s timeout) + PostHog (5s) + RevenueCat lazy.
- Router redirects to `/` (dashboard) per first-time + session check.
- Default tab = Antrenman (`dashboard_screen.dart:37 _index = 0`).
- User must find and tap Today Task Card (which is on Gelişim, not Antrenman) OR Challenge Hero (on Antrenman).
- /plan-detail intermediate screen.
- Day tile tap → /workout.
- HAZIRLAN! prep.
- First rep.

That's structurally 5 in-app screens after bootstrap.

The notification intent-deep-link to `formai://workout/today` *exists* (atlas §3.3) but the smart-reminder pings don't use it as their payload. So users tapping the smart reminder land on dashboard, not on `/workout`.
**Cost:**
- For a notification-driven user (the segment that needs the most retention scaffolding), the friction is the highest.
- The notification *could* stash `payload: workout/today` and have the route open intent-deep-link → /workout. The structural absence is the signal.

**Evidence:**
```dart
// notification_service.dart:237–254
await _plugin.zonedSchedule(
  id: _dailyReminderId,
  title: variant.title,
  body: variant.body,
  scheduledDate: scheduled,
  notificationDetails: const NotificationDetails(...),
  androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
  matchDateTimeComponents: DateTimeComponents.time,
);
```
No `payload:` argument. No deep-link binding.

### 2.6 In-app session-end nudge (recovery-recipe card)

`session_complete_overlay.dart:43–46, 89–92` — when recipes load, picks a high-protein recipe matching prep preference and surfaces it. The user can tap to open recipe detail.

### Finding T-10: Recovery-recipe suggestion does not chain to "log this meal"
**Severity:** 3/5
**Where:** `lib/features/workout/presentation/widgets/session_complete_overlay.dart:43–46, 89–92, 170+`
**Mechanism:** Endowment + workflow capture. The user has just completed a workout — the highest-investment moment of their day. The overlay surfaces a recipe ("toparlanma için bunu öner"). Tapping it opens recipe detail, which is great — but the natural next workflow ("ate it / will eat it") has no capture point. The user has to navigate Beslenme tab → find the meal → log it manually.
**Observation:** The overlay's `_RecoverySuggestionCard` (line 170+) has `onTap: () { context.push(AppRoutes.recipeDetail, ...) }` — opens recipe detail. Recipe detail has a "Plana Ekle" CTA per atlas §9.2 / PREMIUMIZATION 1.5. But "Plana Ekle" adds it to the day's plan; the user still has to *log* it as eaten separately if the nutrition tracking model includes consumed-vs-planned (which it does per `consumedMacrosProvider` in `nutrition_provider.dart`).
**Cost:**
- The post-workout window is the highest-conversion moment for nutrition-action capture. The system goes 80% of the way ("here's a recipe") and stops 20% short ("did you eat it?").
- A user who does eat the suggested recipe but doesn't log it leaves the consumed-macros database under-counted; the AI Coach's "Protein hedefini kaçırıyorsun" line (`nutrition_tab.dart:730–732`) would then fire incorrectly.
- The chain `workout complete → suggested recipe → 1-tap "I ate this"` would be the perfect Hooked Model investment moment.

**Evidence:** above + `session_complete_overlay.dart:_RecoverySuggestionCard` taps recipe detail but doesn't pre-fill consumption.

---

## 3. INTERNAL TRIGGERS — DOES THE APP BECOME A REFLEX?

### 3.1 Hooked Model — internal trigger inventory

Eyal's Hooked Model graduates external triggers into internal ones via repeated cycles of action + variable reward + investment. Internal triggers are emotional reflexes ("I feel anxious → open Twitter"). For a fitness app, the highest-value internal triggers are:

| Emotional state | App opens because… | Does FormAI achieve this? |
|---|---|---|
| Boredom | "5 minutes free, look at my plan" | Partially — Today Task is browsable but not engineered for snack-browsing |
| Guilt | "I ate too much, what does the coach say" | Weakly — `_AiInsightRow` has guilt copy ("$overage kcal fazla aldın") but the whole nutrition tab is 4 taps deep + nutrition onboarding sheet on first visit (F-09) |
| Pride | "I want to see my Day 7 stats" | Weakly — Gelişim has progress numbers but they're cold (P-01 cluster) |
| Anticipation | "Tomorrow's plan is what?" | No — atlas confirms no "tomorrow preview" surface |
| Belonging | "Did anyone else complete today?" | No — no social, no community, no leaderboard |
| Identity | "I'm someone who trains" | No — P-17 |
| Restless / fidget | "Quick swipe through recipes" | Yes-mid — `nutrition/discover` is genuinely browsable but is 4 taps deep |
| Stress relief | "Just want to do something productive" | No — no quick-win surface |

The matrix above measures *internal trigger fitness* — when the user feels emotion X, do they reach for the app reflexively? FormAI scores low across most rows. The strongest internal trigger candidates today are:
- **Guilt-after-eating** (nutrition tab AI insight banner) — but the path is friction-heavy.
- **Restless-fidget** (nutrition/discover) — but it's 4 taps deep.

The strategic question: *for what emotional state does FormAI become the reflex?* Based on the surface inventory, the answer today is: **for the streak-protection-reflex.** A user who has built a streak feels anxiety about losing it; that anxiety drives daily app open. This works — for users with active streaks. But it's:
- Loss-aversion-only (P-07)
- Capped at 5 visual ceiling (P-08)
- Vanishes the moment the streak breaks (no internal trigger replacement)

So FormAI's internal trigger architecture is single-mechanism (streak anxiety) with a known dropout cliff. Mature apps layer multiple internal triggers so a break in one doesn't churn the user.

### 3.2 Variable reward density audit

Hooked Model's third stage is variable reward — when the user takes the action, what reward do they get, and is it variable? Variable reward is what produces dopamine; fixed reward plateaus.

Inventory of post-action rewards in FormAI:

| Action | Reward rendered | Fixed or variable? |
|---|---|---|
| Complete a workout | trophy 96px + "Gün N Tamam!" 32pt + 3-line copy + share + suggestion card | **Fixed** — same overlay every time, only `dayNumber` changes |
| Earn a streak day | green check filled in checklist + streak number ticks +1 | **Fixed** — predictable progression |
| Unlock a badge | _BadgeUnlockDialog fullscreen modal with 1.6s pulsing halo + heavyImpact haptic | **Slightly variable** — 5 distinct badges in the strip; unlock order partially varies based on user behavior |
| Hit calorie target | "Harika gidiyorsun!" line in `_AiInsightRow` | **Fixed** |
| Open AI Coach card | one of 3 hardcoded copy branches keyed on streak | **Quasi-fixed** — 3 strings, transitions are predictable |
| Daily summary TTS | composed phrase from current providers (calories + muscle + meal) | **Variable** — 3 dynamic fields |
| 30-day grid current cell | pulsing neon ring | **Fixed** — same animation every day |

**Net density:** 2 of 7 reward sites have meaningful variability. The rest are fixed.

### Finding T-03: Variable-reward density is near-zero
**Severity:** 5/5
**Where:** inventory above; `today_task_card.dart:176–216` (program complete fixed); `gelisim_tab.dart:1613–1621` (coach copy 3 branches); `session_complete_overlay.dart:65–151` (workout complete fixed); various.
**Mechanism:** Variable-ratio reinforcement (Skinner) is the canonical engagement mechanic. Predictable rewards plateau the user's dopamine response within a handful of cycles. After ~7 workouts, the same trophy + same +1 streak + same green check produces no novel reward signal.
**Observation:** A user who completes Day 7 sees:
- Same `SessionCompleteOverlay` UI as Day 1
- Same `Gün 7 Tamam!` headline (only the number varies)
- Same recovery suggestion card (driven by the same algorithm)
- Same green-check Day 7 cell on the 30-day grid
- Same `Şampiyon serisi devam ediyor!` AI Coach copy (now that streak >= 7, P-06)

The user has now seen every reward shape the app produces. From Day 8 onward, every workout produces zero novel reward signal.

**Cost:**
- The user's dopamine response decays faster than it would with any variability injected.
- The app structurally discourages long-tail engagement — the per-workout reward is the same on Day 7 and Day 30.
- Variable reward injection points the codebase makes easy:
  - Random AI Coach insight in 1 of 30 daily slots
  - Random badge surfaced (rotated through unlocked set)
  - Random recovery recipe (already partially varied, but could pull from a wider pool)
  - Random celebration micro-copy in `SessionCompleteOverlay` (currently always "Harika iş çıkardın, yarın görüşürüz")
  - Random "did you know" panel on Gelişim
- Each one is a few lines of code. The structural absence is the signal.

**Evidence:** see code refs above. The most striking: `session_complete_overlay.dart:84-87` — every workout completion shows `'Harika iş çıkardın, yarın görüşürüz.'` literally. A user finishes their 1st workout and their 27th and reads identical text.

### 3.3 Investment capture

The Hooked Model's fourth stage: investment. The user puts something in (data, time, social capital, content) that increases their stake in returning.

Inventory of investment moments:

| Action | What's invested | Captured? |
|---|---|---|
| Complete onboarding | Demographic + emotional disclosure | **Yes** — persisted to `user_metrics` in Supabase + SharedPreferences |
| Complete a workout | Time + effort | **Yes** — completion logged to `user_progress` |
| Build a streak | Behavioral consistency | **Yes** — `maxStreak` watermark persisted |
| Set reminder time | Workflow integration | **Yes** — but only via Profile (T-12) |
| Favorite a recipe | Personal taste | **Yes** — `favorite_recipes_provider` persists |
| Share progress | Social capital | **Partial** — the share template (`share_templates.dart`) renders an off-screen card; user shares it externally; no persistent in-app marker that "user shared 3 times" |
| Refer a friend | Social investment | **Partial** — referral code generated and persisted; no count of "users I've referred" surface |
| Complete the AI report | Trust / personal narrative | **No** — the report is generated and discarded (P-23) |
| Complete daily nutrition log | Tracking discipline | **Partial** — logged but no historical trend surface in dashboard |
| Connect with another user | Social bond | **N/A** — no social features |

**Net investment-capture rate:** ~5 of 10 acts are visibly captured. The biggest miss is the AI report (the highest-emotional-investment artifact, never re-shown). The second biggest is social — no community, no friend graph, no "you trained with X".

For a 30-day program, *time-to-investment-cost* is the key metric: how much time does a user invest before quitting becomes psychologically painful? FormAI's investment density is fine for the 30-day arc (you complete workouts, the streak builds, the badges accrue) — but post-Day-30 there's no investment to continue building (P-29).

### 3.4 Cue analysis — what does the app rely on?

The cue is the trigger that fires the routine. For a daily-workout app, possible cues:

| Cue type | Used by FormAI? | Notes |
|---|---|---|
| Time-of-day | Yes — daily reminder at user-set time | Default 19:00, no learning |
| Streak-loss anticipation | Yes — `streakWarning` at 48h | Misfires per T-01 |
| Notification badge / icon | Default iOS / Android system | No active app-icon-badge management |
| Habit stack (after X, do Y) | No — atlas confirms no habit-stack feature | "Daha önce spor yaptın mı?" question never re-surfaces as planning |
| Environmental (location, calendar) | No | No calendar integration, no geofencing |
| Internal emotional | Partially — guilt-after-eating via nutrition tab | Friction-heavy |
| Friend / social trigger | No | No friend graph |
| Streak-renewal anticipation (positive) | No — system has only loss-framing | T-08 |

The cue system is structurally **time + loss-aversion**. That's the canonical fitness-app baseline; mature apps add at least 2 more cue layers. For long-tail retention, FormAI's cue surface is thin.

---

## 4. STRUCTURAL OBSERVATIONS — RETENTION SUMMARY

### Where the system succeeds:
1. **Smart reminder branching** in `notification_service.dart` (3 condition pools) — conceptually correct architecture; the copy ratio (T-08) is the issue.
2. **Streak-warning cancel-and-replace** logic — every workout completion replaces the next warning, so the user never gets a stale "you'll lose your streak" for an active streak. The 48h timing is wrong (T-01) but the architecture is right.
3. **Home-screen widget data sync** — `widgetSyncListenerProvider` correctly listens to workoutSessionProvider; widget always reflects latest session state. The missed retention opportunity is intent preservation (T-02), not the data flow.
4. **Live Activity during workout** — clean ActivityKit integration; the surface utilization gap (T-06) is opportunity, not failure.
5. **Recovery recipe in session-complete overlay** — thoughtful endowment moment, even though the workflow capture (T-10) is incomplete.

### Where the system fails:
1. **Variable reward density is near-zero** (T-03) — the canonical engagement engine is missing.
2. **Streak warning misfires by ~24 hours** (T-01) — the canonical retention notification fires after the consequence has happened.
3. **Widget tap on signed-out devices vaporizes intent** (T-02) — the canonical fastest entry point becomes the slowest at the worst moment.
4. **No comeback channel out of app** (T-04) — lapsed users get the same generic 19:00 reminder as everyone else.
5. **Loss-framing pool dominance** (T-08) — variant pools are 5 loss : 3 celebration : 2 mixed. Trains the user to associate FormAI with guilt.
6. **No identity-reinforcing surface** — see USER_PSYCHOLOGY_REPORT.md P-17.

### The 3 most consequential retention defects:
- **T-01** Streak-warning timing
- **T-02** Widget intent vaporization
- **T-03** Variable reward absence

Fixing these three would shift the app from "reactive notification engine" to "proactive habit scaffolding."

---

## 5. ERRATA AGAINST PRIOR PHASES

### ERRATA E-15 (extends atlas §10.3 services + §11)
Atlas §10.3 lists `WidgetSyncService` and `LiveActivityService` as services. Atlas §11 mentions notification scheduling. Neither documents the *psychological mismatch* between the streak-warning trigger time (48h) and the streak-break risk window (~22h). This report's T-01 is the structural call-out.

### ERRATA E-16 (extends atlas §3.3 deep links)
Atlas §3.3 documents `formai://workout/today` deep link routing. The atlas notes the gates apply ("workout/today applies gates"). It does *not* document the missing intent-preservation mechanism (i.e., no pendingIntent stash + replay after auth). This report's T-02 surfaces it.

---

## 6. APPENDIX — RETENTION EVIDENCE INDEX

| Finding | Primary file:line | Mechanism |
|---|---|---|
| T-01 | `notification_service.dart:299–331` + `workout_repository.dart:781–818` | Re-engagement timing |
| T-02 | `deep_link_service.dart:96–106` + `app_router.dart:78–126` | Intent preservation |
| T-03 | reward inventory across `gelisim_tab.dart`, `today_task_card.dart`, `session_complete_overlay.dart` | Variable-ratio reinforcement |
| T-04 | absence pattern in `notification_service.dart` + `gelisim_tab.dart:1617` | Re-engagement coverage |
| T-05 | `account_settings_screen.dart:248`, no time-of-day step in `onboarding_screen.dart:53–66` | Smart scheduling absence |
| T-06 | `live_activity_service.dart` (workout-only lifecycle) | Surface utilization |
| T-07 | `widget_sync_service.dart:99, 153–155` | Public failure broadcast |
| T-08 | `notification_service.dart:70–123` variant pools | Loss vs celebration ratio |
| T-09 | `notification_service.dart` (no targetMuscle / dayNumber awareness) | Personalization in channel |
| T-10 | `session_complete_overlay.dart:43–46, 89–92` | Workflow capture |
| T-11 | `notification_service.dart:237–254` (no payload) + atlas §8.6 | Friction at intent |
| T-12 | `account_settings_screen.dart:248` + onboarding step list | Default-bias capture |
| T-13 | `paywall_screen.dart:315–319` | No-escape gate |
| T-14 | `notification_service.dart:70–123` variant body lengths | Notification truncation |
| T-15 | `widget_sync_service.dart:103–106` `_kUpdatedAtMs` | Widget staleness signal |

---

**END OF RETENTION_TRIGGER_REPORT.md**
