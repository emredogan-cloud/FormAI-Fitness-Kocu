import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/unit_system_provider.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/theme/neon_surface.dart';
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
/// the chart first, then the target, then how reliably they have been
/// turning up, then the raw entries. Adherence sits below the body
/// measures on purpose — it is the part they control, and it is the
/// honest thing to point at on a week when the scale has not moved.
///
/// **Nothing on this screen is coloured by valence.** No red for a gain,
/// no green for a loss, no confetti. Down is the goal for one user and
/// the opposite for another, and a recomposition user putting on two
/// kilos of muscle is succeeding.
///
/// ---
///
/// **Pre-Phase-10 polish · rebuilt to the founder's reference**
/// (`photos/new-image/your-body.png`, assets `021`–`026`). The screen
/// was stock Material on the ambient theme; it is now the brand's
/// neon-on-black surface, with the cards filling ~91 % of the width
/// rather than floating inside 20 dp gutters.
///
/// Four decisions the rebuild had to make, recorded here because they
/// are not visible in the diff:
///
///   * **This surface is dark-only**, like the workout and camera
///     screens. Light mode ships and a user can pick it, but the
///     reference is neon on pure black and there is no light rendering
///     of it that is not an approximation. Hardcoding the canvas also
///     retires the defect class that has bitten this app three times —
///     `Colors.white` over a tint fill that is dark in one theme and
///     pastel in the other — because the backdrop no longer changes.
///   * **The lime accent is the reference's, not the app's.**
///     `AppColors.neonGreen` is `#39FF14`; every green in the founder's
///     comp samples around `#B8FF33`, a yellow-green. It is defined
///     locally rather than promoted into `AppColors` until a second
///     screen wants it.
///   * **The delta line is lime whichever way the arrow points.** The
///     comp colours a loss green. Colouring a direction is exactly what
///     Phase 9 ruled out, so the *arrow* carries the direction and the
///     colour is constant — which is also how the comp treats lime
///     everywhere else on the screen (the CTA, the recent half of the
///     line): as "now", not as "good".
///   * **The comp's entry row shows a clock time. There isn't one.**
///     `BodyMetric.recordedOn` is a day — `dayOf` strips the time on the
///     way in, and one entry per day is the model. The mock reads 14:34
///     because that is when the screenshot was taken. The second line
///     carries the other measures logged that day instead, which is real.
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

// --- Surface tokens ---------------------------------------------------
//
// Sampled from `photos/new-image/your-body.png`. Local to this screen
// while it is the only one wearing them.

const String _kIconTrend = 'assets/body_metrics/icon_trend.png';
const String _kIconFlame = 'assets/body_metrics/icon_flame.png';
const String _kIconTarget = 'assets/body_metrics/icon_target.png';
const String _kIconConsistency = 'assets/body_metrics/icon_consistency.png';
const String _kArtDumbbell = 'assets/body_metrics/art_dumbbell.png';

/// 16 dp each side of a 360 dp phone leaves the cards 91 % of the width,
/// which is what the reference measures.

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
    final entriesAsync = ref.watch(bodyMetricsProvider);

    if (!_viewLogged) {
      _viewLogged = true;
      unawaited(AnalyticsService.instance.trendViewed(range: _range.token));
    }

    return Scaffold(
      backgroundColor: NeonSurface.bg,
      appBar: AppBar(
        backgroundColor: NeonSurface.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          l10n.bodyMetricsTitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: l10n.bodyMetricsAboutCta,
            color: Colors.white,
            onPressed: () => _showAboutSheet(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      // No FAB on the empty state. The device walk showed the two
      // together and they read as a bug: the same words, twice, on one
      // screen, and the eye stops to ask whether they do different
      // things. The empty state's own button is the better placement
      // because it is part of the sentence explaining what logging buys.
      floatingActionButton: (entriesAsync.value?.isEmpty ?? true)
          ? null
          : _AddMeasurementButton(
              label: l10n.bodyMetricsAddCta,
              onTap: _openEntrySheet,
            ),
      body: entriesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: NeonSurface.purple),
        ),
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

// ---------------------------------------------------------------------
// Chrome
// ---------------------------------------------------------------------

/// The bottom action. A gradient rim over a dark fill, not a filled
/// gradient — the reference's button is an outline, and a solid one at
/// this width dominates the screen it sits on.
class _AddMeasurementButton extends StatelessWidget {
  const _AddMeasurementButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: NeonSurface.purple.withValues(alpha: 0.38),
                blurRadius: 26,
                spreadRadius: -4,
              ),
              BoxShadow(
                color: NeonSurface.lime.withValues(alpha: 0.22),
                blurRadius: 26,
                spreadRadius: -6,
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(
                colors: NeonSurface.brandSweep,
                begin: AlignmentDirectional.centerStart,
                end: AlignmentDirectional.centerEnd,
              ),
            ),
            padding: const EdgeInsets.all(1.6),
            child: Material(
              color: const Color(0xFF14121C),
              borderRadius: BorderRadius.circular(999),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded,
                          color: Colors.white, size: 24),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
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
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(_kIconTrend, height: 76, fit: BoxFit.contain),
            const SizedBox(height: 20),
            Text(
              l10n.bodyMetricsEmptyTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.bodyMetricsEmptyBody,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: NeonSurface.muted,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            _AddMeasurementButton(
              label: l10n.bodyMetricsAddCta,
              onTap: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// The loaded screen
// ---------------------------------------------------------------------

class _Loaded extends ConsumerStatefulWidget {
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
  ConsumerState<_Loaded> createState() => _LoadedState();
}

class _LoadedState extends ConsumerState<_Loaded> {
  /// The reference shows a short entry list under a "View all". Three is
  /// what fits above the fold beside everything else on the screen.
  static const int _collapsedEntries = 3;

  bool _allEntries = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final system = ref.watch(unitSystemProvider);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final target = ref.watch(targetWeightProvider);
    final today = BodyMetric.dayOf(DateTime.now());

    // Only offer a measure the user has actually logged. A selector full
    // of empty tabs is an accusation.
    final tracked = <BodyMeasure>[
      for (final candidate in BodyMeasure.values)
        if (widget.entries.any((entry) => entry.valueOf(candidate) != null))
          candidate,
    ];
    final active = tracked.contains(widget.measure)
        ? widget.measure
        : (tracked.isEmpty ? BodyMeasure.weight : tracked.first);

    final series = TrendSeries.from(widget.entries, active);
    final windowDays = widget.range.days ?? _spanDays(series, today);
    final points = widget.range.days == null
        ? series.points
        : series.since(today.subtract(Duration(days: widget.range.days!)));
    final summary = series.summarize(asOf: today, days: windowDays);
    final reconciliation =
        active.isWeight ? series.reconcile(asOf: today, target: target) : null;

    if (reconciliation != null) {
      // Scheduled out of build: firing an analytics event during a frame
      // is how a rebuild loop starts.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onPaceRendered(reconciliation.pace),
      );
    }

    final ordered = widget.entries.reversed.toList(growable: false);
    final shown = _allEntries || ordered.length <= _collapsedEntries
        ? ordered
        : ordered.sublist(0, _collapsedEntries);

    return ListView(
      // 140 of bottom padding, not 96. The button is ~56 tall plus its
      // 16 margin, and 96 left the last history row's delete button
      // sitting underneath it — reachable only by scrolling past the end
      // of a list that had already ended. Found on the device.
      padding: const EdgeInsets.fromLTRB(
          NeonSurface.gutter, 4, NeonSurface.gutter, 140),
      children: [
        if (tracked.length > 1) ...[
          _MeasureSelector(
            tracked: tracked,
            active: active,
            onChanged: widget.onMeasureChanged,
          ),
          const SizedBox(height: 12),
        ],
        _RangeSelector(range: widget.range, onChanged: widget.onRangeChanged),
        const SizedBox(height: 14),
        _TrendCard(
          measure: active,
          points: points,
          latest: series.latest,
          summary: summary,
          target: active.isWeight ? target : null,
          system: system,
          localeTag: localeTag,
          onInsights: () => _showInsightsSheet(
            context,
            measure: active,
            summary: summary,
            reconciliation: reconciliation,
            system: system,
            localeTag: localeTag,
          ),
        ),
        const SizedBox(height: 14),
        _TargetCard(target: target, system: system, localeTag: localeTag),
        const SizedBox(height: 14),
        const _ConsistencyCard(),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.bodyMetricsHistoryTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (ordered.length > _collapsedEntries)
              Flexible(
                child: NeonPill(
                  bordered: false,
                  label: _allEntries
                      ? l10n.bodyMetricsHistoryShowLess
                      : l10n.bodyMetricsHistoryViewAll,
                  onTap: () => setState(() => _allEntries = !_allEntries),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        for (final entry in shown) ...[
          _EntryRow(
            entry: entry,
            active: active,
            system: system,
            localeTag: localeTag,
            onEdit: () => widget.onEdit(entry),
            onDelete: () => widget.onDelete(entry),
          ),
          const SizedBox(height: 10),
        ],
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
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tracked.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final measure = tracked[index];
          final selected = measure == active;
          return Semantics(
            button: true,
            selected: selected,
            child: Material(
              color: selected
                  ? NeonSurface.purple.withValues(alpha: 0.16)
                  : NeonSurface.card,
              borderRadius: BorderRadius.circular(999),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onChanged(measure),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected
                          ? NeonSurface.purple.withValues(alpha: 0.75)
                          : NeonSurface.hairline,
                    ),
                  ),
                  child: Text(
                    measureLabel(l10n, measure),
                    style: TextStyle(
                      color: selected ? Colors.white : NeonSurface.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Asset `021`. A hairline pill split into four, with the selected
/// segment lifted out of it by a gradient rim and a bloom.
///
/// Not a [SegmentedButton]: the selected segment has to carry a
/// two-colour rim and a glow, and Material's selected state is a fill.
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

    return Container(
      // 46, not the comp's ~26: every segment is a tap target and 26 dp
      // is under the 48 dp minimum by half. The rest of the proportions
      // are the comp's.
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: NeonSurface.hairline),
      ),
      child: Row(
        children: [
          for (final value in _Range.values)
            Expanded(
              child: _RangeSegment(
                label: label(value),
                selected: value == range,
                // The dividers sit between segments, so the first one
                // does not get a leading rule.
                divided: value != _Range.values.first && value != range,
                onTap: () => onChanged(value),
              ),
            ),
        ],
      ),
    );
  }
}

class _RangeSegment extends StatelessWidget {
  const _RangeSegment({
    required this.label,
    required this.selected,
    required this.divided,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool divided;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: selected ? Colors.white : NeonSurface.muted,
        fontSize: 14.5,
        fontWeight: FontWeight.w800,
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
          child: selected
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: NeonSurface.purple.withValues(alpha: 0.45),
                        blurRadius: 18,
                        spreadRadius: -4,
                      ),
                      BoxShadow(
                        color: NeonSurface.lime.withValues(alpha: 0.30),
                        blurRadius: 18,
                        spreadRadius: -5,
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: NeonSurface.brandSweep,
                        begin: AlignmentDirectional.centerStart,
                        end: AlignmentDirectional.centerEnd,
                      ),
                    ),
                    padding: const EdgeInsets.all(1.6),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF120C1E),
                        borderRadius: BorderRadius.circular(12.4),
                      ),
                      child: text,
                    ),
                  ),
                )
              : DecoratedBox(
                  decoration: BoxDecoration(
                    border: divided
                        ? const Border(
                            left: BorderSide(color: NeonSurface.hairline),
                          )
                        : null,
                  ),
                  child: Center(child: text),
                ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Trend card (asset 022 + 023)
// ---------------------------------------------------------------------

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.measure,
    required this.points,
    required this.latest,
    required this.summary,
    required this.target,
    required this.system,
    required this.localeTag,
    required this.onInsights,
  });

  final BodyMeasure measure;
  final List<TrendPoint> points;
  final TrendPoint? latest;
  final TrendSummary? summary;
  final double? target;
  final UnitSystem system;
  final String localeTag;
  final VoidCallback onInsights;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reading = latest;
    return NeonCard(
      gradient: true,
      fill: NeonSurface.cardDeep,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(_kIconTrend, height: 30, fit: BoxFit.contain),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l10n.bodyMetricsTrendCardTitle(measureLabel(l10n, measure)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              // Only offered when the sheet would have something in it.
              // A button that opens an empty drawer is worse than no
              // button.
              if (summary != null) ...[
                const SizedBox(width: 8),
                // Flexible, not bare. An inflexible child in a Row lays
                // out at its full intrinsic width, and the pseudo-locale
                // sweep put this one 42 px off a 320 px card.
                Flexible(
                  child: NeonPill(
                    label: l10n.bodyMetricsInsightsCta,
                    onTap: onInsights,
                  ),
                ),
              ],
            ],
          ),
          if (reading != null) ...[
            const SizedBox(height: 10),
            _BigReading(
              value: formatMeasure(
                reading.value,
                measure,
                system: system,
                localeTag: localeTag,
                withUnit: false,
              ),
              unit: measureUnitLabel(measure, system),
            ),
          ],
          if (summary != null) ...[
            const SizedBox(height: 6),
            _DeltaLine(
              summary: summary!,
              measure: measure,
              system: system,
              localeTag: localeTag,
            ),
          ],
          const SizedBox(height: 14),
          if (points.length < 2)
            _ChartPlaceholder(message: l10n.bodyMetricsChartNeedsTwo)
          else
            BodyTrendChart(
              points: points,
              targetValue: target,
              targetLabel: l10n.bodyMetricsTargetLineLabel,
              height: 200,
              strokeGradient: NeonSurface.brandSweep,
              endDotColor: Colors.white,
              axisColor: NeonSurface.faint,
              gridColor: Colors.white.withValues(alpha: 0.09),
              valueLabel: (value) => formatMeasure(
                value,
                measure,
                system: system,
                localeTag: localeTag,
                withUnit: false,
              ),
              dateLabel: (day, {required isLast}) => isLast
                  ? l10n.bodyMetricsEntryToday
                  : DateFormat.MMMd(localeTag).format(day),
            ),
          // The hint is the empty-trend sentence given the reference's
          // treatment: it appears when, and only when, there is not yet
          // enough logged to draw a line.
          if (summary == null) ...[
            const SizedBox(height: 14),
            const _HintStrip(),
          ],
        ],
      ),
    );
  }
}

class _BigReading extends StatelessWidget {
  const _BigReading({required this.value, required this.unit});

  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 46,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            unit,
            style: const TextStyle(
              color: NeonSurface.muted,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// "↓ 1.2 kg vs 30 days ago".
///
/// **The colour does not change with the direction.** The arrow is the
/// direction; lime is this screen's "now" accent and says nothing about
/// whether the movement was wanted. See the screen's class doc.
///
/// **The window is the span of the readings, not the range the user
/// picked.** The device walk caught this line claiming "vs 30 days ago"
/// beside an insights sheet saying "over the last 13 days" — the 30 was
/// the selected range and the 13 was how far back the data actually
/// went. Naming the range is a claim about a weight the app has never
/// been told. [TrendSummary.spanDays] is the honest number and it is the
/// one `trendSentence` has always used, so reading it here also makes
/// the two agree by construction rather than by coincidence.
class _DeltaLine extends StatelessWidget {
  const _DeltaLine({
    required this.summary,
    required this.measure,
    required this.system,
    required this.localeTag,
  });

  final TrendSummary summary;
  final BodyMeasure measure;
  final UnitSystem system;
  final String localeTag;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final flat = summary.direction == TrendDirection.flat;
    final magnitude = summary.totalChange.abs();
    final days = summary.spanDays;
    final sentence = flat
        ? l10n.bodyMetricsDeltaNoChange(days)
        : l10n.bodyMetricsDeltaVsWindow(
            formatMeasure(
              magnitude,
              measure,
              system: system,
              localeTag: localeTag,
            ),
            days,
          );

    return Row(
      children: [
        if (!flat) ...[
          Icon(
            summary.direction == TrendDirection.rising
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            color: NeonSurface.lime,
            size: 17,
          ),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Text(
            sentence,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: NeonSurface.lime,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Asset `023` · the "log once more" strip inside the trend card.
class _HintStrip extends StatelessWidget {
  const _HintStrip();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NeonSurface.purple.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Image.asset(_kIconFlame, height: 42, fit: BoxFit.contain),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.bodyMetricsTrendNeedsMore,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Decoration, and the only thing on the screen that is. Hidden
          // from the reader rather than described, because there is
          // nothing to say about it.
          ExcludeSemantics(
            child: Image.asset(_kArtDumbbell, height: 58, fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }
}

class _ChartPlaceholder extends StatelessWidget {
  const _ChartPlaceholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: NeonSurface.hairline),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: NeonSurface.muted, fontSize: 13),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Target (asset 024)
// ---------------------------------------------------------------------

class _TargetCard extends ConsumerWidget {
  const _TargetCard({
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
    return NeonCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(_kIconTarget, height: 46, fit: BoxFit.contain),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.bodyMetricsTargetTitle,
                  style: const TextStyle(
                    color: NeonSurface.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  target == null
                      ? l10n.bodyMetricsTargetNone
                      : formatMeasure(
                          target!,
                          BodyMeasure.weight,
                          system: system,
                          localeTag: localeTag,
                        ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (target == null) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.bodyMetricsTargetHint,
                    style: const TextStyle(
                      color: NeonSurface.faint,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Flexible, not fixed: an inflexible child in a Row lays out at
          // its full intrinsic width, and "Set a target" is not the
          // longest this button gets.
          Flexible(
            child: NeonPill(
              label: target == null
                  ? l10n.bodyMetricsTargetSet
                  : l10n.bodyMetricsTargetChange,
              onTap: () => _showTargetSheet(context, ref),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Consistency (asset 025)
// ---------------------------------------------------------------------

class _ConsistencyCard extends ConsumerWidget {
  const _ConsistencyCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final adherence = ref.watch(adherenceProvider);
    final planned = adherence.weekPlanned;

    return NeonCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child:
                Image.asset(_kIconConsistency, height: 46, fit: BoxFit.contain),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.adherenceCardTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // A count, not a percentage. See
                            // [AdherenceSummary].
                            _AdherenceFigure(
                              label: l10n.adherenceWeeklyLabel,
                              text: planned == null
                                  ? null
                                  : l10n.adherenceSessionsValue(
                                      adherence.weekCompleted,
                                      planned,
                                    ),
                            ),
                            if (planned != null) ...[
                              const SizedBox(height: 10),
                              _WeekDots(
                                completed: adherence.weekCompleted,
                                planned: planned,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const VerticalDivider(
                        color: NeonSurface.hairline,
                        width: 25,
                        thickness: 1,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _AdherenceFigure(
                              label: l10n.adherenceThirtyLabel,
                              text: adherence.rollingThirtyDay == null
                                  ? null
                                  : percentLabel(
                                      l10n, adherence.rollingThirtyDay!),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              l10n.adherenceLongestStreak(
                                  adherence.longestStreak),
                              style: const TextStyle(
                                color: NeonSurface.muted,
                                fontSize: 12.5,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

/// One ring per planned session this week, filled as they are done.
///
/// Capped at seven: the row is beside a divider on a 360 dp phone and a
/// user who planned fourteen sessions still gets a readable row, with
/// the exact count already stated above it as "9 of 14".
class _WeekDots extends StatelessWidget {
  const _WeekDots({required this.completed, required this.planned});

  final int completed;
  final int planned;

  @override
  Widget build(BuildContext context) {
    final count = planned.clamp(0, 7);
    if (count == 0) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 7),
            Container(
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < completed
                    ? NeonSurface.purple
                    : NeonSurface.purple.withValues(alpha: 0.10),
                border: Border.all(
                  color: NeonSurface.purple
                      .withValues(alpha: i < completed ? 1 : 0.55),
                  width: 1.4,
                ),
              ),
            ),
          ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: NeonSurface.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          text ?? l10n.adherenceNothingPlanned,
          style: TextStyle(
            color: Colors.white,
            fontSize: text == null ? 13 : 22,
            fontWeight: text == null ? FontWeight.w600 : FontWeight.w800,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Entries
// ---------------------------------------------------------------------

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.active,
    required this.system,
    required this.localeTag,
    required this.onEdit,
    required this.onDelete,
  });

  final BodyMetric entry;
  final BodyMeasure active;
  final UnitSystem system;
  final String localeTag;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isToday = entry.recordedOn == BodyMetric.dayOf(DateTime.now());
    final headline = isToday
        ? l10n.bodyMetricsEntryToday
        : DateFormat.yMMMd(localeTag).format(entry.recordedOn);
    final activeValue = entry.valueOf(active);

    // Everything this entry holds APART from the value already shown on
    // the right, so the row never says the same number twice.
    final others = [
      for (final measure in entry.presentMeasures)
        if (measure != active || activeValue == null)
          '${measureLabel(l10n, measure)} '
              '${formatMeasure(entry.valueOf(measure)!, measure, system: system, localeTag: localeTag)}',
    ].join(' · ');
    final subtitle = [
      if (others.isNotEmpty) others,
      if (entry.note != null) entry.note!,
    ].join(' · ');

    return Material(
      color: NeonSurface.card,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 6, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: NeonSurface.hairline),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: NeonSurface.purple.withValues(alpha: 0.55)),
                ),
                child: const Icon(
                  Icons.event_note_rounded,
                  color: NeonSurface.purple,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      headline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: NeonSurface.faint, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              if (activeValue != null) ...[
                const SizedBox(width: 8),
                Text(
                  formatMeasure(
                    activeValue,
                    active,
                    system: system,
                    localeTag: localeTag,
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: NeonSurface.muted,
                tooltip: l10n.bodyMetricsDelete,
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Sheets
// ---------------------------------------------------------------------

/// The screen's own dark sheet chrome, so a bottom sheet opening off a
/// hardcoded-dark surface does not arrive in the ambient theme.
Future<void> _showDarkSheet(BuildContext context, Widget child) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: NeonSurface.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: NeonSurface.hairline)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      child: SafeArea(top: false, child: child),
    ),
  );
}

Widget _sheetTitle(String text) => Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 19,
        fontWeight: FontWeight.w800,
      ),
    );

Widget _sheetBody(String text) => Text(
      text,
      style:
          const TextStyle(color: NeonSurface.muted, fontSize: 14, height: 1.5),
    );

/// The longer reading of the trend — the sentence, the plateau note and
/// the target reconciliation.
///
/// These three used to sit inline under the chart. The reference does
/// not have them there and it is a better screen for it: the compact
/// "↓ 1.2 kg vs 30 days ago" carries the headline, and the paragraphs
/// that interpret it are one tap away rather than three cards deep.
void _showInsightsSheet(
  BuildContext context, {
  required BodyMeasure measure,
  required TrendSummary? summary,
  required GoalReconciliation? reconciliation,
  required UnitSystem system,
  required String localeTag,
}) {
  final l10n = AppLocalizations.of(context);
  final sentence = trendSentence(
    l10n,
    measure,
    summary,
    system: system,
    localeTag: localeTag,
  );
  _showDarkSheet(
    context,
    Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetTitle(l10n.bodyMetricsInsightsTitle),
        const SizedBox(height: 14),
        _sheetBody(sentence ?? l10n.bodyMetricsTrendNeedsMore),
        if (reconciliation != null) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.bodyMetricsGoalCardTitle,
                  style: const TextStyle(
                    color: NeonSurface.faint,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  goalWeekLabel(l10n, reconciliation),
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: NeonSurface.faint,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _sheetBody(
            goalSentence(
              l10n,
              reconciliation,
              system: system,
              localeTag: localeTag,
            ),
          ),
        ],
        if (summary?.isPlateau ?? false) ...[
          const SizedBox(height: 20),
          Text(
            l10n.bodyMetricsPlateauTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          _sheetBody(l10n.bodyMetricsPlateauBody),
        ],
      ],
    ),
  );
}

/// What the chart is doing, and why nothing on it is coloured.
void _showAboutSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  _showDarkSheet(
    context,
    Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetTitle(l10n.bodyMetricsAboutCta),
        const SizedBox(height: 14),
        _sheetBody(l10n.bodyMetricsAboutSmoothing),
        const SizedBox(height: 14),
        _sheetBody(l10n.bodyMetricsAboutNoValence),
      ],
    ),
  );
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
        decoration: const BoxDecoration(
          color: NeonSurface.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: NeonSurface.hairline)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetTitle(l10n.bodyMetricsTargetSheetTitle),
            const SizedBox(height: 8),
            _sheetBody(l10n.bodyMetricsTargetExplain),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.bodyMetricsTargetTitle,
                labelStyle: const TextStyle(color: NeonSurface.muted),
                suffixText: weightUnitLabel(system),
                suffixStyle: const TextStyle(color: NeonSurface.muted),
                errorText:
                    _invalid ? _rangeError(l10n, system, localeTag) : null,
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: NeonSurface.hairline),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: NeonSurface.purple),
                ),
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
                    child: Text(
                      l10n.bodyMetricsTargetRemove,
                      style: const TextStyle(color: NeonSurface.muted),
                    ),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: NeonSurface.purple,
                    foregroundColor: Colors.white,
                  ),
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
