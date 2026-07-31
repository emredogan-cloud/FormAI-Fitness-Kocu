# Adding a locale

What a second language actually costs, written while the plumbing was
still fresh.

Phase 5 built the machinery. It did **not** ship a second language, and
the app still resolves Turkish for everyone — `_supportedLocales` in
`main.dart` declares `tr` only, on purpose. Turning that on is Phase 6.

---

## What is already done

- 1385 keys in ARB, every user-facing string in the app.
- `app_en.arb` is the template and carries a real English value for
  every key — machine-assisted, human-reviewable, not a placeholder.
- Placeholder parity is enforced by CI.
- English count messages carry ICU `plural` blocks.
- `localeResolutionCallback` is wired, and so is `app_copy.dart` for the
  surfaces with no widget tree.
- Every coach-chat request already sends its `locale`; the server has a
  `PERSONAS` registry keyed on it.
- Migration 011 added `*_i18n` columns and a coverage view for the
  content tables.
- No text is baked into any bundled image.
- Layout survives a 40 %-longer language and renders right-to-left.

## What is not

**The English values have not been reviewed by a native speaker.** They
are a translator's starting point, not a shippable locale. Treat
`app_en.arb` as a well-formed first draft with accurate descriptions —
that is genuinely most of the work, and it is not the last of it.

**Content is not translated.** Recipes, exercises and plans live in
Supabase. The columns exist (migration 011); nothing has been written to
them. That is Phase 7, and it is a content project, not an engineering
one.

**Units are metric-only in the UI.** `unit_system.dart` converts
correctly and is tested, but no toggle exposes it and the physical-data
wheels are labelled `cm` / `kg` directly. A US launch needs that wired
before it needs a single translated word.

**Formatting beyond dates.** `intl` handles month names. Number grouping
in the paywall's strikethrough price (`_scalePriceString`) is
hand-rolled for Turkish conventions — thousands `.`, decimals `,`. It
preserves whatever prefix the store gives it, so a `$` price stays
`$2,159.88`-shaped only by accident. Check it before shipping a
non-European locale.

---

## The steps

1. **Add `lib/l10n/app_xx.arb`.** Values only, no `@` entries.
2. **Translate.** Read `GLOSSARY.md` first. The `description` on each
   key in `app_en.arb` is there for exactly this.
3. `flutter gen-l10n`
4. **`dart run tool/arb_coverage.dart`.** Missing keys and — the one
   that matters — placeholder mismatches. A translation that drops
   `{count}` compiles fine and renders a sentence with a hole.
5. **Add the locale to `_supportedLocales` in `main.dart`.** Read
   `_onLocaleResolved` before you do; it is what assigns `app_copy`.
6. **Run the layout sweeps.** `test/i18n/pseudo_locale_sweep_test.dart`
   already proves the layouts survive +40 % — if the new language is
   longer than that, raise `kPseudoInflation` and fix what falls out.
7. **Walk the funnel on a device**, in the new locale, on a small
   screen. The pseudo sweep catches overflow; it does not catch copy
   that is grammatically fine and reads badly.

## Order of work, if it were me

The cost is not evenly spread.

1. **English review** — the values exist; a native reader turning a
   good draft into shippable copy is days, not weeks.
2. **Units** — a US locale reading `178 cm` is worse than an untranslated
   string, because it looks like a bug rather than a gap.
3. **Store listing and screenshots** — translated app, Turkish store
   page, is a conversion problem before it is a quality one.
4. **Content** (Phase 7) — the largest single cost, and the one that
   degrades most gracefully: an untranslated recipe title next to
   translated chrome is legible.
5. **Coach personas** — server-side, no app release needed, which is
   why the locale has been threaded on every request since Phase 5.
