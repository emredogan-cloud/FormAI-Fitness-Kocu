import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/unit_system_provider.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../core/utils/unit_system.dart';
import '../../../l10n/app_localizations.dart';
import '../data/body_metrics_repository.dart';
import '../domain/models/body_metric.dart';
import '../domain/trend_calculator.dart';
import '../providers/adherence_provider.dart';
import '../providers/target_weight_provider.dart';
import 'body_metrics_copy.dart';
import 'widgets/body_metric_entry_sheet.dart';
import 'widgets/body_trend_chart.dart';

/// Roadmap Phase 9 (C1, C3) · "is this working?", answered from inside
/// the app.
///
/// The screen is ordered by what a person actually came to find out:
/// the chart first, then the sentence that reads it aloud, then the
/// target, then how reliably they have been turning up, then the raw
/// entries. Adherence sits below the body measures on purpose — it is
/// the part they control, and it is the honest thing to point at on a
/// week when the scale has not moved.
///
/// **Nothing on this screen is coloured by valence.** No red for a gain,
/// no green for a loss, no confetti. Down is the goal for one user and
/// the opposite for another, and a recomposition user putting on two
/// kilos of muscle is succeeding. The chart line is the app's own accent
/// colour in every state.
class BodyMetricsScreen extends ConsumerStatefulWidget {
  const BodyMetricsScreen({super.key});

  @override
  ConsumerState<BodyMetricsScreen> createState() => _BodyMetricsScreenState();
}

/// The chart windows, in the order the segmented control shows them.
enum _Range {
  week(7, 'week'),
  month(30, 'month'),
  quarter(90, 'quarter'),
  all(null, 'all');

  const _Range(this.days, this.token);

  /// Null means "everything logged".
  final int? days;

  /// Stable analytics token, never the localised label.
  final String token;
}

class _BodyMetricsScreenState extends ConsumerState<BodyMetricsScreen> {
  _Range _range = _Range.month;
  BodyMeasure _measure = BodyMeasure.weight;

  /// Fired once per visit rather than on every rebuild, so the event
  /// counts people rather than frames.
  bool _viewLogged = false;

  /// The pace last reported, so a rebuild that does not change the
  /// verdict does not send a second event.
  GoalPace? _lastPaceLogged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;
    final entriesAsync = ref.watch(bodyMetricsProvider);

    if (!_viewLogged) {
      _viewLogged = true;
      unawaited(AnalyticsService.instance.trendViewed(range: _range.token));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        foregroundColor: scheme.onSurface,
        title: Text(
          l10n.bodyMetricsTitle,
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
      ),
      // No FAB on the empty state. The device walk showed the two
      // together and they read as a bug: the same words, twice, on one
      // screen, and the eye stops to ask whether they do different
      // things. The empty state's own button is the better placement
      // because it is part of the sentence explaining what logging buys.
      floatingActionButton: (entriesAsync.value?.isEmpty ?? true)
          ? null
          : FloatingActionButton.extended(
              onPressed: _openEntrySheet,
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.bodyMetricsAddCta),
            ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        // A read that could not reach the network still has the local
        // copy, so the repository never surfaces an error here. If one
        // ever escapes, an empty state is the truthful fallback.
        error: (_, __) => _EmptyState(onAdd: _openEntrySheet),
        data: (entries) => entries.isEmpty
            ? _EmptyState(onAdd: _openEntrySheet)
            : _Loaded(
                entries: entries,
                range: _range,
                measure: _measure,
                onRangeChanged: (range) {
                  setState(() => _range = range);
                  unawaited(
                    AnalyticsService.instance.trendViewed(range: range.token),
                  );
                },
                onMeasureChanged: (measure) =>
                    setState(() => _measure = measure),
                onPaceRendered: _logPace,
                onEdit: (entry) => _openEntrySheet(existing: entry),
                onDelete: _delete,
              ),
      ),
    );
  }

  void _logPace(GoalPace pace) {
    if (_lastPaceLogged == pace) return;
    _lastPaceLogged = pace;
    unawaited(
      AnalyticsService.instance.goalReconciliationViewed(pace: pace.name),
    );
  }

  Future<void> _openEntrySheet({BodyMetric? existing}) async {
    final saved = await showBodyMetricEntrySheet(context, existing: existing);
    if (saved != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).bodyMetricsEntrySaved),
      ),
    );
  }

  Future<void> _delete(BodyMetric entry) async {
    await ref.read(bodyMetricsRepositoryProvider).delete(entry.recordedOn);
    ref.invalidate(bodyMetricsProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).bodyMetricsDeleted),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.show_chart_rounded,
              size: 48,
              color: scheme.onSurface.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.bodyMetricsEmptyTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.bodyMetricsEmptyBody,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.65),
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onAdd,
              child: Text(l10n.bodyMetricsAddCta),
            ),
          ],
        ),
      ),
    );
  }
}

class _Loaded extends ConsumerWidget {
  const _Loaded({
    required this.entries,
    required this.range,
    required this.measure,
    required this.onRangeChanged,
    required this.onMeasureChanged,
    required this.onPaceRendered,
    required this.onEdit,
    required this.onDelete,
  });

  final List<BodyMetric> entries;
  final _Range range;
  final BodyMeasure measure;
  final ValueChanged<_Range> onRangeChanged;
  final ValueChanged<BodyMeasure> onMeasureChanged;
  final ValueChanged<GoalPace> onPaceRendered;
  final ValueChanged<BodyMetric> onEdit;
  final ValueChanged<BodyMetric> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final system = ref.watch(unitSystemProvider);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final target = ref.watch(targetWeightProvider);
    final today = BodyMetric.dayOf(DateTime.now());

    // Only offer a measure the user has actually logged. A selector full
    // of empty tabs is an accusation.
    final tracked = <BodyMeasure>[
      for (final candidate in BodyMeasure.values)
        if (entries.any((entry) => entry.valueOf(candidate) != null)) candidate,
    ];
    final active = tracked.contains(measure)
        ? measure
        : (tracked.isEmpty ? BodyMeasure.weight : tracked.first);

    final series = TrendSeries.from(entries, active);
    final windowDays = range.days ?? _spanDays(series, today);
    final points = range.days == null
        ? series.points
        : series.since(today.subtract(Duration(days: range.days!)));
    final summary = series.summarize(asOf: today, days: windowDays);
    final reconciliation =
        active.isWeight ? series.reconcile(asOf: today, target: target) : null;

    if (reconciliation != null) {
      // Scheduled out of build: firing an analytics event during a frame
      // is how a rebuild loop starts.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => onPaceRendered(reconciliation.pace),
      );
    }

    return ListView(
      // 140 of bottom padding, not 96. An extended FAB is ~56 tall plus
      // its 16 margin, and 96 left the last history row's delete button
      // sitting underneath it — reachable only by scrolling past the end
      // of a list that had already ended. Found on the device.
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 140),
      children: [
        if (tracked.length > 1) ...[
          _MeasureSelector(
            tracked: tracked,
            active: active,
            onChanged: onMeasureChanged,
          ),
          const SizedBox(height: 14),
        ],
        _RangeSelector(range: range, onChanged: onRangeChanged),
        const SizedBox(height: 12),
        if (points.length < 2)
          _ChartPlaceholder(message: l10n.bodyMetricsChartNeedsTwo)
        else
          BodyTrendChart(
            points: points,
            targetValue: active.isWeight ? target : null,
            targetLabel: l10n.bodyMetricsTargetLineLabel,
          ),
        const SizedBox(height: 16),
        _TrendReadout(
          sentence: trendSentence(
            l10n,
            active,
            summary,
            system: system,
            localeTag: localeTag,
          ),
        ),
        if (summary?.isPlateau ?? false) ...[
          const SizedBox(height: 14),
          const _PlateauCard(),
        ],
        const SizedBox(height: 20),
        _TargetRow(target: target, system: system, localeTag: localeTag),
        if (reconciliation != null) ...[
          const SizedBox(height: 14),
          _GoalCard(
            reconciliation: reconciliation,
            system: system,
            localeTag: localeTag,
          ),
        ],
        const SizedBox(height: 20),
        const _AdherenceCard(),
        const SizedBox(height: 20),
        _HistoryList(
          entries: entries.reversed.toList(growable: false),
          system: system,
          localeTag: localeTag,
          onEdit: onEdit,
          onDelete: onDelete,
        ),
      ],
    );
  }

  /// The span the "All" range covers, so the readout can name a real
  /// number of days rather than a window that does not exist.
  int _spanDays(TrendSeries series, DateTime today) {
    final first = series.first;
    if (first == null) return 0;
    return today.difference(first.day).inDays + 1;
  }
}

class _MeasureSelector extends StatelessWidget {
  const _MeasureSelector({
    required this.tracked,
    required this.active,
    required this.onChanged,
  });

  final List<BodyMeasure> tracked;
  final BodyMeasure active;
  final ValueChanged<BodyMeasure> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final measure in tracked) ...[
            ChoiceChip(
              label: Text(measureLabel(l10n, measure)),
              selected: measure == active,
              onSelected: (_) => onChanged(measure),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.range, required this.onChanged});

  final _Range range;
  final ValueChanged<_Range> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String label(_Range value) => switch (value) {
          _Range.week => l10n.bodyMetricsRange7,
          _Range.month => l10n.bodyMetricsRange30,
          _Range.quarter => l10n.bodyMetricsRange90,
          _Range.all => l10n.bodyMetricsRangeAll,
        };
    return SegmentedButton<_Range>(
      showSelectedIcon: false,
      segments: [
        for (final value in _Range.values)
          ButtonSegment(value: value, label: Text(label(value))),
      ],
      selected: {range},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _ChartPlaceholder extends StatelessWidget {
  const _ChartPlaceholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Container(
      height: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.12)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: scheme.onSurface.withValues(alpha: 0.6),
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _TrendReadout extends StatelessWidget {
  const _TrendReadout({required this.sentence});

  final String? sentence;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;
    return Text(
      sentence ?? l10n.bodyMetricsTrendNeedsMore,
      style: TextStyle(
        color: scheme.onSurface.withValues(alpha: sentence == null ? 0.6 : 0.9),
        fontSize: 15,
        height: 1.4,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _PlateauCard extends StatelessWidget {
  const _PlateauCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.bodyMetricsPlateauTitle,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.bodyMetricsPlateauBody,
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.75),
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetRow extends ConsumerWidget {
  const _TargetRow({
    required this.target,
    required this.system,
    required this.localeTag,
  });

  final double? target;
  final UnitSystem system;
  final String localeTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;
    return _SoftCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.bodyMetricsTargetTitle,
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  target == null
                      ? l10n.bodyMetricsTargetNone
                      : formatMeasure(
                          target!,
                          BodyMeasure.weight,
                          system: system,
                          localeTag: localeTag,
                        ),
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          // Same reason as the goal card's week label: an inflexible
          // child in a Row lays out at its full intrinsic width, and
          // "Set a target" is not the longest this button gets.
          Flexible(
            child: TextButton(
              onPressed: () => _showTargetSheet(context, ref),
              child: Text(
                target == null
                    ? l10n.bodyMetricsTargetSet
                    : l10n.bodyMetricsTargetChange,
                textAlign: TextAlign.end,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showTargetSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _TargetSheet(),
  );
}

class _TargetSheet extends ConsumerStatefulWidget {
  const _TargetSheet();

  @override
  ConsumerState<_TargetSheet> createState() => _TargetSheetState();
}

class _TargetSheetState extends ConsumerState<_TargetSheet> {
  final _controller = TextEditingController();
  bool _seeded = false;
  bool _invalid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;
    final system = ref.watch(unitSystemProvider);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final current = ref.watch(targetWeightProvider);

    if (!_seeded) {
      _seeded = true;
      if (current != null) {
        _controller.text = formatMeasure(
          current,
          BodyMeasure.weight,
          system: system,
          localeTag: localeTag,
          withUnit: false,
        );
      }
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.bodyMetricsTargetSheetTitle,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.bodyMetricsTargetExplain,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.65),
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.bodyMetricsTargetTitle,
                suffixText: weightUnitLabel(system),
                errorText:
                    _invalid ? _rangeError(l10n, system, localeTag) : null,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (current != null)
                  TextButton(
                    onPressed: () async {
                      await ref.read(targetWeightProvider.notifier).set(null);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: Text(l10n.bodyMetricsTargetRemove),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _save,
                  child: Text(l10n.bodyMetricsEntrySave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _rangeError(
    AppLocalizations l10n,
    UnitSystem system,
    String localeTag,
  ) {
    final range = measureRangeMetric(BodyMeasure.weight);
    return l10n.bodyMetricsEntryRangeError(
      formatMeasure(range.min, BodyMeasure.weight,
          system: system, localeTag: localeTag, withUnit: false),
      formatMeasure(range.max, BodyMeasure.weight,
          system: system, localeTag: localeTag, withUnit: false),
      weightUnitLabel(system),
    );
  }

  Future<void> _save() async {
    final system = ref.read(unitSystemProvider);
    final raw = _controller.text.trim().replaceAll(',', '.');
    final parsed = double.tryParse(raw);
    if (parsed == null) {
      setState(() => _invalid = true);
      return;
    }
    final kg = system == UnitSystem.metric ? parsed : lbToKg(parsed);
    final range = measureRangeMetric(BodyMeasure.weight);
    if (kg < range.min || kg > range.max) {
      setState(() => _invalid = true);
      return;
    }
    await ref.read(targetWeightProvider.notifier).set(roundTo(kg, 1));
    if (mounted) Navigator.of(context).pop();
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.reconciliation,
    required this.system,
    required this.localeTag,
  });

  final GoalReconciliation reconciliation;
  final UnitSystem system;
  final String localeTag;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  l10n.bodyMetricsGoalCardTitle,
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Flexible, not bare: a `Text` in a Row's inflexible slot
              // lays out on one line at its full intrinsic width, so a
              // longer translation of "Week 5 of 12" pushes the whole row
              // off the card. This one did — 98 px under pseudo-
              // localisation, which is roughly what German would do.
              Flexible(
                child: Text(
                  goalWeekLabel(l10n, reconciliation),
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            goalSentence(
              l10n,
              reconciliation,
              system: system,
              localeTag: localeTag,
            ),
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdherenceCard extends ConsumerWidget {
  const _AdherenceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;
    final adherence = ref.watch(adherenceProvider);

    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.adherenceCardTitle,
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.7),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                // A count, not a percentage. See [AdherenceSummary].
                child: _AdherenceFigure(
                  label: l10n.adherenceWeeklyLabel,
                  text: adherence.weekPlanned == null
                      ? null
                      : l10n.adherenceSessionsValue(
                          adherence.weekCompleted,
                          adherence.weekPlanned!,
                        ),
                ),
              ),
              Expanded(
                child: _AdherenceFigure(
                  label: l10n.adherenceThirtyLabel,
                  text: adherence.rollingThirtyDay == null
                      ? null
                      : percentLabel(l10n, adherence.rollingThirtyDay!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.adherenceLongestStreak(adherence.longestStreak),
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.65),
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdherenceFigure extends StatelessWidget {
  const _AdherenceFigure({required this.label, required this.text});

  final String label;

  /// Null means this window has nothing it can honestly report —
  /// rendered as a sentence saying so, never as 0 %.
  final String? text;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: scheme.onSurface.withValues(alpha: 0.6),
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          text ?? l10n.adherenceNothingPlanned,
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: text == null ? 12.5 : 19,
            fontWeight: text == null ? FontWeight.w500 : FontWeight.w900,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.entries,
    required this.system,
    required this.localeTag,
    required this.onEdit,
    required this.onDelete,
  });

  final List<BodyMetric> entries;
  final UnitSystem system;
  final String localeTag;
  final ValueChanged<BodyMetric> onEdit;
  final ValueChanged<BodyMetric> onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.bodyMetricsHistoryTitle,
          style: TextStyle(
            color: scheme.onSurface.withValues(alpha: 0.7),
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        for (final entry in entries)
          _HistoryRow(
            entry: entry,
            system: system,
            localeTag: localeTag,
            onEdit: () => onEdit(entry),
            onDelete: () => onDelete(entry),
          ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.entry,
    required this.system,
    required this.localeTag,
    required this.onEdit,
    required this.onDelete,
  });

  final BodyMetric entry;
  final UnitSystem system;
  final String localeTag;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;
    final isToday = entry.recordedOn == BodyMetric.dayOf(DateTime.now());
    final values = [
      for (final measure in entry.presentMeasures)
        '${measureLabel(l10n, measure)} '
            '${formatMeasure(entry.valueOf(measure)!, measure, system: system, localeTag: localeTag)}',
    ].join(' · ');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onEdit,
      title: Text(
        isToday
            ? l10n.bodyMetricsEntryToday
            : DateFormat.yMMMd(localeTag).format(entry.recordedOn),
        style: TextStyle(
          color: scheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            values,
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.7),
              fontSize: 12.5,
            ),
          ),
          if (entry.note != null)
            Text(
              entry.note!,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.5),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline_rounded, size: 20),
        tooltip: l10n.bodyMetricsDelete,
        onPressed: onDelete,
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }
}
