# DESIGN CONSISTENCY REPORT

**Phase 2 — Product Analysis**
**Project:** SixPack AI / FormAI Fit
**Generated:** 2026-05-08
**Scope:** Internal visual coherence — token compliance, component reuse, light/dark parity. Severity-scored findings; no recommendations.

---

## 0. EXECUTIVE SUMMARY (severity-sorted)

| ID | Severity | Title |
|---|---|---|
| C-01 | 5/5 | Brand purple ships in two hues — `#8E5BFF` (token) and `#8B5CF6` (Tailwind violet-500) — across the same product |
| C-02 | 5/5 | `AppColors` token compliance is ~36 %: 88 token references vs 158+ matching brand-color hex literals |
| C-03 | 5/5 | `Theme.of(context).textTheme` has 1 use; the entire app paints type via 509 inline `TextStyle(...)` declarations |
| C-04 | 4/5 | Card chrome is reinvented per-file: `_SoftCard` exists in two divergent versions; 6+ Container-based card patterns |
| C-05 | 4/5 | Six different primary-CTA implementations across onboarding, auth, dashboard, paywall (V-07 mirror) |
| C-06 | 4/5 | Light-mode hardcoded `Colors.white54/38/24/12/70/60` ships in 195 places — none flip with theme |
| C-07 | 4/5 | 7 hardcoded `backgroundColor: Colors.black` Scaffolds break light mode for onboarding, auth, prediction, workout camera |
| C-08 | 3/5 | Loading-state UX inconsistency: skeleton (Gelişim/Recipe), centered spinner (Antrenman), shimmer (Paywall prices) — three patterns |
| C-09 | 3/5 | Toast vs SnackBar usage is mixed: TopToast widget for some flows, ScaffoldMessenger.showSnackBar for others, hard-coded `Colors.red.shade900` instead of AppColors.danger |
| C-10 | 3/5 | `AppColors.neonAccent` token has zero call-sites (V-14 mirror); 38 hex literals of `#4DA6FF` instead |
| C-11 | 3/5 | `AppColors.orangeOnLight` (Phase 53 WCAG-AA fix) has zero call-sites (V-15 mirror); failing #F97316 still ships in light mode |
| C-12 | 3/5 | 8+ "near-black surface" hex literals (`0xFF0F0F14`, `0xFF14141B`, `0xFF111118`, `0xFF141028`, `0xFF1A0B3D`, `0xFF221145`, `0xFF1E0A40`, `0xFF0E0729`) painted as ad-hoc dark backgrounds |
| C-13 | 3/5 | Section-header treatment: 4 distinct visual styles across 4 dashboard tabs (V-08 mirror) |
| C-14 | 3/5 | Atlas §7.6 claims "Material Icons exclusively" — emoji icon system in production for badges/recipe-tags/streak (V-22 mirror) |
| C-15 | 2/5 | `Colors.redAccent`, `Colors.red`, `Colors.green` used as semantic tokens in auth/workout/referral instead of `AppColors.danger`/`AppColors.success` |
| C-16 | 2/5 | `lightTextSecondary` 5.07:1 contrast claim is verified; many surfaces use ad-hoc `onSurface.withValues(alpha: 0.55)` instead — drops below 5.07 in light mode |
| C-17 | 2/5 | Each `_neon` constant is locally redefined per-file (~14 files) instead of imported from AppColors — the centralization pass never finished |

---

## 1. TOKEN COMPLIANCE AUDIT

### Finding C-01: Brand purple ships in two hues across the same app
**Severity:** 5/5
**Where:** App-wide grep:
```
$ grep -rn 'Color(0xFF8E5BFF)' lib/ | wc -l
38   ← correct (matches AppColors.neon)

$ grep -rn 'Color(0xFF8B5CF6)' lib/ | wc -l
5    ← wrong (Tailwind violet-500)

$ grep -rln 'Color(0xFF8B5CF6)' lib/
lib/features/progress/presentation/calendar_screen.dart:8
lib/features/progress/presentation/suggestions_screen.dart:12
lib/features/progress/presentation/badges_screen.dart:10
lib/features/home/presentation/widgets/today_task_card.dart:10
lib/features/home/presentation/widgets/gelisim_tab.dart:27
```
**Observation:** The 5 wrong-purple files are ALL on the most-trafficked progression path: Gelişim tab + Today Task Card + Calendar + Suggestions + Badges. The 38 correct-purple uses are spread across paywall/onboarding/auth/profile/nutrition. The drift was acknowledged in `app_colors.dart:7–10` ("Every feature surface defined its own `_neon`… the values agreed in spirit but disagreed in detail (e.g. one screen shipped `0xFF8E5BFF`, another shipped `0xFF8B5CF6` — both labelled 'neon')") but never closed.
**Perceptual cost:** Brand-recognition fragility. Cross-file inspection reveals the wrong purple sits in the most user-visible places (Gelişim is the priority surface per atlas). On a side-by-side view, #8E5BFF reads slightly redder and more saturated; #8B5CF6 reads slightly bluer and less saturated. The user can't articulate it but the brand pulse loses fidelity on every navigation.
**Evidence:** Listed above.

### Finding C-02: ~36 % AppColors token compliance app-wide
**Severity:** 5/5
**Where:** Grep tally:
```
$ grep -rn 'AppColors\.' lib/ | wc -l
88     ← total token references

$ grep -rn 'AppColors\.neon\b' lib/ | wc -l
27     ← AppColors.neon

$ grep -rn 'AppColors\.danger' lib/ | wc -l
6      ← AppColors.danger

$ grep -rn 'Color(0xFF8E5BFF)' lib/ | wc -l
38     ← correct hex literal of AppColors.neon

$ grep -rn 'Color(0xFF4DA6FF)' lib/ | wc -l
38     ← AppColors.neonAccent (token has 0 uses)

$ grep -rn 'Color(0xFF00F0FF)' lib/ | wc -l
25     ← AppColors.cyberCyan
```
Brand-only literal subtotals: 8E5BFF(38) + 4DA6FF(38) + 00F0FF(25) + 39FF14(18) + FF4DDB(12) + 6A3DFF(11) = **142 hex literals matching named AppColors tokens, plus 16+ for semantic colors (FF4D6D, F97316, FFB84D, 22C55E)**. Total brand-literal usage is north of 158, vs 88 token references. **Token compliance ~36 %.**
**Observation:** AppColors was created in Phase 48 with the explicit goal: "Centralising the palette here lets a future redesign edit a single literal instead of grepping the codebase." Nine months later, the file is decorative — most engineers still type the hex directly because that's faster than importing. Of the 88 token uses, the majority are in core widgets (top_toast, app_theme, error_card) — feature code rarely uses tokens.
**Perceptual cost:** Small individually, large at scale. Any future "rebrand to a slightly cooler purple" requires editing 38+ files. Any "introduce a tertiary brand accent" requires writing the new token and then individually migrating 50+ hex usages. The codebase actively penalizes design system maintenance.

### Finding C-10: `AppColors.neonAccent` token has zero call-sites
**Severity:** 3/5
**Where:** Token declared at `app_colors.dart:27`. Search:
```
$ grep -rn 'AppColors\.neonAccent' lib/
(zero matches)
```
**Observation:** The blue-violet `#4DA6FF` is referenced 38 times — every one as `Color(0xFF4DA6FF)` literal. The token exists in name only.
**Perceptual cost:** Documentation-vs-code drift. Atlas §7.1 calls out `neonAccent` as the secondary brand color. The codebase doesn't believe it.

### Finding C-11: `AppColors.orangeOnLight` is dead code
**Severity:** 3/5
**Where:** `app_colors.dart:60–66`. Search returns zero references in `lib/`. Meanwhile `Color(0xFFF97316)` (the failing AA-on-light orange) appears 4 times directly in feature code, plus 7 occurrences of `_orange = Color(0xFFF97316)` in feature-local consts. Light-mode users see the failing orange every time the streak pill, kcal card, or warning state renders.
**Observation:** Phase 53 added the WCAG-fix token with a rationale-rich docstring but didn't migrate any call-sites. The fix is "done" on paper, not in product.
**Perceptual cost:** Compliance theater. Future audit shows "we have a WCAG-AA orange"; reality shows the failing orange ships.

### Finding C-15: Generic `Colors.red`/`Colors.green` used as semantic tokens
**Severity:** 2/5
**Where:**
- `auth_screen.dart:201` — `backgroundColor: Colors.red.shade900` (toast bg)
- `auth_screen.dart:413, 417` — `BorderSide(color: Colors.redAccent, width: 1)` (input error border)
- `workout_camera_screen.dart:1156–1159` — `Colors.redAccent` warning chip
- `referral_landing_screen.dart:211–212, 240–241` — `Colors.green.withValues(alpha: 0.12)`, `Colors.red.withValues(alpha: 0.12)` for success/error cards
**Observation:** `AppColors.danger` (`#FF4D6D`) and `AppColors.success` (`#22C55E`) are the spec'd semantic tokens. Auth, workout, and referral all sidestep them with the Flutter framework's generic `Colors.red`/`Colors.green` shades.
**Perceptual cost:** Error/success treatments don't share a hue. The auth error border (Material's `Colors.redAccent` = `#FF5252`) is a different red from the AppColors.danger pink-red (`#FF4D6D`) used elsewhere. The user sees inconsistent error-states.

### Finding C-17: `_neon` constants redefined per-file in ~14 files
**Severity:** 2/5
**Where:**
```bash
$ grep -rn 'const Color _neon' lib/ | wc -l
14
```
Files redefining `_neon`:
- `today_task_card.dart` — `0xFF8B5CF6` (wrong)
- `gelisim_tab.dart` — `0xFF8B5CF6` (wrong)
- `calendar_screen.dart`, `suggestions_screen.dart`, `badges_screen.dart` — `0xFF8B5CF6` (wrong)
- `antrenman_tab.dart`, `weekly_goal_card.dart`, `challenge_hero_card.dart` — `0xFF8E5BFF` (correct)
- `paywall_screen.dart` — `0xFF8E5BFF` (correct)
- `onboarding_screen.dart`, `prediction_screen.dart`, `profile_tab.dart` — `0xFF8E5BFF` (correct)
- `auth_screen.dart` — `0xFF00F0FF` (cyan — divergent)
- `workout_camera_screen.dart` — `0xFF00F0FF` (cyan — intentional per atlas)
- `recipe_detail_screen.dart`, `nutrition_tab.dart` — `0xFF8E5BFF` (correct)
**Observation:** 14 different `_neon` constants in 14 files. Even within the "correct" group, every file has its own private const rather than `import AppColors.neon`. The centralization that AppColors exists to enable hasn't propagated.
**Perceptual cost:** Maintenance smell rather than visual cost. But the wrong-purple bug (V-01/C-01) only happened because the shape of "redefine `_neon` locally" let three files independently pick a different value.

---

## 2. CARD COMPONENT VARIANCE

### Finding C-04: Card chrome reinvented per-file; multiple `_SoftCard` definitions; 6+ ad-hoc `Container(decoration:)` card patterns
**Severity:** 4/5
**Where:**
- `gelisim_tab.dart:2147–2196` — `_SoftCard` (light-mode aware)
- `today_task_card.dart:218–248` — `_SoftCard` (dark-only — V-09)
- `weekly_goal_card.dart:42–52` — Container w/ `_surfaceDark` (#111118), light-aware
- `paywall_screen.dart:1232–1258` — `AnimatedContainer` per-plan-card with bespoke decoration
- `challenge_hero_card.dart:44–54` — Stack-of-DecoratedBox + InkWell, dark-only
- `equipment_strip.dart` — `_EquipmentCard` widget
- `antrenman_tab.dart:357–403` — empty-state Container w/ surface decoration
- `nutrition_tab.dart:281–323` — `_MacroBarsRow` Material+InkWell with bespoke chrome
- `nutrition_tab.dart:1131+` — `_DiscoverAllPill` Container
- `profile_tab.dart` — `_SettingsTile`, `_InfoTile` (separate card definitions)
**Observation:** No shared `Card` primitive in `lib/core/widgets/`. Every dashboard, every form, every settings list reinvents its container chrome. Border-radius lands on 12, 14, 16, 18, 20, 24 — six radius values for the same conceptual element. Border colors, shadow sizes, padding all per-file.
**Perceptual cost:** A consistent card primitive is the single most-impactful design system element. Without it, every screen has subtly different card breathing room and shadow. The user processes each card as "kind of like the others" rather than "the standard FormAI card".
**Evidence:** Per-file inspections + the lack of any `core/widgets/card.dart`.

### Finding C-12: 8+ "near-black surface" hex literals scattered as ad-hoc backgrounds
**Severity:** 3/5
**Where:** Surfaces: `0xFF0F0F14` (canonical), `0xFF14141B` (snackbar), `0xFF111118` (weekly_goal_card), `0xFF141028` (prediction), `0xFF1A0B3D` (paywall hero), `0xFF221145`/`0xFF0D0622` (branded fallback), `0xFF1E0A40`/`0xFF0A0612` (gelisim halo), `0xFF0E0729` (coach intro fallback). All near-black, all with subtle violet tints, none of them aliased.
**Observation:** Pulled into one stack visually they look "vaguely the same" but a side-by-side comparison reveals 4–5 distinct violet tints. Premium products use 1–2 surface tones; here there are 8+.
**Perceptual cost:** As the user navigates, the dark register tints ever-so-slightly differently. Imperceptible per-frame; corrosive over a session.

---

## 3. BUTTON / CTA VARIANCE

### Finding C-05: Six different primary-CTA implementations
**Severity:** 4/5
*(Mirror of V-07 — repeated here for consistency framing)*
**Where:**
1. `_WelcomeStep` BAŞLA — `FilledButton(_neon, white, fontSize 18 ls 4)` (`onboarding_screen.dart:434`)
2. `_PrimaryButton` (onboarding step CTA) — `FilledButton(_neon, **black**, fontSize 14 ls 2.5)` (line 988)
3. `AuthScreen` GİRİŞ YAP — `FilledButton(_neon=cyan, **black**, no fontSize override, ls 2)` (`auth_screen.dart:248`)
4. `_PrimaryCta` (TodayTaskCard) — `Material+Ink` gradient `[_neonDeep, _neon]`, white, fontSize 13 ls 1.4 (`today_task_card.dart:268`)
5. `_buildCta` (PaywallScreen) — `DecoratedBox+Ink` gradient `[_neon, _neonAccent]`, white, fontSize 16 ls 1.4 (`paywall_screen.dart:368`)
6. `ChallengeHeroCard` BAŞLA — `Material(white) StadiumBorder` purple ink, fontSize 14 ls 2 (`challenge_hero_card.dart:160`)
**Observation:** Solid-fill / gradient / outline / pill chrome — four distinct shape languages. Black-on-purple / white-on-gradient / purple-on-white — three distinct ink/fill conventions. fontSize 13/14/16/18 — four sizes. letterSpacing 1.4/2/2.5/4 — four values.
**Perceptual cost:** Mirror of V-07 finding. The user's CTA-recognition reflex doesn't build because the shape changes per surface.

---

## 4. ICONOGRAPHY DRIFT

### Finding C-14: Material Icons + emoji icon system both ship; atlas §7.6 claim is incomplete
**Severity:** 3/5
*(Mirror of V-22)*
**Where:**
- 340 `Icons.*` references (Material Design) — verified by grep
- 0 `CupertinoIcons.*` references — atlas correct on this point
- Emoji icons: `lib/features/progress/providers/badge_unlocks_provider.dart` defines `emoji:` field per badge (lines 33–93); `lib/features/nutrition/presentation/widgets/recipe_tags.dart:125–130` uses emoji as primary tag icons; `today_task_card.dart:185` and `gelisim_tab.dart:430, 617` embed emoji directly
**Observation:** Atlas §7.6 declares "Material Icons only". Emojis are unstated but production. They render via system glyphs (different per OS / version).
**Perceptual cost:** Cross-platform brand fragmentation. iOS users see one trophy emoji, Android users see another. Premium products use one icon family for control over rendering.

---

## 5. LIGHT/DARK MODE PARITY

### Finding C-06: 195 hardcoded `Colors.white54/38/24/12/70/60` patterns
**Severity:** 4/5
*(Mirror of V-05's first sub-finding)*
**Where:** App-wide grep `Colors\.white\(54\|38\|24\|12\|70\|60\)` → 195 matches across `lib/features/`. The migration pattern Phase 53 introduced (`scheme.onSurface.withValues(alpha: 0.55)`) was applied selectively; many widgets skipped it.
**Observation:** Each of these 195 patterns paints translucent-white text/borders. In dark mode → readable. In light mode → near-invisible because the alpha sits on a near-white scaffold.
**Perceptual cost:** Light mode looks unfinished. Specific examples:
- `gelisim_tab.dart:1326` — `Colors.white54` for stats unit (the `'kcal'` next to "YAKILAN KALORİ" big number) — invisible in light mode
- `gelisim_tab.dart:1432` — `Colors.white38` for day-strip labels (Pzt/Sal/Çar) under bar charts — invisible in light mode
- `today_task_card.dart:84–85` — `Colors.white54` for "X dk · Level" descriptor — invisible in light mode
- `prediction_screen.dart:182` — `Colors.white38` "Planın seni bekliyor — kaçırma." — invisible in light mode
**Evidence:** Listed counts above.

### Finding C-07: 7 hardcoded `backgroundColor: Colors.black` Scaffolds
**Severity:** 4/5
**Where:**
```
$ grep -rn 'backgroundColor: Colors\.black' lib/features/
auth_modal_bottom_sheet.dart:347
auth_screen.dart:211, 570
workout_camera_screen.dart:698, 1107
prediction_screen.dart:105
onboarding_screen.dart:223
```
Plus the Scaffold body inside auth_modal_bottom_sheet's `Material(color: Colors.black, ...)` (line 347) — explicit black.
**Observation:** The Scaffold's `backgroundColor` is set to `Colors.black` directly, bypassing `scaffoldBackgroundColor` from the active ThemeData. Phase 53 added light-mode tokens but these surfaces never honor them.
**Perceptual cost:** Light mode flips Antrenman + Gelişim to off-white scaffold, then onboarding/auth/prediction/workout are still pitch black. The user toggles light mode and discovers it works on some surfaces and not others. Atlas claims "every dashboard section render correctly" — outside dashboards, parity isn't there.

### Finding C-16: `lightTextSecondary` 5.07:1 contrast claim verified; many surfaces use ad-hoc `onSurface.withValues(alpha: 0.55)` instead
**Severity:** 2/5
**Where:** `app_colors.dart:130` declares `lightTextSecondary = Color(0xFF565B66)` with 5.07:1 against lightSurface. But the Phase 53C migration pattern recipes use `scheme.onSurface.withValues(alpha: 0.55)` instead (e.g. `gelisim_tab.dart:413, 581, 715, 1080, 1158, 1165, 2208, 2232`).
**Observation:** `onSurface * 0.55 alpha` on `lightTextPrimary (#111118)` over `lightSurface (#FFFFFF)` produces an effective color ≈ `#7B7E83` — contrast ratio ~4.6:1, just barely AA but **lower than the 5.07:1 the dedicated token provides**. The token migration was rejected in favor of the alpha-recipe, which trades 0.5 contrast points for terseness.
**Perceptual cost:** Small but cumulative. Secondary text is perceptibly grayer than the spec; on bright displays in sunlight the difference matters.

---

## 6. LOADING-STATE PATTERNS

### Finding C-08: Three loading-state UX patterns live concurrently
**Severity:** 3/5
**Where:**
- **Skeleton shimmer**: `gelisim_tab.dart:170, 847` (`_ProgramSyncingCard`, `DayGridSkeleton`); recipe grid (atlas §7.4); paywall price slot (`paywall_screen.dart:1196` `SkeletonBox`)
- **Centered spinner**: `antrenman_tab.dart:111–112` `CircularProgressIndicator(color: _neon)` for full-tab loading; `paywall_screen.dart:524–531` for restore button; auth_screen.dart for OAuth spinner; today_task_card has implicit spinner inside `_PrimaryCta` when busy
- **No-state**: prediction_screen, profile_tab — content renders directly even on loading because they read SharedPreferences (synchronous)
**Observation:** Atlas §5.9 noted "Gelişim uses skeleton, Antrenman uses centered spinner" as a structural inconsistency. Adding the paywall (mixed) and account screens (no-state), the codebase has at least 3 loading-state patterns. None is "wrong"; they're just not unified.
**Perceptual cost:** When skeleton is on Gelişim and spinner on Antrenman, swiping between them on first launch feels like two different products. Premium products converge on one loading vocabulary.

### Finding C-09: Toast/snackbar/error patterns are mixed
**Severity:** 3/5
**Where:**
- `lib/core/widgets/top_toast.dart` — Phase 51 `TopToast` widget (slide+fade, replaces previous)
- `lib/core/theme/app_theme.dart:75–97, 141–164` — `SnackBarThemeData` with neon hairline border
- `auth_screen.dart:195–204` — uses `ScaffoldMessenger.showSnackBar` with **`backgroundColor: Colors.red.shade900`** (bypasses theme)
- `paywall_screen.dart:_toast(...)` — calls `TopToast` for purchase outcomes
- `gelisim_tab.dart:1048–1057` — uses `ScaffoldMessenger.showSnackBar` with `backgroundColor: _success.withValues(alpha: 0.9)` (bypasses theme)
- `feedback_sheet.dart` — likely yet another pattern
**Observation:** Three notification UIs in one codebase: TopToast (top-anchored, neon-bordered), themed SnackBar (bottom-anchored, neon hairline), ad-hoc SnackBar with hardcoded background. Even within Gelişim alone, success states use SnackBar (line 1048), error states use ErrorCard (atlas §7.4), and paywall uses TopToast.
**Perceptual cost:** The user can't form an expectation about where notifications appear. "Did the action succeed?" requires looking at top + bottom + page-content because any of them could carry the message.

---

## 7. ATLAS ERRATA & EXTENSIONS

The Phase 1 atlas is mostly accurate. Items below extend / correct it:

### ERRATA-1: Brand purple drift not surfaced
Atlas §7.1 lists `neon: #8E5BFF` but does not flag the 5 production files painting `#8B5CF6` instead. Severity 5 finding for Phase 2.

### ERRATA-2: `AppColors.neonAccent` and `AppColors.orangeOnLight` are dead tokens
Atlas §7.1 lists both as palette entries. Code search shows zero call-sites. They are documentation, not implementation.

### ERRATA-3: "Material Icons exclusively" is partially false (atlas §7.6)
Emoji icons are an unstated parallel system on badge metadata, recipe tags, and motivational copy.

### ERRATA-4: Typography "system fonts" claim is technically true but understated
Atlas §7.2 says "system fonts (no Google Fonts imports)" — verified. But the claim implies a coherent type scale; in practice 31 distinct fontSize values ship across 509 inline TextStyles. The Material 3 `textTheme` is essentially unused (1 reference app-wide).

### ERRATA-5: Atlas §5.7 estimates Gelişim primary CTA position at 420–450 px
Per-widget spacing math (V-04) puts the CTA closer to ~470–520 px to top. The discrepancy is ~50–100 px — meaningful on iPhone SE-class viewports where 444 px is the practical fold.

### ERRATA-6: Atlas §7.4 "shared widget inventory" omits the unshared cards
The atlas lists `SkeletonBox`, `BrandedMediaFallback`, `ErrorCard`, etc. — all real, all in `core/widgets/`. But the most-used dashboard primitive — the soft elevated card `_SoftCard` — is NOT in core/widgets; it's redefined per-file with divergent behavior. This is a structural gap the atlas should reflect.

### EXTENSION-1: Auth screen primary brand color is cyber-cyan (`#00F0FF`)
Atlas §7.1 documents cyber-cyan as the workout-camera HUD color. Code shows it's also the auth screen primary, the auth modal's primary, and the auth divider. Atlas could note "auth flows" as a third surface using cyan.

### EXTENSION-2: 8+ near-black surface tones, not 4
Atlas §7.1 lists `darkBg #0B0B12`, `surface #0F0F14`, `surfaceBorder #1E1E26`, `inactive #1C1C24`. Reality: 8+ ad-hoc near-black surfaces (`#14141B`, `#111118`, `#141028`, `#1A0B3D`, `#221145`, `#1E0A40`, `#0A0612`, `#0E0729`).

### EXTENSION-3: Coach-intro typewriter is ~3.92 s, not under 3
Atlas §4.1 estimates "~4 s". Code: 28 ms × ~140 chars = 3920 ms exact. Aligns; calling out as confirmation.

---

## 8. SUMMARY

The visual-system layer that exists is well-intentioned: AppColors centralization (Phase 48), Phase 53 light-mode token introduction, Phase 49 skeleton shimmer primitives, the SnackBarThemeData neon-hairline. None of these has the engineering follow-through to complete the migration:

- AppColors is ~36% adopted; two key tokens (neonAccent, orangeOnLight) are dead.
- Phase 53 light-mode pass migrated some surfaces and skipped 7 entire screens + 195 white-alpha references.
- Skeleton primitives are used on some loading paths and bypassed on others.
- The shared SnackBar theme is bypassed by ad-hoc `Colors.red.shade900` toasts.

The brand-primary color drift (#8E5BFF vs #8B5CF6) is the single highest-severity consistency issue: it ships in production today, on the priority surface (Gelişim), with the docstring of the central palette acknowledging the drift but the migration never finishing.

The codebase has the bones of a design system. It needs the migration to be carried through.
