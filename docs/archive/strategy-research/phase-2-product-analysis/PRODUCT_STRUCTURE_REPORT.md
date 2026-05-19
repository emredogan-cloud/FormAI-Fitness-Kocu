# PRODUCT STRUCTURE REPORT

**Phase 2 — Product Analysis · Information Architecture**
**Project:** SixPack AI / FormAI Fit
**Generated:** 2026-05-08
**Inputs:** `reports/phase-1-project-discovery/PROJECT_STRUCTURE_MAP.md` (atlas), targeted source-file inspection (~20 files).
**Scope:** Information-architecture critique. Severity-scored findings with file:line evidence. No redesigns — this surfaces problems for Phase 5 to act on.

---

## 0. HOW TO READ THIS REPORT

Each finding follows the schema:

```
### Finding F-NN: [imperative title]
Severity: N/5
Where:    file:line  + atlas §X.Y reference
Observation: [factual]
Cost:        [behavioral / cognitive consequence]
Evidence:    [snippet or specific reference]
```

Severity scale (calibrated to a freemium subscription app at launch):
- **5** — directly blocks core conversion or core retention loop (paywall failure, first-run abandonment, can't find primary CTA)
- **4** — meaningful drop-off contributor; users complete the task but with friction that compounds session-to-session
- **3** — measurable cognitive load or feature non-discovery for non-trivial slice of users
- **2** — minor pattern-break, cleanable in a small refactor
- **1** — cosmetic / surface-only pattern inconsistency

Findings are sorted within each section by severity descending. ERRATA versus the Phase 1 atlas are flagged inline.

---

## 1. EXECUTIVE FINDINGS TABLE (severity-sorted)

| ID | Sev | Title | File anchor |
|---|---|---|---|
| F-01 | 5 | Antrenman / Gelişim role overlap forces user to choose tab without affordance signal | `antrenman_tab.dart:171–177`, `today_task_card.dart:96` |
| F-02 | 5 | Day 4+ paywall gate decided at CTA tap, not pre-tap | `today_task_card.dart:104–108`, `plan_detail_screen.dart:280–314` |
| F-03 | 5 | Onboarding has no autosave — exit between steps 1–11 wipes progress | `onboarding_screen.dart:165–217` |
| F-04 | 5 | Anonymous user can complete onboarding and reach paywall, then is force-gated by an undismissible auth modal | `paywall_screen.dart:182–214`, `auth_modal_bottom_sheet.dart:67–69` |
| F-05 | 4 | Gelişim tab stacks 9 distinct content blocks; primary CTA at ~420–450 px | `gelisim_tab.dart:149–206` |
| F-06 | 4 | `/progress/suggestions` is reachable from a single in-app surface (AI Coach card) — buried orphan | `gelisim_tab.dart:1605` |
| F-07 | 4 | Streak rendered in 2 places with 2 visual treatments and 1 source of truth duplicated | `antrenman_tab.dart:200–210`, `gelisim_tab.dart:211–220` |
| F-08 | 4 | Profile tab mixes 7 functional sections under 5 hand-rolled headers | `profile_tab.dart:65–300` |
| F-09 | 4 | Nutrition onboarding fires on first Beslenme-tab visit (post-paywall), not as a logical extension of primary onboarding | `dashboard_screen.dart:184–202` |
| F-10 | 4 | "Antrenman" tab name and "Antrenmana Başla" CTA on Gelişim collide vocabulary | `dashboard_screen.dart:248–251`, `today_task_card.dart:323` |
| F-11 | 3 | Plan-detail screen renders two distinct visual treatments (regional plan hero vs 30-day program) under one route | `plan_detail_screen.dart:138–148, 887–928` |
| F-12 | 3 | Empty-state pattern inconsistency between Gelişim (skeleton) and Antrenman (centered spinner) | `gelisim_tab.dart:170–177`, `antrenman_tab.dart:110–112` |
| F-13 | 3 | Workout / today widget tap on signed-out devices forces onboarding loop without context | `deep_link_service.dart:96–106`, `app_router.dart:78–126` |
| F-14 | 3 | Badge celebrations only fire on Gelişim tab — no in-app cue that celebrations are pending elsewhere | `dashboard_screen.dart:136–174` |
| F-15 | 3 | "PRO" pill in Antrenman header has the same affordance as profile-tab "FormAI Premium" tile but different position/visual | `antrenman_tab.dart:547–587`, `profile_tab.dart:262–267` |
| F-16 | 3 | Three nutrition entry points (Beslenme tab, Profile→Favorilerim, Beslenme tab→Discover) render different cards from the same data | `nutrition_tab.dart:293`, `profile_tab.dart:247–253`, `discover_recipes_screen.dart` |
| F-17 | 3 | `/prediction` is a defined route that the onboarding wizard skips; redirect rule still references it (atlas §4.4 ERRATA conflict) | `app_router.dart:109–111`, `onboarding_screen.dart:210–216` |
| F-18 | 3 | Dead-end on `_MissingRecipe` and `_MissingReferralCode` — only escape is "back to dashboard" | `app_router.dart:357–429` |
| F-19 | 3 | Dashboard tabs hidden behind workout flow — once user pushes `/workout`, no tab navigation; back-button is the only exit | `workout_camera_screen.dart:962–973` |
| F-20 | 3 | Profile tab is the only entry point to: notifications, theme, referral, feedback, privacy, account-deletion, admin — 8+ unrelated functions in one tab | `profile_tab.dart:65–500` |
| F-21 | 2 | "PRO" badge on Antrenman header tapping opens paywall without context — equivalent to a 7th paywall surface but discoverable only by curiosity | `antrenman_tab.dart:548–587` |
| F-22 | 2 | "Düzenle" button at line 116–135 of Profile is redundant with each per-tile tap action | `profile_tab.dart:79–89, 96–101, 116–135` |
| F-23 | 2 | "Bir Davet Kodu Kullan" tile (manual referral redeem) is an unmarked degraded-path counterpart to the deep-link flow | `profile_tab.dart:233–239` |
| F-24 | 2 | "Şampiyon serisi devam ediyor!" copy fires for any streak ≥7, but max-streak (e.g., 30+) gets the same line | `gelisim_tab.dart:1613–1621` |

**Total findings: 24** (5 sev-5, 6 sev-4, 11 sev-3, 4 sev-2, 0 sev-1)

---

## 2. TAB-LEVEL IA EVALUATION

### 2.1 The 4-tab shell (atlas §3.4)

| # | Label | Widget | Purpose (per atlas) | Actually does |
|---|---|---|---|---|
| 0 | Antrenman | `AntrenmanTab` | "workout-focused entry" | Workout entry + weekly goal + equipment filters + region filter (1500+ line list) |
| 1 | Beslenme | `NutritionTab` | "nutrition" | Nutrition hero (calorie ring + macros + AI insight) + meal plan timeline |
| 2 | Gelişim | `GelisimTab` | "progress / analytics" | **Also workout entry** (Today Task Card, line 177) + 9 sections of analytics |
| 3 | Profil | `ProfileTab` | "profile" | Profile + Settings + Notifications + Theme + Referral + Account deletion + Admin (when JWT claim) + Feedback + Privacy + Subscription mgmt |

**The contract suggested by the labels:** Antrenman = "do workout", Beslenme = "eat", Gelişim = "see progress", Profil = "your account."

**The contract delivered by the code:** Antrenman = "do workout (variant 1: discovery + challenge)", Gelişim = "do workout (variant 2: today's task + analytics)", Profil = "every settings function".

This is documented in the atlas observation §5.9 ("Antrenman vs Gelişim role overlap") and produces three concrete failures, captured below.

### Finding F-01: Antrenman / Gelişim role overlap forces user to choose tab without affordance signal
**Severity:** 5/5
**Where:** `lib/features/home/presentation/widgets/antrenman_tab.dart:171–177` (Challenge Hero Card → `/plan-detail`); `lib/features/home/presentation/widgets/today_task_card.dart:96–113` (Today Task → `/plan-detail`); atlas §5.7 "Quick-start CTAs"
**Observation:** Two tabs each present a "primary" CTA that lands on the same destination (`/plan-detail`) for the same user state (Day 1–3 free, Day 4+ → paywall). The Challenge Hero card on Antrenman is a 320 px image card; the Today Task Card on Gelişim is a 140 px metadata + neon-gradient pill. Both produce "Day N – Focus, 25 min, Beginner" in slightly different layouts. The user has no visual or copy distinction telling them which is "the" primary entry point.
**Cost:**
- **Decision paralysis on Day 1:** every fresh launch lands on Antrenman (default tab, `dashboard_screen.dart:37 _index = 0`). The first-time user's eye finds the Challenge Hero ("BAŞLA") but the primary completion-tracking surface (Gelişim tab Today Task Card with the same CTA) is one tab-tap away — invisible until user explores.
- **Habit formation defeat:** users who develop a Day-2 muscle memory of one tab will not see the other tab's surface; the "weekly goal" widget on Antrenman and the "30-day grid" on Gelişim each undercount because the user doesn't know to check both.
- **Analytics impurity:** PostHog `paywallViewed` from Day 4+ taps will fire from two distinct trigger surfaces with the same outcome — funnel attribution gets noisy without a `source` parameter (atlas §6.3 already flags `paywallViewed` lacks `source`).

**Evidence:**
```dart
// antrenman_tab.dart:171–177
ChallengeHeroCard(
  title: _challengeTitleFor(nextDay),
  dayNumber: nextDay?.dayNumber ?? 1,
  completed: completed,
  total: 30,
  onTap: () => context.push(AppRoutes.planDetail),
),
```
```dart
// today_task_card.dart:104–113
final isPro = ref.read(isProProvider);
if (!isPro && activeDay.dayNumber > kFreeDayLimit) {
  AppHaptics.secondaryTap();
  context.push(AppRoutes.paywall);
  return;
}
AppHaptics.primaryCta();
context.push(AppRoutes.planDetail);
```

The two destination calls are identical (both `context.push(AppRoutes.planDetail)`) for users in the free range. The Antrenman card carries no Pro gate at the card level — the gate is checked inside `_onDayTap` in plan-detail (`plan_detail_screen.dart:300–314`) when the user taps a specific day tile.

---

### Finding F-02: Day 4+ paywall gate decided at CTA tap, not pre-tap
**Severity:** 5/5
**Where:** `lib/features/home/presentation/widgets/today_task_card.dart:104–108`; `lib/features/workout/presentation/plan_detail_screen.dart:280, 312`; atlas §5.9 "Free-tier paywall gate at Day 4+ is decided at CTA tap, not signaled pre-tap"
**Observation:** The Today Task Card on Gelişim shows "Gün 4 – Bacak Gücü, 30 dk · Orta Seviye" with a full-width neon-gradient "ANTRENMANA BAŞLA" CTA. Tapping it triggers a paywall redirect (`context.push(AppRoutes.paywall)`) with no pre-tap badge, lock icon, dim treatment, or in-card disclosure. The sole visible signal that the user is at a Pro gate is the "PRO" pill in the Antrenman header — which is a separate tab.
**Cost:**
- **Frustration spike at Day 4:** the user has built a 3-day habit (per §5.6 streak system) and is presented with a green "go" CTA that punishes the tap with a paywall. This is the canonical "dark pattern" complaint pattern in app reviews.
- **Trust erosion:** shows the user a personalized program ("Gün 4 – Bacak Gücü") then withholds it; the personalization itself becomes the decoy.
- **Conversion noise:** users who would have paid voluntarily at Day 3 (last free day) cannot — the "upgrade now" affordance is a tiny 60 px pill at the top of a different tab. Users who hit the gate on Day 4 are 24h after their last completed session, when motivation is lowest (this is the worst possible moment for an unexpected paywall).

**Evidence:**
```dart
// today_task_card.dart:104–108
final isPro = ref.read(isProProvider);
if (!isPro && activeDay.dayNumber > kFreeDayLimit) {
  AppHaptics.secondaryTap();
  context.push(AppRoutes.paywall);
  return;
}
```
The check happens *after* the user taps. The card's visual rendering at lines 33–99 is identical for Day 1, 4, 15, or 30 — same neon-gradient CTA, same "Gün N – Focus" layout. There is no `isLocked` parameter passed to `TodayTaskCard`.

Compare to `plan_detail_screen.dart:280` which DOES compute `isLocked` and visibly dims rows: `final isLocked = !isPro && dayNumber > _freeDayLimit;`. The plan-detail screen does it right; the dashboard task card doesn't.

---

### Finding F-10: "Antrenman" tab name and "Antrenmana Başla" CTA on Gelişim collide vocabulary
**Severity:** 4/5
**Where:** `lib/features/home/presentation/dashboard_screen.dart:248–251` (tab label `Antrenman`); `lib/features/home/presentation/widgets/today_task_card.dart:323–333` (CTA text `ANTRENMANA BAŞLA`); atlas §3.4 + §5.7
**Observation:** Tab 0's label is "Antrenman" (Workout). The primary CTA on tab 2 (Gelişim) reads "ANTRENMANA BAŞLA" (Start Workout). For a user who learns "Antrenman" = a tab on the bottom nav, seeing the same word as a CTA inside a different tab creates a small but consistent vocabulary collision: "the start-workout button is on the progress tab, not the workout tab."
**Cost:**
- Mental-model fracture for first-week users; the lexicon "Antrenman is a tab AND an action" forces them to disambiguate via context every time.
- For Turkish-language readers (the entire app is Turkish), this feels like a translation oversight — but it's structural.

**Evidence:**
```dart
// dashboard_screen.dart:248–251
BottomNavigationBarItem(
  icon: Icon(Icons.fitness_center_outlined),
  activeIcon: Icon(Icons.fitness_center),
  label: 'Antrenman',
),
```
```dart
// today_task_card.dart:323–333
Text(
  'ANTRENMANA BAŞLA',
  ...
),
```

---

## 3. FEATURE DISCOVERABILITY HEATMAP

The atlas (§3.1) lists 18 named routes. We map each to count of in-app entry points (excluding deep links and the route's own widget self-references).

| Route | In-app entry points | Surfaces |
|---|---|---|
| `/` (dashboard) | n/a (default landing) | — |
| `/onboarding` | 1 redirect-only | first-time install |
| `/auth` | 2 | redirect on signed-out + Profile "Üye Ol" tile + Auth modal email-fallback link |
| `/workout` | 2 | `plan_detail_screen.dart:323`, `plan_detail_screen.dart:1119` (regional plan CTA), deep link |
| `/workout/today` | 1 | deep link only (alias to `/workout`) |
| `/paywall` | **8** | profile tile, profile FormAI Premium, antrenman PRO pill, today task card, plan-detail day tile, plan-detail regional CTA, plan-detail upsell CTA, post-onboarding, post-auth |
| `/prediction` | 0 | unreachable from in-app navigation; only via direct router push (none observed) |
| `/plan-detail` | 4 | antrenman challenge hero, antrenman regional plan tile, equipment strip card, today task card |
| `/account-settings` | 1 | profile tab "Hesabı Sil" |
| `/recipe` | n/a | reached by recipe tap inside nutrition_tab + recipe lists |
| `/nutrition/category/:type` | n/a | nutrition tab category filter |
| `/progress/calendar` | **1** | gelisim_tab "Takvimi Gör →" pill |
| `/progress/suggestions` | **1** | gelisim_tab AI Coach card "Önerilere Git →" pill |
| `/progress/badges` | **1** | gelisim_tab badges section "Tümünü Gör →" |
| `/nutrition/discover` | **1** | nutrition_tab "Keşfet" button |
| `/nutrition/favorites` | **1** | profile_tab "Favorilerim" tile |
| `/admin` | 1 | profile tab tile (JWT-gated, invisible to non-admin) |
| `/referral` | 0 in-app | only deep link `formai://r/<code>` |

### Finding F-06: `/progress/suggestions` is reachable from a single in-app surface (AI Coach card), creating an orphan
**Severity:** 4/5
**Where:** `lib/features/home/presentation/widgets/gelisim_tab.dart:1605` (sole entry); atlas §3.1 (route exists); atlas §9.1
**Observation:** `/progress/suggestions` produces 3 contextual AI Coach tips (workout, nutrition, hydration). The route is reachable from exactly one tap target — a low-prominence "Önerilere Git" pill at the bottom of the AI Coach card on the Gelişim tab, itself the 7th of 9 sections (atlas §5.2). To reach it: open app → tap Gelişim tab → scroll past 6 cards → find AI Coach card → tap pill. That is a 4-tap path on a small surface for a feature designed as the user's primary AI coach interaction.
**Cost:**
- **Coach feature non-discovery.** Three tailored tips is the only place "AI Coach" is interactive (apart from the audio summary button). Users who don't make it to the bottom of the Gelişim tab never know the feature exists.
- **Personalization waste.** The screen's recommender pulls live data (`firstIncomplete`, `remainingMacrosProvider` — `suggestions_screen.dart:43–47`); compute spent, not seen.

**Evidence:**
```dart
// gelisim_tab.dart:1601–1607 (inside _AiCoachCard)
Align(
  alignment: Alignment.centerLeft,
  child: _SectionLinkPill(
    label: 'Önerilere Git',
    onTap: () => context.push(AppRoutes.progressSuggestions),
  ),
),
```
A grep across the codebase confirms zero other references to `progressSuggestions`:
```
grep -rn "context.push(AppRoutes.progressSuggestions" lib/
→ lib/features/home/presentation/widgets/gelisim_tab.dart:1605 (only hit)
```

---

### Finding F-13: Workout / today widget tap on signed-out devices forces onboarding loop without context
**Severity:** 3/5
**Where:** `lib/core/services/deep_link_service.dart:96–106`; `lib/core/routing/app_router.dart:78–126`; atlas §3.3 + §5.8
**Observation:** Phase 55 ships an iOS WidgetKit tile and Android AppWidgetProvider that deep-link to `formai://workout/today`. The deep-link service routes to `AppRoutes.workout` (`deep_link_service.dart:104`). The router's redirect rules (`app_router.dart:78–126`) gate `/workout` behind first-time + auth checks. A user who taps the home-screen widget on a device where they were signed out (token expired beyond refresh, or different account on a shared device) lands on `/auth` — with no contextual message that they tapped a workout widget; the auth screen shows the standard `'Tekrar hoşgeldin.'` headline.
**Cost:**
- The tap intent ("start today's workout") is silently transformed into a generic auth flow. After signing in, the user is routed to `/paywall` (per redirect rule 5, `app_router.dart:112–114`) — not back to the workout. The workout intent is lost.
- Comparable to a calendar widget that opens an app's homepage instead of the event you tapped.

**Evidence:**
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
The code comment acknowledges this as designed behavior. The cost is borne by the user; there is no preserved intent, no toast on auth-screen-arrival explaining "Sign in to start your workout."

---

### Finding F-18: Dead-end on `_MissingRecipe` and `_MissingReferralCode` — only escape is "back to dashboard"
**Severity:** 3/5
**Where:** `lib/core/routing/app_router.dart:357–429` (_MissingRecipe + _MissingReferralCode)
**Observation:** Two error fallbacks render identical "Ana ekrana dön" buttons when the user lands on `/recipe` without a Recipe object (e.g., a malformed deep link) or `/referral` without `?code=`. There is no "try again", "open app", or "search recipes" affordance.
**Cost:**
- For `/recipe`: a user who shared a recipe link via WhatsApp without metadata gets a dead-end. No recovery to "find this recipe" alternative.
- For `/referral`: missing-code flow tells the user "your link is broken" but offers no path to redeem manually. (The Profile tab does have a "Bir Davet Kodu Kullan" tile, but the error screen doesn't surface that.)

**Evidence:**
```dart
// app_router.dart:380–384 (_MissingReferralCode)
FilledButton(
  onPressed: () => context.go(AppRoutes.dashboard),
  child: const Text('Ana ekrana dön'),
),
```
Same pattern at line 419–422 for `_MissingRecipe`.

---

## 4. COGNITIVE OVERLOAD AUDIT

### Finding F-05: Gelişim tab stacks 9 distinct content blocks; primary CTA at ~420–450 px
**Severity:** 4/5
**Where:** `lib/features/home/presentation/widgets/gelisim_tab.dart:149–206` (build method); atlas §5.2 (9 sections enumeration), §5.3 (above-the-fold inventory)
**Observation:** The Gelişim tab's `ListView` constructs nine stacked sections in this order:
1. Top Header (title + subtitle + streak pill + share button) — `_TopHeader` at line 153
2. Program Stats Column (progress card + streak card) — line 159–163
3. Sync/Offline/Complete state OR Today Task Card — line 170–177
4. 30-Day Grid — line 179–183
5. Three Stats Cards (week bars + calorie line + workout bars) — line 185–189
6. Weekly Retrospective Card (Sundays only) — line 197
7. AI Coach Card — line 198
8. Badges Section — line 200–204
9. Implicit final padding (40 px bottom)

**Above-the-fold (~600 px on a 6.1" device, atlas §5.3):** sections 1, 2, top of 3 (Today Task Card metadata only — CTA is below the fold or at exact threshold). The "ANTRENMANA BAŞLA" CTA sits at ~420–450 px from the top of the safe area.

**Cost:**
- **Primary action below first viewport on smaller phones.** The CTA is the single most important interaction in the app per the Today Task Card semantic label (`'Antrenmana başla'`, `today_task_card.dart:285`). It being below the day-metadata block AND below the program-progress + streak cards forces a scroll-and-search.
- **Hick's Law:** 9 sections in one scroll surface increases time-to-decision for any non-CTA action (badge tap, calendar tap, suggestions tap) — the user must visually scan past 4–7 unrelated cards to reach what they want.
- **Metric impurity:** scrolling depth is not analytics-tagged (atlas does not list scroll-depth events); we can't tell which sections users actually see vs scroll past.

**Evidence:**
```dart
// gelisim_tab.dart:149–206
return RefreshIndicator(
  ...
  child: ListView(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
    children: [
      _TopHeader(...),                       // §1 ~88 px
      const SizedBox(height: 22),
      _ProgramStatsColumn(...),              // §2 ~220 px (two stacked cards)
      const SizedBox(height: 14),
      if (isSessionLoading) ...              // §3 (~110 px)
      else if (...) ...
      else if (activeDay != null)
        TodayTaskCard(activeDay: activeDay), // §3 actual today task ~140 px
      const SizedBox(height: 24),
      _DayGridSection(...),                  // §4
      const SizedBox(height: 24),
      _StatsCardsColumn(...),                // §5
      const SizedBox(height: 22),
      const WeeklyRetrospectiveCard(),       // §6 (Sunday-only)
      _AiCoachCard(...),                     // §7
      const SizedBox(height: 22),
      _BadgesSection(...),                   // §8
    ],
  ),
);
```

The cumulative offset before the Today Task Card CTA on a 6.1" device:
- 16 px top pad
- 88 px Top Header
- 22 px gap
- 220 px Program Stats Column (Program Progress + 12 px gap + Streak Card)
- 14 px gap
- ~70 px Today Task Card metadata block (label + day text + minutes/level)
≈ 430 px from the top of the safe area before the CTA renders.

This matches atlas §5.3's 420–450 px estimate.

---

### Finding F-08: Profile tab mixes 7 functional sections under 5 hand-rolled headers
**Severity:** 4/5
**Where:** `lib/features/home/presentation/widgets/profile_tab.dart:65–500`
**Observation:** The Profile tab renders the following section headers + content groups in order:
1. `_ProfileHeader` (avatar, email, guest indicator) — line 67
2. `BİLGİLERİM` (age, weight, height, goal as 4 InfoTiles + Düzenle button) — line 70–135
3. `İLERLEME` (streak + completed) — line 137–157
4. `HESAP AYARLARI` (Profili Düzenle + Şifreyi Değiştir + Bildirimler + Hesabı Sil) — line 166–197
5. (Conditional admin section, visible only with JWT claim) — line 205–215
6. `ARKADAŞINI DAVET ET` (referral card + redeem-code tile) — line 222–239
7. `BESLENMEM` (Favorilerim only — single tile) — line 245–253
8. `AYARLAR` (Theme + FormAI Premium + Subscription cancel + Sesli Koç Testi + Gizlilik + Destek + ...) — line 255–end

**Cost:**
- **8 sections in a single scroll** for what should be a "you" tab. The user looking for "delete account" must scroll past info, progress, account-settings, admin, referral, BESLENMEM, AYARLAR top items to find the danger tile (it's actually inside HESAP AYARLARI — line 191–197, *third* from the top of that block, but several scrolls below the screen origin).
- **`Profili Düzenle` appears twice** — as a tile in HESAP AYARLARI (`profile_tab.dart:168–173`) and as a "Düzenle" FilledButton in BİLGİLERİM (line 116–135), both opening `_openEditSheet`. Two routes to the same action.
- **`BESLENMEM` is a single-item section** (Favorilerim) — unnecessary chrome for one tile.
- **Section ordering does not match user priority:** post-purchase, the most-used setting is likely "subscription cancel" (per RC support data conventions) — but that tile is buried at line 274 inside AYARLAR, conditionally rendered behind `isProProvider`.

**Evidence:**
```dart
// profile_tab.dart:166–197 (HESAP AYARLARI)
const _SettingsHeader(title: 'HESAP AYARLARI'),
const SizedBox(height: 10),
_SettingsTile(icon: Icons.person_outline, title: 'Profili Düzenle', ...),
_SettingsTile(icon: Icons.lock_outline, title: 'Şifreyi Değiştir', ...),
_SettingsTile(icon: Icons.notifications_outlined, title: 'Bildirimler', ...),
if (!(user?.isAnonymous ?? true))
  _DangerSettingsTile(...),
```
Comment at line 159–165 explicitly admits this was a Phase 48.1 PR retrofit: "*The PM specifically flagged this section as missing in the Phase 48 review*" — confirming the Profile tab grew to its current state by accretion, not a single IA design pass.

---

### Finding F-20: Profile tab is the only entry point to: notifications, theme, referral, feedback, privacy, account-deletion, admin
**Severity:** 3/5
**Where:** `lib/features/home/presentation/widgets/profile_tab.dart:65–500`
**Observation:** The Profile tab consolidates 8+ functions, none of which are profile-related in a strict sense. Theme switch, notifications timer, referral code share, account deletion, admin panel, feedback sheet, privacy modal — all live exclusively under tab 3.
**Cost:**
- Discoverability — users seeking notification settings must intuit "Profil" rather than e.g. a system-style settings menu.
- The atlas-listed Profile tab (`profile_tab.dart`) becomes the dumping ground for everything that doesn't fit elsewhere.
- Mobile UX convention is split: iOS users expect a "Settings" tab; Android users expect overflow menus. This app provides neither and uses Profil as both.

**Evidence:** see atlas §13 inventory and `profile_tab.dart:166–500` chain of sections.

---

## 5. DEAD-ENDS AND BACKTRACK PATHS

### Finding F-19: Dashboard tabs hidden behind workout flow — once user pushes `/workout`, no tab navigation; back-button is the only exit
**Severity:** 3/5
**Where:** `lib/features/workout/presentation/workout_camera_screen.dart:962–973` (`_exit`); atlas §8 (workout flow span = 5 screens)
**Observation:** The workout camera is a top-level route (`/workout`), not a sub-route of dashboard. Once the user enters via `context.push(AppRoutes.workout)` (from plan-detail or deep link), the bottom navigation bar is replaced by the workout camera scaffold. The only exits are: exercise completion → SessionCompleteOverlay → `_exit` → `context.pop()` (back to plan-detail or dashboard if no canPop) OR the back gesture mid-exercise.
**Cost:**
- Mid-workout interruption (phone call, scroll up to check time, tap a notification) requires hitting hardware back to leave — but back during exercise loses rep state (no autosave on workout reps observed). The atlas notes `workout_back_button.dart` exists with "exit w/ unsaved-progress safeguard" — but this is a back-button-only safeguard, not a tab-exit one.
- Users accustomed to "hit Beslenme tab to check meal during rest" cannot — the bottom nav is gone.

**Evidence:**
```dart
// workout_camera_screen.dart:962–973
void _exit(BuildContext context) {
  unawaited(WorkoutLiveActivityService.instance.endWorkout());
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/');
  }
}
```
The route is pushed by `plan_detail_screen.dart:323` (`context.push(AppRoutes.workout)`) — a `push`, not a `go`, so it sits on top of the stack. But because `/workout` is registered as a top-level GoRoute (`app_router.dart:158–161`), the dashboard's IndexedStack is not in the visual tree.

---

## 6. IA INCONSISTENCIES — SAME CONCEPT, DIFFERENT TREATMENT

### Finding F-07: Streak rendered in 2 places with 2 visual treatments and 1 source of truth duplicated
**Severity:** 4/5
**Where:**
- `lib/features/home/presentation/widgets/antrenman_tab.dart:200–210` (`_streakOf`)
- `lib/features/home/presentation/widgets/gelisim_tab.dart:211–220` (`_streakOf`)
- Antrenman header flame badge (atlas §5.6); Gelişim top streak pill + 5-dot streak card (atlas §5.2 §3-§3a)

**Observation:** Streak is computed by an identical helper function defined in two places (`antrenman_tab.dart:200` and `gelisim_tab.dart:211`) and rendered as:
- Antrenman tab: `_FlameStreakBadge` — orange flame icon + small black-on-orange counter pill (32 px square; `antrenman_tab.dart:589–636`)
- Gelişim tab top: orange-bordered pill with "🔥 N Günlük Seri" copy (`gelisim_tab.dart:420–443`)
- Gelişim tab Streak Card: 5-dot checklist with label "Seri" + flame puck (atlas §5.2 §3a)
- Profile tab Stats Tile: text "N gün" with `Icons.local_fire_department` (`profile_tab.dart:142–146`)

That's 4 visual treatments of the same concept. Color, scale, and label all differ.

**Cost:**
- Pattern-recognition cost: the user must learn that all four are the same number.
- Duplicate logic: two `_streakOf` helpers means a future bug fix in streak math (e.g., timezone edge case) requires patching both files. Atlas §10 cross-cutting note: badge predicates are also duplicated between `gelisim_tab.dart` and `badges_screen.dart`.
- Source of truth fracture: `appPreferencesProvider.maxStreak` is a separate persisted value (atlas §5.6) used only by AI Coach copy — there's no canonical "streakProvider" so the two `_streakOf` functions silently re-derive the value on every rebuild.

**Evidence:**
```dart
// antrenman_tab.dart:200–210
int _streakOf(List<WorkoutDay> days) {
  var streak = 0;
  for (final day in days) {
    if (day.isCompleted) {
      streak += 1;
    } else {
      break;
    }
  }
  return streak;
}
```

Identical at `gelisim_tab.dart:211–220`. The atlas §10.1 calls out duplicate badge predicates as the same anti-pattern.

---

### Finding F-12: Empty-state pattern inconsistency between Gelişim (skeleton) and Antrenman (centered spinner)
**Severity:** 3/5
**Where:** `lib/features/home/presentation/widgets/gelisim_tab.dart:170–177` (`_ProgramSyncingCard` skeleton); `lib/features/home/presentation/widgets/antrenman_tab.dart:110–112` (`Center(child: CircularProgressIndicator)`); atlas §5.5
**Observation:** Loading state on Gelişim tab is a skeleton card preserving layout height (Phase 49 work, atlas §0.7.4 lists `SkeletonBox` etc.). Loading state on Antrenman tab is a centered `CircularProgressIndicator` with no layout reservation.
**Cost:**
- Visual jump on Antrenman tab when data lands (spinner replaced by full ListView).
- Pattern inconsistency: the user learns one loading visual on Gelişim, sees a different one on Antrenman, must mentally bridge.

**Evidence:**
```dart
// antrenman_tab.dart:110–112
return sessionAsync.when(
  loading: () =>
      const Center(child: CircularProgressIndicator(color: _neon)),
```
vs. `gelisim_tab.dart:170–177` which renders `_ProgramSyncingCard` (a skeleton-like card) inside the ListView at the Today Task Card slot.

---

### Finding F-15: "PRO" pill in Antrenman header has the same affordance as profile-tab "FormAI Premium" tile but different position/visual
**Severity:** 3/5
**Where:** `lib/features/home/presentation/widgets/antrenman_tab.dart:547–587` (`_ProButton`); `lib/features/home/presentation/widgets/profile_tab.dart:262–267`
**Observation:** Both surfaces deep-link to `/paywall`:
- Antrenman: small purple-bordered pill with crown icon + "PRO" label, top-right of header
- Profile: full-width `_SettingsTile` with crown icon + "FormAI Premium" + subtitle "Aboneliğini yönet"

For a Pro user (entitlement active), Antrenman's pill is still rendered (no conditional guard at `antrenman_tab.dart:547`) but tapping still routes to paywall — the paywall handles the "already Pro" case via its restore button. Profile renders an additional "Aboneliği İptal Et" tile beneath the FormAI Premium tile when Pro (line 274–280).

**Cost:**
- Free user sees paywall hook in 2+ places (PRO pill, profile tile, Today Task Day 4+, plan-detail upsells, etc.) but each affords a different visual — no learned association.
- Pro user still sees the "PRO" pill — no visual confirmation of their Pro status via that surface; it's purely a paywall portal regardless of entitlement.
- Subscription management is a 4-tap path (Profil tab → scroll → AYARLAR section → "Aboneliği İptal Et"), buried.

**Evidence:**
```dart
// antrenman_tab.dart:547–586
class _ProButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      ...
      child: InkWell(
        onTap: () => context.push(AppRoutes.paywall),
        ...
      ),
    );
  }
}
```
No `ref.watch(isProProvider)` check — the pill renders identically for Free and Pro users.

---

### Finding F-16: Three nutrition entry points render different cards from the same data
**Severity:** 3/5
**Where:** `lib/features/nutrition/presentation/nutrition_tab.dart:293`; `lib/features/home/presentation/widgets/profile_tab.dart:247–253`; `lib/features/nutrition/presentation/discover_recipes_screen.dart`; `lib/features/nutrition/presentation/category_recipes_screen.dart`; atlas §9.2
**Observation:** Nutrition is reachable from:
1. Beslenme tab's main timeline (today's planned meals) → recipe detail
2. Beslenme tab's category chips → `nutrition/category/:type` → recipe detail
3. Beslenme tab's "Keşfet" button → `/nutrition/discover` (paginated 20/page) → recipe detail
4. Profile tab → Favorilerim → `/nutrition/favorites` → recipe detail

Each of (2), (3), (4) renders a *list* of recipes with subtly different card chrome. Discover is a 2-col grid (atlas §9.2: "paginated 2-col grid"); Favorites is "saved recipes + shopping-list export"; Category is filtered list. Same underlying `Recipe` model, but the user sees the same recipe styled differently in each surface.
**Cost:** breaks visual consistency for what should be one canonical recipe-tile. Each new dev onboarding learns three slightly different card patterns.

---

## 7. DEFERRED-ONBOARDING DISCONTINUITY

### Finding F-09: Nutrition onboarding fires on first Beslenme-tab visit (post-paywall), not as a logical extension of primary onboarding
**Severity:** 4/5
**Where:** `lib/features/home/presentation/dashboard_screen.dart:184–202`; `lib/features/nutrition/presentation/widgets/nutrition_onboarding_sheet.dart:52–62`; atlas §4.3 (7 deferred steps)
**Observation:** Primary onboarding completes at `_finish()` and routes to `/paywall`. The user completes (or dismisses) the paywall, lands on the dashboard (default tab Antrenman). The 7 nutrition questions (`nutrition_goal`, `nutrition_diet_preference`, `nutrition_allergies`, `nutrition_meal_frequency`, `nutrition_prep_time`, `nutrition_water_intake`, `nutrition_taste_preference`) do not fire until the user clicks the Beslenme tab.

Behavior:
- The sheet is `isDismissible: false` (`nutrition_onboarding_sheet.dart:57`), `enableDrag: false`, and at 95% screen height — same modal contract as the auth gate (atlas §6.7).
- Users who never tap Beslenme never see the questions. Their `userMetrics` lacks nutrition prefs forever; the AI Coach card on Gelişim falls back to default macros (`gelisim_tab.dart:1620`: "Bugün hedeflerimize bir adım daha yaklaşıyoruz").

**Cost:**
- **Delayed personalization.** The macro target depends on these answers (`MacroTarget` model, atlas §9.2). A user who explores Antrenman + Gelişim for a week before tapping Beslenme has 7 days of fallback macro targets feeding their AI Coach summary.
- **Surprise modal.** First Beslenme tap presents 7 mandatory questions (non-dismissible) — a friction spike at a moment when the user expected to browse meals.
- **IA fracture.** Onboarding "feels" finished after the paywall; the user has crossed the welcome wall. A 7-step modal weeks later violates the contract that primary onboarding ended at the paywall close.
- Atlas §4 calls this out as "deferred nutrition onboarding — 7 steps" but the structural cost is uncalled.

**Evidence:**
```dart
// dashboard_screen.dart:184–202
if (newIndex == _nutritionTabIndex && previous != _nutritionTabIndex) {
  _maybePromptNutritionSheet();
}

void _maybePromptNutritionSheet() {
  final prefs = ref.read(appPreferencesProvider);
  if (prefs.hasCompletedNutritionPrefs) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    showNutritionOnboardingSheet(context);
  });
}
```

```dart
// nutrition_onboarding_sheet.dart:52–62
Future<void> showNutritionOnboardingSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    enableDrag: false,
    isDismissible: false,
    ...
  );
}
```

The non-dismissible sheet means a user who tapped Beslenme out of curiosity is forced through 7 questions to escape — even if they only wanted to peek at meal photos.

---

## 8. ONBOARDING IA — STRUCTURAL FAILURES

### Finding F-03: Onboarding has no autosave — exit between steps 1–11 wipes progress
**Severity:** 5/5
**Where:** `lib/features/onboarding/presentation/onboarding_screen.dart:165–217` (`_finish` is sole persistence call); atlas §4.6 "No autosave mid-onboarding"
**Observation:** The onboarding wizard's state is held in a Riverpod `Notifier<WizardState>` (memory only). Persistence to SharedPreferences happens once, at the end, inside `_finish()` (line 177: `await prefs.saveUserMetrics(wizard.toJson())`). If the user kills the app, hits home then loses focus, gets a phone call, or the OS reclaims memory between steps 1 and 11, all answers are lost. Relaunch forces them back to step 1 (router redirect rule 2: `prefs.isFirstTime == true` → `/onboarding`).
**Cost:**
- **Catastrophic for retention on cold installs.** Onboarding is 12 steps with two ~4–6 second labor-illusion screens (`_AnalysisIllusionStep`, `_DynamicReportStep`). A user interrupted at step 9 ("Pain Point") loses gender, age, height, weight, goal, experience, daily-minutes, activity level, and pain-point data — back to step 1.
- **No "resume where you left off" pattern** which most well-designed onboarding flows ship as a default. Compare e.g. duolingo, headspace, betterme — all autosave per question.
- **Compound with `_AnalysisIllusionStep`'s 6-second labor-illusion + `_DynamicReportStep`'s 1.4 s fade-in:** users at step 10 have invested 8+ seconds in a "thinking" animation; an interruption mid-animation forces a complete restart.

**Evidence:**
```dart
// onboarding_screen.dart:165–217 (_finish — sole save)
Future<void> _finish() async {
  AppHaptics.primaryCta();
  final wizard = ref.read(wizardProvider);
  final prefs = ref.read(appPreferencesProvider);
  await prefs.saveUserMetrics(wizard.toJson());  // ← single save
  await prefs.completeOnboarding(goal: wizard.targetPhysique?.name);
  ...
}
```
No partial-save calls inside `_next()` (line 143–154) or any `_GoalStep`/`_GenderStep` callbacks. Search confirms:
```
grep -n "saveUserMetrics\|completeOnboarding" lib/features/onboarding/
→ only onboarding_screen.dart:177, 178 (within _finish)
→ auth_screen.dart:48 (post-sign-in fallback)
```

The provider state lives in memory only — `wizard_provider.dart`'s `Notifier<WizardState>` does not write through to disk on `update`.

---

### Finding F-17: `/prediction` is a defined route that the onboarding wizard skips; redirect rule still references it
**Severity:** 3/5
**Where:**
- `lib/core/routing/app_router.dart:109–111` (redirect rule references prediction)
- `lib/features/onboarding/presentation/onboarding_screen.dart:210–216` (skips prediction)
- `lib/features/onboarding/presentation/prediction_screen.dart` (route widget)
- atlas §4.4 already calls out the discrepancy

**ERRATA NOTE:** Atlas §4.4 says: "*Route to `/paywall` (NOT `/prediction` — the prediction screen widget exists and the redirect rule references it, but the wizard exit bypasses it; Phase 60C decision documented in code)*". This is accurately described, but the *cost* of the leftover route is undertabulated.

**Observation:** The wizard's `_finish()` calls `context.go(AppRoutes.paywall)` (line 216). Redirect rule 4 (`app_router.dart:109–111`) maps `path == AppRoutes.onboarding` → `AppRoutes.prediction` — this fires only if a user with a non-firstTime + auth-session manually navigates to `/onboarding`, which is not a path any in-app surface produces. So the rule is effectively unreachable from in-app flows.

**Cost:**
- **Zombie code.** `prediction_screen.dart` is a 200+ line widget plus the route + the redirect rule, and zero in-app surfaces reach it. Dead-but-loaded.
- **Dev surprise.** A future PM reading the redirect rules sees `/onboarding` → `/prediction` and may believe the prediction screen is part of the standard flow. The wizard's `_finish` comment (line 210–215) explains the bypass — but the route + redirect should have been removed if Phase 60C truly killed the screen, not left as a vestigial path.

**Evidence:**
```dart
// onboarding_screen.dart:210–216
// Phase 60C · the dynamic report screen is now the on-wizard hook
// that the prediction screen used to be, so the wizard exits
// straight to /paywall instead of stopping over at /prediction.
// Anonymous users are allowed at /paywall (the redirect rule only
// bounces *registered* users away from /auth back to it), so this
// is safe without any router change.
context.go(AppRoutes.paywall);
```
```dart
// app_router.dart:109–111
if (path == AppRoutes.onboarding) {
  return AppRoutes.prediction;
}
```

A grep for `context.push(AppRoutes.prediction)` and `context.go(AppRoutes.prediction)`:
```
grep -rn "AppRoutes.prediction" lib/
→ lib/core/routing/app_router.dart:36 (declaration)
→ lib/core/routing/app_router.dart:110 (redirect rule)
→ lib/core/routing/app_router.dart:182 (route registration)
```
No producer surfaces. Confirmed orphan.

---

### Finding F-04: Anonymous user can complete onboarding and reach paywall, then is force-gated by an undismissible auth modal
**Severity:** 5/5
**Where:** `lib/features/monetization/presentation/paywall_screen.dart:182–214`; `lib/features/auth/presentation/auth_modal_bottom_sheet.dart:67–69` (PopScope canPop:false); atlas §6.7 Phase 94 forced auth gate
**Observation:** The Phase 94 forced-auth gate is structurally sound (it prevents anonymous purchases from being orphaned post-sign-in; documented in `auth_modal_bottom_sheet.dart:11–55`). But from the user's perspective:
1. Onboarding `_finish()` calls `signInAnonymously()` and routes to `/paywall` (`onboarding_screen.dart:193, 216`).
2. Paywall mounts; `_onAuthStateChanged` fires immediately (paywall_screen.dart:213–214); detects `user.isAnonymous == true`; sets `_authGateShown = true`; schedules `showAuthGate(context)` post-frame.
3. The auth modal slides up over the bottom 50% of the paywall. `PopScope(canPop: false)` (line 67) and `barrierDismissible: false` (line 61) make the modal impossible to dismiss by gesture, system back, or tap-outside.

The only escape paths:
- (a) Successful Google or Apple OAuth (`auth_modal_bottom_sheet.dart:444–451`)
- (b) Tap "E-posta ile Giriş Sayfasına Git" → routes to `/auth` (line 468–471)

**Cost:**
- **No graceful degradation for OAuth failures.** If Google Sign-In fails (e.g., GOOGLE_WEB_CLIENT_ID misconfigured per `auth_provider.dart:84–85`), Apple Sign-In fails, AND the device is offline (network checked pre-OAuth at line 435), the user is stuck looking at the modal with no buttons that work. The connectivity check shows a toast but does not dismiss the modal. There is no "skip for now" or "try again later" path.
- **Coupling between paywall view and auth.** A user who simply wants to *see* the paywall (say, a user who reached it via the Profile tab "FormAI Premium" tile while signed-in-but-anonymous) cannot. The first frame of paywall mount triggers the gate.
- **Cold-start race.** If `auth_state` stream re-emits anonymous mid-OAuth-flow, the latch (`_authGateShown`) prevents re-trigger, but the OAuth flow itself can race the `signInAnonymously()` from onboarding's `_finish()`. The 600 ms post-purchase delay (atlas §6.6) is a separate timing safeguard for purchase, not for this.
- **No way back to dashboard.** The user can't decide "actually I want to think about this and explore the app more" without first signing in. The paywall close X (top-right) is behind the blur layer (atlas §6.7) and is unreachable while the modal is up.

**Evidence:**
```dart
// auth_modal_bottom_sheet.dart:57–78
Future<void> showAuthGate(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,                  // tap-outside disabled
      barrierColor: Colors.transparent,
      ...
      pageBuilder: (context, animation, secondaryAnimation) {
        return PopScope(
          canPop: false,                          // back gesture disabled
          child: _AuthGateScaffold(animation: animation),
        );
      },
      ...
    ),
  );
}
```
```dart
// paywall_screen.dart:182–191
void _onAuthStateChanged(User? previous, User? next) {
  if (_authGateShown) return;
  final needsAuth = next == null || next.isAnonymous;
  if (!needsAuth) return;
  _authGateShown = true;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    showAuthGate(context);
  });
}
```

The atlas calls this Phase 94 work and the developer-facing rationale is sound. The cost surfaced here is the user experience side — there is no escape valve for a user whose OAuth is broken or who simply wants to back out. The Navigation Friction Report (separate file) covers this with more detail.

---

## 9. CROSS-CUTTING IA OBSERVATIONS

### Finding F-11: Plan-detail screen renders two distinct visual treatments under one route
**Severity:** 3/5
**Where:** `lib/features/workout/presentation/plan_detail_screen.dart:138–148, 887–928`
**Observation:** The route `/plan-detail` accepts an optional `WorkoutPlan` via `state.extra`. If non-null, the screen renders the regional plan hero + exercise list + "PLANI BAŞLAT" / "PRO İLE KİLİDİ AÇ" CTA. If null (the dashboard's daily-challenge hero card pushes here without extra), the screen renders the legacy 30-day program view with `_DayTile` rows and the `_freeDayLimit` Pro gate.

**Cost:**
- One route, two screens — cognitive overload for devs and analysts. Users see the same URL with very different chrome based on entry point.
- The branching is documented in code (atlas §6.4 also references it) but the user has no signal that there are "two modes" of plan-detail; tapping the dashboard challenge card produces "30 gün kaldı" UI; tapping a regional card produces a fixed-length plan with hero image. They are functionally separate features sharing a route.

**Evidence:**
```dart
// plan_detail_screen.dart:138–148
/// Two faces:
///   • [plan] non-null  → renders that plan's hero + exercise list.
///   • [plan] null      → renders the legacy 30-day program view (the
///                        dashboard's "Günlük Meydan Okuma" hero card
///                        opens this mode).
class PlanDetailScreen extends ConsumerStatefulWidget {
  const PlanDetailScreen({super.key, this.plan});
  final WorkoutPlan? plan;
  ...
}
```

---

### Finding F-14: Badge celebrations only fire on Gelişim tab — no in-app cue that celebrations are pending elsewhere
**Severity:** 3/5
**Where:** `lib/features/home/presentation/dashboard_screen.dart:136–174` (`_maybeCelebrate`); atlas §3.4 + §5.9
**Observation:** Phase 57 work (atlas §5.4) deliberately gates badge unlock dialogs to fire only when the user is on the Gelişim tab AND dashboard is the topmost route. Off-tab unlocks are queued in `unlockedBadgesProvider \ celebratedBadgesProvider`. There is no badge dot, no animated bottom-nav icon, no in-tab toast indicating that pending celebrations exist.
**Cost:**
- Users on Antrenman tab who unlock a badge mid-workout (e.g., "İlk 7 Gün") get no feedback at all. They must navigate to Gelişim to see it.
- Reduces the dopamine loop — celebrations work best in temporal proximity to the unlocking action.

**Evidence:**
```dart
// dashboard_screen.dart:136–146
Future<void> _maybeCelebrate() async {
  if (!mounted || !_routeIsCurrent || _celebrating) return;
  // Phase 57 · the PM specifically asked that badge unlocks ONLY
  // surface on the Gelişim (progress) tab.
  if (_index != _gelisimTabIndex) return;
  ...
}
```
The `_BottomNav` widget at line 206–271 has no badge-pending visual on the Gelişim icon.

---

### Finding F-21: "PRO" badge on Antrenman header opens paywall — equivalent to a 7th paywall surface but discoverable only by curiosity
**Severity:** 2/5
**Where:** `lib/features/home/presentation/widgets/antrenman_tab.dart:548–587`
**Observation:** The "PRO" pill is a 60×24 px purple-bordered button with a crown icon, top-right of the Antrenman header. There is no caption. A user reading "PRO" in a fitness app might assume it's a status indicator ("you have Pro") rather than a CTA ("upgrade to Pro"). Tapping opens the paywall.
**Cost:**
- Mis-affordance: looks like a static badge, behaves like a button.
- Pro users (who already have entitlement) tapping it land on a paywall they can't purchase from again — disorienting "I already have this" state.

**Evidence:**
```dart
// antrenman_tab.dart:550–586
class _ProButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      child: InkWell(
        onTap: () => context.push(AppRoutes.paywall),
        ...
        child: const Row(
          ...
          children: [
            Icon(Icons.workspace_premium, color: Colors.white, size: 14),
            SizedBox(width: 4),
            Text('PRO', ...),
          ],
        ),
      ),
    );
  }
}
```
No conditional render based on `isProProvider`. No "ÜYE OL" or "PRO YAPI" copy that would clarify it's an upsell.

---

### Finding F-22: "Düzenle" button at line 116–135 of Profile is redundant with each per-tile tap action
**Severity:** 2/5
**Where:** `lib/features/home/presentation/widgets/profile_tab.dart:79–89, 96–101, 108–112, 116–135`
**Observation:** Profile's BİLGİLERİM section renders 4 InfoTiles (YAŞ, KİLO, BOY, HEDEF), each with `onTap: () => _openEditSheet(metrics)` (lines 79, 88, 100, 110). Then immediately below is a full-width FilledButton "Düzenle" with the same `onTap` (line 119: `_openEditSheet(metrics)`).
**Cost:**
- 5 affordances opening the same sheet. UI lint.
- The "Düzenle" button increases the section height by ~70 px, pushing the next section (İLERLEME) further down.

**Evidence:** see file lines 79, 88, 100, 110, 119 — 5 `_openEditSheet` calls inside the same section.

---

### Finding F-23: "Bir Davet Kodu Kullan" tile is an unmarked degraded-path counterpart to the deep-link flow
**Severity:** 2/5
**Where:** `lib/features/home/presentation/widgets/profile_tab.dart:233–239`
**Observation:** The referral happy-path is: friend shares deep link → tap → app opens to `/referral?code=XXXX` → auto-redeem (atlas §9.4). The fallback for "deep link didn't work" is a Profile-tab tile labeled "Bir Davet Kodu Kullan" at line 233–239, which opens a manual code entry dialog. The code comment at line 225–232 explains:
> *"Even with deep links wired through Android intent-filters + iOS CFBundleURLTypes, a share that lands as plain text in WhatsApp / Instagram DM doesn't always auto-linkify (older clients, copied screenshots, etc.) — so a typed 'Bir Davet Kodu Kullan' tile is the safety net the PM asked for."*

**Cost:**
- A user without a working deep link must intuit "I have a code to redeem, where do I enter it?" The Profile tab is not the obvious answer (referral landing screen would be, but it requires the code in URL).
- The Profile tab is two tabs deep (Antrenman → Beslenme → Gelişim → Profil) for a user opening the app fresh.

**Evidence:** The line comment explicitly admits this is a workaround for broken deep-link auto-linkify.

---

### Finding F-24: "Şampiyon serisi devam ediyor!" copy fires for any streak ≥ 7
**Severity:** 2/5
**Where:** `lib/features/home/presentation/widgets/gelisim_tab.dart:1613–1621`
**Observation:** The AI Coach copy branches:
- streak ≥ 7 → "Şampiyon serisi devam ediyor! Böyle kal."
- streak == 0 AND maxStreak > 0 → "Geri dönüş zamanı. 10 dakika yeterli."
- otherwise → "Bugün hedeflerimize bir adım daha yaklaşıyoruz."

A user with a 7-day streak and a user with a 30-day streak see identical copy.

**Cost:**
- Personalization-illusion failure. Users learn that "Şampiyon serisi" is the canonical "you're doing great" line and stops feeling personalized after the first time it surfaces (e.g., day 7 vs day 14).
- Wasted opportunity: by Day 25 of a 30-day program, a user near the finish should be addressed differently from a user who just hit a 7-day milestone.

**Evidence:**
```dart
// gelisim_tab.dart:1613–1621
String _copyFor({required int streak, required int maxStreak}) {
  if (streak >= 7) {
    return 'Şampiyon serisi devam ediyor! Böyle kal.';
  }
  if (streak == 0 && maxStreak > 0) {
    return 'Geri dönüş zamanı. 10 dakika yeterli.';
  }
  return 'Bugün hedeflerimize bir adım daha yaklaşıyoruz.';
}
```

---

## 10. STRUCTURAL OBSERVATIONS — IA SUMMARY

### Tab IA
- **Tab assignment is clear in label, blurry in delivery.** Atlas §3.4 conveys 4 distinct labels; in practice, Antrenman + Gelişim share workout entry, Profil absorbs all settings.
- **Default tab on cold launch is Antrenman** (`dashboard_screen.dart:37 _index = 0`). For a returning user whose primary need is "complete today's workout," Gelişim's Today Task Card is more useful than Antrenman's Challenge Hero — but the user lands on Antrenman.
- **Tab state preservation is via `IndexedStack`** (line 119–126), which preserves widget state per tab — but **does not preserve scroll position within a deeply pushed sub-route** (e.g., a recipe detail page pushed from Beslenme is not saved across tab switches; tapping back reloads). See Navigation Friction Report.

### Feature discoverability
- **`/progress/suggestions` and `/progress/calendar` and `/progress/badges` are each reachable from one in-app surface only** — all three are buried inside the Gelişim tab body.
- **`/nutrition/discover` and `/nutrition/favorites` similarly each have one entry point.**
- **Paywall is reachable from 8 entry points** — over-indexed compared to the 18 named routes total. Roughly 1 in 2 routes leads, somehow, to the paywall.

### Cognitive overload
- **9 sections on Gelişim** (atlas §5.2 explicitly counts), with primary CTA at ~430 px.
- **8 sections on Profile** with highest-frequency setting (theme, notifications) buried mid-list.
- **Onboarding is 12 + 7 = 19 screens** (atlas §4.6) — 7 of those are post-paywall, surprise-modal triggered by Beslenme tab tap.

### IA inconsistencies
- **Streak rendered 4 ways**, computed by 2 duplicate helpers.
- **Same-route, two-faces pattern** at `/plan-detail` (regional vs 30-day).
- **Empty/loading state UI inconsistent** between Antrenman (spinner) and Gelişim (skeleton).
- **Paywall hooks in 8 places**, none with consistent visual chrome.

### Dead-ends
- `_MissingRecipe`, `_MissingReferralCode` → "back to dashboard" only.
- Forced-auth gate on paywall → no escape valve if OAuth fails.
- Workout camera screen → no tab nav, only back button (and `_exit` which falls through to dashboard).

### Onboarding
- **No autosave** between steps (atlas §4.6 calls out, this report quantifies the cost as severity-5).
- **`/prediction` is an orphan route** — defined, redirect-referenced, never reached from in-app surfaces (atlas §4.4 ERRATA correctly notes the discrepancy).
- **Deferred nutrition onboarding is a 7-step undismissible modal** that fires on first Beslenme-tab visit, weeks after the user thinks onboarding is done.

---

## 11. ERRATA AGAINST THE PHASE 1 ATLAS

The atlas is largely accurate. Two extensions/corrections surfaced during this analysis:

1. **Atlas §4.4 / §3.2** describe the `/prediction` route discrepancy correctly. **This report extends:** the redirect rule (`app_router.dart:109–111`) is *unreachable from any in-app surface* because no producer pushes `/onboarding` after `prefs.isFirstTime == false`. The route is fully orphaned, not just "bypassed by current exit." Sev-3 finding F-17.

2. **Atlas §5.7** lists 4 quick-start CTAs (Antrenman Challenge, Gelişim Today Task, Equipment cards, Regional plans). **This report extends:** the Antrenman header `_ProButton` (line 547–587) is a fifth paywall-surfacing CTA that the atlas §6.3 paywall trigger table also enumerates separately — so the cross-tab consistency map is incomplete in §5.7. The "PRO" pill behaves like a Quick-Start surface but is actually a 7th paywall trigger.

3. **Atlas §5.6** says "Display surfaces: Antrenman header flame badge + Gelişim streak card (5-dot checklist)." **This report extends:** there are at least 4 streak surfaces, not 2 (also Gelişim top header pill and Profile stats tile — see F-07). The atlas count is conservative.

No other errata. The atlas's structural facts are otherwise corroborated by direct file inspection.

---

## 12. APPENDIX — EVIDENCE INDEX

| Finding | Primary file:line | Atlas §ref |
|---|---|---|
| F-01 | `antrenman_tab.dart:171–177`, `today_task_card.dart:96` | §5.7 |
| F-02 | `today_task_card.dart:104–108`, `plan_detail_screen.dart:280–314` | §5.9, §6.4 |
| F-03 | `onboarding_screen.dart:165–217` | §4.6 |
| F-04 | `paywall_screen.dart:182–214`, `auth_modal_bottom_sheet.dart:67–69` | §6.7 |
| F-05 | `gelisim_tab.dart:149–206` | §5.2, §5.3 |
| F-06 | `gelisim_tab.dart:1605` | §3.1 |
| F-07 | `antrenman_tab.dart:200–210`, `gelisim_tab.dart:211–220` | §5.6 |
| F-08 | `profile_tab.dart:65–500` | §13 |
| F-09 | `dashboard_screen.dart:184–202`, `nutrition_onboarding_sheet.dart:52–62` | §4.3 |
| F-10 | `dashboard_screen.dart:248–251`, `today_task_card.dart:323` | §3.4, §5.7 |
| F-11 | `plan_detail_screen.dart:138–148, 887–928` | §6.4 |
| F-12 | `gelisim_tab.dart:170–177`, `antrenman_tab.dart:110–112` | §5.5 |
| F-13 | `deep_link_service.dart:96–106`, `app_router.dart:78–126` | §3.3, §5.8 |
| F-14 | `dashboard_screen.dart:136–174` | §3.4, §5.9 |
| F-15 | `antrenman_tab.dart:547–587`, `profile_tab.dart:262–267` | §6.3 |
| F-16 | `nutrition_tab.dart:293`, `profile_tab.dart:247–253`, `discover_recipes_screen.dart` | §9.2 |
| F-17 | `app_router.dart:109–111`, `onboarding_screen.dart:210–216` | §4.4 (ERRATA) |
| F-18 | `app_router.dart:357–429` | §3.3 |
| F-19 | `workout_camera_screen.dart:962–973` | §8 |
| F-20 | `profile_tab.dart:65–500` | §13 |
| F-21 | `antrenman_tab.dart:548–587` | §5.7, §6.3 |
| F-22 | `profile_tab.dart:79–135` | §9 |
| F-23 | `profile_tab.dart:233–239` | §9.4 |
| F-24 | `gelisim_tab.dart:1613–1621` | §5.2 |

---

**END OF PRODUCT_STRUCTURE_REPORT.md**
