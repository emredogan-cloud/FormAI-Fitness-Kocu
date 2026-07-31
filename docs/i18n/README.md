# Localisation

FormAI ships Turkish. Every user-facing string lives in ARB, and the
build fails if that stops being true.

This directory is the runbook. Four files:

| file | what it answers |
| --- | --- |
| `README.md` (this) | how the pipeline works, and how to add or change a string |
| `GLOSSARY.md` | terms that are never translated, and terms with one fixed translation |
| `TEXT_IN_IMAGES.md` | every bundled asset with words baked into it |
| `ADDING_A_LOCALE.md` | what a second language actually costs |

---

## The shape of it

```
lib/l10n/app_en.arb        template — values AND the @key metadata
lib/l10n/app_tr.arb        Turkish — values only, no @ entries
        ↓  flutter gen-l10n  (config in l10n.yaml)
lib/l10n/app_localizations.dart          abstract class, 1385 members
lib/l10n/app_localizations_{en,tr}.dart  the per-locale implementations
```

`en` is the template because gen-l10n reads placeholder types and
descriptions from the template only. Turkish carries values and nothing
else — that is the house convention, and `tool/arb_coverage.dart`
enforces parity without needing the metadata duplicated.

Read a string with `AppLocalizations.of(context).someKey`. It is
non-nullable in this project (`nullable-getter: false`), so no `!`.

### Surfaces without a BuildContext

Notifications, the home-screen widget and TTS run outside the widget
tree. They read `core/utils/app_copy.dart`, which
`main.dart`'s `localeResolutionCallback` assigns when the locale
resolves. Do not reach for `AppLocalizations` there — there is no
context to reach it with.

---

## Adding or changing a string

1. **Name the key after what the string IS, not what it says.**
   `badgeFirstStepTitle`, not `badgeIlkAdim`. Rewording the copy must
   not force a key rename, because a key rename is a re-translation.
2. Add it to **both** ARBs. `app_en.arb` also needs an `@key` entry with
   a `description`, and `placeholders` if it takes any.
3. `flutter gen-l10n`
4. Use it. If you are replacing a literal, **the enclosing `const` has
   to go** — that is the single most common breakage, and the analyzer
   reports the innermost position, so stripping one often exposes
   another. Iterate: analyze → strip → repeat.
5. `dart run tool/gen_pseudo_localizations.dart` — regenerates the
   pseudo-locale wrapper. CI fails if you forget.
6. `flutter analyze && flutter test`

### Writing the description

The description is the only thing a translator has. Say where the
string appears and what constrains it. These earn their keep:

> "The 'both start switched off' promise is a KVKK Article 5
> commitment and the screen's own test asserts the default."

> "Turkish takes no plural agreement after a numeral, so the Turkish
> form is deliberately invariant."

> "#FormAI is the brand tag and never changes; the second is a campaign
> tag a translator should localise to something people in that language
> would actually search."

### Sentences, not fragments

Never build a sentence by concatenating localised pieces. Clause order
is not universal — Turkish puts the accented noun in the middle of
"Vücudunu **Yapay Zeka** ile Şekillendir" and English does not.

When part of a sentence needs different styling or a tap target, keep
the whole sentence in ARB with a placeholder, and split it at render
time:

```dart
children: splitHighlighted(
  l10n.act1HeroTitle(l10n.act1HeroTitleHighlight),
  l10n.act1HeroTitleHighlight,
  const TextStyle(color: AppColors.neon),
),
```

`core/utils/text_span_split.dart` has `splitHighlighted` (styling) and
`splitLinked` (tap targets). Both fail soft: a fragment the translation
dropped simply is not styled or linked, and the sentence still renders.

### Copy inside a `const` catalogue

A `const` list or map cannot hold a closure, so the entry holds a
lookup and the collection drops `const`:

```dart
typedef _Copy = String Function(AppLocalizations);

final List<_ShowcaseCardData> _kCards = [
  _ShowcaseCardData(title: (l) => l.showcaseFormTitle, ...),
];
```

Keep the **token** (`belly_burn`, `sedentary`) as a plain literal. It is
what gets persisted and what analytics joins on; translating it would
silently change the data.

---

## What is NOT copy

Three categories, and the distinction matters:

**Data identity.** A `case` value that comes from the database. The
nutrition filters compare against `recipe.tags`, which are Supabase row
values — localising them would have emptied every recipe list without
an error. Rule of thumb: *does the value come from the database?* If
yes it is content, and Phase 7 localises it through the `*_i18n`
columns added in migration 011. Mark it `// i18n-ignore`.

**Prompt scaffolding.** The instructions sent to the coach LLM are
never rendered. Per-locale prompts are Phase 7's job, server-side,
keyed on the `locale` every coach-chat request already threads. Marked,
not extracted.

**Diagnostics.** Log messages, assert reasons, regex sources. The gate
skips them automatically.

`// i18n-ignore` must sit **on the literal's own line**. A comment on
the line above does nothing. If the line is too long to hold the marker,
hoist the literal to a named constant — `dart format` will otherwise
move a trailing comment off the line and silently un-suppress it.

---

## The gates

Four, all wired into `.github/workflows/ci.yml`:

### `tool/check_hardcoded_strings.dart`

A ratchet. `tool/hardcoded_strings_baseline.json` records the count per
file; the build fails only when a file goes **up**. That is what made it
useful from the first commit instead of after the last one — a gate that
failed on 1,900 pre-existing violations on day one is a gate somebody
disables in week one.

It is currently at **0 in 0 files**.

Two allowlist entries, each with a written reason and both reported on
every run so an exclusion can never masquerade as progress:

- `lib/features/admin/` — staff-only content-ops panel, router-gated on
  the `admin` claim.
- `lib/scripts/` — developer CLI output.
- `lib/features/workout/data/workout_repository.dart` — the seeded
  exercise catalogue, which mirrors database rows.

Its heuristics have been wrong three times, and each fix found real
strings hiding behind the blind spot:
- scoped to `/presentation/` → missed ~540 strings including the live
  camera guidance;
- rejected literals containing a backslash → missed every `'İKİ\nSATIR'`;
- rejected literals containing `$` → missed 69 interpolated strings,
  one of which was rendering `Closure: (AppLocalizations) => String` on
  the plan screen.

If you widen it again, expect it to find something.

### `tool/arb_coverage.dart`

Missing keys, unused keys, **placeholder parity**, and a plural-readiness
audit. Placeholder parity is the one that matters most: a translation
that drops `{count}` still compiles, and renders a sentence with a hole.

The unused-key list doubles as an extraction check — an unused key means
a replacement did not land.

### `tool/gen_pseudo_localizations.dart --check`

The pseudo-locale wrapper is generated from the generated localisations
class. A stale wrapper renders new keys un-inflated, and the layout
sweep below silently stops testing them while staying green.

### `dart format --set-exit-if-changed`

Not an i18n gate, but it has broken CI twice during this work. Run it.

---

## Pseudo-localisation

`dart run tool/gen_pseudo_localizations.dart` writes
`test/support/pseudo_localizations.dart`, which wraps every message so
it comes back bracketed and ~40 % longer — roughly what German does to
Turkish.

It lives under `test/` deliberately. A pseudo ARB would mean a second
~1300-method class riding along in the release binary for a debug-only
feature, plus a real language code in `supportedLocales` that a real
device could resolve to. Wrapping the *result* rather than the ARB
template also means ICU has already run, so pseudo mode cannot break a
plural — only make a finished sentence longer.

`test/i18n/pseudo_locale_sweep_test.dart` renders 18 surfaces at
393×851, 320×640, and 393×851 at a 1.3 text scale, and fails on any
layout exception. It found six real overflows the first time it ran,
including a consent screen that ran 549 px past the bottom — on a screen
that cannot be dismissed.

The assertion is "no overflow", not "these pixels". Pinning geometry
against a machine-generated pseudo string would break on every copy edit
and teach everyone to regenerate goldens without reading them. That is
also why there are no image goldens here: the signal they would add over
the sweep is small, and the maintenance cost — plus font-rendering
differences between CI and a workstation — is not.

---

## RTL

`test/i18n/rtl_readiness_test.dart` renders the same surfaces
right-to-left.

This is readiness, not support. Rendering right-to-left does not prove a
screen reads well in Arabic — that needs a translator and a native
reader. It proves the widget tree does not assume a direction in a way
translation alone can never repair.

The conventions:

- `EdgeInsetsDirectional.fromSTEB` / `.only(start:, end:)` when the
  padding is asymmetric. Symmetric `EdgeInsets.fromLTRB(20, 4, 20, 20)`
  is already direction-agnostic — converting it is churn.
- `AlignmentDirectional.centerStart` / `.centerEnd` for widget
  alignment. Gradient `begin:` / `end:` stay `Alignment` — a gradient is
  decorative, and Flutter has no directional form for it.
- `TextAlign.start` / `.end`, never `.left` / `.right`.

Known remainder: `Positioned` is used with explicit `left:` / `right:`
in a handful of decorative overlays (glow rings, speech-bubble tails).
`PositionedDirectional` is the fix when those surfaces are next touched.

---

## Units

`core/utils/unit_system.dart` converts between metric and imperial with
exact factors, and **storage is always metric**. The imperial path is
tested — including the 12-inch carry, so it can never render `5'12"` —
but is not yet wired to a user-facing toggle. That is Phase 6's job,
alongside actually offering `en`.

The physical-data step still labels its wheels `cm` and `kg` directly.
Converting those pickers is a behaviour change, not an extraction, and
belongs with the unit toggle.

---

## Turkish specifics worth knowing

- **No plural agreement after a numeral.** "3 gün", not "3 günler". The
  Turkish forms of every count message are invariant on purpose; the
  English ones carry ICU `plural` blocks.
- **Suffixes attach to proper nouns with an apostrophe** and harmonise
  with the preceding vowel: `FormAI'ı`, `Gün 12'ün`. This is why those
  sentences are whole ARB strings rather than `'$name' + ' hedefi'`.
- **Month names come from `intl`**, which matches the old hand-written
  Turkish array exactly. Weekday names do **not** — the app uses a
  two-letter form ('Pt', 'Ça') that is a density choice, not the locale
  abbreviation, and `DateFormat('EEEEEE')` throws outright. Weekday
  labels live in ARB.
