import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/app_preferences.dart';
import '../../../core/widgets/error_card.dart';
import '../../onboarding/providers/wizard_provider.dart';
import '../domain/models/macro_target.dart';
import '../domain/models/recipe.dart';
import '../providers/nutrition_provider.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _proteinColor = Color(0xFF4DA6FF);
const Color _carbsColor = Color(0xFF39FF14);
const Color _fatColor = Color(0xFFFFA726);

/// Nutrition home surface. Reads the user's stored body metrics, computes
/// the daily [MacroTarget] through [NutritionCalculatorService], and
/// surfaces a visual macro summary + a meal plan drawn from the recipe
/// catalogue. The tab is pure read — it writes nothing back to prefs or
/// Supabase.
class NutritionTab extends ConsumerWidget {
  const NutritionTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(recipesProvider);
    final target = _computeTarget(ref);
    final mealFrequency = _readMealFrequency(ref);

    return recipesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: _neon),
      ),
      error: (err, st) {
        debugPrint('NutritionTab recipes error: $err\n$st');
        return ErrorCard(
          message: 'Tarifler yüklenirken bir sorun oluştu.',
          onRetry: () => ref.invalidate(recipesProvider),
        );
      },
      data: (recipes) => ListView(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
        children: [
          const _SectionHeader(
            title: 'Beslenme',
            subtitle: 'Hedefin için günlük makro planı.',
          ),
          const SizedBox(height: 18),
          _MacroRingsCard(target: target),
          const SizedBox(height: 26),
          const _SectionTitle(title: 'Günün Menüsü'),
          const SizedBox(height: 12),
          _DailyMenu(
            recipes: recipes,
            mealFrequency: mealFrequency,
          ),
          const SizedBox(height: 26),
          const _SectionTitle(title: 'Keşfet'),
          const SizedBox(height: 12),
          _DiscoverStrip(recipes: recipes),
        ],
      ),
    );
  }

  /// Pulls body metrics from the onboarding payload and hands them to the
  /// calculator. Anything missing falls back to a reasonable default so a
  /// guest who skipped onboarding still sees a sensible plan.
  MacroTarget _computeTarget(WidgetRef ref) {
    final calc = ref.watch(nutritionCalculatorProvider);
    final metrics = ref.watch(appPreferencesProvider).userMetrics ??
        const <String, dynamic>{};
    return calc.calculateDailyMacros(
      weight: (metrics['weightKg'] as int?) ?? 70,
      height: (metrics['heightCm'] as int?) ?? 175,
      age: (metrics['age'] as int?) ?? 28,
      gender: (metrics['gender'] as String?) ?? 'male',
      activityLevel: (metrics['activityLevel'] as String?) ?? 'sedentary',
      goal: (metrics['targetPhysique'] as String?) ?? 'sixpack',
    );
  }

  String _readMealFrequency(WidgetRef ref) {
    final metrics = ref.watch(appPreferencesProvider).userMetrics ??
        const <String, dynamic>{};
    return (metrics['mealFrequency'] as String?) ?? kDefaultMealFrequency;
  }
}

// ============================================================================
// Header + section titles
// ============================================================================

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ============================================================================
// Macro rings
// ============================================================================

class _MacroRingsCard extends StatelessWidget {
  const _MacroRingsCard({required this.target});
  final MacroTarget target;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withValues(alpha: 0.04),
          border: Border.all(color: _neon.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: _neon.withValues(alpha: 0.25),
              blurRadius: 20,
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: Column(
          children: [
            _MacroRing(
              size: 140,
              stroke: 10,
              value: target.calories,
              label: 'KALORİ',
              unit: 'kcal',
              color: _neon,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _MacroRing(
                    size: 88,
                    stroke: 7,
                    value: target.protein,
                    label: 'PROTEİN',
                    unit: 'g',
                    color: _proteinColor,
                  ),
                ),
                Expanded(
                  child: _MacroRing(
                    size: 88,
                    stroke: 7,
                    value: target.carbs,
                    label: 'KARB',
                    unit: 'g',
                    color: _carbsColor,
                  ),
                ),
                Expanded(
                  child: _MacroRing(
                    size: 88,
                    stroke: 7,
                    value: target.fat,
                    label: 'YAĞ',
                    unit: 'g',
                    color: _fatColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroRing extends StatelessWidget {
  const _MacroRing({
    required this.size,
    required this.stroke,
    required this.value,
    required this.label,
    required this.unit,
    required this.color,
  });

  final double size;
  final double stroke;
  final int value;
  final String label;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background ring — low-alpha of the accent colour so the
              // "full target" ring has something to glow against.
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: stroke,
                  backgroundColor: color.withValues(alpha: 0.14),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$value',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: size * 0.24,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      shadows: [
                        Shadow(
                          color: color.withValues(alpha: 0.6),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    unit,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Daily menu
// ============================================================================

class _DailyMenu extends StatelessWidget {
  const _DailyMenu({required this.recipes, required this.mealFrequency});
  final List<Recipe> recipes;
  final String mealFrequency;

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) {
      return const _EmptyState(message: 'Henüz tarif eklenmemiş.');
    }
    final slots = _slotsFor(mealFrequency);
    // Rotate selection by day-of-year so the menu feels fresh each day
    // without being random (two users on the same day see the same plan —
    // easier to reason about in QA).
    final seed = DateTime.now().difference(DateTime(2024)).inDays;

    final picks = <_DailyMenuPick>[];
    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final candidates = recipes.where((r) => _matchesSlot(r, slot)).toList();
      if (candidates.isEmpty) continue;
      final recipe = candidates[(seed + i) % candidates.length];
      picks.add(_DailyMenuPick(slot: slot, recipe: recipe));
    }
    if (picks.isEmpty) {
      return const _EmptyState(
        message: 'Bu tercih için uygun tarif bulunamadı.',
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          for (final pick in picks) ...[
            _MenuTile(slot: pick.slot, recipe: pick.recipe),
            if (pick != picks.last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  /// Maps the onboarding's `mealFrequency` token to an ordered list of
  /// meal-type slots. The order matters — it's the order the tiles
  /// render, so `breakfast → main → snack` reads top-to-bottom like a day.
  List<String> _slotsFor(String freq) {
    switch (freq) {
      case '2_ogun':
        return const ['main', 'main'];
      case '4_ogun':
        return const ['breakfast', 'main', 'snack', 'main'];
      case '3_ogun':
      default:
        return const ['breakfast', 'main', 'snack'];
    }
  }

  /// Lenient match — Supabase vocab might use `lunch`/`dinner` instead
  /// of a single `main`, and we don't want the filter to collapse an
  /// otherwise healthy catalogue to empty.
  bool _matchesSlot(Recipe recipe, String slot) {
    final type = recipe.mealType.toLowerCase();
    switch (slot) {
      case 'main':
        return type == 'main' || type == 'lunch' || type == 'dinner';
      case 'breakfast':
        return type == 'breakfast' || type == 'kahvalti' || type == 'kahvaltı';
      case 'snack':
        return type == 'snack' || type == 'atistirmalik';
      default:
        return type == slot;
    }
  }
}

class _DailyMenuPick {
  const _DailyMenuPick({required this.slot, required this.recipe});
  final String slot;
  final Recipe recipe;
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.slot, required this.recipe});
  final String slot;
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/recipe/${recipe.id}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withValues(alpha: 0.04),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 68,
                height: 68,
                child: _RecipeThumb(recipe: recipe),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _slotLabel(slot),
                    style: const TextStyle(
                      color: _neon,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recipe.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _MetaChip(
                        icon: Icons.local_fire_department,
                        label: '${recipe.calories} kcal',
                      ),
                      const SizedBox(width: 8),
                      _MetaChip(
                        icon: Icons.schedule,
                        label: '${recipe.prepTimeMinutes} dk',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  String _slotLabel(String slot) {
    switch (slot) {
      case 'breakfast':
        return 'KAHVALTI';
      case 'main':
        return 'ANA ÖĞÜN';
      case 'snack':
        return 'ATIŞTIRMALIK';
      case 'dessert':
        return 'TATLI';
      default:
        return slot.toUpperCase();
    }
  }
}

// ============================================================================
// Discover (dessert + high-protein snacks)
// ============================================================================

class _DiscoverStrip extends StatelessWidget {
  const _DiscoverStrip({required this.recipes});
  final List<Recipe> recipes;

  @override
  Widget build(BuildContext context) {
    final items = recipes
        .where((r) =>
            r.mealType.toLowerCase() == 'dessert' ||
            (r.mealType.toLowerCase() == 'snack' && r.protein >= 15))
        .toList(growable: false);
    if (items.isEmpty) {
      return const _EmptyState(
          message: 'Keşfedilecek yeni tarif yok — yakında.');
    }
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _DiscoverCard(recipe: items[index]),
      ),
    );
  }
}

class _DiscoverCard extends StatelessWidget {
  const _DiscoverCard({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/recipe/${recipe.id}'),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _RecipeThumb(recipe: recipe),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.45),
                      Colors.black.withValues(alpha: 0.88),
                    ],
                    stops: const [0.35, 0.65, 1.0],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      recipe.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                        shadows: [
                          Shadow(blurRadius: 10, color: Colors.black87)
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _MetaChip(
                          icon: Icons.local_fire_department,
                          label: '${recipe.calories} kcal',
                        ),
                        const SizedBox(width: 8),
                        _MetaChip(
                          icon: Icons.fitness_center,
                          label: '${recipe.protein}g prot.',
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

// ============================================================================
// Shared bits
// ============================================================================

class _RecipeThumb extends StatelessWidget {
  const _RecipeThumb({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: Colors.white10,
      alignment: Alignment.center,
      child: const Icon(Icons.restaurant, color: Colors.white54, size: 28),
    );
    final url = recipe.imageUrl;
    if (url == null || url.isEmpty) return fallback;
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : Container(color: Colors.white10),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.03),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          message,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
      ),
    );
  }
}
