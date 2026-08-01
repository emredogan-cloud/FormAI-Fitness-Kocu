# Phase 6 — English Launch & Language Preference

**Roadmap:** `TESTERS_COMMUNITY_PRODUCT_ROADMAP.md` § PHASE 6 · covers
R3.1 (first new language), R3.2, C29.

**Build:** `1.0.0+26` · **Branch:** `main`

---

## 1. What shipped

FormAI is no longer a Turkish app. `_supportedLocales` declares `en`,
every user-facing string resolves in both languages, and the user picks
between them in two places — the first screen of onboarding and a row in
Settings — with the change applying live and surviving a reinstall.

| Roadmap item | State |
| --- | --- |
| Full English localization (R3.1) | 1454 keys, 100% both ways, reviewed |
| Language picker as onboarding step 0 (R3.2, C29) | done |
| Language row in Settings (R3.2) | done |
| Smart default + override memory | done — device default, explicit choice wins, carried by `user_metrics.locale` |
| Fallback chain | done, with a caveat — see §5 |
| English store listing | copy written (`docs/store/LISTING_EN.md`); screenshots and feature graphic are founder-side |
| English coach persona | authored and wired |

---

## 2. The parts worth reading

### The language picker applies live

Step 0's own title, subtitle and CTA re-render in the language the user
just tapped. That is the whole design: someone who cannot read the
current language does not have to trust a label they can't parse — they
tap their language and watch the screen become readable. It also means
the hot-switch path is exercised by the first interaction in the
product, rather than by a settings screen most users never open.

Nothing is written until a row is actually tapped. Arriving on an
English phone, seeing English pre-selected and pressing continue leaves
the preference as *follow the device*. Accepting a default is not the
same act as choosing one, and only the second should pin a language
against a phone whose own language may change.

### `null` is a real state

`localeProvider` holds `Locale?`. Null means follow the device, and
"never been asked" is deliberately distinguishable from "chose Turkish":
the first tracks a device whose language may change tomorrow, the second
does not. Choosing to follow the device stores the token `system` rather
than clearing the key — a cleared key reads as never-asked, which would
let the account copy overwrite an explicit reset on the next launch.

### The account copy exists for exactly one case

Migration `012_user_locale.sql` puts `locale` on `user_metrics`. The
device copy stays authoritative while the app runs; the column serves
the reinstall — a user who picked English, reinstalled, and landed on a
Turkish-locale phone. Every sync failure is a breadcrumb rather than a
Sentry issue: offline and signed-out are normal conditions, and the
language still changed. Only the carry-over is lost.

### The coach was authored, not translated

`PERSONAS` in `coach-chat/index.ts` had a selection seam with nothing on
the other side of it — `startsWith("tr") ? "tr" : "tr"`. It now selects,
and an unknown locale falls back to Turkish rather than English, because
a locale with no persona is one whose UI already resolves to Turkish and
the coach must not be the one surface speaking differently.

Three things in the English persona are deliberately not literal: the
"use only Turkish-alphabet characters" instruction is gone rather than
rendered into something meaningless, *sıcak* becomes "on the user's
side" because English "warm" has drifted toward customer service, and
the forbidden-promise example is re-picked so a US reader recognises the
shape of the claim. The guardrails are identical in force: no invented
history, no invented set/rep numbers, no medical advice, no diagnosis,
no exaggerated promises.

The prompt scaffolding moved with the persona, and one piece of it
matters more than it looks. The summariser's output is stored on the
device and fed back as the coach's memory on later turns — so
summarising an English conversation with the Turkish summariser grounds
every future English reply in Turkish notes under a Turkish heading, and
the coach starts quoting itself in the wrong language. The summarize
call carries the locale too.

---

## 3. What the phase found

Phase 6 was supposed to be a translation phase. Most of its value turned
out to be defects that only became visible once a second language forced
someone to look.

### Blind spot #4 — the gate could not see ASCII Turkish

`_turkishSignal` recognised Turkish by its diacritics or by an
eighteen-word stopword list. It was silent on every Turkish word that is
pure ASCII and isn't one of those eighteen. `'Tema'` sat in the profile
tab's theme tile — a title on a settings screen — and the file reported
zero.

Widening to "shaped like a label, not a key" surfaced **107 literals, 69
of them real**:

- `'Rozetler'` — the badges screen title
- `'Tamamlanan'` / `'Bekleyen'` / `'Planlanan'` — the calendar legend
- Four separate `'DEVAM ET'` buttons
- Five body-feelings options, including `'Form bende kayboldu'`
- `'Beslenme'` and `'Profil'` in the bottom navigation bar
- `'Devam'` / `'Atla'` in the spotlight tour
- `'Boy (cm)'`, `'Kilo (kg)'`, `'Kopyala'`, `'Davet Kodu'`, `'Kullan'`
- A support email still going out with the pre-rename subject
  `'SixPack AI Destek'`

All of it would have rendered Turkish inside the English app. 57 new ARB
keys; the gate is now bilingual, so an English literal in `lib/` is as
wrong as a Turkish one. `--list` was added so the next extraction pass
does not have to re-derive the lines by hand.

### Blind spot #5 — the sweeps only saw the top of a scroll view

A `RenderFlex` reports its overflow from `paint`, and a viewport paints
only what is visible plus a 250 px cache extent. A broken widget far
enough down a scroll view is therefore silently clean.

This made **inflation actively counterproductive**. The welcome hero's
progress ring overflowed by 32 px at a 1.3 text scale in *both*
languages, and the pseudo sweep passed: its +40 % copy had pushed the
ring 328 px below the fold, out of the cache extent, where nothing
painted it. The English sweep caught it only because English is shorter
and left the ring 17 px down.

`scrollThrough` now drags every sweep to the end of its content. That
alone surfaced two more overflows immediately.

### Blind spot #6 — `%` placement is a language decision

Found on the device, not by a test. The progress tab rendered `%0` in
the English app because five screens built their percentage as
`'%$value'`, and Turkish writes the symbol before the number while
English writes it after.

The gate's composition rule was right that there is no *word* to
translate in `'%$value'`. It was wrong that there is nothing to
localise: the order is the localisation.

The first fix attempt did not work, and the way it failed is the lesson.
Un-excluding the literal from "pure composition" was not enough — it
then failed the Turkish test and the label test and was skipped anyway,
and the gate still reported zero. It had to become a positive *signal*.
A synthetic probe caught that; the real files, all now clean, would not
have.

### Five layout defects, none of them English-specific

Every one of these was broken in Turkish too. Nothing had looked.

| Screen | Defect | Fix |
| --- | --- | --- |
| Welcome hero | 72 px progress ring, contents needed 104 px at 1.3 scale | ring sized from the text scaler |
| AI report card | "AI READY" pill, 32 px over at 320 wide | `Flexible` |
| Pre-paywall summary | early-access line, 47 px over | `Flexible` |
| Badges grid | fixed `childAspectRatio`, 11 tiles overflowed at 1.3 | ratio divided by the text scaler |
| Suggestions CTA | pill label 53 px past its card | `Flexible` |

Three of the five are the same shape: a `Text` in a `Row` with no
`Flexible`. Two are the same shape as each other: a fixed-size box
holding text that scales. Both patterns are worth grepping for.

### The English draft was well-formed but inconsistent

No Turkish left in any value, every placeholder in step, and all the
compliance copy intact — the health disclaimer, the KVKK "both start
switched off" promise, the auto-renewal and trial terms, the "your video
never leaves your device" claim, the results disclaimer.

What it was not was consistent. 24 keys said "programme" and ten said
"program"; "analyses" sat beside "optimise"; "favourites" beside
"favorites"; "metres", "litres", "centre", "catalogue". Either variety
reads fine — the mixture reads like nobody proofread it. Normalised to
American English and written into `GLOSSARY.md` so the next translator
has a rule rather than a coin flip.

### One thing found and deliberately not fixed

The copy calls the paid tier **"Premium" in 13 keys and "Pro" in 6**,
while the RevenueCat product constant is `FormAI Pro` and a plan badge
reads "PRO required". A user can be sold Premium and then told they need
PRO. Naming it is a product decision that touches the store listing, so
it is recorded in `GLOSSARY.md` rather than resolved in a translation
pass. **This needs a founder decision before the English listing goes
live.**

---

## 4. Tests

**+50 tests** (849 → 899), against a roadmap minimum of +25.

| Suite | What it holds |
| --- | --- |
| `test/core/providers/locale_provider_test.dart` (13) | the default, the never-chosen/chose-Turkish distinction, persistence, decode of an unshipped or corrupted value, endonyms, the idempotence guard, and `deviceLocale()` including the ordered list Android actually sends |
| `test/features/onboarding/presentation/language_step_test.dart` (6) | every language offered and named in itself, the device pre-selected without being stored, tapping re-renders the screen, the tap is what persists, continuing without tapping leaves the device in charge |
| `test/i18n/english_locale_sweep_test.dart` (17) | 17 funnel surfaces rendered in English at 393×851, ×1.0 and ×1.3 — no overflow, no Turkish |
| `test/i18n/english_app_sweep_test.dart` (5) | the same, for five post-onboarding screens |
| `test/i18n/locale_resolution_test.dart` (6) | the resolution policy and the hot switch |
| `test/features/coach/coach_locale_test.dart` (2) | the coach follows the app, not the device |
| `test/features/.../onboarding_screen_test.dart` (updated) | routed through the new step 0 |

### On the roadmap's "10 goldens"

**Deliberately not image goldens**, consistent with the decision
recorded in `docs/i18n/README.md` one phase ago: pinning pixels against
machine-generated copy breaks on every edit and teaches the team to
regenerate goldens without reading them. The spirit of the requirement —
key screens verified in English at 393×851 — is met by 22 surfaces
asserting no-overflow and no-Turkish, which is a stronger claim than a
pixel diff and does not rot.

The `expectNoTurkish` probe is worth calling out as a *second detector*.
The hardcoded-string gate reads source and guesses which literals are
copy; this reads the frame and sees what a user would. They fail
differently, which is the point: the gate has now been wrong four times.

---

## 5. Known limitations

- **The fallback chain is half build-time.** The roadmap asks for
  missing key → English → Turkish → key name. The first two links are
  enforced by `arb_coverage` in CI (now `--strict`), not by a runtime
  mechanism — a missing key cannot ship. Only the last link runs on a
  device. "We have a runtime fallback" and "we have a build-time
  guarantee" are different promises and only the second is true here.
- **English has not been read by a native speaker.** It is a reviewed,
  internally consistent draft with accurate key descriptions. The store
  listing is the highest-leverage hour to spend on this.
- **Content is not translated.** Recipes, exercises and plan text still
  come from Supabase in Turkish. Migration 011 added the columns;
  nothing writes to them. That is Phase 7.
- **Units are still metric-only in the UI.** `unit_system.dart` converts
  correctly and is tested, but no toggle exposes it. A US user reading
  `178 cm` looks like a bug rather than a gap, and this is the single
  most important thing left before an English launch actually converts.
- **Migration 012 is written but not applied to production.** The app
  degrades correctly without it — the sync fails, a breadcrumb is
  logged, and the local preference still works — but the reinstall
  carry-over does nothing until it runs.
- **Screenshots and the feature graphic are Turkish.** Founder-side; see
  `LISTING_EN.md` § "Still outstanding".
- **The Premium/Pro naming split** — §3.

---

## 6. Device validation

Redmi `AYXSUKIVJVPZ7HPZ` (M1908C3JGG, Android 11, 1080×2340), build
`1.0.0+26`. Device language: Turkish, so every English render below is
an override rather than a default — which is the harder case.

The `uiautomator` semantics tree is the read surface, not screenshots:
Flutter paints to a canvas, so `content-desc` is what a screen reader
would get and therefore what is actually asserted.

### Walked

| Surface | Result |
| --- | --- |
| Profile → Settings, Turkish | `Dil / Türkçe` row present; `Tema`, `Sistem`/`Açık`/`Koyu` all localized |
| Language sheet, Turkish | `Uygulama dili` · `Cihaz dili — Şu anda Türkçe` · `Türkçe` · `English` |
| **Tap English** | sheet re-rendered in English **without closing** — `App language`, `Device language`, same process, no restart |
| Profile, English | `SETTINGS`, `Theme — Currently: Dark`, `Language — English`, `My favorites`, nav `Training / Nutrition / Progress / Profile` |
| Training tab, English | `Weekly goal`, `Your personal training program`, `START`, `Talk to Form, your AI coach`, `online` |
| Nutrition tab, English | `1272 kcal left`, `Protein / Carbs / Fat`, `Add now`, `Sat 1 August` |
| Progress tab, English | `Lv 1 · Novice · 0 XP`, `PROGRAM COMPLETION`, `0%`, `You're doing great — keep going! 💪`, `Don't break your streak!` |
| **Reset to Device language** | back to Turkish immediately; `Cihaz dili — Şu anda Türkçe` |
| Restart after reset | still Turkish — the preference persisted |

Newly extracted keys confirmed rendering live in both languages:
`navNutrition`, `navProfile`, `levelShort` (`Sv 1` → `Lv 1`),
`themeTileTitle`, `macroProteinChip`, `macroCarbChip`, `nutritionAddNow`,
`progressCompletionLabel`, `progressKeepGoing`, `progressDontBreakStreak`,
`coachStatusOnline`, `commonCopy`, `referralCodeLabel`.

### Found on the device, fixed, re-verified on `1.0.0+26`

1. **"Device language — Currently English"** on a Turkish phone with
   English selected. The row described the choice it exists to undo. It
   was reading `Localizations.localeOf`, which returns the *active*
   locale and therefore the override. Now `deviceLocale()` asks the
   platform. Re-verified: reads `Currently Türkçe` while the app is in
   English.
2. **`%0` on the progress tab.** Five screens built their percentage as
   `'%$value'`; Turkish puts the symbol before the number, English after.
   Every ARB percent key was already correct — these five never went
   through ARB. Now `percentValue`. Re-verified: reads `0%`.

### Confirmed but not fixed

**`Izgara Bonfile ve Közlenmiş Sebze`** — a Turkish recipe name inside
the English nutrition tab. This is the known limitation working exactly
as documented: content lives in Supabase and is Phase 7's job. Worth
having seen rather than assumed, because it is the most visible seam an
English user will hit.

### Not reachable in this pass

- **The paywall interior** — still auth-gated, and adb sign-in still
  does not register (carried from Phase 5; the gate itself is verified).
- **Clean-install onboarding in English**, including the language step
  as an actual first screen. Requires `adb uninstall`, which destroys
  the session the rest of this sweep depended on. The step is covered by
  six widget tests and by the English sweep at two text scales; what is
  missing is visual confirmation on glass.

---

## 7. Verification

```
flutter analyze                                   0 issues
flutter test                                      899
dart format --output=none --set-exit-if-changed   clean
dart run tool/check_hardcoded_strings.dart        0 in 0 files (allowlist 244)
dart run tool/arb_coverage.dart --strict          1454 keys · tr 100% · en 100%
dart run tool/gen_pseudo_localizations.dart --check  up to date
```

All six are CI steps. `arb_coverage` runs with `--strict` from this
phase on.
