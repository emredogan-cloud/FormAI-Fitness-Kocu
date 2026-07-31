# Phase 5 — Internationalisation

**Status: engineering complete. Device validation partial — see §7.**

Build `1.0.0+24` · analyze 0 · 849 tests · hardcoded-string gate **0 in 0
files** · ARB **1390 keys, 100 % referenced and 100 % resolved**.

Roadmap: `TESTERS_COMMUNITY_PRODUCT_ROADMAP.md`, Wave 2.
Commits: parts 1–18 (earlier sessions) and parts 19–36, `b4cfa64…HEAD`.

---

## 1. What Phase 5 was for

Not "add English". FormAI ships Turkish and will keep shipping Turkish.
Phase 5 was about removing the reason a second language is a rewrite:
1,900 Turkish string literals welded into widget trees, with no way to
tell which ones a user could actually see.

The deliverable is a **claim that can be checked**: every user-facing
string in `lib/` is in ARB, and CI fails if that stops being true.

---

## 2. Extraction

| | |
| --- | --- |
| gated literals at the start of this session | 283 in 14 files |
| gated literals now | **0 in 0 files** |
| ARB keys | 1390 (was 1028) |
| allowlisted, with a written reason | 204 |

The allowlist is three entries, each printed on every gate run so an
exclusion can never look like progress:

- `lib/features/admin/` (106) — staff-only content-ops panel, router-gated
  on the `admin` claim.
- `lib/features/workout/data/workout_repository.dart` (98) — the seeded
  exercise catalogue. Data identity that mirrors database rows; Phase 7
  localises it through the `*_i18n` columns migration 011 added. Putting
  it in ARB would fork the catalogue.
- `lib/scripts/` — developer CLI output.

### The surfaces closed this session

Act 3 (89) · the AI report and prediction screen (45) · the hook, name
chat and post-paywall showcase (53) · consent, commitment and social
proof (43) · the paywall (50).

The paywall went last on purpose. It is the revenue surface and it
carries store-compliance copy; a mistake there costs money or a
rejection.

---

## 3. What the gate could not see

Three times this phase, widening the scanner found strings that were
shipping untranslated while the report said zero. Each is worth
recording, because the pattern is the point.

**Escape sequences.** The literal pattern rejected anything containing a
backslash, so every `'İKİ\nSATIR'` was invisible. Three real strings:
the coach's speech bubble, the AI-report title, and the share hashtags.
Widening it also surfaced `shareRecipe`, whose entire payload — intro,
macros, both headings, the referral line, the mail subject — was
hardcoded Turkish.

**Interpolation.** The pattern also rejected anything containing `$`.
That is not a small exclusion in a fitness app: "Gün 12 tamamlandı!",
"3 günlük seri", "450 kcal kaldı", "Set 2 / 4". **69 strings**, all in
shipped screens.

One of them was broken. `plan_detail_screen` rendered

```
'İleri Seviye $_categoryLabel(AppLocalizations.of(context)) Antrenmanları'
```

which interpolates the method *tear-off* and prints the rest as literal
text. The premium section heading had been showing
`Closure: (AppLocalizations) => String (AppLocalizations.of(context))`
since it was localised. Nothing caught it until the scanner widened.

**Enum names.** Found on a device, not by a tool: the live workout HUD
rendered `CrunchState.name.toUpperCase()`, so a Turkish user watched
**UNKNOWN** sit beside their rep counter until the pose analyser locked
on. An enum name is an identifier; it had never been copy, so nothing
was looking for it.

The gate now reads interpolated literals, with two exemptions that keep
it useful rather than noisy: a statement that is a logger, an assert, a
throw or a RegExp is diagnostic; and a literal made only of
interpolations and punctuation is composition of already-localised
values. Without those, 236 flags would have been ~170 log lines and the
gate would have been muted inside a week.

---

## 4. Decisions worth keeping

**Sentences, never fragments.** Clause order is not universal. The hero
title was three `TextSpan`s with the accent colour pinned to the middle
line, which is where Turkish puts the noun and English does not. It is
now one ARB sentence with the highlight as a placeholder, split at
render time by `core/utils/text_span_split.dart`. Same treatment for the
legal line, the paywall disclosure and Form's acknowledgment lines.

Both helpers fail soft, and that is tested: a fragment the translation
dropped is simply not styled or linked, and the sentence still renders.

**Tokens are not copy.** `belly_burn`, `sedentary`, `dongu` — persisted
state and analytics join keys. They stay literal, and a test asserts the
gender step still stores an enum after all its copy moved.

**Data identity is not copy.** A `case` value that comes from Supabase is
content. The nutrition filter compared against `recipe.tags`; localising
it would have emptied every recipe list with no error at all.

**Prompt scaffolding is not copy.** The coach's context block and the
onboarding prompts are never rendered. Per-locale prompts are Phase 7's
job, server-side, keyed on the `locale` every coach-chat request has
been threading since part 1.

**Store-formatted values come from the store.** The trial CTA said
"₺0,00 karşılığında dene" with the lira sign and Turkish decimal comma
in Dart. It now quotes the introductory price the store reports; a test
drives the paywall with a USD offering and asserts no lira reaches the
screen.

**Numbers live inside the string.** "%12 Tamamlandı" puts the percent
sign in front and English puts it after. No amount of `'$percent% '`
gets that right in both.

---

## 5. Pseudo-localisation, and the six layouts it broke

`tool/gen_pseudo_localizations.dart` generates a wrapper — into `test/`,
not `lib/` — that runs all 1390 messages through `pseudoLocalize`:
bracketed and ~40 % longer, roughly what German does to Turkish. A pseudo
ARB would have meant a second ~1300-method class in the release binary
for a debug-only feature, plus a real language code in
`supportedLocales` a device could resolve to. CI checks the wrapper is
in step; a stale one renders new keys un-inflated and the sweep stops
testing them while staying green.

18 surfaces × 3 viewports (393×851, 320×640, 393×851 @ 1.3 text scale).
Six failed the first run:

| surface | failure |
| --- | --- |
| consent screen | 549 px past the bottom — on a screen that cannot be dismissed |
| social-proof step | 202 px past the bottom |
| Başla capability badge + sample-score row | horizontal overflow at 320 px |
| Act-3 option card | 2 px over its fixed height with a long label *and* helper |
| early-access strip | 433 px off the right edge |
| highlight-carousel title | pushed its body out of a fixed card |
| weekly-dot pill | 126 px of dots in a 108 px slot — seven days, six visible |

The last one predates translation entirely.

Two harness bugs were worth fixing properly, because both sent me
looking for bugs at sizes that never had one: taking exceptions one at a
time reported the second overflow against the *next* viewport, and
pumping each case over the previous tree made the frame where the old
size meets the new text scale overflow on its own.

**No image goldens**, deliberately. The signal they add over the sweep is
small; the maintenance cost and the CI-versus-workstation font
differences are not. Recorded in `docs/i18n/README.md` rather than left
as a silent omission.

---

## 6. RTL, plurals, docs

**RTL** — 16 surfaces render right-to-left in CI. The conversions were
narrower than the raw counts suggested: of 134 `EdgeInsets.fromLTRB`
only 12 were asymmetric, and a symmetric one is already
direction-agnostic. Changed: those 12, 7 directional `EdgeInsets.only`,
one `TextAlign.right`, 19 widget alignments. Gradient `begin:`/`end:`
stay `Alignment` — a gradient is decorative and Flutter has no
directional form.

This is readiness, not support, and the test says so. Rendering
right-to-left does not prove a screen reads well in Arabic; it proves
the tree does not assume a direction in a way translation can never
repair.

**Plurals** — 98 messages take an int. 19 English ones named the thing
being counted and would have read "1 exercises"; they carry ICU `plural`
blocks now. Turkish stays invariant — it takes no plural agreement after
a numeral, which is exactly the case the block exists to express rather
than guess at. `arb_coverage` gained a plural audit that **reports**
rather than fails: "{value} kg" is invariant in every language, so the
judgement stays with a person. It lists 22, all correctly invariant.

**Docs** — `docs/i18n/`: the pipeline runbook, a glossary (never-translate
terms, fixed translations, and the claims that are legally load-bearing),
the text-in-images inventory, and what a second locale actually costs.

The image inventory records a **verdict**, not just a list: no bundled
asset carries localisable text, so a second locale needs zero design
work. Worth keeping true; the rule that keeps it true is one line.

---

## 7. Device validation — partial

Build `1.0.0+24` installed on the Redmi (`AYXSUKIVJVPZ7HPZ`,
1080×2340). Verified live:

- **dashboard** — weekly goal `0/3 egzersiz`, `1. Gün`, `0/30 Gün`, tips,
  coach card. All localised, no bracket artefacts, no `Closure:`.
- **plan detail** — `1. gün` … `30. gün`, `%14 Tamamlandı`,
  `7 Egzersiz`, `Premium ile aç` on the locked days.
- **live workout** — set indicator, framing hint, rest overlay
  (`DİNLENME ZAMANI`, `Set 1 / 3`, `SIRADAKİ`), exit dialog.
- **nutrition onboarding sheet** — `Son 4 adım`.

**Two defects found on the device, both fixed:**

1. **`UNKNOWN` beside the rep counter** (§3). Now
   `BEKLİYOR` / `AŞAĞI` / `YUKARI`, with a test that asserts the enum
   name can never render again.
2. **Selected nutrition goal card overlapped its own subtitle.** With a
   photo the text column is ~55 % of the card, so a wrapping label plus a
   two-line helper exactly fills the fixed height — and the 1.02
   selected-state scale pushes it into a collision. The helper drops to
   one line on photo cards.

**Not yet walked on a device**: nutrition tab, progress tab, profile,
discovery hub, help centre, badges, paywall, and the full 19-step
onboarding from a clean install. The nutrition-preferences sheet is
modal and gates the other tabs; completing it needs a real interactive
pass rather than scripted taps.

That is the honest state. The engineering gates (analyze, 849 tests,
the string gate, ARB parity, both layout sweeps) are green and CI is
green; the device sweep is roughly a third done and is the first task
for the next session. `RESUME_GUIDE.md` says so and says where to start.

Also still open, carried from Phase 3 and unchanged by this phase: the
guided practice rep and the "Seni görüyorum" success stage have never
been seen on a device, because both need a person standing two metres
back doing a squat. Not drivable over adb.

---

## 8. Numbers

```
analyze                     0 issues
tests                       849  (was 791 at the start of this session)
hardcoded-string gate       0 in 0 files   (was 283 in 14)
ARB keys                    1390           (was 1028)
  referenced in lib/        1390 / 1390
  tr coverage               100.0%
  placeholder parity        clean
pseudo-locale sweep         18 surfaces × 3 viewports
RTL sweep                   16 surfaces
CI                          green
build                       1.0.0+24, APK 133.7 MB
```

## 9. What Phase 6 inherits

Everything needed to turn on a second language, and a written account of
what it would cost (`docs/i18n/ADDING_A_LOCALE.md`). Short version: the
English values exist and are well-formed but have not been read by a
native speaker; units are metric-only in the UI even though
`unit_system.dart` converts correctly and is tested; content lives in
Supabase and is Phase 7.

The one thing worth doing before any translation: **wire the unit
toggle.** A US user reading `178 cm` looks like a bug, not a gap.
