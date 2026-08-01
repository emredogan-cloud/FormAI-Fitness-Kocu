# RESUME GUIDE

Read this first. It is written so a session with no memory of the
previous one can continue without re-analysing the repository.

**Last updated:** 2026-08-01, end of Phase 6.

---

## 1. Where we are

**Roadmap:** `TESTERS_COMMUNITY_PRODUCT_ROADMAP.md` — 18 phases, 5 waves.
Autonomous execution: no approval between phases. Each phase ends with
one `PHASE_NN_COMPLETION_REPORT.md`. Final deliverable at the very end:
`FORMAI_MASTER_COMPLETION_REPORT.md`.

| phase | state | report |
| --- | --- | --- |
| 1 · Rate & feedback loop | done | `PHASE_01_COMPLETION_REPORT.md` |
| 2 · Dynamic walkthrough I | done | `PHASE_02_COMPLETION_REPORT.md` |
| 3 · First-workout tutorial | done | `PHASE_03_COMPLETION_REPORT.md` |
| 3b · Phase-3 leftovers | done | `PHASE_3B_COMPLETION_REPORT.md` |
| 4 · Feature flags + disclosure | done | `PHASE_04_COMPLETION_REPORT.md` |
| 5 · i18n | done except 2 device surfaces | `PHASE_05_COMPLETION_REPORT.md` |
| **6 · English launch** | **done** — see §2.1 for what is founder-side | `PHASE_06_COMPLETION_REPORT.md` |
| 7 · Content & AI localization | **not started** | — |

**Branch:** `main`. **Build:** `1.0.0+26`.

---

## 2. Start here

### 2.1 What Phase 6 left for someone else

**Migration 012 is written but not applied.** `supabase/migrations/
012_user_locale.sql` adds `locale` to `user_metrics`. The app degrades
correctly without it — the sync fails, a breadcrumb is logged, the local
preference still works — but the reinstall carry-over does nothing until
it runs. See §7 for how to run the CLI on this box.

**The Premium/Pro naming split needs a product decision.** The copy sells
"Premium" in 13 keys and "Pro" in 6, the RevenueCat product is
`FormAI Pro`, and a plan badge says "PRO required". A user can be sold
Premium and then told they need PRO. It is visible on one screen at once
in the profile tab. Recorded in `docs/i18n/GLOSSARY.md`; it touches the
store listing, so it is not an engineering call.

**English screenshots and feature graphic**, and pasting
`docs/store/LISTING_EN.md` into Play Console → Manage translations. The
listing copy is written. See its "Still outstanding" section.

**A native-speaker read of the English.** It is a reviewed, internally
consistent draft, not proofread copy. The store listing is the highest-
leverage hour.

**Two device surfaces still unverified**, both carried from Phase 5:
the paywall interior (auth-gated; adb sign-in taps still do not
register) and a clean-install onboarding — which now also means seeing
the language step as an actual first screen. Both need `adb uninstall`
or a working sign-in, and both destroy the session everything else
depends on, so do them last.

### 2.2 Then Phase 7

Content & AI localization. Read the roadmap for the definition. The
single most important thing before English actually converts is NOT in
Phase 7 though — it is the **unit toggle**. `unit_system.dart` converts
and is tested, but nothing exposes it, and a US user reading `178 cm`
looks like a bug rather than a gap.

## 3. Current numbers

```
analyze                     0 issues
tests                       899
hardcoded-string gate       0 in 0 files  (allowlist 244, printed per entry)
ARB                         1454 keys · tr 100% · en 100% · all referenced
locales shipped             tr, en
pseudo-locale sweep         18 surfaces × 3 viewports, now scrolled through
English sweep               17 funnel + 5 app surfaces × 2 text scales
RTL sweep                   16 surfaces
CI                          green
build                       1.0.0+26 · APK 133.8 MB
working tree                clean except pre-existing untracked founder files
```

`macos/Flutter/GeneratedPluginRegistrant.swift` has been modified since
before this session started. It is **not ours** — leave it.

---

## 4. How to verify anything

```bash
flutter analyze                                   # must be 0 — CI fails on infos too
flutter test                                      # 899
dart format --output=none --set-exit-if-changed lib test tool
dart run tool/check_hardcoded_strings.dart        # ratchet, currently 0
dart run tool/check_hardcoded_strings.dart --list # every flagged line
dart run tool/arb_coverage.dart --strict          # parity, plurals, EN audit
dart run tool/gen_pseudo_localizations.dart --check
```

All of these are CI steps. `flutter analyze` exits 1 on **info**-level lints,
which is how CI was red for four commits before this session noticed.

---

## 5. Gotchas that cost real time

1. **CI Flutter is 3.44.8, local is 3.41.9.** Newer framework assertions
   and lints cannot fire locally. *Local green ≠ done.* Always confirm
   CI. This has bitten four times: an `ExpansionTile` in a
   `DecoratedBox`, an orphaned `_EmptyState`, an unused ML Kit import,
   and six `curly_braces_in_flow_control_structures` infos.
2. **`dart format` moves trailing comments.** `// i18n-ignore` must be on
   the literal's own line *after* formatting. If the line is too long,
   hoist the literal to a named constant, or reorder `||` operands so
   the marked literal is not last.
3. **Localising a literal invalidates every enclosing `const`**, and the
   analyzer reports the innermost position. Loop: analyze → strip →
   repeat. The scratch `fixconst.sh` automates it.
4. **Widget tests need `localizationsDelegates`.** Missing ones throw
   "Null check operator used on a null value" from `AppLocalizations.of`.
   Adding the delegates makes the harness render the *same* Turkish, so
   every original assertion must still pass. If an assertion needs
   rewording, that is a real copy change — think about it.
5. **adb.** `adb devices` empty → `kill-server` / `start-server`.
   Displayed screenshot 923×2000 vs device 1080×2340 → **×1.17** for
   taps. `keyevent 111` dismisses a bottom sheet. `input text` breaks on
   spaces. Blind-tapping through a screen silently dismisses a
   `SpotlightTour` — any tap advances it — burning the one-shot.
6. **The founder's other app** `com.ehliyetegitim.ehliyet_akademi` steals
   foreground focus: `adb shell am force-stop` it before verifying.
7. **The local build is upload-key signed.** If the installed build came
   from Play, `install -r` fails `INSTALL_FAILED_UPDATE_INCOMPATIBLE` and
   you must `adb uninstall` first — which loses the session and forces a
   19-step onboarding re-walk. +24 installed over +23 cleanly, so both
   are currently upload-signed.
8. **`dart format` also moves an `// i18n-ignore` that follows an
   opening brace**, not just a long line — `if (x) { // i18n-ignore`
   becomes a comment on the block's first line. When a marker will not
   stay put, hoist the literal to a named top-level constant; that is
   what `auth_error_messages.dart` does now.
9. **An overflow is reported from `paint`, not layout.** A viewport
   paints its visible area plus a 250 px cache extent, so a broken
   widget further down a scroll view is silently clean. `scrollThrough`
   in `test/support/layout_probe.dart` is why the sweeps see it.
10. **Widening the gate means adding a SIGNAL, not removing an
    exclusion.** Un-excluding a literal still leaves it failing the
    Turkish and label tests, so the count stays at zero and looks fine.
    Prove any widening with a synthetic probe file under `lib/`.
11. **Never source `.env.local`.** It is freeform notes, not dotenv, and
   sourcing it *executes* `flutter build apk`.

---

## 6. Architecture decisions from Phase 5

- **One string = one ARB key = one whole sentence.** Never concatenate
  localised fragments; clause order is not universal. When part of a
  sentence needs styling or a tap target, keep the sentence whole and
  split it at render time with `core/utils/text_span_split.dart`.
- **Copy in a `const` catalogue** becomes `String Function(AppLocalizations)`
  and the collection drops `const`. Tokens stay literal.
- **Three things are not copy**, each marked `// i18n-ignore` with a
  reason: data identity (values that come from Supabase), prompt
  scaffolding (never rendered; Phase 7 does per-locale personas
  server-side), and diagnostics (the gate skips these automatically).
- **`core/utils/app_copy.dart` is the one locale source for tree-less
  surfaces** — notifications, home widget, TTS. `main.dart`'s
  `localeResolutionCallback` assigns it.
- **Pseudo-localisation lives in `test/`**, generated from the generated
  localisations class. Not a third ARB — that would put a second
  ~1300-method class in the release binary and a resolvable language
  code in `supportedLocales`.
- **Layout assertions are "no overflow", not "these pixels".** No image
  goldens; reasoning in `docs/i18n/README.md`. Phase 6 held to this
  against the roadmap's "10 goldens" and met the intent with 22 surfaces
  asserting no-overflow and no-Turkish instead.

## 6b. Architecture decisions from Phase 6

- **`Locale?` where null means follow the device.** "Never asked" and
  "chose Turkish" are different states; the first tracks a phone whose
  language may change. Choosing device-follow stores the token `system`
  rather than clearing the key, so an explicit reset is durable.
- **The picker applies live.** Someone who cannot read the current
  language should not have to trust a label they cannot parse.
- **`deviceLocale()` for "what would happen if you had not chosen".**
  `Localizations.localeOf` returns the active locale, which is the
  override when there is one.
- **Personas are authored per locale, never translated**, and selection
  is server-side so a language ships without an app release. The prompt
  scaffolding — including the summariser — goes with the persona: its
  output becomes the coach's memory, so summarising in the wrong
  language poisons every later turn.
- **American English**, recorded in `docs/i18n/GLOSSARY.md`. The Phase 6
  draft mixed both varieties and read unproofed.
- **The gate is bilingual.** An English literal in `lib/` is as wrong as
  a Turkish one.

---

## 7. Migrations

`001`–`011` applied to production and verified live (history, RLS on 9
tables, seeded flags matching compiled defaults, anon read 200 / write
401).

**`012_user_locale.sql` is written and NOT applied.** It adds `locale`
to `user_metrics` for the reinstall carry-over. The app degrades
correctly without it.

Supabase CLI notes: run it from a scratch dir holding a copy of
`supabase/`; the direct DB host is IPv6-only so use the **session
pooler**; there is no `psql` on this box — a venv with `psycopg2` is the
introspection tool.

---

## 8. Known limitations

- **The practice rep and the "Seni görüyorum" success stage have never
  been seen on a device.** Both need a person standing ~2 m back doing a
  squat. Not drivable over adb. Carried since Phase 3.
- **`RequiredView` is defined and tested but not applied per exercise** —
  needs catalogue view metadata; belongs with a content pass.
- **English has not been read by a native speaker.** It is a reviewed,
  internally consistent draft with accurate key descriptions.
- **The paid tier is called two things.** "Premium" in 13 keys, "Pro" in
  6, `FormAI Pro` in RevenueCat, "PRO required" on a plan badge. Needs a
  product decision — see `docs/i18n/GLOSSARY.md`.
- **Units are metric-only in the UI.** `unit_system.dart` converts
  correctly and is tested (including the 12-inch carry, so it can never
  render `5'12"`), but no toggle exposes it and the physical-data wheels
  are labelled `cm`/`kg` directly.
- **Content is not translated.** Migration 011 added the columns;
  nothing is written to them. Phase 7.
- **`Positioned` with explicit `left:`/`right:`** remains in a few
  decorative overlays. `PositionedDirectional` when next touched.
- **Google Sign-In is broken** and is a founder-side Google Cloud SHA-1
  registration task, not an engineering one. Email and guest work.
  Details in `FORMAI_CONFIGURATION_MASTER_GUIDE.md` §2.

---

## 9. Files that matter

```
tool/check_hardcoded_strings.dart      the ratchet + allowlist (read its header)
tool/arb_coverage.dart                 parity, unused keys, plural audit
tool/gen_pseudo_localizations.dart     generates test/support/pseudo_localizations.dart
tool/hardcoded_strings_baseline.json   per-file counts; currently empty

lib/l10n/app_en.arb                    TEMPLATE — values AND @key metadata
lib/l10n/app_tr.arb                    values only (house convention)
lib/core/utils/text_span_split.dart    splitHighlighted / splitLinked
lib/core/utils/pseudo_locale.dart      pseudoLocalize
lib/core/utils/app_copy.dart           locale for tree-less surfaces
lib/core/utils/unit_system.dart        metric/imperial, storage always metric

test/support/layout_probe.dart         sweepPseudoLayouts / sweepRtlLayout
test/i18n/pseudo_locale_sweep_test.dart
test/i18n/rtl_readiness_test.dart
test/i18n/english_locale_sweep_test.dart  17 funnel surfaces, in English
test/i18n/english_app_sweep_test.dart     5 post-onboarding surfaces
test/i18n/locale_resolution_test.dart     the policy + the hot switch
test/support/locale_probe.dart            expectNoTurkish — the second detector

docs/i18n/README.md                    the runbook — read before touching a string
docs/i18n/GLOSSARY.md                  never-translate + legally load-bearing claims
docs/i18n/TEXT_IN_IMAGES.md            verdict: no image carries localisable text
docs/i18n/ADDING_A_LOCALE.md           what a second locale costs
docs/store/LISTING_EN.md               English store copy + what is founder-side
tool/coach_eval.md                     the 12 scenarios, now in both languages
```

---

## 10. Devices

- **Redmi `AYXSUKIVJVPZ7HPZ`** (M1908C3JGG, Android 11, 1080×2340,
  **×1.17** for taps read off a screenshot; `uiautomator` dumps are
  already in real coordinates) — the primary. Online, `1.0.0+26`
  installed, device language Turkish.
- **Huawei `89U4C18908003735`** (ANE-LX1, Android 9, 1080×2280, ×1.14,
  animation scale 0.5) — **no network**, so guest sign-in cannot
  complete and it only covers offline surfaces. It does exercise the
  onboarding chat's offline fallback, which the Redmi never reaches. Its
  nav bar eats taps below raw y≈2150.
