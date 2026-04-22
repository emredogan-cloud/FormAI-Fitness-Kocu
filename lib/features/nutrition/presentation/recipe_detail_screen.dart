import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/error_card.dart';
import '../domain/models/recipe.dart';
import '../providers/nutrition_provider.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _proteinColor = Color(0xFF4DA6FF);
const Color _carbsColor = Color(0xFF39FF14);
const Color _fatColor = Color(0xFFFFA726);

/// Full-bleed recipe view reached from `/recipe/:id`. Looks up the
/// recipe in the already-fetched `recipesProvider` cache so navigating
/// here doesn't trigger a second Supabase query. If the id isn't in the
/// catalogue (stale link, bad deeplink), a friendly "not found" card is
/// shown instead of a crash.
class RecipeDetailScreen extends ConsumerWidget {
  const RecipeDetailScreen({super.key, required this.recipeId});

  final String recipeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(recipesProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B12),
      body: recipesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: _neon),
        ),
        error: (err, st) {
          debugPrint('RecipeDetailScreen recipes error: $err\n$st');
          return ErrorCard(
            message: 'Tarif yüklenirken bir sorun oluştu.',
            onRetry: () => ref.invalidate(recipesProvider),
          );
        },
        data: (recipes) {
          final recipe = recipes.where((r) => r.id == recipeId).firstOrNull;
          if (recipe == null) return const _RecipeNotFound();
          return _RecipeBody(recipe: recipe);
        },
      ),
    );
  }
}

class _RecipeBody extends StatelessWidget {
  const _RecipeBody({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          backgroundColor: const Color(0xFF0B0B12),
          elevation: 0,
          leading: const _BackButton(),
          flexibleSpace: FlexibleSpaceBar(
            background: _HeroImage(recipe: recipe),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MealTypePill(mealType: recipe.mealType),
                const SizedBox(height: 12),
                Text(
                  recipe.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _MetaChip(
                      icon: Icons.schedule,
                      label: '${recipe.prepTimeMinutes} dk',
                    ),
                    const SizedBox(width: 8),
                    _MetaChip(
                      icon: Icons.local_fire_department,
                      label: '${recipe.calories} kcal',
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _MacroBreakdown(recipe: recipe),
                const SizedBox(height: 26),
                if ((recipe.instructions ?? '').trim().isNotEmpty) ...[
                  const Text(
                    'YAPILIŞI',
                    style: TextStyle(
                      color: _neon,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    recipe.instructions!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final url = recipe.imageUrl;
    final image = (url != null && url.isNotEmpty)
        ? Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallback(),
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : Container(color: Colors.white10),
          )
        : _fallback();
    return Stack(
      fit: StackFit.expand,
      children: [
        image,
        // Bottom fade keeps the title panel readable when it overlaps
        // the hero edge.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.85),
              ],
              stops: const [0.55, 1.0],
            ),
          ),
        ),
      ],
    );
  }

  Widget _fallback() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A3DFF), Color(0xFF4DA6FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.restaurant, color: Colors.white70, size: 56),
      );
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

class _MealTypePill extends StatelessWidget {
  const _MealTypePill({required this.mealType});
  final String mealType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: _neon.withValues(alpha: 0.18),
        border: Border.all(color: _neon.withValues(alpha: 0.55)),
      ),
      child: Text(
        mealType.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.6,
        ),
      ),
    );
  }
}

class _MacroBreakdown extends StatelessWidget {
  const _MacroBreakdown({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _MacroCell(
              label: 'PROTEİN',
              value: '${recipe.protein}g',
              color: _proteinColor,
            ),
          ),
          _VerticalDivider(),
          Expanded(
            child: _MacroCell(
              label: 'KARB',
              value: '${recipe.carbs}g',
              color: _carbsColor,
            ),
          ),
          _VerticalDivider(),
          Expanded(
            child: _MacroCell(
              label: 'YAĞ',
              value: '${recipe.fat}g',
              color: _fatColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroCell extends StatelessWidget {
  const _MacroCell({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(color: color.withValues(alpha: 0.55), blurRadius: 14),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: Colors.white12,
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeNotFound extends StatelessWidget {
  const _RecipeNotFound();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, color: Colors.white38, size: 56),
          const SizedBox(height: 12),
          const Text(
            'Tarif bulunamadı.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Bu tarif kaldırılmış olabilir.',
            style: TextStyle(color: Colors.white54, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => context.go('/'),
            style: FilledButton.styleFrom(
              backgroundColor: _neon,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            ),
            child: const Text('Geri dön'),
          ),
        ],
      ),
    );
  }
}
