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
}
