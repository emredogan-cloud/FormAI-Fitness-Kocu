import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/widgets/cached_image.dart';
import '../domain/models/recipe.dart';
import '../providers/favorite_recipes_provider.dart';
import '../providers/nutrition_provider.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _heartRed = Color(0xFFFF4D6D);

/// Phase 56 Lite · "Favorilerim" — the user's saved recipes hub.
///
/// Two responsibilities:
///   1. Render the list of recipes the user has hearted from the
///      detail screen, with quick links back into each.
///   2. Generate a deduplicated shopping list across every favourite
///      and hand it to the OS share sheet via share_plus.
///
/// We don't yet have a structured `ingredients` column on the
/// `recipes` table — Phase 56 Lite is explicitly avoiding that
/// schema lift. Instead the export aggregates each favourite's
/// title + macro line + (when present) the free-text instructions
/// preamble so the user gets a usable list. When the catalogue grows
/// an `ingredients` column we can swap the body builder without
/// touching call sites.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoriteRecipesProvider);
    final recipesAsync = ref.watch(recipesProvider);
    final scheme = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorilerim'),
        backgroundColor: scheme.surface,
        elevation: 0,
      ),
      body: recipesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: _neon),
        ),
        error: (_, __) => _ErrorState(
          onRetry: () => ref.invalidate(recipesProvider),
        ),
        data: (allRecipes) {
          final saved = allRecipes
              .where((r) => favorites.contains(r.id))
              .toList(growable: false);
          if (saved.isEmpty) return const _EmptyState();
          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  itemCount: saved.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _FavoriteRow(recipe: saved[i]),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _exportShoppingList(saved),
                      icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                      label: const Text('Alışveriş Listesi Oluştur'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _neon,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportShoppingList(List<Recipe> recipes) async {
    AppHaptics.primaryCta();
    final body = _buildShoppingListBody(recipes);
    AnalyticsService.instance.shoppingListExported(recipeCount: recipes.length);
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: body,
          subject: 'FormAI · Alışveriş Listem',
        ),
      );
    } catch (e, st) {
      AppLogger.warning(
        'shopping list share failed: $e',
        category: 'favorites',
        data: {'stack': st.toString()},
      );
    }
  }

  /// Phase 57 · shopping-list body formatted to the PM's exact spec:
  ///
  ///     FormAI Öğün Malzemeleri
  ///     1) <Meal 1 Name>
  ///     Malzemeler:
  ///     - <Ingredient 1>
  ///     - <Ingredient 2>
  ///     2) <Meal 2 Name>
  ///     ...
  ///
  /// Per-recipe ingredients are sourced in priority order:
  ///   1. The structured `recipe.ingredients` text[] column when the
  ///      backend has migrated to it (Phase 57 schema bump).
  ///   2. Heuristic extraction from `recipe.instructions` — most
  ///      curated rows lead with a "Malzemeler:" section so we look
  ///      for that header and collect the bullets/lines beneath it.
  ///   3. A polite fallback line so the recipient sees the recipe
  ///      title + a "malzeme listesi yakında" placeholder rather than
  ///      an empty section.
  String _buildShoppingListBody(List<Recipe> recipes) {
    if (recipes.isEmpty) return 'Alışveriş listen boş.';
    final buf = StringBuffer()..writeln('FormAI Öğün Malzemeleri');
    for (var i = 0; i < recipes.length; i++) {
      final r = recipes[i];
      buf
        ..writeln('${i + 1}) ${r.title}')
        ..writeln('Malzemeler:');
      final items = _ingredientsFor(r);
      if (items.isEmpty) {
        buf.writeln('- (malzeme listesi yakında — tarif: formai://)');
      } else {
        for (final ing in items) {
          buf.writeln('- $ing');
        }
      }
    }
    return buf.toString().trimRight();
  }

  /// Resolves a clean ingredients list per recipe. Tries the
  /// structured column first; falls back to a "Malzemeler:" header
  /// scan inside `instructions`.
  List<String> _ingredientsFor(Recipe recipe) {
    if (recipe.ingredients.isNotEmpty) return recipe.ingredients;
    final raw = (recipe.instructions ?? '').trim();
    if (raw.isEmpty) return const [];
    final lines = raw.split(RegExp(r'\r?\n'));
    final extracted = <String>[];
    var inBlock = false;
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        if (inBlock) break; // blank line ends the ingredients block
        continue;
      }
      // Header detection: "Malzemeler" / "Malzemeler:" / "MALZEMELER".
      if (RegExp(r'^malzemeler\s*:?\s*$', caseSensitive: false)
          .hasMatch(trimmed)) {
        inBlock = true;
        continue;
      }
      // Method header ends the ingredients block.
      if (RegExp(r'^(yapılışı|hazırlanışı|tarif)\s*:?\s*$',
              caseSensitive: false)
          .hasMatch(trimmed)) {
        if (inBlock) break;
      }
      if (inBlock) {
        extracted.add(_stripBullet(trimmed));
      }
    }
    if (extracted.isNotEmpty) return extracted;
    // No "Malzemeler:" header found — try splitting the first sentence
    // on commas as a last-resort heuristic for short single-line
    // recipes ("2 yumurta, 1 dilim peynir, 1 yulaf"). 240-char guard
    // protects against dumping a paragraph as a single ingredient.
    final firstSentence = raw.split(RegExp(r'(?<=[.!?])\s+')).first;
    if (firstSentence.length > 240) return const [];
    final commaSplit = firstSentence
        .split(RegExp(r'[,;]'))
        .map((e) => _stripBullet(e.trim()))
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (commaSplit.length >= 2) return commaSplit;
    return const [];
  }

  String _stripBullet(String line) {
    return line.replaceFirst(RegExp(r'^[-•*•]\s*'), '').trim();
  }
}

class _FavoriteRow extends ConsumerWidget {
  const _FavoriteRow({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colors;
    final isDark = context.isDarkMode;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/recipe', extra: recipe),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color:
                isDark ? Colors.white.withValues(alpha: 0.04) : scheme.surface,
            border: Border.all(
              color: isDark ? Colors.white12 : scheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: _Thumb(imageUrl: recipe.imageUrl),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      recipe.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${recipe.calories} kcal · ${recipe.protein}g P · ${recipe.prepTimeMinutes} dk',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.65),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.favorite, color: _heartRed, size: 22),
                tooltip: 'Favoriden Çıkar',
                onPressed: () async {
                  AppHaptics.secondaryTap();
                  await ref
                      .read(favoriteRecipesProvider.notifier)
                      .toggle(recipe.id);
                },
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
      child: const Icon(Icons.restaurant, color: Colors.white54, size: 22),
    );
    final src = imageUrl;
    if (src == null || src.isEmpty) return fallback;
    return CachedImage(
      url: src,
      fit: BoxFit.cover,
      memCacheHeight: 200,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_border,
              size: 56,
              color: scheme.onSurface.withValues(alpha: 0.30),
            ),
            const SizedBox(height: 12),
            Text(
              'Henüz favori tarifin yok',
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Bir tarif aç ve kalp simgesine dokun. Burada listelenir; '
              'sonra alışveriş listesini tek tıkla paylaşabilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.60),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Tarif kataloğu yüklenemedi.',
            style: TextStyle(color: context.colors.onSurface),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Yeniden Dene')),
        ],
      ),
    );
  }
}
