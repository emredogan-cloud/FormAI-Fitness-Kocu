import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/unit_system_provider.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/theme_extension.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/body_metrics_repository.dart';
import '../../domain/models/body_metric.dart';
import '../../domain/trend_calculator.dart';
import '../body_metrics_copy.dart';

/// Roadmap Phase 9 (C1) · the body-metrics card on the Progress tab.
///
/// This is tap two of the three the roadmap allows between the dashboard
/// and a logged weight, so it is a single tap target end to end — the
/// whole card opens the screen, rather than hiding the action behind a
/// small chevron.
///
/// It shows the latest weight and the trend sentence, and nothing else.
/// A summary that repeats the chart is a second chart; what a person
/// wants from a dashboard card is the one line they would have read the
/// chart to find.
class BodyMetricsSummaryCard extends ConsumerWidget {
  const BodyMetricsSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;
    final system = ref.watch(unitSystemProvider);
    final localeTag = Localizations.localeOf(context).toLanguageTag();

    // `.value` rather than `.when`: this card sits in the middle of a
    // scrolling tab, and a spinner that appears for one frame on every
    // rebuild is worse than the empty state it replaces.
    final entries =
        ref.watch(bodyMetricsProvider).value ?? const <BodyMetric>[];
    final series = TrendSeries.from(entries, BodyMeasure.weight);
    final latest = series.latest;
    final today = BodyMetric.dayOf(DateTime.now());
    final summary = series.summarize(asOf: today, days: 30);

    return GestureDetector(
      onTap: () {
        AppHaptics.secondaryTap();
        context.push(AppRoutes.progressBody);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.bodyMetricsCardTitle,
                    style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: scheme.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (latest == null)
              Text(
                l10n.bodyMetricsCardEmptyCta,
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.75),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              )
            else ...[
              Text(
                l10n.bodyMetricsCardLatest,
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.55),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatMeasure(
                  latest.value,
                  BodyMeasure.weight,
                  system: system,
                  localeTag: localeTag,
                ),
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                trendSentence(
                      l10n,
                      BodyMeasure.weight,
                      summary,
                      system: system,
                      localeTag: localeTag,
                    ) ??
                    l10n.bodyMetricsTrendNeedsMore,
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
