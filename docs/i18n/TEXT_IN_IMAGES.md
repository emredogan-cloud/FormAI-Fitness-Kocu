# Text baked into images

A string inside a `.webp` cannot be translated by editing an ARB file.
It needs a designer, a re-export, and a second copy of the asset per
locale. This is the inventory of what that would cost, taken during
Phase 5.

**Verdict: the shipped app has no localisable text in any bundled
image.** Everything below is either a photograph, an icon, or a
wordmark that is never translated. A second locale needs zero asset
work.

That is not luck — it is worth keeping. The rule below is cheap to
follow and expensive to retrofit.

---

## The rule

> If a word has to be readable, it renders in Flutter. Images carry
> subject matter, not sentences.

The one place this was violated and fixed: the Başla screen used to
ship `photos/onboarding_hero_start.webp`, artwork with the FormAI
wordmark baked in and cropped. It was replaced (closed-test hotfix T1)
with a native layout around a plain photograph, and the wordmark is now
a `Text` widget. The old asset is orphaned but left in place.

---

## Inventory

### `assets/illustrations/` — 6 files

| asset | content | text? |
| --- | --- | --- |
| `milestone_medal.webp` | medal glyph | none |
| `xp_gem.webp` | gem glyph | none |
| `showcase_ai_coach.webp` | coach illustration | none |
| `showcase_form_analysis.webp` | pose-analysis illustration | none |
| `showcase_nutrition.webp` | food illustration | none |
| `showcase_plan.webp` | calendar illustration | none |

The showcase cards deliberately put every word in Flutter beside the
image rather than in it — see `feature_showcase_screen.dart`.

### `photos/` — 54 files

Four groups, none of them text-bearing:

**People and food photography** (~40 files) — gender-selection portraits,
goal tiles, activity-level shots, diet tiles, meal photos, workout
cards, the coach portrait `PT_FORM.png`. Subject matter only.

**Body-type reference cartoons** (`kişiselleştirilmişplanda*`) — the
before/after silhouettes on the AI report. Line art, no labels; the
figures are annotated by Flutter text.

**Launcher and store icons** (`APP_ICON.png`, `APP_ICON_512.png`,
`tool/app_icon*.png`) — the FormAI mark. A wordmark, never translated.

**Orphans** — `onboarding_hero_start.webp` (superseded, see above),
`First_opening.png` and `APP_ICON.png` (design sources that still ship;
flagged to the founder in the Part-2 polish report as ~3.8 MB of
avoidable payload, deliberately not deleted here).

> `core/utils/media_url.dart` passes any `photos/…` path through from
> Supabase, so "no references in `lib/`" does **not** mean an asset is
> unused. Nothing in this inventory was deleted on that basis.

---

## If this changes

Adding a text-bearing image would mean:

1. one export per locale, named `foo_{locale}.webp`;
2. a resolver keyed on `Localizations.localeOf(context)`;
3. a fallback when the locale's variant is missing;
4. a line in this file.

Steps 1–3 are the reason step 0 — *put the words in Flutter* — is the
standing answer.
