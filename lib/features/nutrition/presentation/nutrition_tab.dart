import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/error_card.dart';
import '../domain/models/macro_target.dart';
import '../domain/models/recipe.dart';
import '../providers/nutrition_provider.dart';
import 'widgets/ai_insight_banner.dart';
import 'widgets/meal_plan_timeline.dart';
import 'widgets/next_best_meal_card.dart';
import 'widgets/recipe_tags.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _proteinColor = Color(0xFF4DA6FF); // neon blue
const Color _carbsColor = Color(0xFFFF4DDB); // neon pink
const Color _fatColor = Color(0xFFEAFF00); // neon yellow

// Traffic-light palette for the calorie ring's "on track / low / over"
// readout — tuned warmer than pure red/green/yellow so the ring still
// reads as neon instead of dashboard-warning-ugly.
const Color _statusOnTrack = Color(0xFF39FF14); // neon green
const Color _statusLow = Color(0xFFEAFF00); // neon yellow
const Color _statusOver = Color(0xFFFF5577); // neon red

/// Nutrition home surface. Reads the user's stored body metrics via
/// [macroTargetProvider], their consumed macros via
/// [consumedMacrosProvider], and renders a decision-first stack:
/// dashboard header → macro status card → AI coach banner →
/// next-best-meal card → meal plan timeline → recipe discovery.
///
/// Stateful because the AI coach banner's "Öneriyi Gör" CTA scrolls
/// the tab down to the next-best-meal section; that needs a
/// [GlobalKey] held across rebuilds.
class NutritionTab extends ConsumerStatefulWidget {
  const NutritionTab({super.key});

  @override
  ConsumerState<NutritionTab> createState() => _NutritionTabState();
}

class _NutritionTabState extends ConsumerState<NutritionTab> {
  /// Attached to the next-best-meal section so the coach banner can
  /// scroll to it with [Scrollable.ensureVisible].
  final GlobalKey _suggestionKey = GlobalKey();

  Future<void> _scrollToSuggestion() async {
    final target = _suggestionKey.currentContext;
    if (target == null) return;
    await Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
      alignment: 0.1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipesAsync = ref.watch(recipesProvider);
    final target = ref.watch(macroTargetProvider);
    final consumed = ref.watch(consumedMacrosProvider);
    final suggestion = ref.watch(nextBestMealProvider);

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
      data: (recipes) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _DailyDashboardHeader(),
            const SizedBox(height: 14),
            const _DailyScoreCard(),
            const SizedBox(height: 18),
            _MacroStatusCard(target: target, consumed: consumed),
            const SizedBox(height: 16),
            AiInsightBanner(onShowSuggestion: _scrollToSuggestion),
            const SizedBox(height: 26),
            if (suggestion != null) ...[
              KeyedSubtree(
                key: _suggestionKey,
                child: const _SectionTitle(
                  title: '🎯 Sana En Uygun Sonraki Öğün',
                ),
              ),
              const SizedBox(height: 12),
              const NextBestMealCard(),
              const SizedBox(height: 26),
            ],
            const _SectionTitle(title: 'Günün Menüsü'),
            const SizedBox(height: 12),
            const MealPlanTimeline(),
            const SizedBox(height: 26),
            const _SectionTitle(title: 'Tarif Keşfet'),
            const SizedBox(height: 12),
            _DiscoverySection(recipes: recipes),
          ],
        ),
      ),
    );
  }
}

double _safeProgress(int consumed, int target) {
  if (target <= 0) return 0;
  return consumed / target;
}

// ============================================================================
// Dashboard header — title + formatted date
// ============================================================================

class _DailyDashboardHeader extends StatelessWidget {
  const _DailyDashboardHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bugün',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatTurkishDate(DateTime.now()),
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }

  /// Formats as e.g. "Çarşamba, 22 Nisan 2026". Inlined rather than
  /// adding `intl` as a dependency for one string — the day/month
  /// tables below are small and change only when Turkish does.
  static String _formatTurkishDate(DateTime d) {
    const days = [
      'Pazartesi',
      'Salı',
      'Çarşamba',
      'Perşembe',
      'Cuma',
      'Cumartesi',
      'Pazar',
    ];
    const months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    // DateTime.weekday is 1..7 with Monday=1, so a direct `-1` indexes
    // straight into the days list.
    final day = days[d.weekday - 1];
    final month = months[d.month - 1];
    return '$day, ${d.day} $month ${d.year}';
  }
}

// ============================================================================
// Daily score + streak pill — phase 25.2 gamification.
// ============================================================================

/// Prominent card at the very top of the nutrition dashboard. Shows
/// today's score out of 100 with a tier-coloured border + progress
/// bar (red <50, yellow <80, green ≥80) alongside the streak flame.
class _DailyScoreCard extends ConsumerWidget {
  const _DailyScoreCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final score = ref.watch(dailyScoreProvider);
    final streak = ref.watch(nutritionStreakProvider);
    final tierColor = _tierColor(score);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withValues(alpha: 0.04),
          border: Border.all(color: tierColor.withValues(alpha: 0.55)),
          boxShadow: [
            BoxShadow(
              color: tierColor.withValues(alpha: 0.25),
              blurRadius: 18,
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'GÜNLÜK SKOR',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                          children: [
                            TextSpan(
                              text: '$score',
                              style: TextStyle(
                                color: tierColor,
                                fontSize: 32,
                                shadows: [
                                  Shadow(
                                    color: tierColor.withValues(alpha: 0.6),
                                    blurRadius: 14,
                                  ),
                                ],
                              ),
                            ),
                            const TextSpan(
                              text: ' / 100',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _StreakPill(streak: streak),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: score / 100),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  backgroundColor: tierColor.withValues(alpha: 0.14),
                  valueColor: AlwaysStoppedAnimation(tierColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Traffic-light tiering per the phase 25.2 spec. Colours match the
  /// macro status ring so both surfaces tell the same story at a glance.
  static Color _tierColor(int score) {
    if (score >= 80) return const Color(0xFF39FF14); // neon green
    if (score >= 50) return const Color(0xFFEAFF00); // neon yellow
    return const Color(0xFFFF5577); // neon red
  }
}

class _StreakPill extends StatelessWidget {
  const _StreakPill({required this.streak});
  final int streak;

  static const Color _flame = Color(0xFFFF8A00);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: _flame.withValues(alpha: 0.18),
        border: Border.all(color: _flame.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            'Seri: $streak Gün',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Macro status card — calorie ring + protein/carb/fat horizontal bars
// ============================================================================

class _MacroStatusCard extends StatelessWidget {
  const _MacroStatusCard({required this.target, required this.consumed});
  final MacroTarget target;
  final MacroTarget consumed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withValues(alpha: 0.04),
          border: Border.all(color: _neon.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: _neon.withValues(alpha: 0.22),
              blurRadius: 22,
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: Column(
          children: [
            _CalorieRing(
              consumed: consumed.calories,
              target: target.calories,
            ),
            const SizedBox(height: 20),
            _MacroBar(
              label: 'Protein',
              consumed: consumed.protein,
              target: target.protein,
              color: _proteinColor,
            ),
            const SizedBox(height: 12),
            _MacroBar(
              label: 'Karbonhidrat',
              consumed: consumed.carbs,
              target: target.carbs,
              color: _carbsColor,
            ),
            const SizedBox(height: 12),
            _MacroBar(
              label: 'Yağ',
              consumed: consumed.fat,
              target: target.fat,
              color: _fatColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _CalorieRing extends StatelessWidget {
  const _CalorieRing({required this.consumed, required this.target});
  final int consumed;
  final int target;

  @override
  Widget build(BuildContext context) {
    final progress = _safeProgress(consumed, target);
    final color = _colorForProgress(progress);
    // Over-target rings visually clamp at 100% — otherwise the stroke
    // would wrap past 12 o'clock and look buggy. The numeric readout
    // still reflects the real overage, and the red colour carries the
    // "you're over" signal.
    final clamped = progress.clamp(0.0, 1.0);
    return SizedBox(
      width: 170,
      height: 170,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Phase 25.1 dopamine loop: tween the stroke fill to its new
          // value instead of snapping. TweenAnimationBuilder detects
          // the new `end` on each rebuild and animates from the
          // currently-displayed value, so completing a meal visibly
          // nudges the ring forward instead of teleporting.
          SizedBox.expand(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: clamped),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => CircularProgressIndicator(
                value: value,
                strokeWidth: 12,
                strokeCap: StrokeCap.round,
                backgroundColor: color.withValues(alpha: 0.14),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$consumed',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  shadows: [
                    Shadow(color: color.withValues(alpha: 0.6), blurRadius: 14),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '/ $target kcal',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _remainingLabel(consumed: consumed, target: target),
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _colorForProgress(double progress) {
    if (progress > 1.0) return _statusOver;
    if (progress < 0.5) return _statusLow;
    return _statusOnTrack;
  }

  /// Renders the live delta against the target:
  ///   • under target → "N kcal kaldı" (positive remaining)
  ///   • over target  → "N kcal aşıldı" (absolute overage)
  ///   • exactly hit  → "hedef tam"
  static String _remainingLabel({required int consumed, required int target}) {
    final remaining = target - consumed;
    if (remaining > 0) return '$remaining kcal kaldı';
    if (remaining < 0) return '${-remaining} kcal aşıldı';
    return 'hedef tam';
  }
}

class _MacroBar extends StatelessWidget {
  const _MacroBar({
    required this.label,
    required this.consumed,
    required this.target,
    required this.color,
  });

  final String label;
  final int consumed;
  final int target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = _safeProgress(consumed, target).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '$consumed g',
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '/ $target g',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.14),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Section title (reused by both remaining sections)
// ============================================================================

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
// Discovery gallery
// ----------------------------------------------------------------------------
// Filter chips + horizontal card list so a user can graze the recipe
// catalogue when they want variety beyond the planned meals above.
// Filters are lightweight predicates so users get an immediate effect;
// "Vegan" is a best-effort keyword match since the Recipe model has no
// dedicated dietary flag yet.
// ============================================================================

class _DiscoverySection extends StatefulWidget {
  const _DiscoverySection({required this.recipes});
  final List<Recipe> recipes;

  @override
  State<_DiscoverySection> createState() => _DiscoverySectionState();
}

class _DiscoverySectionState extends State<_DiscoverySection> {
  /// Null = no filter active (show all recipes). Tapping the active chip
  /// again clears the filter.
  String? _activeFilter;

  static const List<String> _filters = [
    'Yüksek Protein',
    'Düşük Kalori',
    'Hacim',
    'Sıkılaşma',
    'Vegan',
  ];

  List<Recipe> get _filtered {
    final source = widget.recipes;
    switch (_activeFilter) {
      case 'Yüksek Protein':
        return source.where((r) => r.protein >= 25).toList(growable: false);
      case 'Düşük Kalori':
        return source.where((r) => r.calories <= 400).toList(growable: false);
      case 'Hacim':
        return source.where((r) => r.calories >= 500).toList(growable: false);
      case 'Sıkılaşma':
        return source
            .where((r) => r.calories <= 500 && r.protein >= 20)
            .toList(growable: false);
      case 'Vegan':
        // No dedicated diet flag on Recipe yet — match on the title +
        // instructions blob for the word "vegan" so the filter does
        // something useful today and is trivial to retire once a real
        // tag lands on the Supabase schema.
        return source.where((r) {
          final hay = '${r.title} ${r.instructions ?? ''}'.toLowerCase();
          return hay.contains('vegan');
        }).toList(growable: false);
      default:
        return source;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final filter = _filters[index];
              final selected = filter == _activeFilter;
              return _DiscoveryFilterChip(
                label: filter,
                selected: selected,
                onTap: () => setState(
                  () => _activeFilter = selected ? null : filter,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        if (items.isEmpty)
          const _EmptyState(
            message: 'Bu filtre için tarif bulunamadı.',
          )
        else
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) =>
                  RecipeDiscoveryCard(recipe: items[index]),
            ),
          ),
      ],
    );
  }
}

class _DiscoveryFilterChip extends StatelessWidget {
  const _DiscoveryFilterChip({
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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

class RecipeDiscoveryCard extends StatelessWidget {
  const RecipeDiscoveryCard({super.key, required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/recipe', extra: recipe),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _RecipeThumb(recipe: recipe),
              // Dark gradient keeps the title readable regardless of how
              // bright the underlying photo is.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.5),
                      Colors.black.withValues(alpha: 0.92),
                    ],
                    stops: const [0.35, 0.65, 1.0],
                  ),
                ),
              ),
              // Category tags anchored top-left so they read above the
              // photography without blocking the title below.
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: RecipeTagsStrip(
                  recipe: recipe,
                  maxTags: 2,
                  compact: true,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
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
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                        shadows: [
                          Shadow(blurRadius: 10, color: Colors.black87),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
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
                        const SizedBox(width: 8),
                        Container(
                          width: 1,
                          height: 12,
                          color: Colors.white24,
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.fitness_center,
                          color: Color(0xFF4DA6FF),
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
