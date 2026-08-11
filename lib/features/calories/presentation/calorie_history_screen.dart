import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../nutrition/providers/nutrition_provider.dart';
import '../domain/models/meal_entry.dart';
import '../providers/calorie_providers.dart';

/// Fourteen days of calories against the target.
///
/// Fourteen rather than seven or thirty for a specific reason: seven
/// cannot show whether a weekend pattern is a pattern or a one-off, and
/// thirty compresses the bars past the point where a single day is
/// readable on a 360 dp phone. Two weeks shows the shape and keeps every
/// bar tappable.
///
/// The averages below the chart skip days with nothing logged. A day the
/// user did not open the app is missing data, not a zero-calorie day, and
/// averaging zeros in would quietly tell someone eating 2000 kcal that
/// they average 900 — a number that is not merely wrong but discouraging
/// in the direction that makes people stop logging.
class CalorieHistoryScreen extends ConsumerWidget {
  const CalorieHistoryScreen({super.key});

  static const int days = 14;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final target = ref.watch(macroTargetProvider);
    final historyAsync = ref.watch(calorieHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.calorieHistoryTitle)),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.calorieLoadFailed, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () => ref.invalidate(calorieHistoryProvider),
                  child: Text(l10n.calorieRetry),
                ),
              ],
            ),
          ),
        ),
        data: (byDay) => _History(byDay: byDay, goal: target.calories),
      ),
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.byDay, required this.goal});

  final Map<DateTime, DailyTotals> byDay;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final today = DateTime.now();
    final days = [
      for (var i = CalorieHistoryScreen.days - 1; i >= 0; i--)
        DateTime(today.year, today.month, today.day - i),
    ];
    final values = [for (final d in days) byDay[d]?.kcal ?? 0];

    final logged = values.where((v) => v > 0).toList();
    final avg = logged.isEmpty
        ? 0
        : (logged.reduce((a, b) => a + b) / logged.length).round();
    final onTarget = logged.where((v) => goal > 0 && v <= goal).length;

    if (logged.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.insights_outlined,
                  size: 40, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(l10n.calorieHistoryEmpty, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 180,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _BarsPainter(
                    values: values,
                    goal: goal,
                    barColor: AppColors.neon,
                    overColor: AppColors.orange,
                    gridColor:
                        theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_shortDate(days.first),
                      style: theme.textTheme.labelSmall),
                  Text(l10n.calorieHistoryGoalLine(goal),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                  Text(_shortDate(days.last),
                      style: theme.textTheme.labelSmall),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: l10n.calorieHistoryAverage,
                value: '$avg',
                unit: l10n.calorieKcal,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: l10n.calorieHistoryDaysLogged,
                value: '${logged.length}',
                unit: '/ ${CalorieHistoryScreen.days}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: l10n.calorieHistoryOnTarget,
                value: '$onTarget',
                unit: '/ ${logged.length}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          l10n.calorieHistoryAverageNote,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  static String _shortDate(DateTime d) =>
      '${d.day}.${d.month}'; // i18n-ignore — numeric date
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.neon,
              )),
          Text(unit, style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
        ],
      ),
    );
  }
}

/// Bars with a dashed goal line.
///
/// RTL: not mirrored, deliberately. The x axis is time and reads
/// left-to-right in both supported locales; mirroring it would put
/// "today" on the left and read as counting backwards.
class _BarsPainter extends CustomPainter {
  const _BarsPainter({
    required this.values,
    required this.goal,
    required this.barColor,
    required this.overColor,
    required this.gridColor,
  });

  final List<int> values;
  final int goal;
  final Color barColor;
  final Color overColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    // Scale to the taller of the biggest day and the goal, so the goal
    // line is always on-canvas. Scaling to the max alone would push the
    // goal off the top on a week where the user under-ate every day —
    // exactly when seeing the gap matters most.
    final peak = [
      ...values,
      if (goal > 0) goal,
    ].reduce((a, b) => a > b ? a : b);
    if (peak <= 0) return;

    final gap = 4.0;
    final barWidth = (size.width - gap * (values.length - 1)) / values.length;
    final scale = size.height / (peak * 1.1);

    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v <= 0) continue;
      final h = v * scale;
      final x = i * (barWidth + gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - h, barWidth, h),
        const Radius.circular(3),
      );
      canvas.drawRRect(
        rect,
        Paint()..color = (goal > 0 && v > goal) ? overColor : barColor,
      );
    }

    if (goal <= 0) return;
    final y = size.height - goal * scale;
    final dash = Paint()
      ..color = gridColor
      ..strokeWidth = 1.5;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, y), Offset(x + 4, y), dash);
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.goal != goal || !_sameValues(old.values, values);

  static bool _sameValues(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
