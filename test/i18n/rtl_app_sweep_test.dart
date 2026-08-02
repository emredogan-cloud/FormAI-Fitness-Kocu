import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/features/nutrition/domain/models/recipe.dart';
import 'package:sixpack_ai/features/nutrition/domain/models/recipe_ingredient.dart';
import 'package:sixpack_ai/features/nutrition/presentation/category_recipes_screen.dart';
import 'package:sixpack_ai/features/nutrition/presentation/discover_recipes_screen.dart';
import 'package:sixpack_ai/features/nutrition/presentation/favorites_screen.dart';
import 'package:sixpack_ai/features/nutrition/presentation/recipe_detail_screen.dart';
import 'package:sixpack_ai/features/nutrition/providers/nutrition_provider.dart';
import 'package:sixpack_ai/features/progress/data/body_metrics_repository.dart';
import 'package:sixpack_ai/features/progress/domain/models/body_metric.dart';
import 'package:sixpack_ai/features/progress/presentation/body_metrics_screen.dart';
import 'package:sixpack_ai/features/progress/providers/target_weight_provider.dart';
import 'package:sixpack_ai/features/referral/providers/referral_provider.dart';

import '../support/layout_probe.dart';

/// Roadmap Phase 8 (C13) · RTL past the paywall.
///
/// `rtl_readiness_test.dart` renders sixteen surfaces right-to-left and
/// every one of them is part of the onboarding funnel. The screens a
/// user spends the rest of their time in — the whole nutrition feature
/// Phase 7 built, among others — had never been rendered in either
/// direction by any automated pass. That is the wrong half of the app to
/// leave uncovered before claiming "ready to add Arabic without
/// structural work".
///
/// The raw counts make the risk look worse than it is: `lib/` has 127
/// `EdgeInsets.fromLTRB` call sites and **not one of them is
/// horizontally asymmetric**, so none of them mirrors wrong. What can
/// actually break is `Alignment.centerLeft` where
/// `AlignmentDirectional.centerStart` was meant, a `Positioned(left:)`
/// on a decorative overlay, and a `CustomPainter` that assumes it paints
/// from x=0 leftwards.
///
/// Rendering right-to-left does not prove these screens read well in
/// Arabic — that needs a translator. It proves the widget tree does not
/// assume a direction in a way translation alone can never repair.

const String _kFavKey = 'sixpack.favorite_recipe_ids';

Recipe _recipe({
  String id = 'r1',
  String title = 'Protein Bowl',
  String mealType = 'lunch',
  List<String> tagTokens = const ['high_protein', 'low_calorie'],
}) {
  return Recipe(
    id: id,
    title: title,
    mealType: mealType,
    calories: 420,
    protein: 32,
    carbs: 40,
    fat: 15,
    prepTimeMinutes: 12,
    tagTokens: tagTokens,
    instructions: 'MALZEMELER:\n- 100 g yulaf\n\nHAZIRLANIŞI:\n'
        '1. Karıştır ve servis et.',
    ingredientRows: const [
      RecipeIngredient(position: 1, name: 'yulaf', quantity: 100, unit: 'g'),
      RecipeIngredient(position: 2, name: 'süt', quantity: 200, unit: 'ml'),
    ],
  );
}

/// The paginated catalogue, stubbed so no page is ever requested.
class _StubRecipes extends PaginatedRecipesNotifier {
  _StubRecipes(this._seed);
  final List<Recipe> _seed;

  @override
  Future<List<Recipe>> build() async => _seed;
}

List<Recipe> _catalogue() => [
      _recipe(id: '1', title: 'Fıstık Ezmeli Protein Yulaf Ezmesi'),
      _recipe(id: '2', title: 'Proteinli Caprese Tabağı', mealType: 'snack'),
      _recipe(
        id: '3',
        title: 'Izgara Bonfile ve Közlenmiş Sebze',
        mealType: 'dinner',
        tagTokens: const ['bulking'],
      ),
      _recipe(
        id: '4',
        title: 'Chia Tohumlu Vegan Pancake',
        mealType: 'breakfast',
        tagTokens: const ['vegan', 'budget_friendly'],
      ),
    ];

/// Every nutrition surface reads the same handful of providers, so the
/// scope is built once rather than repeated per test.
ProviderScope _scope(SharedPreferences prefs, Widget child) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      referralCodeProvider.overrideWith((ref) async => 'TESTCODE'),
      recipesProvider.overrideWith(() => _StubRecipes(_catalogue())),
      tagFilteredRecipesProvider.overrideWith(
        (ref, token) async => _catalogue()
            .where((r) => r.tagTokens.contains(token))
            .toList(growable: false),
      ),
      categoryRecipesProvider.overrideWith((ref, key) async => _catalogue()),
    ],
    child: child,
  );
}

Future<SharedPreferences> _prefs([Map<String, Object> seed = const {}]) async {
  SharedPreferences.setMockInitialValues(seed);
  return SharedPreferences.getInstance();
}

void main() {
  testWidgets('recipe detail lays out right-to-left', (tester) async {
    final prefs = await _prefs();
    await sweepRtlLayout(
      tester,
      'Recipe detail',
      () => _scope(prefs, RecipeDetailScreen(recipe: _recipe())),
    );
  });

  testWidgets('discover grid lays out right-to-left', (tester) async {
    final prefs = await _prefs();
    await sweepRtlLayout(
      tester,
      'Discover recipes',
      () => _scope(prefs, const DiscoverRecipesScreen()),
    );
  });

  testWidgets('category list lays out right-to-left', (tester) async {
    final prefs = await _prefs();
    await sweepRtlLayout(
      tester,
      'Category recipes',
      () =>
          _scope(prefs, const CategoryRecipesScreen(categoryType: 'breakfast')),
    );
  });

  testWidgets('favourites lays out right-to-left', (tester) async {
    // Seeded so the list renders rows and the shopping-list CTA, rather
    // than the empty state — the empty state is the easy case.
    final prefs = await _prefs({
      _kFavKey: <String>['1', '3'],
    });
    await sweepRtlLayout(
      tester,
      'Favourites',
      () => _scope(prefs, const FavoritesScreen()),
    );
  });

  testWidgets('favourites empty state lays out right-to-left', (tester) async {
    final prefs = await _prefs();
    await sweepRtlLayout(
      tester,
      'Favourites (empty)',
      () => _scope(prefs, const FavoritesScreen()),
    );
  });

  // ─── Roadmap Phase 9 · body metrics ─────────────────────────────────
  //
  // Added the moment the surfaces existed rather than in a later sweep
  // pass, which is the lesson Phase 8 recorded: the nutrition screens
  // went a whole phase without either direction being rendered once.
  //
  // Populated AND empty, because they are different trees — the empty
  // state is a centred column and the populated one carries a chart, a
  // segmented control and a history list.

  testWidgets('body metrics lays out right-to-left', (tester) async {
    final prefs = await _prefs({
      TargetWeightNotifier.storageKey: 75.0,
    });
    await sweepRtlLayout(
      tester,
      'Body metrics',
      () => _bodyScope(prefs, _bodyEntries()),
    );
  });

  testWidgets('body metrics empty state lays out right-to-left',
      (tester) async {
    final prefs = await _prefs();
    await sweepRtlLayout(
      tester,
      'Body metrics (empty)',
      () => _bodyScope(prefs, const []),
    );
  });
}

/// A month of weekly weigh-ins plus a waist series, so the sweep renders
/// the measure selector, the chart, the trend readout and the history
/// list rather than a placeholder.
List<BodyMetric> _bodyEntries() {
  final today = BodyMetric.dayOf(DateTime.now());
  return [
    for (var week = 4; week >= 0; week--)
      BodyMetric(
        recordedOn: today.subtract(Duration(days: week * 7)),
        weightKg: 84 - (4 - week) * 1.0,
        waistCm: week.isEven ? 92 - (4 - week) * 0.5 : null,
        note: week == 0 ? 'sabah, aç karnına' : null,
      ),
  ];
}

ProviderScope _bodyScope(SharedPreferences prefs, List<BodyMetric> entries) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      bodyMetricsProvider.overrideWith((ref) async => entries),
    ],
    child: const BodyMetricsScreen(),
  );
}
