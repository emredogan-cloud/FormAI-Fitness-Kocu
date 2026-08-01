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

### `assets/illustrations/` — 9 files

| asset | content | text? |
| --- | --- | --- |
| `language_hero.webp` | language-picker artwork | none |
| `milestone_medal.webp` | medal glyph | none |
| `xp_gem.webp` | gem glyph | none |
| `showcase_ai_coach.webp` | deadlift photograph, pose mesh | **was not none — see below** |
| `showcase_form_analysis.webp` | kettlebell photograph | none |
| `showcase_nutrition.webp` | food photograph | none |
| `showcase_plan.webp` | lunge photograph | none |
| `showcase_emblem_coach.webp` | coach portrait in a ring | none |
| `showcase_emblem_nutrition.webp` | fork-and-leaf glyph | none |

The showcase cards deliberately put every word in Flutter beside the
image rather than in it — see `feature_showcase_screen.dart`.

**This audit was wrong once, and it is worth knowing how.**
`showcase_ai_coach.webp` was recorded as carrying no text. It carried
six English UI labels baked into the left third of the photograph —
`JOINT TRACKING`, `12/12 ACTIVE`, `POWER OUTPUT`, `842 W`, `RANGE OF
MOTION`, `FULL` — on a screen a Turkish user sees in their first minute
in the app. Phase 6 polish re-cropped the asset to remove them and
rebuilt the panels as Flutter widgets, so they translate.

The lesson is not "be more careful." It is that **this inventory is a
claim about pixels, and reading the filename is not checking it.** The
row said "coach illustration"; the file is a photograph with a HUD over
it. Open every asset when revising this table.

Two things now defend the rule where prose could not:

- `test/features/onboarding/presentation/feature_showcase_screen_test.dart`
  asserts the coach card's stat labels render in Turkish, which is only
  possible if they are widgets.
- The 30-day emblem is **painted**, not bundled, precisely because the
  supplied artwork had `30 DAYS` in it and the headline beside it says
  `30 gün`.

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
