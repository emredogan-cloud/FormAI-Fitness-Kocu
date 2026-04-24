import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/cached_image.dart';
import '../../../../core/widgets/error_card.dart';
import '../../domain/models/daily_meal_slot.dart';
import '../../domain/models/planned_meal.dart';
import '../../domain/models/recipe.dart';
import '../../providers/daily_menu_provider.dart';
import '../../providers/nutrition_provider.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _neonGreen = Color(0xFF39FF14);
const Color _skippedColor = Color(0xFFFF5577);
const Color _warningColor = Color(0xFFFF5577);
const Color _proteinColor = Color(0xFF4DA6FF);
const Color _carbsColor = Color(0xFFFF4DDB);
const Color _fatColor = Color(0xFFEAFF00);

/// Accordion meal-plan timeline rendered as a direct sliver inside the
/// nutrition tab's [CustomScrollView].
///
/// Phase 26 behaviour:
///   • "Current" = first meal with `status == planned` (not time-based
///     any more). Current meal is **expanded**, has a neon glow, and
///     shows the "⏳ Şu an" badge.
///   • All other meals (future-planned, completed, skipped) default to
///     **collapsed** — a single line showing slot label + status icon
///     + recipe title at reduced weight. Tapping expands the full card.
///   • Over-calorie switch: when consumed ≥ target, the planned meal
///     cards swap their primary CTA from "Yedim" to the warning
///     "❌ Daha Hafif Alternatif Gör" which routes to the next-best
///     (light) suggestion.
class MealPlanSliver extends ConsumerWidget {
  const MealPlanSliver({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(dailyMenuProvider);
    final target = ref.watch(macroTargetProvider);
    final consumed = ref.watch(consumedMacrosProvider);
    final overCalories =
        target.calories > 0 && consumed.calories >= target.calories;
    final lighterSuggestion = ref.watch(nextBestMealProvider)?.recipe;

    return menuAsync.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator(color: _neon)),
        ),
      ),
      error: (err, st) {
        debugPrint('MealPlanSliver menu error: $err\n$st');
        return SliverToBoxAdapter(
          child: ErrorCard(
            message: 'Günün menüsü yüklenemedi.',
            onRetry: () => ref.invalidate(dailyMenuProvider),
          ),
        );
      },
      data: (meals) {
        if (meals.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: _EmptyPlaceholder(
                message: 'Günün menüsü için tercih bulunamadı.',
              ),
            ),
          );
        }
        final currentMealId = _firstPlannedId(meals);
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.builder(
            itemCount: meals.length,
            itemBuilder: (context, i) {
              final meal = meals[i];
              return _TimelineRow(
                meal: meal,
                isFirst: i == 0,
                isLast: i == meals.length - 1,
                isCurrent: meal.id == currentMealId,
                overCalories: overCalories,
                lighterSuggestion: lighterSuggestion,
              );
            },
          ),
        );
      },
    );
  }

  /// Returns the id of the first meal still marked `planned`. When the
  /// whole day is complete (all meals logged or skipped) this returns
  /// null and no card gets the "current" highlight.
  static String? _firstPlannedId(List<PlannedMeal> meals) {
    for (final meal in meals) {
      if (meal.status == MealStatus.planned) return meal.id;
    }
    return null;
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.meal,
    required this.isFirst,
    required this.isLast,
    required this.isCurrent,
    required this.overCalories,
    required this.lighterSuggestion,
  });

  final PlannedMeal meal;
  final bool isFirst;
  final bool isLast;
  final bool isCurrent;
  final bool overCalories;
  final Recipe? lighterSuggestion;

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
                isCurrent: isCurrent,
                isFirst: isFirst,
                isLast: isLast,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: _MealCard(
                meal: meal,
                isCurrent: isCurrent,
                overCalories: overCalories,
                lighterSuggestion: lighterSuggestion,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints the vertical connecting line + status-coloured dot at the
/// top of each row. The current meal's dot gets an extra glow so the
/// "you are here" marker is obvious even on a crowded list.
class _TimelineGutterPainter extends CustomPainter {
  const _TimelineGutterPainter({
    required this.status,
    required this.isCurrent,
    required this.isFirst,
    required this.isLast,
  });

  final MealStatus status;
  final bool isCurrent;
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
      ..color = color.withValues(alpha: isCurrent ? 0.9 : 0.55)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, isCurrent ? 10 : 6);
    canvas.drawCircle(
      Offset(centerX, _dotY),
      isCurrent ? _dotRadius + 1 : _dotRadius,
      glow,
    );
    final dot = Paint()..color = color;
    canvas.drawCircle(
      Offset(centerX, _dotY),
      isCurrent ? _dotRadius + 0.5 : _dotRadius,
      dot,
    );
  }

  @override
  bool shouldRepaint(covariant _TimelineGutterPainter old) =>
      old.status != status ||
      old.isCurrent != isCurrent ||
      old.isFirst != isFirst ||
      old.isLast != isLast;
}

/// Accordion meal entry. Stateful purely for the expansion toggle —
/// everything else is driven by [PlannedMeal.status] + [isCurrent].
///
/// Default-expanded rule: `_expanded = isCurrent`. Every non-current
/// card starts collapsed (saves vertical space per phase 26 spec).
class _MealCard extends ConsumerStatefulWidget {
  const _MealCard({
    required this.meal,
    required this.isCurrent,
    required this.overCalories,
    required this.lighterSuggestion,
  });

  final PlannedMeal meal;
  final bool isCurrent;
  final bool overCalories;
  final Recipe? lighterSuggestion;

  @override
  ConsumerState<_MealCard> createState() => _MealCardState();
}

class _MealCardState extends ConsumerState<_MealCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    // Phase 26: all non-current meals collapse by default, regardless
    // of whether they are future-planned, completed, or skipped.
    _expanded = widget.isCurrent;
  }

  @override
  void didUpdateWidget(covariant _MealCard old) {
    super.didUpdateWidget(old);
    // When this card becomes the current meal (user skipped the
    // previous one, say), auto-expand so they see the action row.
    if (!old.isCurrent && widget.isCurrent) {
      _expanded = true;
    }
    // When a meal transitions into a completed state, auto-collapse —
    // the user just acted on it, reduce visual weight.
    if (old.meal.status != MealStatus.completed &&
        widget.meal.status == MealStatus.completed) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_expanded) {
      return _CollapsedCard(
        meal: widget.meal,
        onTap: () => setState(() => _expanded = true),
      );
    }
    return _ExpandedCard(
      meal: widget.meal,
      isCurrent: widget.isCurrent,
      overCalories: widget.overCalories,
      lighterSuggestion: widget.lighterSuggestion,
      onCollapse: () => setState(() => _expanded = false),
    );
  }
}

/// Minimal single-line row used for every non-current meal.
///   • completed → "✔ KAHVALTI · {title} (Tamamlandı)" strikethrough
///   • skipped   → "✖ KAHVALTI · {title} (Atlandı)" strikethrough
///   • planned   → "KAHVALTI · {title}" subtle
class _CollapsedCard extends StatelessWidget {
  const _CollapsedCard({required this.meal, required this.onTap});
  final PlannedMeal meal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = meal.status;
    final (icon, iconColor, borderColor, suffix, opacity, strike) =
        _visualsFor(status);

    return Opacity(
      opacity: opacity,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withValues(alpha: 0.03),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: iconColor, size: 18),
                  const SizedBox(width: 10),
                ],
                Text(
                  _slotLabel(meal.slot),
                  style: const TextStyle(
                    color: _neon,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${meal.recipe.title}$suffix',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      decoration: strike ? TextDecoration.lineThrough : null,
                      decorationColor: Colors.white38,
                    ),
                  ),
                ),
                const Icon(
                  Icons.expand_more_rounded,
                  color: Colors.white38,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  (IconData?, Color?, Color, String, double, bool) _visualsFor(
    MealStatus status,
  ) {
    switch (status) {
      case MealStatus.completed:
        return (
          Icons.check_circle,
          _neonGreen,
          _neonGreen.withValues(alpha: 0.35),
          ' (Tamamlandı)',
          0.6,
          true,
        );
      case MealStatus.skipped:
        return (
          Icons.cancel_outlined,
          _skippedColor,
          _skippedColor.withValues(alpha: 0.35),
          ' (Atlandı)',
          0.55,
          true,
        );
      case MealStatus.planned:
        return (
          null,
          null,
          Colors.white12,
          '',
          1.0,
          false,
        );
    }
  }
}

class _ExpandedCard extends ConsumerWidget {
  const _ExpandedCard({
    required this.meal,
    required this.isCurrent,
    required this.overCalories,
    required this.lighterSuggestion,
    required this.onCollapse,
  });

  final PlannedMeal meal;
  final bool isCurrent;
  final bool overCalories;
  final Recipe? lighterSuggestion;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(dailyMenuProvider.notifier);
    final recipe = meal.recipe;

    final card = _CardShell(
      onTap: () => context.push('/recipe', extra: recipe),
      borderColor: _borderColorFor(
        status: meal.status,
        isCurrent: isCurrent,
      ),
      glow: isCurrent,
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
                      _HeaderRow(
                        slot: meal.slot,
                        status: meal.status,
                        isCurrent: isCurrent,
                        onCollapse: onCollapse,
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
            _PrimaryActionRow(
              meal: meal,
              notifier: notifier,
              overCalories: overCalories,
              lighterSuggestion: lighterSuggestion,
            ),
            const SizedBox(height: 6),
            _TertiaryRow(recipe: recipe),
          ],
        ),
      ),
    );
    if (!isCurrent) return card;
    // Slight scale-up on the current meal amplifies its presence
    // without disturbing layout neighbours.
    return Transform.scale(scale: 1.02, child: card);
  }

  Color? _borderColorFor({
    required MealStatus status,
    required bool isCurrent,
  }) {
    if (isCurrent) return _neon;
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

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.slot,
    required this.status,
    required this.isCurrent,
    required this.onCollapse,
  });

  final DailyMealSlot slot;
  final MealStatus status;
  final bool isCurrent;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          _slotLabel(slot),
          style: const TextStyle(
            color: _neon,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
          ),
        ),
        if (isCurrent) ...[
          const SizedBox(width: 8),
          const _CurrentNowPill(),
        ] else if (status != MealStatus.planned) ...[
          const SizedBox(width: 8),
          _StatusPill(status: status),
        ],
        const Spacer(),
        // Collapse affordance on non-current cards (a user might re-fold
        // the card after peeking). Current meal stays pinned open.
        if (!isCurrent)
          InkWell(
            customBorder: const CircleBorder(),
            onTap: onCollapse,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.expand_less_rounded,
                color: Colors.white38,
                size: 18,
              ),
            ),
          ),
      ],
    );
  }
}

class _CurrentNowPill extends StatelessWidget {
  const _CurrentNowPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: _neon.withValues(alpha: 0.28),
        border: Border.all(color: _neon),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('⏳ ', style: TextStyle(fontSize: 9)),
          Text(
            'ŞU AN',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryActionRow extends StatelessWidget {
  const _PrimaryActionRow({
    required this.meal,
    required this.notifier,
    required this.overCalories,
    required this.lighterSuggestion,
  });

  final PlannedMeal meal;
  final DailyMenuNotifier notifier;
  final bool overCalories;
  final Recipe? lighterSuggestion;

  @override
  Widget build(BuildContext context) {
    switch (meal.status) {
      case MealStatus.planned:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  notifier.markAsSkipped(meal.id);
                },
                icon: const Icon(Icons.sync, size: 16),
                label: const Text('Değiştir'),
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
              child: overCalories
                  ? _LighterAlternativeButton(
                      suggestion: lighterSuggestion,
                    )
                  : _YedimButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        notifier.markAsCompleted(meal.id);
                      },
                    ),
            ),
          ],
        );
      case MealStatus.completed:
      case MealStatus.skipped:
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              notifier.resetMeal(meal.id);
            },
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

class _YedimButton extends StatelessWidget {
  const _YedimButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
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
    );
  }
}

/// Outlined warning CTA per the phase 26 over-calorie switch spec. The
/// button is outlined (not filled) so the visual weight is lower than
/// a green Yedim — matching "no new calories, go reconsider".
class _LighterAlternativeButton extends StatelessWidget {
  const _LighterAlternativeButton({required this.suggestion});
  final Recipe? suggestion;

  @override
  Widget build(BuildContext context) {
    final enabled = suggestion != null;
    return OutlinedButton.icon(
      onPressed: enabled
          ? () {
              HapticFeedback.lightImpact();
              context.push('/recipe', extra: suggestion);
            }
          : null,
      icon: const Icon(Icons.cancel_outlined, size: 16),
      label: const Text(
        'Daha Hafif Alternatif',
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: _warningColor,
        side: BorderSide(
          color: _warningColor.withValues(alpha: enabled ? 1.0 : 0.35),
          width: 1.2,
        ),
        disabledForegroundColor: _warningColor.withValues(alpha: 0.35),
        padding: const EdgeInsets.symmetric(vertical: 10),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _TertiaryRow extends StatelessWidget {
  const _TertiaryRow({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: () => context.push('/recipe', extra: recipe),
        icon: const Icon(Icons.open_in_new, size: 14),
        label: const Text('Detay'),
        style: TextButton.styleFrom(
          foregroundColor: Colors.white60,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: const Size(0, 32),
          textStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
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
    this.glow = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? borderColor;
  final bool glow;

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
            border: Border.all(
              color: borderColor ?? Colors.white12,
              width: glow ? 1.5 : 1,
            ),
            boxShadow: glow
                ? [
                    BoxShadow(
                      color: _neon.withValues(alpha: 0.35),
                      blurRadius: 22,
                      spreadRadius: 0.5,
                    ),
                  ]
                : null,
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
    return CachedImage(
      url: src,
      fit: BoxFit.cover,
      memCacheHeight: 300,
      errorBuilder: (_, __, ___) => fallback,
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
