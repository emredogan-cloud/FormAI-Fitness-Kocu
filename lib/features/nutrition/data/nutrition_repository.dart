import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/recipe.dart';

/// Thin data-access layer over the Supabase `recipes` table. Kept
/// intentionally small — the calorie / macro math lives in
/// [NutritionCalculatorService], not here.
class NutritionRepository {
  NutritionRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String _table = 'recipes';

  /// Phase 48 · default page size for paginated fetches. 20 rows fits a
  /// 2-column grid 10-rows tall, which covers the user's first viewport
  /// even on tall phones with room to spare. The trailing pages are
  /// loaded on-demand once the user nears the bottom of the list.
  static const int defaultPageSize = 20;

  /// Phase 48 · cursor-paginated fetch.
  ///
  /// Replaces the unbounded `select()` that previously yanked the whole
  /// `recipes` table on every cold open. Now the UI requests one page
  /// at a time using `.range(from, to)` and the notifier accumulates
  /// pages as the user scrolls. Returns up to [limit] rows starting at
  /// offset [from]; an empty result indicates the caller has reached
  /// the end of the catalogue and should stop paginating.
  ///
  /// Order is `id` ascending so successive pages don't return
  /// duplicates when a recipe gets edited mid-pagination. The Supabase
  /// `.range(start, end)` upper bound is INCLUSIVE, hence
  /// `from + limit - 1`.
  ///
  /// Errors from the Supabase SDK (network, RLS denials, schema drift)
  /// propagate up so the caller's notifier can surface the failure
  /// instead of silently rendering an empty list.
  Future<List<Recipe>> fetchRecipes({
    int from = 0,
    int limit = defaultPageSize,
  }) async {
    final rows = await _client
        .from(_table)
        .select()
        .order('id', ascending: true)
        .range(from, from + limit - 1);
    return rows.map<Recipe>(Recipe.fromJson).toList(growable: false);
  }

  /// Phase 83 · sentinel route token used by `CategoryRecipesScreen` for
  /// the tag-based "Pratik & Ekonomik" bucket. Mirrors the constant in
  /// `category_recipes_screen.dart` — kept in sync manually because both
  /// sides need to recognise the same string and a shared constants file
  /// would be a layering churn we don't yet need.
  static const String budgetCategoryToken = 'budget';
  static const String budgetCategoryTagLabel = 'Pratik & Ekonomik';

  /// Phase 83 hotfix · server-side category fetch.
  ///
  /// Replaces the prior client-side flow where the paginated catalogue
  /// (page size 20, ordered by random UUID) was filtered after-the-fact
  /// in `_CategoryRecipesScreenState._filter`. With 35+ rows in the
  /// `recipes` table the budget rows scattered across pages — page 1
  /// could return zero matching tags, leaving the category screen stuck
  /// on an empty state because `_onScroll` only fires `loadMore()` when
  /// the user reaches the bottom of a list that, in the empty-filtered
  /// case, never grew tall enough to scroll.
  ///
  /// New shape: ask Postgres to do the filtering. For the five existing
  /// `meal_type` tokens (`breakfast` / `lunch` / `dinner` / `snack` /
  /// `dessert`) it's an `eq()`; for the Phase 83 `budget` sentinel it's
  /// `.contains('tags', ['Pratik & Ekonomik'])` which the supabase-flutter
  /// SDK translates into a `tags @> ARRAY['Pratik & Ekonomik']` predicate
  /// on the `text[]` column. Returns the complete filtered list because
  /// individual category sizes are bounded (today: <20 each, plausibly
  /// <100 long-term — well within a single round-trip budget).
  ///
  /// Phase 83 dashboard expansion · optional [mealTypeSubFilter]. The
  /// new "Pratik & Ekonomik" dashboard strip exposes five sub-cards
  /// (Kahvaltı / Öğle / Akşam / Tatlı Çeşitleri / Atıştırmalıklar) —
  /// each tap routes here with token `'budget'` AND a `meal_type`
  /// hint, producing the intersection
  /// `tags @> ARRAY['Pratik & Ekonomik'] AND meal_type = $sub`. Ignored
  /// for non-budget tokens (where the meal_type is already the
  /// primary filter).
  Future<List<Recipe>> fetchRecipesByCategory(
    String categoryToken, {
    String? mealTypeSubFilter,
  }) async {
    var query = _client.from(_table).select();
    if (categoryToken == budgetCategoryToken) {
      query = query.contains('tags', const [budgetCategoryTagLabel]);
      if (mealTypeSubFilter != null && mealTypeSubFilter.isNotEmpty) {
        query = query.eq('meal_type', mealTypeSubFilter);
      }
    } else {
      query = query.eq('meal_type', categoryToken);
    }
    final rows = await query.order('id', ascending: true);
    return rows.map<Recipe>(Recipe.fromJson).toList(growable: false);
  }
}
