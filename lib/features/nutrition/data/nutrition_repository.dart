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

  /// Returns every row from the `recipes` table, already parsed into
  /// [Recipe] instances. The list is unfiltered — UI layers filter by
  /// `mealType` or macro range as needed.
  ///
  /// Errors from the Supabase SDK (network, RLS denials, schema drift)
  /// propagate up so the caller's `FutureProvider` can surface the
  /// failure instead of silently rendering an empty list.
  Future<List<Recipe>> fetchRecipes() async {
    final rows = await _client.from(_table).select();
    return rows.map<Recipe>(Recipe.fromJson).toList(growable: false);
  }
}
