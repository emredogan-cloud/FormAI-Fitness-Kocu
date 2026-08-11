# FormAI — Next Product Evolution Roadmap

**Created:** 2026-08-11 · **Baseline:** `1.0.0+39`, branch `main`, migrations 001–027 applied.
**Supersedes nothing.** `TESTERS_COMMUNITY_PRODUCT_ROADMAP.md` (18 phases, phases 1–14
done, 11 deferred) is the *previous* programme and stays closed. This document is the
new one, covering the founder brief of 2026-08-11.

---

## 0. What the baseline audit actually found

Five findings changed the shape of this roadmap versus the brief's suggested phase list.
They are recorded here because each one saves a future session from re-deriving it.

### 0.1 The icon divergence is a source-asset bug, not a pipeline bug

The Android icon pipeline is *correct and healthy*. `flutter_launcher_icons` is
configured, the adaptive trio exists, the manifest points at `@mipmap/launcher_icon`,
and every density is populated. The bug is one level up: **the source image it is
pointed at is the wrong artwork.**

| surface | asset | what it depicts |
| --- | --- | --- |
| installed launcher | `tool/app_icon.png` → `mipmap-*/launcher_icon.png` | a photographic **marketing scene** — two figures, a holographic skeleton, and the words "AI FITNESS COACH" |
| Play Store listing | `playstore-new-ASO/FINAL/*/app-icon-512.png` | the purple **"F" logomark** |

The Play Console icon was replaced during the recent ASO refresh (commit `b216fb9`,
"the icon's white stripe"). The native icon pipeline was never re-pointed at the new
artwork, so the store and the launcher have simply been showing two different images
since that refresh. Nothing about mipmaps, manifests or adaptive layers needs
investigating — they faithfully render the wrong input.

A second-order problem: **`playstore-new-ASO/` is gitignored** (`.gitignore:125`).
The canonical F artwork therefore exists nowhere in version control. Phase 1 must
import it into a tracked path before it can be a build input.

There is also a third, unrelated icon in `tool/app_icon_source_formai.png` — a purple
running figure. It is not the store icon and not the launcher icon. The brief names
the **F** explicitly, so the F wins; the runner is left in place untouched.

### 0.2 Automatic device language already ships — only the screen has to go

Workstream D is largely built. `lib/core/providers/locale_provider.dart` already
models `null` as *follow the device* (not as a stand-in for Turkish), `deviceLocale()`
already reads `platformDispatcher.locales`, and `main.dart:747` already resolves the
device locale against the supported set by language code with a documented fallback.
The account-sync carry-over across reinstalls is built too.

So Phase 3 is **not** "implement locale detection". It is: delete the mandatory
onboarding language step, and settle the fallback question below. The manual override
in Settings already exists and stays.

**Open decision (Phase 3):** the current fallback for an unsupported device locale is
`kSupportedLocales.first` = **Turkish**, because that list is also the picker's render
order and Turkish is the home market. The brief asks for **English**. A French or
German user is far likelier to read English than Turkish, so the brief is right on
product grounds — but the fix must *decouple fallback from picker order* rather than
reorder the list, or the picker changes as a side effect. Phase 3 introduces an
explicit `kFallbackLocale`.

### 0.3 The bottom navigation already has five tabs, and the brief's layout deletes a shipped feature

The brief proposes: `Workout · Nutrition · Calories · Progress · Profile`.

The app currently ships: `Workout · Nutrition · Progress · Community · Profile`.

The brief's five-tab layout has no slot for **Community** — squads, leaderboards and
challenges, the entire output of Phases 12 and 13 of the previous programme. Adopting
it verbatim would silently remove a shipped feature from navigation.

The brief anticipates this: *"Use the actual existing navigation architecture if a
better arrangement is required."* Phase 7 therefore treats the nav shape as a decision
to be made and documented, not a given. `dashboard_screen.dart:824` carries a long
note explaining why five items already forced a custom bar (a fixed
`BottomNavigationBar` shows every label, and "Antrenman" does not fit in 72 dp) — the
current bar shows **only the selected item's label**, in a pill. That design is what
makes a sixth destination arithmetically survivable at all. Phase 7 evaluates:

- **(a) six tabs** — preserves everything; 60 dp per slot; the one-label-at-a-time
  design absorbs it, and `TourTargets.navItemRect`'s equal-slice arithmetic still holds.
- **(b) Calories nested under Nutrition** — no nav change; weaker discovery for a
  headline feature.
- **(c) displace Community to Profile** — matches the brief's layout exactly; costs a
  shipped feature its front-door placement.

### 0.4 The AI backend pattern the calorie feature needs already exists

`supabase/functions/coach-chat/index.ts` is a working, shipped, server-side Anthropic
integration: `ANTHROPIC_API_KEY` is read from the function environment and **never
leaves the server**, the client holds no model key, and the function already handles
locale-aware prompting, model/token caps via env, and error mapping. `lib/` contains
zero references to any AI provider — by design.

The calorie scanner is the same shape (image in, structured nutrition out) and should
be a sibling function, not a new architecture. This substantially de-risks Phases 6–10
and is the main reason the architecture recommendation in
`docs/CALORIE_TRACKING_RESEARCH.md` lands where it does.

### 0.5 Nutrition domain foundations exist and should be reused

`nutrition_calculator_service.dart`, `macro_target.dart` and the recipe/ingredient
models already encode macro maths and targets. The calorie tracker consumes daily
targets and macro arithmetic — it should reuse these rather than introduce a parallel
nutrition model.

---

## 1. Phases

Every phase ends with: tests → `dart format` → `flutter analyze` → all 9 CI gates →
build → **physical-device walk** → fix → commit → push → CI green. A phase with a red
gate or a failed device walk is not complete.

| # | phase | state | gate that proves it |
| --- | --- | --- | --- |
| 0 | Baseline audit + roadmap + traceability | this document | — |
| 1 | Canonical F app icon | | device launcher + recents + app info + release AAB |
| 2 | Production onboarding performance | | measured before/after on a clean install |
| 3 | Automatic device language | | tr / en / unsupported device walk |
| 4 | Growth & advertising strategy | | document review |
| 5 | Calorie market + technology research | | document review |
| 6 | Calorie architecture + backend | | migration applied, RLS tested, function deployed |
| 7 | Calorie UI + navigation | | device walk, nav decision recorded |
| 8 | Camera capture | | permission grant/deny on device |
| 9 | AI food recognition | | real photos on device |
| 10 | Nutrition estimation + editing | | correction flow on device |
| 11 | Meal logging + dashboard | | totals update on device |
| 12 | History / analytics / corrections | | device walk |
| 13 | Turkish + English localization | | ARB coverage gate + live switch on device |
| 14 | Privacy / security / cost hardening | | RLS tests, retention verified, cost ceiling proven |
| 15 | Full integration QA + release | | full regression + AAB |

### Sequencing note

Phases 1–3 are independent of each other and of the calorie programme; they are
shipped first because each fixes a defect in the *currently published* app. Phases 4–5
are research and gate the calorie build. Phases 6–15 are one feature programme and are
strictly ordered.

**Phase 6 has an external dependency the founder must clear:** the `food-scan` edge
function needs `ANTHROPIC_API_KEY` present in the Supabase function environment (the
same secret `coach-chat` already uses) and a nutrition-database decision. Both are
recorded in the traceability matrix as founder actions.

---

## 2. Traceability matrix

Every requirement in the founder brief maps to exactly one phase. `⧗` marks work not
yet started.

### Workstream A — app icon

| founder requirement | phase | files / components | tests | device validation |
| --- | --- | --- | --- | --- |
| Investigate whole Android icon pipeline | 1 | `android/app/src/main/res/**`, `AndroidManifest.xml:37`, `pubspec.yaml:281` | — | — |
| Determine why installed ≠ Play icon | 1 | root cause in §0.1 | — | — |
| Use the existing official F icon, no approximation | 1 | `playstore-new-ASO/FINAL/*/app-icon-512.png` → tracked `tool/` | asset-presence test | visual compare vs store listing |
| One canonical icon | 1 | `tool/app_icon.png` + `_bg` + `_fg` regenerated | — | launcher, recents, app info |
| Validate launcher / recents / app info | 1 | — | — | ✔ device |
| Validate release APK + AAB | 1 | — | — | ✔ install release build |
| Manifest references | 1 | `AndroidManifest.xml` | — | — |
| Remove obsolete references | 1 | stale `mipmap-*/ic_launcher.png` | — | — |

### Workstream B — onboarding performance

| founder requirement | phase | files / components | tests | device validation |
| --- | --- | --- | --- | --- |
| Reproduce before assuming | 2 | production build, clean device | — | ✔ clean install |
| Measure cold start / first frame / transitions / jank | 2 | `flutter run --profile`, `adb shell am start -W`, frame timings | — | ✔ |
| Measure each SDK init | 2 | `main.dart` bootstrap | — | ✔ |
| Compare clean vs existing, cold vs warm | 2 | — | — | ✔ |
| Fix root cause, not symptoms | 2 | TBD by measurement | regression test | ✔ |
| Regression tests | 2 | `test/` | ✔ | — |

### Workstream C — growth strategy

| founder requirement | phase | deliverable |
| --- | --- | --- |
| Paid acquisition analysis (§3.1) | 4 | `docs/FORM_AI_GROWTH_AND_ADVERTISING_STRATEGY.md` §2 |
| Free / low-cost channels (§3.2) | 4 | §3 |
| Marketing funnel (§3.3) | 4 | §4 |
| Creative strategy + prohibited claims (§3.4) | 4 | §5 |
| Budget scenarios A–D (§3.5) | 4 | §6 |
| Tracking (§3.6) | 4 | §7 |
| "What I would do first" 30/60/90 (§3.7) | 4 | §8 |
| **No in-app advertising** | 4 | constraint — nothing shipped into `lib/` |

### Workstream D — device language

| founder requirement | phase | files / components | tests | device validation |
| --- | --- | --- | --- | --- |
| Automatic device locale | 3 | already built — `locale_provider.dart`, `main.dart:747` | existing | ✔ tr + en device |
| Unsupported locale → English fallback | 3 | new `kFallbackLocale` | unit test | ✔ set device to fr |
| Remove mandatory language screen | 3 | `onboarding_screen.dart:402`, `steps/language_step.dart` | widget test | ✔ clean install |
| Keep manual change in Settings | 3 | settings sheet | existing | ✔ live switch |
| Test all localized surfaces | 3 | — | ARB coverage gate | ✔ walk |

### Workstream E — calorie tracking

| founder requirement | phase | files / components | tests | device validation |
| --- | --- | --- | --- | --- |
| Market + technology research first | 5 | `docs/CALORIE_TRACKING_RESEARCH.md` | — | — |
| Architecture comparison A–D + recommendation | 5 | same, §3–4 | — | — |
| Backend + migration + RLS | 6 | `supabase/migrations/028_*.sql` | RLS tests | ✔ writes |
| `food-scan` edge function | 6 | `supabase/functions/food-scan/` | — | ✔ |
| Cost controls (§12) | 6, 14 | size cap, compression, timeout, retries, rate limit | unit | ✔ |
| Calorie UI per reference | 7 | `lib/features/calories/**` | widget | ✔ |
| Bottom-nav destination | 7 | `dashboard_screen.dart` — **decision, see §0.3** | widget | ✔ |
| Camera capture | 8 | capture screen | widget | ✔ grant + deny |
| AI recognition | 9 | scan service | unit | ✔ real food |
| Portion / macro estimation + editing | 10 | result screen | unit + widget | ✔ correction |
| Never present uncertainty as truth (§8) | 9, 10 | confidence model | unit | ✔ low-confidence path |
| Meal logging + daily totals | 11 | providers | unit | ✔ |
| History / analytics / corrections | 12 | history screen | widget | ✔ |
| tr + en, no hardcoded strings (§14) | 13 | ARB | ARB gate + hardcoded-string gate | ✔ live switch |
| Privacy: retention, EXIF, RLS, disclosure (§13) | 14 | storage policy, privacy doc | RLS tests | ✔ |
| Full QA matrix (§16) | 15 | — | full suite | ✔ full matrix |
| Release AAB (§17) | 15 | — | — | ✔ |

### Founder / external actions (cannot be done from this repo)

| action | needed by | why |
| --- | --- | --- |
| Confirm `ANTHROPIC_API_KEY` in Supabase function env | 6 | `food-scan` cannot run without it; `coach-chat` already uses it |
| Approve nutrition-database choice | 6 | licensing + Turkish food coverage — see research doc |
| Upload the new icon to Play Console *if* it ever diverges again | 1 | the store icon is already the F; the app is what changes |
| Approve the navigation decision in §0.3 | 7 | it affects a shipped feature's placement |

---

## 3. Decisions log

| # | decision | rationale |
| --- | --- | --- |
| D1 | The **F** logomark is canonical, not the runner in `tool/app_icon_source_formai.png` | the brief names the F, and the F is what the store already shows |
| D2 | Import the F into tracked `tool/` rather than un-ignore `playstore-new-ASO/` | that directory holds founder-private store material; `.gitignore:125` is deliberate and `git add -A` has leaked files from it before |
| D3 | Locale fallback becomes an explicit constant, not a reordering of `kSupportedLocales` | the list doubles as picker order; reordering would change the picker as a side effect |
| D4 | Calorie AI runs server-side in a Supabase edge function | matches `coach-chat`; keeps the model key off the device |
| D5 | Reuse `nutrition_calculator_service` / `macro_target` | a second macro model would drift from the first |
