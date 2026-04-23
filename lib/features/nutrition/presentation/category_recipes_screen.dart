import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/error_card.dart';
import '../domain/models/recipe.dart';
import '../providers/nutrition_provider.dart';
import 'widgets/recipe_tags.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _proteinColor = Color(0xFF4DA6FF);

/// Dedicated "all recipes in this meal category" screen pushed via
/// `/nutrition/category/:type`. Reads the same `recipesProvider` the
/// nutrition tab uses, filters by category, and renders a scrollable
/// list. Tapping a card opens the existing [RecipeDetailScreen] with
/// `context.push('/recipe', extra: recipe)`.
class CategoryRecipesScreen extends ConsumerWidget {
  const CategoryRecipesScreen({super.key, required this.categoryType});

  /// Route path parameter. One of: `breakfast`, `lunch`, `dinner`,
  /// `snack`, `dessert`. Unknown values render an empty state rather
  /// than crashing.
  final String categoryType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(recipesProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B12),
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          _titleFor(categoryType),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
      ),
      body: recipesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: _neon),
        ),
        error: (err, st) {
          debugPrint('CategoryRecipesScreen error: $err\n$st');
          return ErrorCard(
            message: 'Tarifler yüklenirken bir sorun oluştu.',
            onRetry: () => ref.invalidate(recipesProvider),
          );
        },
        data: (recipes) {
          final filtered = _filter(recipes, categoryType);
          if (filtered.isEmpty) {
            return _EmptyCategoryState(category: categoryType);
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _CategoryRecipeCard(
              recipe: filtered[index],
            ),
          );
        },
      ),
    );
  }

  /// Maps the route param to the Turkish AppBar title. Unknown values
  /// fall back to a generic "Tarifler" so a malformed deeplink still
  /// renders a sensible header.
  static String _titleFor(String type) {
    switch (type.toLowerCase()) {
      case 'breakfast':
        return 'Kahvaltı Tarifleri';
      case 'lunch':
        return 'Öğle Yemeği Tarifleri';
      case 'dinner':
        return 'Akşam Yemeği Tarifleri';
      case 'snack':
        return 'Ara Öğün Tarifleri';
      case 'dessert':
        return 'Sporcu Tatlıları';
      default:
        return 'Tarifler';
    }
  }

  /// Lenient filter — the seed mixes `main` / `lunch` / `dinner` for
  /// main meals, so lunch shows both and dinner shows both. Snack and
  /// breakfast also accept Turkish aliases.
  static List<Recipe> _filter(List<Recipe> recipes, String type) {
    final normalized = type.toLowerCase();
    return recipes.where((r) {
      final t = r.mealType.toLowerCase();
      switch (normalized) {
        case 'breakfast':
          return t == 'breakfast' || t == 'kahvalti' || t == 'kahvaltı';
        case 'lunch':
          return t == 'lunch' || t == 'main';
        case 'dinner':
          return t == 'dinner' || t == 'main';
        case 'snack':
          return t == 'snack' || t == 'atistirmalik' || t == 'atıştırmalık';
        case 'dessert':
          return t == 'dessert' || t == 'tatli' || t == 'tatlı';
        default:
          return false;
      }
    }).toList();
  }
}

class _CategoryRecipeCard extends StatelessWidget {
  const _CategoryRecipeCard({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/recipe', extra: recipe),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: 0.04),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 110,
                child: _Thumb(imageUrl: recipe.imageUrl),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      RecipeTagsStrip(
                        recipe: recipe,
                        maxTags: 2,
                        compact: true,
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(
                            Icons.local_fire_department,
                            color: _neon,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${recipe.calories} kcal',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.fitness_center,
                            color: _proteinColor,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${recipe.protein}g Protein',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.imageUrl});
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: Colors.white10,
      alignment: Alignment.center,
      child: const Icon(Icons.restaurant, color: Colors.white54, size: 28),
    );
    final src = imageUrl;
    if (src == null || src.isEmpty) return fallback;
    return Image.network(
      src,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : Container(color: Colors.white10),
    );
  }
}

class _EmptyCategoryState extends StatelessWidget {
  const _EmptyCategoryState({required this.category});
  final String category;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _neon.withValues(alpha: 0.12),
              border: Border.all(color: _neon.withValues(alpha: 0.4)),
            ),
            child: const Icon(
              Icons.restaurant_menu,
              color: _neon,
              size: 44,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Bu kategoride henüz tarif yok.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Yeni tarifler yakında ($category).',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
