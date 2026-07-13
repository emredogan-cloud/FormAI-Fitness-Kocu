import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/features/nutrition/domain/models/daily_meal_slot.dart';
import 'package:sixpack_ai/features/nutrition/domain/models/recipe.dart';
import 'package:sixpack_ai/features/nutrition/providers/daily_menu_provider.dart';
import 'package:sixpack_ai/features/nutrition/providers/nutrition_provider.dart';

/// Overrides [recipesProvider] with a fixed catalogue so the menu
/// generator runs against known rows instead of Supabase.
class _StubRecipes extends PaginatedRecipesNotifier {
  _StubRecipes(this._rows);
  final List<Recipe> _rows;

  @override
  Future<List<Recipe>> build() async => _rows;
}

Recipe _recipe({
  required String id,
  required String mealType,
  required int calories,
  int protein = 20,
  List<String> tags = const [],
}) {
  return Recipe(
    id: id,
    title: id,
    mealType: mealType,
    calories: calories,
    protein: protein,
    carbs: 40,
    fat: 12,
    prepTimeMinutes: 15,
    tags: tags,
  );
}

Future<ProviderContainer> _container({
  required List<Recipe> catalogue,
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(sp),
    recipesProvider.overrideWith(() => _StubRecipes(catalogue)),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final catalogue = <Recipe>[
    _recipe(
      id: 'meat-main',
      mealType: 'main',
      calories: 600,
      tags: ['Yüksek Protein'],
    ),
    _recipe(
      id: 'vegan-main',
      mealType: 'main',
      calories: 550,
      tags: ['Vegan'],
    ),
    _recipe(
      id: 'meat-breakfast',
      mealType: 'breakfast',
      calories: 450,
    ),
    _recipe(
      id: 'vegan-breakfast',
      mealType: 'breakfast',
      calories: 420,
      tags: ['Vegan'],
    ),
  ];

  test(
      'vegan preference → every planned meal carries a vegan tag when the '
      'catalogue has vegan candidates (P1-11: a vegan used to get meat '
      'mains because dietPreference was never read)', () async {
    final container = await _container(
      catalogue: catalogue,
      prefs: {
        'sixpack.user_metrics':
            '{"dietPreference":"vegan","mealFrequency":"3_ogun"}',
      },
    );
    final plan = await container.read(dailyMenuProvider.future);

    expect(plan, isNotEmpty);
    for (final meal in plan) {
      expect(
        meal.recipe.tags.any((t) => t.toLowerCase().contains('vegan')),
        isTrue,
        reason: '${meal.recipe.id} planned for a vegan without a vegan tag',
      );
    }
  });

  test(
      'diet filter degrades gracefully: no matching tags in the catalogue '
      '→ falls back to the full pool instead of an empty plan', () async {
    final noVegan = [
      _recipe(id: 'main-1', mealType: 'main', calories: 600),
      _recipe(id: 'breakfast-1', mealType: 'breakfast', calories: 450),
    ];
    final container = await _container(
      catalogue: noVegan,
      prefs: {
        'sixpack.user_metrics':
            '{"dietPreference":"vegan","mealFrequency":"3_ogun"}',
      },
    );
    final plan = await container.read(dailyMenuProvider.future);
    expect(plan, isNotEmpty);
  });

  test(
      'ketojenik accepts a real low-carb macro signal even without a keto '
      'tag', () async {
    final keto = [
      Recipe(
        id: 'low-carb-main',
        title: 'low-carb-main',
        mealType: 'main',
        calories: 500,
        protein: 35,
        carbs: 10, // ≤ 15 g → keto-eligible by macro
        fat: 30,
        prepTimeMinutes: 20,
      ),
      _recipe(id: 'carby-main', mealType: 'main', calories: 500),
      _recipe(
          id: 'keto-breakfast',
          mealType: 'breakfast',
          calories: 400,
          tags: ['Keto']),
    ];
    final container = await _container(
      catalogue: keto,
      prefs: {
        'sixpack.user_metrics':
            '{"dietPreference":"ketojenik","mealFrequency":"3_ogun"}',
      },
    );
    final plan = await container.read(dailyMenuProvider.future);
    final mains = plan.where((m) => m.slot != DailyMealSlot.breakfast).toList();
    expect(mains, isNotEmpty);
    for (final meal in mains) {
      expect(
        meal.recipe.carbs <= 15 ||
            meal.recipe.tags.any((t) => t.toLowerCase().contains('keto')),
        isTrue,
        reason: '${meal.recipe.id} is not keto-eligible',
      );
    }
  });

  test('standart diet keeps the whole catalogue eligible', () async {
    final container = await _container(
      catalogue: catalogue,
      prefs: {
        'sixpack.user_metrics':
            '{"dietPreference":"standart","mealFrequency":"2_ogun"}',
      },
    );
    final plan = await container.read(dailyMenuProvider.future);
    // 2_ogun → lunch + dinner, both resolved from the main pool.
    expect(plan.length, 2);
  });
}
