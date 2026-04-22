import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/recipe.dart';
import '../../providers/daily_menu_provider.dart';
import '../../providers/nutrition_provider.dart';
import 'recipe_tags.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _neonGreen = Color(0xFF39FF14);
const Color _warningColor = Color(0xFFFF5577);
const Color _proteinColor = Color(0xFF4DA6FF);
const Color _carbsColor = Color(0xFFFF4DDB);
const Color _fatColor = Color(0xFFEAFF00);

/// Card sitting directly under the AI coach banner that shows the
/// recipe [nextBestMealProvider] has chosen for the user right now.
///
/// Hides itself (returns `SizedBox.shrink`) when there's no
/// suggestion — the catalogue is still loading or empty. Callers rely
/// on that so the section's header can stay mounted but visually
/// collapse.
class NextBestMealCard extends ConsumerWidget {
  const NextBestMealCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipe = ref.watch(nextBestMealProvider);
    if (recipe == null) return const SizedBox.shrink();
    final target = ref.watch(macroTargetProvider);
    final consumed = ref.watch(consumedMacrosProvider);
    // Over-calorie switch: when consumed >= target, swap the primary
    // "Hemen Ekle" CTA for the warning "Daha Hafif Alternatif Gör" that
    // reroutes the user to a lighter option instead of piling on.
    final overCalories =
        target.calories > 0 && consumed.calories >= target.calories;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/recipe', extra: recipe),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(color: _neonGreen.withValues(alpha: 0.55)),
              boxShadow: [
                BoxShadow(
                  color: _neonGreen.withValues(alpha: 0.28),
                  blurRadius: 22,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: SizedBox(
                    height: 140,
                    width: double.infinity,
                    child: _HeroThumb(recipe: recipe),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      RecipeTagsStrip(recipe: recipe, maxTags: 2),
                      const SizedBox(height: 10),
                      _MacroStrip(recipe: recipe),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: overCalories
                            ? _WarningCta(recipe: recipe)
                            : _HemenEkleButton(
                                onPressed: () =>
                                    _addToPlan(context, ref, recipe),
                              ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () =>
                              context.push('/recipe', extra: recipe),
                          icon: const Icon(Icons.open_in_new, size: 14),
                          label: const Text('Detay'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white60,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: const Size(0, 32),
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addToPlan(BuildContext context, WidgetRef ref, Recipe recipe) {
    // The suggestion's own mealType is the most honest slot hint —
    // breakfast recipes land in breakfast, mains in dinner, etc. No
    // slot picker here: the "Hemen Ekle" button is meant to be one-tap,
    // and the recipe detail screen's CTA is the right place when the
    // user wants explicit control over the slot.
    HapticFeedback.mediumImpact();
    ref
        .read(dailyMenuProvider.notifier)
        .addRecipeToPlan(recipe, recipe.mealType);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${recipe.title} plana eklendi!'),
          backgroundColor: _neonGreen.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

class _HemenEkleButton extends StatelessWidget {
  const _HemenEkleButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add_circle_outline, size: 18),
      label: const Text('Hemen Ekle'),
      style: FilledButton.styleFrom(
        backgroundColor: _neonGreen,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// Phase 25.1 over-calorie guardrail. When consumed >= target, the
/// "Hemen Ekle" CTA is replaced with this warning that pushes the user
/// into the recipe detail (so they see what they'd be committing to)
/// rather than silently piling on. Same recipe — the suggestion engine
/// already prioritises light options once remaining calories drop low.
class _WarningCta extends StatelessWidget {
  const _WarningCta({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () {
        HapticFeedback.lightImpact();
        context.push('/recipe', extra: recipe);
      },
      icon: const Icon(Icons.cancel_outlined, size: 16),
      label: const Text(
        'Daha Hafif Alternatif Gör',
        overflow: TextOverflow.ellipsis,
      ),
      style: FilledButton.styleFrom(
        backgroundColor: _warningColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _HeroThumb extends StatelessWidget {
  const _HeroThumb({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final url = recipe.imageUrl;
    final fallback = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6A3DFF), Color(0xFF39FF14)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.restaurant, color: Colors.white70, size: 36),
    );
    final image = (url == null || url.isEmpty)
        ? fallback
        : Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : Container(color: Colors.white10),
          );
    return Stack(
      fit: StackFit.expand,
      children: [
        image,
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.45),
              ],
              stops: const [0.5, 1.0],
            ),
          ),
        ),
        const Positioned(
          left: 12,
          bottom: 12,
          child: _Pill(icon: Icons.flash_on, label: 'ÖNERİLEN'),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _neon.withValues(alpha: 0.85),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroStrip extends StatelessWidget {
  const _MacroStrip({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _MacroChip(
          icon: Icons.local_fire_department,
          label: '${recipe.calories} kcal',
          iconColor: Colors.white70,
        ),
        _MacroChip(
          label: '${recipe.protein}g P',
          labelColor: _proteinColor,
        ),
        _MacroChip(
          label: '${recipe.carbs}g K',
          labelColor: _carbsColor,
        ),
        _MacroChip(
          label: '${recipe.fat}g Y',
          labelColor: _fatColor,
        ),
      ],
    );
  }
}

class _MacroChip extends StatelessWidget {
  const _MacroChip({
    required this.label,
    this.icon,
    this.iconColor,
    this.labelColor,
  });

  final String label;
  final IconData? icon;
  final Color? iconColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: iconColor ?? Colors.white70, size: 12),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: labelColor ?? Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
