# PHASE 1 COMPLETION REPORT — Rate & Feedback Loop

| | |
|---|---|
| **Roadmap** | `TESTERS_COMMUNITY_PRODUCT_ROADMAP.md` → Wave 1, Phase 1 |
| **Covers** | R2.1 · R2.2 · R2.3 · R4 (extension) · P4 · C8 · C9 · C10 · C30 · C31 |
| **Commits** | `accf12a` (phase) · `73bf33e` (CI fix) |
| **Baseline** | `a0d62bf` / build 1.0.0+18 → **`73bf33e` / build 1.0.0+19** |
| **Quality** | analyze **0** · **408 tests** (was 330, **+78**) · `dart format` clean · **CI GREEN** |
| **Artifact** | release APK **131.5 MB** |
| **Device** | Redmi M1908C3JGG (`AYXSUKIVJVPZ7HPZ`) — full fresh-install walk |
| **Status** | ✅ **COMPLETE** |

---

## 1. Summary

Phase 1 delivers two of the three changes the Production Access Questionnaire
formally commits to Google Play (P8): a **"Rate Your App" surface** and an
**expanded feedback loop**. The third (language support) is Wave 2.

The Testers Community observation was literal and correct — *"There is no
option to rate the app under the settings menu"* — and the underlying problem
was worse than the observation. FormAI already had an elegant cinematic rating
scene (Phase 136), but it was gated `if (!isPro) return;` and fired once, for
Pro subscribers only, at exactly one moment. It reached roughly **5%** of the
user base, and it was the wrong 5%: a new listing is built on reviews from its
whole base, not its payers.

Nine deliverables shipped:

| # | Deliverable | Roadmap ID |
|---|---|---|
| 1 | "Uygulamayı Değerlendir" row in Settings, un-gated | R2.1 |
| 2 | Multi-trigger contextual rating (5 triggers) | R2.2 |
| 3 | `isPro` gate removed — every user is now asked | C10 |
| 4 | Sentiment routing: 4–5★ → store, 1–3★ → feedback | C9 |
| 5 | Feedback-participation reward (50 XP + badge) | R2.3 |
| 6 | Micro-survey engine + NPS at day 14 | C8 · P4 |
| 7 | Searchable in-app help centre (17 FAQs) | C30 |
| 8 | Feedback triage schema + survey_responses table | C31 |
| 9 | `voice_heard` badge, wired into both galleries | R2.3 |

**Net effect on the metric the report cared about:** rating-prompt reach goes
from ~5% of users (Pro, 3rd workout, once) to essentially every user who
completes a single workout — while the *average rating* is protected rather
than diluted, because sentiment routing sends unhappy users to a private
channel instead of the public store.

---

## 2. Architecture

### 2.1 The rating policy is a pure function

The single most important structural decision. All rating logic — which
moment wins, how often we may ask, when we must stay silent — lives in
`selectRatingTrigger()`, a pure function with no widget tree, no clock, and no
SharedPreferences:

```dart
RatingTrigger? selectRatingTrigger({
  required RatingContext context,      // completedDays, streak, badgeJustUnlocked
  required Set<String> firedTokens,    // one-shot ledger
  required int promptCount,            // lifetime cap
  required DateTime? lastPromptAt,     // cooldown
  required DateTime now,
  required int maxLifetimePrompts,
  required Duration cooldown,
})
```

`RatingMomentService` only gathers state and presents UI. The result is that
the entire policy is provable — **22 unit tests** in
`rating_trigger_test.dart` are the specification, including a test that pins
the *absence* of `isPro`: if anyone reintroduces a subscription gate, the
function signature changes and the test stops compiling.

### 2.2 Trigger priority is declaration order

`RatingTrigger` is declared highest-emotion-first, and `eligibleTriggers`
preserves that order:

```
programComplete (30 days)  →  streakSeven (7-day streak)  →
thirdWorkout (3 days)      →  badgeUnlocked (caller-reported)  →
firstWorkout (1 day)
```

A user who crosses several thresholds in one session is asked at the *best*
moment, not the first one evaluated. `firstWorkout` is declared last precisely
so it only wins when nothing richer is available.

### 2.3 Three independent safety mechanisms

Growing from 1 trigger to 5 is only safe if the *set* can't become nagging:

1. **One-shot ledger** — `firedRatingTriggers` (a `Set<String>` of tokens).
   Each trigger fires at most once per install.
2. **Global cooldown** — 90 days between any two prompts, deliberately longer
   than Play's own In-App Review quota window so we never burn a quota slot on
   a user who just declined.
3. **Lifetime cap** — 3 prompts, ever. A user who has ignored three asks has
   answered the question.

Plus a **forward migration**: `seenPro3rdWorkoutRating` (Phase 136) is read
once and translated into the `thirdWorkout` token, so an existing user who
already saw — or declined — that scene is never asked again by the new trigger.

### 2.4 One interruption per dashboard return

`_runDashboardReturnFlow` is now a strict priority chain:

```
1. Badge / level-up celebrations
2. First-workout Pro invitation (non-pro)
3. Contextual rating moment (ALL users)
4. Micro-survey — ONLY if 1–3 all declined to fire
```

Step 4's guard (`if (firedTrigger != null || badgeJustUnlocked) return;`) is
what stops a growing set of prompts from compounding. A survey never stacks on
a rating ask, and neither stacks on a celebration.

`_maybeCelebrate()` was changed from `Future<void>` to `Future<bool>` to
supply the `badgeJustUnlocked` signal — so the `badgeUnlocked` rating trigger
rides a celebration the user is already feeling rather than arriving cold.

### 2.5 Sentiment routing

The five stars were previously decorative — `_RatingStars` ignored the index
entirely. They now report it, and `_onRate` splits on it:

- **4–5★** → `InAppReview.requestReview()`, falling back to the store listing
  if the platform API is unavailable.
- **1–3★** → the feedback sheet, pre-filled with
  `FeedbackSubject.suggestion` and a reframed intro
  (*"Neyi daha iyi yapabiliriz? Seni dinliyoruz."*).

This is why review volume and average rating can rise together: two
populations that previously funnelled to one destination are now separated.

### 2.6 Reward compliance is enforced by the API shape

Google Play's Developer Program Policy prohibits incentivising ratings or
reviews. The roadmap flagged this and Phase 1 implements the compliant form:
the reward attaches to **submitting feedback**, never to a rating.

That isn't a comment — it's the signature. `grantIfEligible()` takes **no
arguments at all**, so there is no rating or review value it could branch on:

```dart
Future<FeedbackReward?> grantIfEligible()   // FeedbackRewardService
```

The reward (50 XP + the `voice_heard` badge) is rate-limited to once per 7
days. The **limit applies to the reward, never to sending feedback** — a user
may always submit; they just won't be paid twice in a week. The lifetime
submission count still increments every time, because that count backs the
badge and should reflect every contribution.

Reward-granting lives inside the feedback sheet's submit path rather than at
the call sites, so both entry points (Settings row, sentiment-routed rating
flow) behave identically with one copy of the policy.

### 2.7 Surveys are data, not widgets

`SurveyDefinition` is a plain value object and `selectSurvey()` is a second
pure decision function. Adding a survey is a list entry in
`survey_definitions.dart`. The shape is deliberately serialisable so the
catalogue can move to the remote-config layer in Phase 4 without a rewrite.

Both shipped surveys gate on **behaviour AND wall-clock** together —
`minCompletedDays` and `minDaysSinceInstall`. A user who installed three weeks
ago but never trained has no informed opinion, and asking them produces noise
rather than signal. A test asserts no survey can ever fire before day 14.

`installedAt` was added to `AppPreferences` as a **self-seeding** getter: the
first read stamps `now` and returns it, so callers never see null and no
boot-sequence wiring was required.

### 2.8 Help centre never dead-ends

Every path through `HelpCenterScreen` terminates in a route to feedback — the
"Cevabını bulamadın mı?" card at the bottom of results, and a "Soru Gönder"
CTA in the no-results state. A help centre that dead-ends is worse than none.

Searching auto-expands matching tiles: a user who typed a query already told
us what they want to read, so making them tap again is friction for nothing.

---

## 3. Files changed

**29 files · +3,616 / −155**

### New — production (9)
| File | Purpose |
|---|---|
| `lib/features/monetization/domain/rating_trigger.dart` | `RatingTrigger`, `RatingContext`, `selectRatingTrigger()` |
| `lib/features/feedback/domain/survey.dart` | `SurveyDefinition`, `SurveyAnswer`, `selectSurvey()`, NPS bucketing |
| `lib/features/feedback/domain/survey_definitions.dart` | Survey catalogue (NPS + value-driver) |
| `lib/features/feedback/services/survey_service.dart` | Scheduling + Supabase transport |
| `lib/features/feedback/services/feedback_reward_service.dart` | R2.3 compliant reward policy |
| `lib/features/feedback/presentation/survey_sheet.dart` | NPS scale + choice list UI |
| `lib/features/feedback/presentation/help_center_screen.dart` | Searchable FAQ screen |
| `lib/features/feedback/data/faq_content.dart` | 5 categories, 17 entries, `searchFaq()` |
| `supabase/migrations/008_feedback_triage_and_surveys.sql` | Triage columns + `survey_responses` |

### Modified — production (10)
| File | Change |
|---|---|
| `rating_moment_service.dart` | Rebuilt: trigger-based, un-gated, sentiment routing, `openStoreListing()` (+430/−…) |
| `app_preferences.dart` | Rating ledger, cooldown, feedback counters, survey ledger, `installedAt` (+171) |
| `analytics_service.dart` | 8 new events; rating events now carry `trigger` (+98) |
| `dashboard_screen.dart` | Trigger wiring, survey step, `_maybeCelebrate → Future<bool>` (+74) |
| `profile_tab.dart` | Rate row, help row, reward-aware toast (+41) |
| `feedback_sheet.dart` | `initialSubject`, `introOverride`, reward on submit (+57) |
| `badges_screen.dart` | `voice_heard` gallery entry (+20) |
| `badge_unlocks_provider.dart` | `voice_heard` catalogue + unlock predicate (+17) |
| `app_router.dart` | `/help` route (+13) |
| `pubspec.yaml` | 1.0.0+18 → +19 |

### Format-only (2)
`paywall_screen.dart`, `act_1_hook_step.dart` — `dart format` line-joins, zero
behaviour change. **These were the cause of a 6-day-old red CI**; including
them repaired the `--set-exit-if-changed` gate.

### New — tests (8)
`rating_trigger_test.dart` (22) · `survey_test.dart` (18) ·
`app_preferences_phase1_test.dart` (14) · `help_center_screen_test.dart` (12) ·
`survey_sheet_test.dart` (6) · `voice_heard_badge_test.dart` (8) ·
`profile_tab_settings_test.dart` (6) · `feedback_reward_service_test.dart` (4)

---

## 4. Testing

**408 tests pass (was 330 — +78). analyze 0. format clean. CI green.**

Coverage by concern:

| Concern | Tests | Notable assertions |
|---|---|---|
| Rating policy | 22 | Trigger priority; one-shot ledger; 90-day cooldown; 3-prompt cap; `isPro` absence pinned; token strings pinned (renaming one re-asks every existing user) |
| Survey policy | 18 | Behaviour AND clock gates; boundary inclusivity; cooldown; NPS bucketing (9–10/7–8/0–6); catalogue integrity; "no survey before day 14" |
| Preferences | 14 | `installedAt` self-seeds, honours an existing stamp, never goes negative, degrades on a corrupt value; ledger de-duplication; policy constants |
| Help centre | 12 | Search case-insensitivity; answer-text indexing; category pruning; no-results state; never-dead-ends; content quality (no duplicate questions, no stub answers) |
| Survey UI | 6 | All 11 NPS values present; answer + dismissal both recorded; 1.3 text scale |
| Badge | 8 | Unlock predicate; **every unlockable badge has catalogue copy**; findable in the gallery locked *and* unlocked |
| Settings rows | 6 | Row present for free/Pro/guest; help sits above feedback (position asserted); tap is crash-safe |
| Reward | 4 | Grants once; cooldown blocks the second; count still increments when unrewarded |

### Two real bugs found by tests

1. **NPS anchor labels overflowed by 83 px at textScaler 1.3.** A
   `spaceBetween` Row couldn't fit both labels on a 393 px viewport. Fixed with
   `Expanded` + wrapping — the accessible fix, rather than capping the scale.
2. **`_FaqTile` hid its own ink splashes.** An `ExpansionTile` inside a
   `DecoratedBox` with a background colour. Caught by **CI's Flutter 3.44.8**,
   which asserts this; **local Flutter 3.41.9 does not**. Fixed with `Material`.

### Environment gap worth recording

**CI runs Flutter 3.44.8; this machine runs 3.41.9.** A whole class of newer
framework assertions cannot fire locally. Local green is therefore necessary
but not sufficient — every phase must be confirmed against CI before being
called done. That is now the working assumption for Phases 2+.

---

## 5. Screens verified on device

Full fresh-install walk on the Redmi (uninstall → install → age gate → consent
→ 19-step onboarding → guest dashboard), because the local build is
upload-key-signed and the installed build was Play-signed.

| # | Verified | Result |
|---|---|---|
| 1 | Settings — "Uygulamayı Değerlendir" | ✅ Renders with star icon + subtitle, styling identical to existing rows |
| 2 | Settings — visible for a **guest** | ✅ Proves the C10 un-gating end to end |
| 3 | Settings — "Yardım Merkezi" | ✅ Positioned directly above "Destek & Geri Bildirim" |
| 4 | Help centre render | ✅ Dark gradient halo, search field, 5 categories, collapsed tiles |
| 5 | FAQ expansion | ✅ Chevron flips, answer body renders |
| 6 | FAQ search (`"iptal"`) | ✅ Filters to ABONELİK, auto-expands the match, clear (×) appears |
| 7 | Help centre never dead-ends | ✅ "Cevabını bulamadın mı?" card present under results |
| 8 | Feedback sheet | ✅ Renders; lifts correctly above the keyboard (`viewInsets`) |
| 9 | Feedback submit | ✅ Completes, sheet dismisses |
| 10 | **Reward granted** | ✅ **"Sv 1 · Acemi · 50 XP"** on a user with **zero** completed workouts — exactly `kFeedbackRewardXp` |
| 11 | **`voice_heard` badge** | ✅ **"Sesini Duyduk · Geri bildirim gönder · ✓ Açıldı"** with the glowing unlocked treatment |
| 12 | Badge persistence | ✅ Survived `install -r` (SharedPreferences intact) |

### No regressions

| Surface | Result |
|---|---|
| RC-18 Başla screen | ✅ BAŞLA above the fold, hero + coach + capability card intact |
| Age gate / consent | ✅ Both render and advance |
| 19-step onboarding | ✅ All steps, progress counter 1/11→11/11 correct |
| LLM name chat | ✅ **Live** personalised Claude reply ("Emre, hoş geldin — ben Form…") |
| Personalised interludes | ✅ Name + goal correctly interpolated |
| AI report (10/11) | ✅ BMI 24.2 Normal, 2144 kcal, %92, 12-week projection |
| Guest → dashboard escape | ✅ "Şimdilik değil" reaches the dashboard |
| Dashboard / Gelişim / Profil | ✅ All render; charts, streak, 30-day grid correct |

---

## 6. Known limitations

1. **The rating cinematic scene was not device-verified.** Every trigger needs
   ≥1 completed workout, and completing one requires real camera reps — not
   drivable over adb. Mitigation: the *policy* has 22 unit tests, and the
   presentation layer is the unchanged `CinematicAiPresence` already
   device-proven in earlier phases. **The genuinely new UI (star index → fill
   animation → routing) has not been seen on a device.** Flagged for the next
   device pass, which should include a real workout.

2. **The micro-survey was not device-verified.** Requires 14 days since
   install + 3 completed workouts. Covered by 24 tests (policy + UI).

3. **Migration 008 is not applied to production.** The client writes to
   `feedback` (already live) and `survey_responses` (new). Survey writes will
   fail quietly — by design, the service logs and moves on, and PostHog still
   carries the answer — but **the rows will be lost until the founder applies
   the migration**. `feedback` triage columns have defaults, so existing
   feedback writes are unaffected. → founder action.

4. **No admin UI for feedback triage.** Migration 008 provides the schema
   (`status`, `tags`, `internal_note`, `responded_at`) and the index, and the
   columns are deliberately service-role-only so a user cannot close their own
   ticket. Triage is currently done via the Supabase dashboard. A surface
   inside the existing `/admin` screen is a natural small follow-up.

5. **FAQ search is a literal substring match.** Turkish suffix mutation means
   `"abonelik"` does not match `"aboneliğimi"` (k→ğ). Documented by an explicit
   test rather than papered over. A locale-aware collation belongs with Phase 5
   (i18n), which is where the FAQ content gets extracted to ARB anyway.

6. **All Phase 1 copy is Turkish literals.** Consistent with the rest of the
   app; ~90 new strings join the ~1,483 awaiting Phase 5 extraction. The FAQ
   content was deliberately authored as data (not widgets) to make that
   extraction mechanical.

7. **Git remote was repaired to push.** `origin` had an expired PAT embedded
   in its URL (`https://user:ghp_...@github.com/…`) pointing at the old repo
   name. Repointed to the canonical
   `https://github.com/emredogan-cloud/FormAI-Fitness-Kocu.git` and configured
   `gh` as the credential helper. **Founder note: that embedded token is dead
   but should be confirmed revoked on GitHub.**

---

## 7. Next phase

**Phase 2 — Dynamic Walkthrough I: Feature Tour & Visibility** (R1.1 · P3 ·
C27 · C37 · F-0.3). Roadmap estimate M / ~7–10 dev-days.

Deliverables: a reusable `SpotlightTour` coach-mark system; a 5-step dashboard
tour replacing the auto-closing narration; a post-paywall 4-card feature
showcase; a replayable "Uygulama Turu" settings entry; an empty-state pass
across all tabs; and feature-discovery affordances (unvisited-tab dots, a
"Biliyor muydun?" tip slot).

Groundwork already in place from Phase 1: the settings-row pattern is proven,
`AppPreferences` one-shot/ledger conventions are established, and the analytics
facade is extended and consistent.

---

*Phase 1 complete. `73bf33e` on `main`, CI green, build 1.0.0+19.*
