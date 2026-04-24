import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/app_logger.dart';
import '../../../core/widgets/cached_image.dart';
import '../../../core/widgets/error_card.dart';
import '../domain/models/recipe.dart';
import '../providers/nutrition_provider.dart';
import 'widgets/recipe_tags.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _proteinColor = Color(0xFF4DA6FF);

/// Phase 47A · "Tüm Tarifler" discover screen.
///
/// Reuses the same filter chip catalogue as the Nutrition tab's
/// compact discovery strip (`Yüksek Protein / Düşük Kalori / Hacim /
/// Sıkılaşma / Vegan`) so users see a consistent filtering language
/// across the app. Reads from the same `recipesProvider` the tab
/// reads — no extra Supabase round-trip. The list is a 2-column grid
/// of recipe cards; every image goes through [CachedImage] so repeat
/// opens don't re-download.
class DiscoverRecipesScreen extends ConsumerStatefulWidget {
  const DiscoverRecipesScreen({super.key});

  @override
  ConsumerState<DiscoverRecipesScreen> createState() =>
      _DiscoverRecipesScreenState();
}

class _DiscoverRecipesScreenState extends ConsumerState<DiscoverRecipesScreen> {
  /// Null = no filter. Tapping the selected chip clears the filter.
  String? _activeFilter;

  static const List<String> _filters = [
    'Yüksek Protein',
    'Düşük Kalori',
    'Hacim',
    'Sıkılaşma',
    'Vegan',
  ];

  /// Exact-match on the raw selected tag. Trim is already done inside
  /// `Recipe._parseTags`, and `toLowerCase` is deliberately avoided
  /// (Turkish İ/I case folding is locale-dependent, and the UI + DB
  /// both ship identical Title Case labels).
  List<Recipe> _apply(List<Recipe> source) {
    final selectedTag = _activeFilter;
    if (selectedTag == null) return source;
    return source.where((r) => r.tags.any((t) => t == selectedTag)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final recipesAsync = ref.watch(recipesProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B12),
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Tüm Tarifler',
          style: TextStyle(
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
          AppLogger.error(
            'DiscoverRecipesScreen error',
            err,
            stackTrace: st,
            category: 'nutrition',
          );
          return ErrorCard(
            message: 'Tarifler yüklenirken bir sorun oluştu.',
            onRetry: () => ref.invalidate(recipesProvider),
          );
        },
        data: (recipes) {
          final filtered = _apply(recipes)
            ..sort((a, b) => b.tags.length.compareTo(a.tags.length));
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _FilterRow(
                  filters: _filters,
                  active: _activeFilter,
                  onTap: (label) => setState(() {
                    _activeFilter = _activeFilter == label ? null : label;
                  }),
                ),
              ),
              SliverToBoxAdapter(
                child: _ResultCount(
                  count: filtered.length,
                  filter: _activeFilter,
                ),
              ),
              if (filtered.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  sliver: SliverGrid.builder(
                    itemCount: filtered.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.7,
                    ),
                    itemBuilder: (context, index) =>
                        _DiscoverRecipeCard(recipe: filtered[index]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.filters,
    required this.active,
    required this.onTap,
  });

  final List<String> filters;
  final String? active;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final label = filters[index];
          final selected = label == active;
          return _FilterChip(
            label: label,
            selected: selected,
            onTap: () => onTap(label),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: selected
                ? _neon.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.04),
            border: Border.all(
              color: selected ? _neon : Colors.white24,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _neon.withValues(alpha: 0.35),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultCount extends StatelessWidget {
  const _ResultCount({required this.count, required this.filter});
  final int count;
  final String? filter;

  @override
  Widget build(BuildContext context) {
    final suffix = filter == null ? '' : ' · $filter';
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
      child: Text(
        '$count tarif bulundu$suffix',
        style: const TextStyle(
          color: Colors.white60,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _DiscoverRecipeCard extends StatelessWidget {
  const _DiscoverRecipeCard({required this.recipe});
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1.3,
                child: _Thumb(imageUrl: recipe.imageUrl),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      recipe.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    RecipeTagsStrip(
                      recipe: recipe,
                      maxTags: 2,
                      compact: true,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.local_fire_department,
                          color: _neon,
                          size: 12,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${recipe.calories}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.fitness_center,
                          color: _proteinColor,
                          size: 12,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${recipe.protein}g',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
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
      child: const Icon(Icons.restaurant, color: Colors.white38, size: 28),
    );
    final src = imageUrl;
    if (src == null || src.isEmpty) return fallback;
    return CachedImage(
      url: src,
      fit: BoxFit.cover,
      memCacheHeight: 300,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
              Icons.restaurant_menu_rounded,
              color: _neon,
              size: 40,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Bu filtreye uygun tarif bulunamadı.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Farklı bir etiket deneyebilir veya filtreyi kaldırabilirsin.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
