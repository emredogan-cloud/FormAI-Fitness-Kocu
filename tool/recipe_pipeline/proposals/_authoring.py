"""Roadmap Phase 7 §5 · helper for authoring recipe proposals.

The proposal JSON the pipeline reads is verbose by design — it carries
both languages, per-ingredient quantities, and a step list per language.
Writing 100 of those by hand is how a typo gets into a macro. So the
briefs live in Python, compactly, and this turns them into the shape
`RecipeProposal.fromJson` parses.

`calories` is DERIVED, not authored: 4·protein + 4·carb + 9·fat, rounded
to the nearest 5. That is how a nutrition label is computed, and it means
the pipeline's macro-arithmetic check tests the thing it is for — that
the macros are internally consistent — rather than testing whether
somebody typed the sum correctly.
"""
import json
import sys

KCAL_P, KCAL_C, KCAL_F = 4, 4, 9


def ing(quantity, unit, name_en, name_tr, note_en=None, note_tr=None):
    """One ingredient. `quantity=None` means to-taste, stated explicitly."""
    row = {"name_en": name_en, "name_tr": name_tr}
    if quantity is None:
        row["to_taste"] = True
    else:
        row["quantity"] = quantity
    if unit:
        row["unit"] = unit
    if note_en:
        row["note_en"] = note_en
    if note_tr:
        row["note_tr"] = note_tr
    return row


def recipe(slug, title_en, title_tr, meal_type, cuisine, minutes, tokens,
           scope, p, c, f, ingredients, steps_en, steps_tr, image):
    if len(steps_en) != len(steps_tr):
        raise SystemExit(f"{slug}: {len(steps_en)} en steps, {len(steps_tr)} tr")
    calories = round((p * KCAL_P + c * KCAL_C + f * KCAL_F) / 5) * 5
    return {
        "slug": slug,
        "title_en": title_en,
        "title_tr": title_tr,
        "meal_type": meal_type,
        "cuisine": cuisine,
        "calories": calories,
        "protein": p,
        "carbs": c,
        "fat": f,
        "prep_time_minutes": minutes,
        "tag_tokens": tokens,
        "locale_scope": scope,
        "ingredients": ingredients,
        "steps_en": steps_en,
        "steps_tr": steps_tr,
        "image_prompt": image,
    }


def emit(recipes, path):
    slugs = [r["slug"] for r in recipes]
    if len(set(slugs)) != len(slugs):
        dupes = {s for s in slugs if slugs.count(s) > 1}
        raise SystemExit(f"duplicate slugs: {sorted(dupes)}")
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(recipes, fh, ensure_ascii=False, indent=1)
    by_meal = {}
    for r in recipes:
        by_meal[r["meal_type"]] = by_meal.get(r["meal_type"], 0) + 1
    print(f"wrote {len(recipes)} proposals to {path}", file=sys.stderr)
    print(f"  {by_meal}", file=sys.stderr)
