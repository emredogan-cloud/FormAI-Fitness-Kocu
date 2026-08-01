import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/app_copy.dart';
import '../domain/models/recipe.dart';
import '../domain/recipe_localization.dart';

/// Thin data-access layer over the Supabase `recipes` table. Kept
/// intentionally small — the calorie / macro math lives in
/// [NutritionCalculatorService], not here.
class NutritionRepository {
  NutritionRepository({SupabaseClient? client, String? languageCode})
      : _client = client ?? Supabase.instance.client,
        _languageCode = languageCode;

  final SupabaseClient _client;

  /// Phase 7 · overridable for tests; otherwise read fresh from
  /// [AppCopy] on every fetch.
  final String? _languageCode;

  /// The language rows are resolved into.
  ///
  /// [AppCopy.locale] is the app's one locale source for code with no
  /// widget tree, which a repository is. Read per fetch rather than
  /// captured in the constructor: the language picker applies live, and
  /// a repository built at startup would keep serving the language the
  /// app opened in.
  String get _language => _languageCode ?? AppCopy.locale.languageCode;

  static const String _table = 'recipes';

  /// Phase 7 · every recipe read pulls its `recipe_ingredients` rows in
  /// the same round-trip.
  ///
  /// The alternative — ingredients only on the detail screen — was
  /// tempting and wrong. Three surfaces need them (detail, the
  /// favourites shopping-list export, the share sheet), two of those
  /// operate on recipes loaded by a *different* query, and the resulting
  /// "does this instance have ingredients?" ambiguity is exactly the
  /// class of bug that ships.
  ///
  /// The cost is small enough to state: 1,642 ingredient rows across 292
  /// recipes is ~5.6 per recipe, so a 20-row page carries ~110 short
  /// rows — single-digit kilobytes against images already measured in
  /// hundreds. Revisit if a recipe ever has fifty ingredients.
  static const String _selectWithIngredients = '*, recipe_ingredients(*)';

  /// Offline short-circuit (mirrors WorkoutRepository._fetchExercises):
  /// without it a recipe fetch on a dead interface waits out the full
  /// HTTP timeout (~30 s) before the UI's error state can render —
  /// the discovery strip looked like it was loading forever offline.
  Future<void> _throwIfOffline() async {
    final results = await Connectivity().checkConnectivity();
    final isOnline = results.any((r) => r != ConnectivityResult.none);
    if (!isOnline) {
      throw const NutritionOfflineException();
    }
  }

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
    await _throwIfOffline();
    // Store-submission S2b · the offline pre-check only catches a dead
    // interface; a captive portal / half-open link passes it and would
    // otherwise spin for the SDK's ~30 s HTTP timeout before the error
    // state can render. 10 s is generous for a 20-row page.
    final rows = await _client
        .from(_table)
        .select(_selectWithIngredients)
        .order('id', ascending: true)
        .range(from, from + limit - 1)
        .timeout(const Duration(seconds: 10));
    return _decode(rows);
  }

  /// Phase 83 · sentinel route token used by `CategoryRecipesScreen` for
  /// the budget bucket. Mirrors the constant in
  /// `category_recipes_screen.dart` — kept in sync manually because both
  /// sides need to recognise the same string and a shared constants file
  /// would be a layering churn we don't yet need.
  ///
  /// Note this is a *route* token and not the same value as the tag
  /// token it selects on; the route has said `budget` since Phase 83 and
  /// renaming it would break deep links for no gain.
  static const String budgetCategoryToken = 'budget';

  /// Phase 7 · the `recipe_tags` identity the budget route selects.
  /// Was the Turkish label `'Pratik & Ekonomik'` until migration 013
  /// split identity from copy — see `domain/recipe_tag_token.dart`.
  static const String budgetTagToken = 'budget_friendly';

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
  /// `.contains('tag_tokens', ['budget_friendly'])`, which the
  /// supabase-flutter SDK translates into a
  /// `tag_tokens @> ARRAY['budget_friendly']` predicate served by the
  /// GIN index migration 013 added. Returns the complete filtered list
  /// because individual category sizes are bounded (today: <20 each,
  /// plausibly <100 long-term — well within a single round-trip budget).
  ///
  /// Phase 7 · the predicate used to read `tags @> ARRAY['Pratik &
  /// Ekonomik']`. Selecting on a Turkish display string meant the
  /// catalogue could not be translated without breaking navigation;
  /// `tag_tokens` is identity and never moves.
  ///
  /// Phase 83 dashboard expansion · optional [mealTypeSubFilter]. The
  /// quick-meals dashboard strip exposes five sub-cards (breakfast /
  /// lunch / dinner / dessert / snack) — each tap routes here with token
  /// `'budget'` AND a `meal_type` hint, producing the intersection
  /// `tag_tokens @> ARRAY['budget_friendly'] AND meal_type = $sub`.
  /// Ignored for non-budget tokens (where the meal_type is already the
  /// primary filter).
  Future<List<Recipe>> fetchRecipesByCategory(
    String categoryToken, {
    String? mealTypeSubFilter,
  }) async {
    await _throwIfOffline();
    var query = _client.from(_table).select(_selectWithIngredients);
    if (categoryToken == budgetCategoryToken) {
      query = query.contains('tag_tokens', const [budgetTagToken]);
      if (mealTypeSubFilter != null && mealTypeSubFilter.isNotEmpty) {
        query = query.eq('meal_type', mealTypeSubFilter);
      }
    } else {
      query = query.eq('meal_type', categoryToken);
    }
    final rows = await query.order('id', ascending: true);
    // Phase 7 · `locale_scope` leads, it does not filter. A category
    // screen returns its complete bucket, so this is where the ordering
    // belongs; the paginated catalogue fetch deliberately keeps its
    // stable `id` order, because re-ranking each page in isolation would
    // interleave scopes rather than group them.
    return sortRecipesForLocale(_decode(rows), _language);
  }

  /// The one place a raw PostgREST row becomes a [Recipe], so the locale
  /// is applied exactly once per fetch instead of once per call site.
  List<Recipe> _decode(List<Map<String, dynamic>> rows) {
    final language = _language;
    return rows
        .map((row) => Recipe.fromJson(row, languageCode: language))
        .toList(growable: false);
  }
}

/// Thrown by the offline short-circuit so `AsyncValue.error` surfaces
/// instantly (instead of after the ~30 s HTTP timeout) and the UI can
/// render its retry state with an accurate message.
class NutritionOfflineException implements Exception {
  const NutritionOfflineException();

  @override
  String toString() => 'NutritionOfflineException: no network interface';
}
