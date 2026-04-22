import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/error_card.dart';
import '../../domain/models/daily_meal_slot.dart';
import '../../domain/models/planned_meal.dart';
import '../../domain/models/recipe.dart';
import '../../providers/daily_menu_provider.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _neonGreen = Color(0xFF39FF14);
const Color _skippedColor = Color(0xFFFF5577);
const Color _proteinColor = Color(0xFF4DA6FF);
const Color _carbsColor = Color(0xFFFF4DDB);
const Color _fatColor = Color(0xFFEAFF00);

/// Vertical meal-plan timeline rendered directly under the AI insight
/// banner in the nutrition tab. Reads [dailyMenuProvider] (now an
/// `AsyncNotifier<List<PlannedMeal>>`) and paints one [_MealCard] per
/// planned meal, stitched together by a continuous neon gutter on the
/// left so the day reads as a chronological arc.
///
/// Uses a plain [Column] instead of [ListView.builder] because the tab
/// already scrolls via [SingleChildScrollView]; a nested scroll view
/// would either fight the outer scroll or require shrinkWrap which
/// defeats the laziness ListView.builder gives you. With 2–4 cards per
/// day the cost of building them all eagerly is negligible.
class MealPlanTimeline extends ConsumerWidget {
  const MealPlanTimeline({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(dailyMenuProvider);
    return menuAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator(color: _neon)),
      ),
      error: (err, st) {
        debugPrint('MealPlanTimeline menu error: $err\n$st');
        return ErrorCard(
          message: 'Günün menüsü yüklenemedi.',
          onRetry: () => ref.invalidate(dailyMenuProvider),
        );
      },
      data: (meals) {
        if (meals.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _EmptyPlaceholder(
              message: 'Günün menüsü için tercih bulunamadı.',
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              for (var i = 0; i < meals.length; i++)
                _TimelineRow(
                  meal: meals[i],
                  isFirst: i == 0,
                  isLast: i == meals.length - 1,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.meal,
    required this.isFirst,
    required this.isLast,
  });

  final PlannedMeal meal;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 40,
            child: CustomPaint(
              painter: _TimelineGutterPainter(
                status: meal.status,
                isFirst: isFirst,
                isLast: isLast,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: _MealCard(meal: meal),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints the vertical connecting line plus a status-coloured dot at
/// the top of each row. First row has no line above, last row has no
/// line below, so the connective tissue flows continuously through the
/// list.
class _TimelineGutterPainter extends CustomPainter {
  const _TimelineGutterPainter({
    required this.status,
    required this.isFirst,
    required this.isLast,
  });

  final MealStatus status;
  final bool isFirst;
  final bool isLast;

  static const double _dotY = 24;
  static const double _dotRadius = 7;

  Color get _dotColor {
    switch (status) {
      case MealStatus.completed:
        return _neonGreen;
      case MealStatus.skipped:
        return _skippedColor;
      case MealStatus.planned:
        return _neon;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final linePaint = Paint()
      ..color = _neon.withValues(alpha: 0.45)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    if (!isFirst) {
      canvas.drawLine(
        Offset(centerX, 0),
        Offset(centerX, _dotY - _dotRadius - 1),
        linePaint,
      );
    }
    if (!isLast) {
      canvas.drawLine(
        Offset(centerX, _dotY + _dotRadius + 1),
        Offset(centerX, size.height),
        linePaint,
      );
    }
    final color = _dotColor;
    final glow = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset(centerX, _dotY), _dotRadius, glow);
    final dot = Paint()..color = color;
    canvas.drawCircle(Offset(centerX, _dotY), _dotRadius, dot);
  }

  @override
  bool shouldRepaint(covariant _TimelineGutterPainter old) =>
      old.status != status || old.isFirst != isFirst || old.isLast != isLast;
}

/// One meal entry. Fully driven by [PlannedMeal.status]; no local state.
/// Actions dispatch to the [dailyMenuProvider] notifier so the change
/// is visible everywhere (timeline, calorie ring, macro bars).
///
///   • `planned` → "Atla" outlined + "Yedim" filled.
///   • `completed` / `skipped` → full-width "Geri Al" that returns the
///     meal to `planned`.
class _MealCard extends ConsumerWidget {
  const _MealCard({required this.meal});
  final PlannedMeal meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(dailyMenuProvider.notifier);
    final recipe = meal.recipe;
    final dimmed = meal.status != MealStatus.planned;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: dimmed ? 0.55 : 1.0,
      child: _CardShell(
        onTap: () => context.push('/recipe', extra: recipe),
        borderColor: _borderColorFor(meal.status),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 68,
                      height: 68,
                      child: _RecipeThumb(imageUrl: recipe.imageUrl),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _slotLabel(meal.slot),
                              style: const TextStyle(
                                color: _neon,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.6,
                              ),
                            ),
                            if (meal.status != MealStatus.planned) ...[
                              const SizedBox(width: 8),
                              _StatusPill(status: meal.status),
                            ],
                          ],
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
                        const SizedBox(height: 8),
                        _MacroStrip(recipe: recipe),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ActionRow(meal: meal, notifier: notifier),
            ],
          ),
        ),
      ),
    );
  }

  Color? _borderColorFor(MealStatus status) {
    switch (status) {
      case MealStatus.completed:
        return _neonGreen.withValues(alpha: 0.45);
      case MealStatus.skipped:
        return _skippedColor.withValues(alpha: 0.45);
      case MealStatus.planned:
        return null;
    }
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.meal, required this.notifier});
  final PlannedMeal meal;
  final DailyMenuNotifier notifier;

  @override
  Widget build(BuildContext context) {
    switch (meal.status) {
      case MealStatus.planned:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => notifier.markAsSkipped(meal.id),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Atla'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => notifier.markAsCompleted(meal.id),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Yedim'),
                style: FilledButton.styleFrom(
                  backgroundColor: _neonGreen,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        );
      case MealStatus.completed:
      case MealStatus.skipped:
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => notifier.resetMeal(meal.id),
            icon: const Icon(Icons.undo, size: 16),
            label: const Text('Geri Al'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        );
    }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final MealStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      MealStatus.completed => ('YENDİ', _neonGreen),
      MealStatus.skipped => ('ATLANDI', _skippedColor),
      MealStatus.planned => ('', Colors.transparent),
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.child,
    required this.onTap,
    this.borderColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: 0.04),
            border: Border.all(color: borderColor ?? Colors.white12),
          ),
          child: child,
        ),
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
        _Chip(
          icon: Icons.local_fire_department,
          label: '${recipe.calories} kcal',
          iconColor: Colors.white70,
        ),
        _Chip(
          label: '${recipe.protein}g P',
          labelColor: _proteinColor,
        ),
        _Chip(
          label: '${recipe.carbs}g K',
          labelColor: _carbsColor,
        ),
        _Chip(
          label: '${recipe.fat}g Y',
          labelColor: _fatColor,
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
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

class _RecipeThumb extends StatelessWidget {
  const _RecipeThumb({required this.imageUrl});
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

class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

String _slotLabel(DailyMealSlot slot) {
  switch (slot) {
    case DailyMealSlot.breakfast:
      return 'KAHVALTI';
    case DailyMealSlot.lunch:
      return 'ÖĞLE YEMEĞİ';
    case DailyMealSlot.dinner:
      return 'AKŞAM YEMEĞİ';
    case DailyMealSlot.snack:
      return 'ARA ÖĞÜN';
  }
}
