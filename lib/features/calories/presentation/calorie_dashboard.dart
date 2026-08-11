import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../nutrition/providers/nutrition_provider.dart';
import '../domain/models/meal_entry.dart';
import '../domain/models/scan_result.dart';
import '../providers/calorie_providers.dart';
import 'food_scan_flow.dart';
import 'widgets/calorie_ring.dart';

/// The AI calorie tracker.
///
/// Lives inside the Nutrition tab rather than in a sixth bottom-nav slot
/// (founder decision, 2026-08-11): Community keeps its place, and
/// "calories" and "recipes" are two views of the same subject rather than
/// two destinations.
///
/// Targets come from `macroTargetProvider` — the same numbers the recipe
/// half of the tab plans against. Computing a second target here would
/// let the two halves of one tab disagree about the user's day.
class CalorieDashboard extends ConsumerWidget {
  const CalorieDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final target = ref.watch(macroTargetProvider);
    final dayAsync = ref.watch(dailyMealsProvider);

    return RefreshIndicator(
      onRefresh: () async => refreshCalorieSurfaces(ref),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          const _DayHeader(),
          const SizedBox(height: 12),
          dayAsync.when(
            loading: () => const _DashboardSkeleton(),
            error: (_, __) => _DashboardError(
              onRetry: () => ref.invalidate(dailyMealsProvider),
            ),
            data: (totals) => Column(
              children: [
                _SummaryCard(totals: totals, target: target),
                const SizedBox(height: 12),
                _MacrosCard(totals: totals, target: target),
                const SizedBox(height: 12),
                _SlotBreakdown(totals: totals),
                const SizedBox(height: 12),
                if (totals.meals.isEmpty)
                  _EmptyDay(l10n: l10n)
                else
                  _MealList(meals: totals.meals),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The date being shown, and how to move between days.
class _DayHeader extends ConsumerWidget {
  const _DayHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final day = ref.watch(selectedCalorieDayProvider);
    final now = DateTime.now();
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 18, color: AppColors.neon),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isToday
                        ? l10n.calorieDayToday
                        : MaterialLocalizations.of(context)
                            .formatMediumDate(day),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: l10n.caloriePreviousDay,
          onPressed: () =>
              ref.read(selectedCalorieDayProvider.notifier).shiftDays(-1),
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          // Tomorrow has no data by definition, so the control stops at
          // today rather than letting the user walk into empty days and
          // wonder whether their log is broken.
          tooltip: l10n.calorieNextDay,
          onPressed: isToday
              ? null
              : () =>
                  ref.read(selectedCalorieDayProvider.notifier).shiftDays(1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _SummaryCard extends ConsumerWidget {
  const _SummaryCard({required this.totals, required this.target});

  final DailyTotals totals;
  final dynamic target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final goal = (target.calories as int?) ?? 0;
    final remaining = goal - totals.kcal;

    return _Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CalorieRing(
            consumed: totals.kcal,
            target: goal,
            size: 150,
            centerLabel: '${totals.kcal}',
            centerSublabel: l10n.calorieConsumed,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  remaining >= 0
                      ? l10n.calorieRemaining
                      : l10n.calorieOverTarget,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${remaining.abs()}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: remaining >= 0 ? AppColors.neon : AppColors.orange,
                  ),
                ),
                Text(
                  l10n.calorieKcal,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                _StatLine(label: l10n.calorieTarget, value: '$goal'),
                _StatLine(label: l10n.calorieConsumed, value: '${totals.kcal}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppColors.neon,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
          ),
          Text(value,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _MacrosCard extends StatelessWidget {
  const _MacrosCard({required this.totals, required this.target});

  final DailyTotals totals;
  final dynamic target;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.calorieMacros,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MacroColumn(
                  label: l10n.calorieProtein,
                  value: totals.proteinG,
                  goal: (target.protein as int?) ?? 0,
                  color: AppColors.neon,
                ),
              ),
              Expanded(
                child: _MacroColumn(
                  label: l10n.calorieCarbs,
                  value: totals.carbsG,
                  goal: (target.carbs as int?) ?? 0,
                  color: AppColors.neonAccent,
                ),
              ),
              Expanded(
                child: _MacroColumn(
                  label: l10n.calorieFat,
                  value: totals.fatG,
                  goal: (target.fat as int?) ?? 0,
                  color: AppColors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroColumn extends StatelessWidget {
  const _MacroColumn({
    required this.label,
    required this.value,
    required this.goal,
    required this.color,
  });

  final String label;
  final int value;
  final int goal;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = goal <= 0 ? 0.0 : (value / goal).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(children: [
              TextSpan(
                text: '$value',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700, color: color),
              ),
              TextSpan(
                text: ' / $goal g',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ]),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Per-slot totals — the reference design's "Kalori Kaynakları".
class _SlotBreakdown extends StatelessWidget {
  const _SlotBreakdown({required this.totals});

  final DailyTotals totals;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.calorieSources,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final slot in MealSlot.values)
                Expanded(
                  child: _SlotTile(
                    label: slotLabel(l10n, slot),
                    kcal: totals.kcalForSlot(slot),
                    icon: slotIcon(slot),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.label,
    required this.kcal,
    required this.icon,
  });

  final String label;
  final int kcal;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final used = kcal > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest
              .withValues(alpha: used ? 0.55 : 0.25),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 20,
                color:
                    used ? AppColors.neon : theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall,
            ),
            const SizedBox(height: 2),
            Text(
              '$kcal',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color:
                    used ? AppColors.neon : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealList extends ConsumerWidget {
  const _MealList({required this.meals});

  final List<MealEntry> meals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.calorieMeals,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          for (final meal in meals) _MealBlock(meal: meal),
        ],
      ),
    );
  }
}

class _MealBlock extends ConsumerWidget {
  const _MealBlock({required this.meal});

  final MealEntry meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.neon.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(9),
                ),
                child:
                    Icon(slotIcon(meal.slot), size: 17, color: AppColors.neon),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  slotLabel(l10n, meal.slot),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                l10n.calorieKcalValue(meal.kcal),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.neon,
                ),
              ),
              IconButton(
                tooltip: l10n.calorieDeleteMeal,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 18),
                onPressed: () async {
                  await ref.read(calorieRepositoryProvider).deleteMeal(meal.id);
                  refreshCalorieSurfaces(ref);
                },
              ),
            ],
          ),
          for (final item in meal.items)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8, top: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: item.name),
                        if (item.portionLabel.isNotEmpty)
                          TextSpan(
                            text: ' · ${item.portionLabel}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ]),
                      style: theme.textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  ConfidenceDot(confidence: item.confidence),
                  const SizedBox(width: 8),
                  Text(
                    l10n.calorieKcalValue(item.kcal),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          // The honesty qualifier from the research doc (§6). Shown only
          // when the meal actually contains a low-confidence item, so it
          // stays meaningful instead of becoming boilerplate the user
          // learns to skip.
          if (meal.hasLowConfidenceItem)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8, top: 8),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.calorieEstimateCaveat,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A small coloured dot carrying an item's confidence.
///
/// Paired with a `Semantics` label rather than relying on colour alone —
/// confidence is the one thing on this screen a user must not miss, and
/// colour is exactly what a colour-blind or low-vision user does miss.
class ConfidenceDot extends StatelessWidget {
  const ConfidenceDot({super.key, required this.confidence});

  final ItemConfidence confidence;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (color, label) = switch (confidence) {
      ItemConfidence.high => (AppColors.success, l10n.calorieConfidenceHigh),
      ItemConfidence.medium => (AppColors.orange, l10n.calorieConfidenceMedium),
      ItemConfidence.low => (AppColors.danger, l10n.calorieConfidenceLow),
    };

    return Semantics(
      label: label,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Card(
      child: Column(
        children: [
          Icon(Icons.restaurant_menu,
              size: 34, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(l10n.calorieEmptyTitle,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            l10n.calorieEmptyBody,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Card(
      child: Column(
        children: [
          Text(l10n.calorieLoadFailed, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          FilledButton.tonal(
            onPressed: onRetry,
            child: Text(l10n.calorieRetry),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: child,
    );
  }
}

IconData slotIcon(MealSlot slot) => switch (slot) {
      MealSlot.breakfast => Icons.wb_sunny_outlined,
      MealSlot.lunch => Icons.lunch_dining_outlined,
      MealSlot.dinner => Icons.dinner_dining_outlined,
      MealSlot.snack => Icons.cookie_outlined,
    };

String slotLabel(AppLocalizations l10n, MealSlot slot) => switch (slot) {
      MealSlot.breakfast => l10n.calorieSlotBreakfast,
      MealSlot.lunch => l10n.calorieSlotLunch,
      MealSlot.dinner => l10n.calorieSlotDinner,
      MealSlot.snack => l10n.calorieSlotSnack,
    };

/// The scan CTA and its quota counter, pinned above the bottom nav.
///
/// The remaining-scans line is not decoration: it is the founder's
/// requirement that a free user can see the limit approaching rather than
/// discovering it at the moment they are refused. A counter that only
/// appears at zero teaches users the feature is broken; one that counts
/// down teaches them what Pro buys.
class CalorieScanBar extends ConsumerWidget {
  const CalorieScanBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final quota = ref.watch(scanQuotaProvider).value ?? ScanQuota.unknown;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (quota.isKnown)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                quota.isExhausted
                    ? l10n.calorieScansExhausted(quota.limit)
                    : l10n.calorieScansLeft(quota.remaining, quota.limit),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: quota.isExhausted
                      ? AppColors.orange
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => startFoodScan(context, ref),
                  icon: const Icon(Icons.center_focus_strong),
                  label: Text(l10n.calorieScanCta),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.neon,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => startManualEntry(context, ref),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.calorieAddManual),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
