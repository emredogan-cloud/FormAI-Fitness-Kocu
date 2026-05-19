# VISUAL UI REPORT

**Phase 2 — Product Analysis**
**Project:** SixPack AI / FormAI Fit
**Generated:** 2026-05-08
**Scope:** Visual sophistication audit. Severity-scored findings with file:line evidence. No recommendations — Phase 5 produces those.

---

## 0. EXECUTIVE SUMMARY (severity-sorted)

| ID | Severity | Title |
|---|---|---|
| V-01 | 5/5 | Two different brand "neon purples" ship side-by-side; Gelişim/Today-Task paint #8B5CF6 while Antrenman/Paywall paint #8E5BFF |
| V-02 | 5/5 | No central typography scale — 31 distinct fontSize values across 509 inline TextStyle declarations |
| V-03 | 5/5 | Auth screen primary color is cyber-cyan (#00F0FF), not brand purple — brand-color flicker on the user's first-login path |
| V-04 | 5/5 | Gelişim primary CTA "ANTRENMANA BAŞLA" lands roughly 470–520 px below scaffold top, below the iPhone-SE fold; CTA copy is fontSize 13 — smaller than body text |
| V-05 | 5/5 | Light-mode parity broken: 195 hardcoded `Colors.white54/38/24/12/70/60` patterns across the codebase plus 7 hardcoded `Colors.black` Scaffolds |
| V-06 | 4/5 | Gender-other paywall hero is a generic Material `Icons.accessibility_new` glyph, while M/F users see a 1024×1359 photo composite |
| V-07 | 4/5 | Four different primary-CTA implementations with four different type treatments across onboarding, auth, dashboard, paywall |
| V-08 | 4/5 | Three different section-header styles across the four dashboard tabs (Antrenman 20px mixed-case, Nutrition 18px mixed-case, Gelişim 11px ALL-CAPS, Profile 11px ALL-CAPS w/ different letter-spacing) |
| V-09 | 4/5 | `_SoftCard` class is duplicated across `gelisim_tab.dart` and `today_task_card.dart` with divergent light-mode behavior |
| V-10 | 4/5 | Inline trial-badge copy on paywall yearly card renders at fontSize 9.5 + fontSize 8.5 — borderline accessibility |
| V-11 | 4/5 | Gender option asset asymmetry: Erkek/Kadın are 1024×1359 photos; "Diğer" is a 1024×683 placeholder ¼ the file size |
| V-12 | 4/5 | Welcome → Auth screen color register flips from purple background gradient to all-black scaffold with cyber-cyan primary — visual whiplash |
| V-13 | 3/5 | Day-grid Pulsing Current Cell text is hardcoded `Colors.white` on a 0.18-alpha purple wash; in light mode the text contrast collapses |
| V-14 | 3/5 | `AppColors.neonAccent` token has zero call-sites in the entire codebase — 38 hex literals of `#4DA6FF` instead |
| V-15 | 3/5 | `AppColors.orangeOnLight` (Phase 53 WCAG-AA fix token) has zero call-sites; the failing `#F97316` orange still ships in light mode |
| V-16 | 3/5 | "ANTRENMANA BAŞLA" CTA text has lower information density and smaller size than the metadata above it ("Gün N – Focus" at fontSize 17 vs CTA at fontSize 13) |
| V-17 | 3/5 | 9 stacked sections on Gelişim with 4 different gap values (12/14/22/24px) and no visible grid system |
| V-18 | 3/5 | Day-0 empty state shows 0 progress, 0/30 days, 0 streak, 5 empty dots, 30 locked grid cells — all zero, no forward-looking copy |
| V-19 | 3/5 | Coach-intro typewriter blocks the CTA for ~3.92 s; analysis-illusion pages adds another ~7.2 s of fake AI thinking — 11 s total of forced waiting on first launch |
| V-20 | 3/5 | Macro fat color is bright phosphor yellow `#EAFF00` — invisible-low-contrast against light scaffold even at 14% alpha background |
| V-21 | 2/5 | 31 surface tone hex literals (e.g. `0xFF14141B`, `0xFF111118`, `0xFF0F0F14`, `0xFF141028`) used as ad-hoc card backgrounds |
| V-22 | 2/5 | `Material Icons exclusively` claim contradicted by emoji icon system on badges and recipe tags |
| V-23 | 2/5 | Coach avatar pulse (2400 ms breathing) competes for attention with current-day pulsing-cell glow (1400 ms) and CTA shadow pulse |
| V-24 | 2/5 | Section-pill label uses hardcoded `Colors.white` on 10%-neon background (gelisim_tab.dart:886) — invisible in light mode |

**Token-compliance ratio:** 88 `AppColors.*` references vs 158+ matching hex literals → **~36 % adoption** of the palette tokens that were created in Phase 48 specifically to end this drift.

**Typography compliance:** 1 use of `Theme.of(context).textTheme` vs 509 inline `TextStyle(...)` → **Material 3's type system is essentially unused.**

---

## 1. TYPOGRAPHY HIERARCHY

### Finding V-02: No central typography scale exists; 31 distinct fontSize values ship across the app
**Severity:** 5/5
**Where:** `lib/core/theme/app_theme.dart:23–73` (no `textTheme:` override); `lib/core/theme/theme_extension.dart:27` exposes `textStyles` accessor that almost no widget reads. App-wide grep finds:
**Observation:** Frequency table of every `fontSize:` literal in `lib/`:

```
67  fontSize: 13
66  fontSize: 12
53  fontSize: 11
49  fontSize: 14
23  fontSize: 15
22  fontSize: 10
21  fontSize: 18
16  fontSize: 12.5
13  fontSize: 22, 13  fontSize: 17, 13  fontSize: 16
8   fontSize: 28
7   fontSize: 26, 7  fontSize: 20
6   fontSize: 9
5   fontSize: 32, 5  fontSize: 13.5
4   fontSize: 9.5, 4  fontSize: 36, 4  fontSize: 24, 4  fontSize: 10.5
3   fontSize: 56, 3  fontSize: 30
2   fontSize: 8.5, 2  fontSize: 34
1   each: 7, 38, 40, 64, 72, 240
```

That's **31 distinct values** — half-points (8.5, 9.5, 10.5, 12.5, 13.5) included, suggesting per-screen tweaks rather than a system. Material 3's seeded `TextTheme` provides 15 named slots (`displayLarge → labelSmall`); only 1 widget in the entire app reads any of them (`app_router.dart:377` reads `titleLarge` for an error route).
**Perceptual cost:** No reading rhythm. A user moving between two surfaces sees the body text at 13pt on Antrenman, 13pt on Today Task subtitle, 12.5pt on Plan tile summary, 14pt on Auth body, 13pt on Welcome subtitle — five "body" sizes within four taps. Headlines suffer worse: Welcome 32, Paywall 26, Gelişim 26 (header) and 34 (program %), Recipe 28, Today Task 17, Antrenman section title 20, Nutrition section 18. There is no "headline tier", just one-off decisions. The brain pattern-matches premium products by recognizing a coherent type rhythm; this codebase actively breaks that pattern-match.
**Evidence:** `gelisim_tab.dart` alone contains 25 inline `TextStyle` declarations with fontSize ∈ {8.5, 9.5, 10, 10.5, 11, 12, 12.5, 13, 15, 17, 22, 26, 34} — 13 distinct sizes inside one tab.

### Finding V-08: Three different section-header type treatments across four dashboard tabs
**Severity:** 4/5
**Where:** Atlas §5 lists the tabs; per-file inspection:
- `antrenman_tab.dart:638–668` — `_SectionTitle`: fontSize 20, fw900, letterSpacing 0.3, **mixed case** ("Bölgeler", "Ekipmanlı Egzersizler")
- `nutrition_tab.dart:1048–1066` — `_SectionTitle`: fontSize 18, fw900, letterSpacing 0.3, **mixed case** ("Günün Menüsü")
- `gelisim_tab.dart:2221–2238` — `_SectionLabel`: fontSize 11, letterSpacing 2.6, fw800, **ALL CAPS** ("ROZETLERİN")
- `profile_tab.dart:902–921` — `_SettingsHeader`: fontSize 11, letterSpacing 3, fw800, **ALL CAPS** ("BİLGİLERİM")
**Observation:** The four primary tabs use four different section-header styles. Antrenman and Nutrition use a 18–20pt mixed-case header; Gelişim and Profile use an 11pt all-caps eyebrow. The two "all-caps" headers don't even share their letter-spacing (2.6 vs 3.0).
**Perceptual cost:** A user swiping through the four tabs sees four different "section" treatments — the visual grammar resets every time. Premium apps signal hierarchy with one consistent grammar; here the hierarchy itself is the variable.
**Evidence:** Per file:
```dart
// antrenman_tab.dart:654
fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 0.3
// nutrition_tab.dart:1060
fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.3
// gelisim_tab.dart:2233
fontSize: 11, letterSpacing: 2.6, fontWeight: FontWeight.w800
// profile_tab.dart:915
fontSize: 11, letterSpacing: 3, fontWeight: FontWeight.w800
```

### Finding V-10: Paywall trial-badge text at fontSize 9.5 / 8.5 borders accessibility violation
**Severity:** 4/5
**Where:** `lib/features/monetization/presentation/paywall_screen.dart:1402–1426` — the inline trial badge inside the highlighted yearly `_PlanCard`:
```dart
Text('7 gün ücretsiz dene', style: TextStyle(... fontSize: 9.5 ...))
Text('şimdi ödeme yok',     style: TextStyle(... fontSize: 8.5 ...))
```
**Observation:** Two-line trial badge at fontSize 9.5 + 8.5 inside a 230×~80 px card. WCAG recommends >12 px / 9pt for body copy; iOS HIG bottom-bound is 11pt. This badge is below both. The legal footer (line 1538) sits at 10.5 — also small, but at least readable.
**Perceptual cost:** The trial offer is the entire monetization-conversion lever ("free for 7 days") — but it ships at the smallest type in the screen. The user with normal vision can squint and read it; the user with the OS scaler bumped one notch sees it overflow the badge.
**Evidence:** The card itself is auto-sized to 220 px tall (line 1216), fitting label-13pt + price-22pt + per-11pt + decoy-11pt + trial-9.5+8.5 + radio-22 — the trial copy was forced small to fit.

---

## 2. SPACING RHYTHM

### Finding V-17: 9 stacked sections on Gelişim use 4 different gap values; spacing is ad-hoc, not a system
**Severity:** 3/5
**Where:** `lib/features/home/presentation/widgets/gelisim_tab.dart:151–204`. The exact spacing sequence:
```
ListView padding: fromLTRB(20, 16, 20, 40)
TopHeader → 22 → ProgramStats → 14 → Today Task → 24 → DayGrid → 24 → Stats → 22 → Retrospective → (none) → AI Coach → 22 → Badges
```
**Observation:** Six `SizedBox(height: …)` separators with values 22, 14, 24, 24, 22, 22. Not 8/16/24/32 (8pt grid), not 4/8/12/16 (4pt grid). Plus the `_ProgramStatsColumn` has its own internal `SizedBox(height: 12)` (line 534) between the two stat cards — a fifth value. Atlas §7.3 documents `12/14/16/18–20 standard, 24 px full-screen centering` — this section uses 12, 14, 22, 24 and the canonical 16/20 are absent.
**Perceptual cost:** The eye can't entrain a rhythm. When sections breathe at 22 px, then 14 px, then 24 px, the brain reads "tightening" or "opening" as a signal. Here the variation is noise — there's no semantic story. Premium IA uses one ratio (e.g. golden-ratio 21/34 or musical 8/12/24); the dashboard is using whatever fit when each section was added.
**Evidence:** Line-by-line audit of separator widths in gelisim_tab.dart §1 (executive build method).

### Finding V-21: 31 surface-tone hex literals scattered as ad-hoc card backgrounds
**Severity:** 2/5
**Where:** All 31 occurrences of variant surface hex literals across `lib/`:
- `0xFF0F0F14` (the canonical card surface) — 6 uses
- `0xFF1E1E26` (canonical surface border) — 6 uses
- `0xFF111118` (`weekly_goal_card.dart:7`) — 1
- `0xFF14141B` (snackbar bg, app_theme.dart:78) — 1
- `0xFF1A0B3D` (paywall hero bg) — 8
- `0xFF221145`, `0xFF0D0622` (branded_media_fallback) — 4 each
- `0xFF1E0A40`, `0xFF0A0612` (gelisim radial halo) — 5 each
- `0xFF141028` (prediction screen) — 1
- `0xFF0E0729` (coach intro) — 2
**Observation:** AppColors.surface is `0xFF0F0F14`, AppColors.surfaceBorder is `0xFF1E1E26`. But every immersive surface (paywall, prediction, coach intro, gelisim halo, weekly-goal card) defines its own dark tone. There are at least 8 distinct "near-black surface" values in the codebase. Most lean violet-tinted, but they're not the same violet.
**Perceptual cost:** The "moody dark" feel reads as coherent at first glance, but a sharp eye sees that the welcome bg, prediction bg, paywall bg, and gelisim halo are slightly different dark purples. Premium products pick one near-black per surface tier and stick to it. This codebase has gradient bg fragments living wherever they were first painted.

---

## 3. COLOR USAGE & PSYCHOLOGY

### Finding V-01: Two different brand "neon purples" ship in production code
**Severity:** 5/5
**Where:**
- `lib/core/theme/app_colors.dart:23` — `static const Color neon = Color(0xFF8E5BFF);` (the spec'd brand purple)
- `lib/features/home/presentation/widgets/gelisim_tab.dart:27` — `const Color _neon = Color(0xFF8B5CF6);` (Tailwind violet-500 — a different hue)
- `lib/features/home/presentation/widgets/today_task_card.dart:10` — `const Color _neon = Color(0xFF8B5CF6);` (same wrong purple)
- `lib/features/progress/presentation/calendar_screen.dart:8`, `suggestions_screen.dart:12`, `badges_screen.dart:10` — all `0xFF8B5CF6`
- 38 occurrences of correct `0xFF8E5BFF` vs 5 occurrences of wrong `0xFF8B5CF6`

The **AppColors.dart docstring itself flags this** (lines 7–10): "Every feature surface defined its own `_neon`, `_neonAccent`, `_success`, `_danger`, etc. as private file-level constants. The values agreed in spirit but disagreed in detail (e.g. one screen shipped `0xFF8E5BFF`, another shipped `0xFF8B5CF6` — both labelled 'neon'). Centralising the palette here lets a future redesign edit a single literal instead of grepping the codebase."

The drift was acknowledged in Phase 48 and never closed. **The most-trafficked dashboard surfaces (Gelişim, Today Task, Calendar, Badges, Suggestions) are still painting the wrong purple.**
**Observation:** `#8E5BFF` is RGB(142, 91, 255). `#8B5CF6` is RGB(139, 92, 246). Side-by-side they read as the "same" purple to most users — but the brand-recognition cue is degraded. Worse, the wrong purple is on the screens the user spends most time on (Gelişim, Today Task), while the correct purple is on the screens they touch briefly (paywall, antrenman header).
**Perceptual cost:** Subconscious brand inconsistency. Premium products are obsessive about *one* primary hue. When the same "FormAI purple" shifts ~3% as the user navigates Antrenman→Gelişim, the brain registers it as imprecision even if it can't name what's wrong. This is the single most damaging finding for premium perception.
**Evidence:**
```bash
$ grep -rn "Color(0xFF8B5CF6)" lib/
lib/features/progress/presentation/calendar_screen.dart:8:const Color _neon = Color(0xFF8B5CF6);
lib/features/progress/presentation/suggestions_screen.dart:12:const Color _neon = Color(0xFF8B5CF6);
lib/features/progress/presentation/badges_screen.dart:10:const Color _neon = Color(0xFF8B5CF6);
lib/features/home/presentation/widgets/today_task_card.dart:10:const Color _neon = Color(0xFF8B5CF6);
lib/features/home/presentation/widgets/gelisim_tab.dart:27:const Color _neon = Color(0xFF8B5CF6);
```

### Finding V-03: Auth screen primary brand color is cyber-cyan, not brand purple
**Severity:** 5/5
**Where:** `lib/features/auth/presentation/auth_screen.dart:24`
```dart
class _AuthScreenState extends ConsumerState<AuthScreen> {
  static const Color _neon = Color(0xFF00F0FF);  // ← cyber cyan!
```
**Observation:** The auth screen — the only surface between onboarding-finish and paywall — re-defines its own `_neon` constant as `cyberCyan` (#00F0FF) per atlas §7.1. The auth screen "GİRİŞ YAP / KAYIT OL" `FilledButton` (line 248) uses `backgroundColor: _neon` (cyan) with `foregroundColor: Colors.black`. The "Misafir Olarak Devam Et" outline button border, the divider neon hairline, and the neon link copy all paint cyan.
**Perceptual cost:** The brand register flips mid-flow. The user finishes onboarding (purple #8E5BFF) → arrives at auth (cyan #00F0FF) → arrives at paywall (purple #8E5BFF) → arrives at dashboard Antrenman (purple #8E5BFF) → swipes to Gelişim (different purple #8B5CF6) → opens Workout Camera (cyan again #00F0FF). Within 60 seconds the user has seen the "primary brand color" change at least 3 times. Cyber-cyan is documented in atlas §7.1 as **intentionally distinct for the camera surface to read as "live/active"** — but it has bled into auth and degrades the brand cohesion at a critical conversion point.
**Evidence:** Line 24 + downstream uses on lines 251, 283, 295, 298, 461, 564, 583.

### Finding V-14: `AppColors.neonAccent` token has zero call-sites
**Severity:** 3/5
**Where:** `lib/core/theme/app_colors.dart:27` defines it; codebase search:
```bash
$ grep -rn "AppColors\.neonAccent" lib/
(zero matches)
$ grep -rn "Color(0xFF4DA6FF)" lib/ | wc -l
38
```
**Observation:** The blue-violet `#4DA6FF` (the secondary brand color, used as gradient pair, badge halos, macro protein bar) is referenced 38 times — every one as a hex literal. The `AppColors.neonAccent` token is dead.
**Perceptual cost:** Behavior signal of the codebase: the central palette doesn't actually own the brand. Adding a new feature is faster by copy-pasting the hex than by importing AppColors, so the team does it that way. Future "swap the secondary blue" requires 38 edits, not 1. Premium engineering organizations have one source of truth for color; here, AppColors is decorative.

### Finding V-15: `AppColors.orangeOnLight` (Phase 53 WCAG-AA fix) has zero call-sites; the failing `#F97316` still ships in light mode
**Severity:** 3/5
**Where:** `lib/core/theme/app_colors.dart:60–66` — the token itself + its docstring explaining the WCAG audit:
```dart
/// Phase 53 accessibility tweak. `Color(0xFFB45309)` (Tailwind
/// orange-700) clears 4.74:1 against pure white and 4.55:1 against
/// our [lightSurface] — a contrast-passing alternative for warning
/// text in light mode.
static const Color orangeOnLight = Color(0xFFB45309);
```
Codebase search:
```
$ grep -rn "AppColors\.orangeOnLight" lib/
(zero matches)
```
**Observation:** The WCAG-AA fix was added in Phase 53 and never adopted. Meanwhile `#F97316` orange is used 7 times in `gelisim_tab.dart` alone (streak pill border, kcal card accent, flame puck). On light mode, all of these fail 4.5:1 contrast.
**Perceptual cost:** The atlas claims WCAG AA compliance for light mode. The compliance-fix token exists, has a docstring explaining its purpose, and ships zero usages. This is "compliance theater" — the documentation states the right thing, the implementation hasn't followed through.

### Finding V-20: Macro fat color is bright phosphor yellow #EAFF00 with low contrast on light scaffold
**Severity:** 3/5
**Where:** `lib/features/nutrition/presentation/nutrition_tab.dart:22, 313–316` — `_fatColor = Color(0xFFEAFF00)` used for the Yağ macro bar (with `LinearProgressIndicator` `backgroundColor: color.withValues(alpha: 0.14)` per `_MacroBar:400`).
**Observation:** Yellow #EAFF00 on white #FFFFFF has contrast ratio ~1.07:1 — fails AA, fails AAA, fails any practical readability check. The Yağ macro fill on light mode is a yellow stripe on a near-yellow translucent background. Even on dark mode, it's bright enough to vibrate against the surface.
**Perceptual cost:** A user trying to read "have I hit my fat target?" can't see the fill. Premium fitness apps use one strong macro color per macro (carbs/protein/fat); the choice of phosphor yellow for fat is a brand-aesthetic choice that breaks function. The `protein` blue and `carbs` pink work; fat is a known weak point.

---

## 4. DASHBOARD VISUAL DENSITY (Gelişim — priority surface)

### Finding V-04: Primary CTA "ANTRENMANA BAŞLA" lands ~470–520 px below scaffold top — below the iPhone-SE fold; CTA copy is fontSize 13
**Severity:** 5/5
**Where:** `lib/features/home/presentation/widgets/gelisim_tab.dart:151–177`, `today_task_card.dart:323–331`. Spacing math (top to CTA):
- ListView top padding: 16
- TopHeader: ~58 px tall (title 26 fw900 height-stack ~31 + subtitle 13 height-stack ~19 + 4 gap = ~54; row height of pill button forces ≥40 → 58)
- SizedBox: 22
- ProgramProgressCard: 16+8+34+4+12+12+7+10+12+16 = ~131 px (label 10 + 8 + value 34 + 4 + meta 12 + 12 + bar 7 + 10 + motivation 12 + padding 16+16)
- SizedBox internal _ProgramStatsColumn: 12
- StreakCard: ~131 px (parallel to progress card)
- SizedBox: 14
- TodayTaskCard padding-top + label (16+14+10) = ~40 px header
- gap 12 + iconbox 52 = 64 px content
- gap 14 → CTA stripe (44 px tall)

Cumulative: 16+58+22+131+12+131+14+40+64+14 = **502 px to the top of the CTA**. CTA itself is ~44 px tall; CTA *label* sits at ~520 px.

iPhone SE 1st-gen viewport: 568 px tall. Subtract status bar (44) + bottom nav (~80) → **444 px usable**. The CTA label is **~76 px below the fold**.
On modern iPhones (~750–800 usable px) the CTA is visible but pushed deep — every user has to scroll to commit to today's workout.
**Observation:** The CTA is also fontSize 13 letterSpacing 1.4 (`today_task_card.dart:329`) — *smaller than the metadata above it*: "Gün N – Focus" sits at fontSize 17 fw900. The single most important action in the app is the smallest type on the card, below 4 stacked content blocks (program %, streak, day metadata) the user must scan past to reach it.
**Perceptual cost:** Two costs compounded. (1) Day-1 user lands on Gelişim, sees stats they haven't earned (0%, 0 streak), has to scroll past zeros to find the "Start" button. Emotional friction. (2) Even a returning user who knows where the button is processes 4 information cards before committing. Choice friction. Premium "next-action" surfaces (Apple Fitness+ "Start", Strava "Start") are top-of-fold within a tap of opening; here it takes 3+ pieces of information consumption first.
**Evidence:** Sequence in build method (line 151–177) + today_task_card.dart's stacked Column (line 40–98) confirms.

### Finding V-16: "ANTRENMANA BAŞLA" CTA is smaller than the descriptive copy above it
**Severity:** 3/5
**Where:** `lib/features/home/presentation/widgets/today_task_card.dart:69–89, 322–333`. The day metadata:
```dart
'Gün ${activeDay.dayNumber} – $focus' → fontSize: 17, FontWeight.w900
'$minutes dk · $level'                → fontSize: 12.5, FontWeight.w600
```
The CTA:
```dart
'ANTRENMANA BAŞLA' → fontSize: 13, FontWeight.w900, letterSpacing: 1.4
```
**Observation:** The action label is smaller than its own descriptor. Standard CTA tier is 14–16 pt. The 13pt all-caps reads as a **secondary action**, not the day's hero verb.
**Perceptual cost:** Subconscious de-prioritization. The eye groups the 17pt "Gün N – Focus" as the page anchor and the 13pt CTA as ancillary chrome. This contradicts the actual hierarchy (the CTA is the only thing the user is supposed to do).
**Evidence:** Above.

### Finding V-13: Day-grid Pulsing Current Cell text is hardcoded `Colors.white`; light-mode contrast collapses
**Severity:** 3/5
**Where:** `lib/features/home/presentation/widgets/gelisim_tab.dart:1016–1024`
```dart
child: Text(
  '${widget.dayNumber}',
  style: const TextStyle(
    color: Colors.white,            // ← always white
    fontSize: 17, fontWeight: FontWeight.w900,
    letterSpacing: 0.4,
  ),
),
```
The cell decoration: `color: _neon.withValues(alpha: 0.18)` → 18% purple wash on light scaffold. White text on a near-white wash is unreadable.
**Observation:** The pulsing-current cell is the most important day in the grid (the cell the user is supposed to tap right now). In dark mode it works; in light mode the day number bleaches into the wash.
**Perceptual cost:** The "now" indicator stops being an indicator. Light-mode users lose the visual anchor for "where am I in the program?".

### Finding V-23: Three concurrent pulse animations compete for attention on Gelişim
**Severity:** 2/5
**Where:**
- `_PulsingCurrentCell` 1400 ms purple glow pulse (gelisim_tab.dart:979–981)
- `_CoachAvatar` 2400 ms breathing scale (gelisim_tab.dart:1827–1830)
- `_PrimaryCta` static neon shadow (today_task_card.dart:295–301) — not pulsing, but sits with a 22-blur 50% alpha purple glow
- The shimmer skeleton (when loading) sweeps every 1400 ms
**Observation:** When the page is loaded with an active day, the user sees a current-cell pulsing every 1.4 s and a coach avatar breathing every 2.4 s simultaneously. Plus the today-task CTA has a static glow. Three "look here" signals competing.
**Perceptual cost:** Attention dilution. Apple-like surfaces use motion sparingly — 1 element moves at a time. Here multiple elements pulse on the same fold.

---

## 5. CTA VISIBILITY & VARIANCE

### Finding V-07: Four different primary-CTA implementations across onboarding, auth, dashboard, paywall
**Severity:** 4/5
**Where:**
1. **Welcome BAŞLA** (`onboarding_screen.dart:434–453`) — `FilledButton(backgroundColor: _neon, foregroundColor: Colors.white)` w/ TextStyle fontSize 18 letterSpacing 4 fw900 (filled solid purple)
2. **Onboarding _PrimaryButton** (`onboarding_screen.dart:988–1025`) — `FilledButton(backgroundColor: _neon, foregroundColor: Colors.black)` w/ fontSize 14 letterSpacing 2.5 fw900 (filled, **black ink** on purple)
3. **Auth GİRİŞ YAP** (`auth_screen.dart:248–270`) — `FilledButton(backgroundColor: _neon=cyberCyan, foregroundColor: Colors.black)` w/ fontSize **default**, letterSpacing 2 fw900 (filled, black ink on **cyan**)
4. **Today Task ANTRENMANA BAŞLA** (`today_task_card.dart:268–351`) — hand-rolled `Material+Ink+InkWell` w/ gradient `[_neonDeep, _neon]`, fontSize 13 letterSpacing 1.4 fw900 white ink (gradient, white)
5. **Paywall ₺0,00 karşılığında dene** (`paywall_screen.dart:368–465`) — hand-rolled `Material+Ink+InkWell` w/ horizontal gradient `[_neon, _neonAccent]`, fontSize 16 letterSpacing 1.4 fw900 white ink (different gradient, larger)
6. **Challenge Hero BAŞLA** (`challenge_hero_card.dart:160–183`) — white `Material` pill (`Colors.white`) w/ purple text, fontSize 14 letterSpacing 2 fw900 (white background, **purple ink**)

**Observation:** Six visually distinct primary-CTA paths. Different shapes (Filled / Material+Ink / pill), different fills (solid purple / cyan / gradient / white), different ink colors (black / white / purple), different sizes (14 / 16 / 18 / default), different letter-spacings (1.4, 2, 2.5, 4). The "primary action" visual register has no fixed identity.
**Perceptual cost:** Premium products converge on one CTA shape. The user's hand has a learned reflex: "this gradient pill = commit". Here the reflex never builds because the shape changes per surface. The user re-orients on every screen.
**Evidence:** Listed file:line above.

---

## 6. VISUAL CONSISTENCY ACROSS TABS

### Finding V-09: `_SoftCard` is duplicated across `gelisim_tab.dart` and `today_task_card.dart` with divergent light-mode behavior
**Severity:** 4/5
**Where:**
- `gelisim_tab.dart:2147–2196` — `_SoftCard` with light-mode awareness (`isDark ? _surface : scheme.surface`, `isDark ? _surfaceBorder : scheme.outlineVariant`, mode-specific shadow)
- `today_task_card.dart:218–248` — `_SoftCard` reimplemented, **dark-only**: `color: _surface` (#0F0F14) regardless of theme. Border: `_surfaceBorder`. Shadow: `accent.withValues(alpha: 0.10)` regardless.
**Observation:** Two classes of the same name with diverging behavior. The Gelişim copy was migrated to light mode in Phase 53; the Today Task copy was forgotten. So when the user toggles light mode, every card on Gelişim flips to white-and-charcoal — except the Today Task Card and the Program Complete card which stay near-black surfaces inside a near-white scaffold. The hero card on the priority page is a glaring dark hole.
**Perceptual cost:** Most damaging error in the light-mode pass. The single most important card — the "what should I do today" hero — looks broken in light mode while everything around it is white. The user assumes the card is in an error state.
**Evidence:**
```dart
// gelisim_tab.dart:2167–2192 (light-mode aware)
final isDark = context.isDarkMode;
color: isDark ? _surface : scheme.surface,
border: Border.all(color: isDark ? _surfaceBorder : scheme.outlineVariant, ...)

// today_task_card.dart:230–246 (dark-only, no theme awareness)
return Container(
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(18),
    color: _surface,                                    // ← always #0F0F14
    border: Border.all(color: _surfaceBorder),          // ← always #1E1E26
    boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.10), ...)],
  ),
  ...
);
```

### Finding V-22: "Material Icons exclusively" claim is partially false — emoji icon system in production
**Severity:** 2/5
**Where:**
- `lib/features/progress/providers/badge_unlocks_provider.dart:33, 51, 63, 69, 75, 87, 93` — every badge has an `emoji:` field used for storefront/share-card display: `'🎯' '🔥' '⚡' '🥗' '🏆'`
- `lib/features/nutrition/presentation/widgets/recipe_tags.dart:125–130` — recipe-tag icons are emojis: `'🔥 Yüksek Protein'`, `'🥗 Düşük Kalori'`, `'💪 Hacim'`, `'⚡ Hızlı'`, `'✨ Sıkılaşma'`
- `lib/features/home/presentation/widgets/today_task_card.dart:185` — `const Text('🏆', style: TextStyle(fontSize: 30))` (program-complete card)
- `lib/features/home/presentation/widgets/gelisim_tab.dart:430` — `const Text('🔥', style: TextStyle(fontSize: 13))` (streak pill)
- `lib/features/home/presentation/widgets/gelisim_tab.dart:617` — `'Harika gidiyorsun, devam et! 💪'` (motivation copy)

**Observation:** Atlas §7.6 declares "Material Icons only". In practice there's a parallel emoji-icon system used for badges, recipe categorization, motivational copy, and the streak indicator. Emojis render as system glyphs — they look different on iOS, Android, and on different OS versions. Premium products use a single icon family for control over rendering.
**Perceptual cost:** The "🏆" trophy looks one way on iOS 17 and another on Samsung One UI 6.1. The cross-platform brand is fragmented at the emoji boundary. Also: emojis-as-icons mark the product as "indie/casual" rather than "premium fitness".

---

## 7. LIGHT MODE PARITY

### Finding V-05: Light-mode parity is broken at scale — 195 hardcoded white-alpha patterns + 7 black Scaffolds
**Severity:** 5/5
**Where:** App-wide grep:
```
$ grep -rn 'Colors\.white\(54\|38\|24\|12\|70\|60\)' lib/ | wc -l
195

$ grep -rn 'backgroundColor: Colors\.black' lib/features/
auth_modal_bottom_sheet.dart:347
auth_screen.dart:211
auth_screen.dart:570
workout_camera_screen.dart:698
workout_camera_screen.dart:1107
prediction_screen.dart:105
onboarding_screen.dart:223
```
**Observation:** Atlas §7.1 documents Phase 53 as the light-mode introduction with the `lightTextSecondary` token at 5.07:1 contrast. The light-mode pass migrated some surfaces (Scaffold, Cards via `_SoftCard`, snack bars, bottom nav) but left:
- 195 hardcoded `Colors.white54/38/24/12/70/60` text/border references — every one invisible on a near-white scaffold
- 7 hardcoded `backgroundColor: Colors.black` Scaffolds — onboarding, auth (×2), prediction, workout camera (×2), auth modal — every one stays black even when the user has light mode on
- The today_task_card `_SoftCard` paints dark-only regardless of theme (V-09)
- The macro fat #EAFF00 yellow ships on light surfaces (V-20)
- The orangeOnLight WCAG-AA fix is unused (V-15)
- The `_PulsingCurrentCell`'s white text bleaches on light wash (V-13)

**Perceptual cost:** Light mode is half-done. A user toggling light mode sees Antrenman + Gelişim cards flip cleanly, then opens Workout Camera and finds it pitch black, then opens Auth and finds it pitch black, then finds the Today Task card on Gelişim still dark, finds the streak pill orange unreadable, finds the day-grid current-cell number bleached out. The toggle exists but the experience is unfinished. Atlas claims compliance; codebase shows ~50% migration.
**Evidence:** Counts above + per-finding evidence in V-05 sub-findings (V-13, V-15, V-20).

### Finding V-24: Section pill label hardcoded `Colors.white` against 10%-neon background
**Severity:** 2/5
**Where:** `lib/features/home/presentation/widgets/gelisim_tab.dart:883–891`
```dart
Text(
  label,
  style: const TextStyle(
    color: Colors.white,             // ← hardcoded
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.8,
  ),
),
```
The pill background is `_neon.withValues(alpha: 0.10)`. On dark mode: white-on-translucent-purple-on-near-black → readable. On light mode: white-on-translucent-purple-on-white → text washes out.
**Perceptual cost:** Both "Takvimi Gör" and "Tümünü Gör" pills become invisible chrome in light mode. The arrow icon to the right is colored `_neon` which IS visible — so the user sees a floating arrow with no label.
**Evidence:** `_SectionLinkPill:866–902` with `color: _neon.withValues(alpha: 0.10)` background and `Colors.white` ink.

---

## 8. ANIMATION PURPOSEFULNESS

### Finding V-19: Onboarding hook screens lock the user into ~11 s of forced waiting on first launch
**Severity:** 3/5
**Where:**
- `_CoachIntroStepState` (`onboarding_screen.dart:551–697`) — typewriter @ 28 ms/char × ~140 chars = **~3.92 s** before CTA enabled
- `_AnalysisIllusionStepState` (`onboarding_screen.dart:1372–1473`) — 5 phrases × 1200 ms + 1200 ms terminal beat = **~7.2 s** with no skip
- Total on critical path: ~11.12 s of motion-illusion / labor-illusion before any reveal
**Observation:** The atlas notes both as labor illusions. Are they rewarding the wait?
- Coach intro: 3.92 s of letter-by-letter Turkish text. The pulsating coach avatar fills the screen. Below 3 s this would feel deliberate; above 4 s it tips into wait. The `Geçmek için ekrana dokun` skip is fontSize 11 `Colors.white54` — easy to miss.
- Analysis illusion: 7.2 s of "Vücudun analiz ediliyor… Metabolizma hesaplanıyor…" cycling at 1.2 s per phrase. There's a rotating sweep ring + counter-rotating sparkle (custom painter). **No skip.** The phrases imply real computation; the actual computation is `AiPersonalizationEngine.generateReport()` which is synchronous and runs in microseconds.
**Perceptual cost:** First-launch friction. The user committed by pressing BAŞLA, then has to wait 4 s, then answers questions, then waits 7 s of fake AI thinking. Real high-touch fitness apps (Centr, Future) run their analysis in 2–3 s with one progress signal — not 7+. The fake waiting is suspicious in a market where users have learned to identify "labor illusion" theater.
**Evidence:** Cited file:line above + duration constants (`_perChar = 28ms`, `_phraseDuration = 1200ms`, `5 phrases + 1 terminal = 7200ms`).

---

## 9. EMPTY-STATE TREATMENT

### Finding V-18: Day-0 user sees a wall of zeros with no forward-looking copy
**Severity:** 3/5
**Where:** Atlas §5.5 + per-widget defaults:
- Program Progress Card: `%0`, `0 / 30 gün tamamlandı`, motivation: `'Harika gidiyorsun, devam et! 💪'` (`gelisim_tab.dart:617` — same copy regardless of state)
- Streak Card: `0 gün`, "Serini bozma!", 5 empty dots
- 30-day grid: 30 cells, all locked except day 1 (pulsing) — visually **29/30 dim cells**, half marked rest
- Stats cards "BU HAFTA": `0 / 7`, "YAKILAN KALORİ": `0 kcal` over flat area chart, "ANTRENMAN": `0 tamamlandı`
- AI Coach card: 'Bugün hedeflerimize bir adım daha yaklaşıyoruz.' (default branch)
- Badges section: 5 hex badges, all dim with `0%` progress under each
**Observation:** A first-launch user opens Gelişim and sees 0%, 0/30, 0 gün, 0 / 7, 0 kcal, 5 empty dots, 25+ locked cells, 5 dim badges. The page has 8 places where a `0` or empty state appears. The motivation copy "Harika gidiyorsun, devam et!" is a hardcoded string regardless of progress — so a Day-0 user with 0% is told "You're doing great, keep going!".
**Perceptual cost:** Emotional cold-open. Day-0 is the most important emotional state to nail in a 30-day program — the user is committing. Premium fitness onboardings (Future, Centr, Caliber) preview the *future* on Day 0: "this is what your Day 30 will look like" rather than "here's your empty progress". The current Gelişim state makes Day 0 feel like "you have a lot of work to do" instead of "let's get started together".
**Evidence:** Atlas §5.5 confirmed + line 617 inspected directly.

---

## 10. ASSET ASYMMETRY

### Finding V-06: Gender-other paywall hero is a generic Material wheelchair-accessibility icon
**Severity:** 4/5
**Where:** `lib/features/monetization/presentation/paywall_screen.dart:785–800` — gender-routing in `_heroContent()`:
```dart
case Gender.male:
  return _GenderBeforeAfter(todayAsset: '...ERKEK.webp', thirtyDayAsset: '...ERKEK.webp');
case Gender.female:
  return _GenderBeforeAfter(todayAsset: '...KADIN.webp', thirtyDayAsset: '...KADIN.webp');
case Gender.other:
case null:
  return _TransformationPlaceholder();  // ← falls through
```
And `_TransformationPlaceholder` (lines 971–1043) renders two `Icons.accessibility_new` glyphs — the **standard Material Design wheelchair-accessibility icon** — sized 100 px and 120 px with cyan/purple halos. There are no custom assets for non-binary users.
**Observation:** Male and female users see a 1024×1359 photo composite (before/after). Other/null users see two stick-figure icons inside a radial purple gradient. The `_HeroTag` for the third category is "AI DESTEKLİ" (rather than the M/F-tagged "BUGÜN" → "30. GÜN").
**Perceptual cost:** Premium-feel collapse for the user. Imagine signing up for a 30-day fitness program, going through onboarding, paying attention to "we're personalizing this for you", arriving at the paywall, and seeing two clip-art wheelchair icons as your "30-day transformation". That's the conversion-killing moment. Beyond conversion: the icon choice (specifically `accessibility_new` — the wheelchair-figure icon) is a culturally insensitive default for a "non-binary or undisclosed" gender option.
**Evidence:** File:line above + the icon constant `Icons.accessibility_new` is the Material Design accessibility/disability icon.

### Finding V-11: Gender option asset asymmetry
**Severity:** 4/5
**Where:** `photos/cinsiyetseçimierkek.webp` (1024×1359, 48 KB), `photos/cinsiyetseçimikadın.webp` (1024×1359, 40 KB), `photos/cinsiyet_diger.webp` (**1024×683**, **10 KB**).
**Observation:** The other-gender option's asset is dimensionally different (683 px tall vs 1359 px) and ¼ the file size. Likely a placeholder/icon that's never been replaced. Atlas §4.6 already noted "Gender option asymmetry: Kadın + Erkek have illustrations; Diğer is icon-only." Combined with V-06 (paywall hero placeholder), the non-binary-user visual path is broken at every gating surface.
**Perceptual cost:** First gender step in onboarding shows two photos and one icon. Compounds with V-06 at the paywall. A non-binary user finishing the onboarding has been shown placeholder treatments at three separate "personalization" surfaces.

---

## 11. VISUAL FLOW (cross-surface)

### Finding V-12: Welcome → Auth color register flips from purple background gradient to all-black with cyber-cyan primary
**Severity:** 4/5
**Where:**
- `_WelcomeStep` (`onboarding_screen.dart:341–469`) — full-bleed `photos/ilkkarşılamaanaekranarkaplanı.webp` photo background, top-to-bottom black gradient overlay, ShaderMask gradient `[_neon, _neonAccent]` on title, FilledButton `_neon` purple BAŞLA
- `AuthScreen` (`auth_screen.dart:208–212`) — `Scaffold(backgroundColor: Colors.black, ...)`, no background image, `_neon` constant local-redefined as `0xFF00F0FF` (cyan), FilledButton black-on-cyan
**Observation:** The Welcome screen establishes "deep purple gradient + photo + neon-purple gradient text" as the brand register. The Auth screen drops all that — pitch-black scaffold with cyan ink, no imagery. Then the paywall picks up the purple gradient again. The "auth screen is cyan and bare" is jarring even if the user can't articulate it.
**Perceptual cost:** The auth screen feels like a different app. Premium products keep visual cohesion through transitions; here, the user experiences "FormAI → ??? → FormAI". This is highest-impact at the conversion/login point — the user has just committed and now the visual register changes.

---

## 12. SHARED-WIDGET INVENTORY VS REALITY

Atlas §7.4 lists shared widgets in `lib/core/widgets/`. Per-feature audit:

| Shared widget | Reality |
|---|---|
| `SkeletonBox`, `SkeletonLine`, `RecipeGridSkeleton`, `DayGridSkeleton`, `ExerciseListSkeleton` | Used; loading-state pattern — **but Antrenman uses `Center(child: CircularProgressIndicator)` instead, atlas §5.9 noted this as factual** |
| `BrandedMediaFallback` | Used in nutrition/recipe detail (line 200), rare elsewhere |
| `ErrorCard` | Used in antrenman_tab.dart:120; not used in gelisim (which has its own _OfflineLikeCard) |
| `TopToast` | Used; replaces previous toast |
| `CachedImage` | Used for network images (recipes); local assets use `Image.asset` directly |
| `ShareProgressTemplate`, `ShareBadgeTemplate` | Used for off-screen render |

The `_SoftCard` pattern (the most-used dashboard primitive) **does not live in core/widgets** — it's redefined per-file (V-09). That's the costliest reuse failure: every "card" on the priority surface is independently maintained.

---

## 13. SCREENSHOT POTENTIAL (cross-reference for Premiumization)

The five highest-screenshot-potential surfaces today, from a visual-system lens:
1. **Recipe detail** (`recipe_detail_screen.dart`) — clean hero photo, fontSize 28 fw900 title, well-aligned macro tiles. **Strong premium feel.**
2. **Welcome step** (`onboarding_screen.dart:_WelcomeStep`) — photo + gradient + ShaderMask 32pt headline + 18pt CTA. **Cinematic.**
3. **Paywall (M/F user)** — before-after composite + glowing arrow + ribbon. **Feels designed**, modulo trial-badge typography (V-10).
4. **Gelişim — IF the wrong purple is fixed and CTA position is fixed.** Currently downgraded by V-01, V-04, V-09, V-13, V-18.
5. **Workout camera** — pose-detection overlay with cyber-cyan skeleton. Unique and premium-looking, modulo the all-black scaffold and `Colors.redAccent` warnings (token drift).

**Surfaces that should NOT be screenshotted today:** Auth screen (cyan brand drift), Gelişim Day-0 (8 zeros), Today-Task card in light mode (broken card, V-09), Profile settings (functional but visually unremarkable).

---

## 14. SUMMARY

The dark-purple cyber/neon aesthetic, the photo asset library, and a handful of surfaces (Welcome, Recipe Detail, Paywall hero) are genuinely premium. But the visual system is **one decision short of cohesion**:

1. **No type scale.** 31 sizes, 509 inline TextStyles, 1 use of the M3 textTheme.
2. **No firm token discipline.** AppColors exists but ~36% adoption; brand purple ships in two hues; orangeOnLight is dead.
3. **No card primitive.** `_SoftCard` is duplicated, with light-mode awareness in one and not the other.
4. **No CTA primitive.** Six different primary-CTA shapes across six surfaces.
5. **Light-mode pass is half-done.** 195 hardcoded white-alphas + 7 black scaffolds + dead WCAG token.
6. **Empty-state copy is a wall of zeros**, with motivation copy that doesn't branch on Day-0.
7. **Forced-wait labor illusions** (~11 s on first launch) read as suspicious in 2026's market.
8. **Non-binary user visual path is broken** at three points (gender step, onboarding, paywall hero).

The bones are there. The system layer that would make those bones move as one organism is not.
