import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/unit_system_provider.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/theme/theme_extension.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../core/utils/unit_system.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/body_metrics_repository.dart';
import '../../domain/models/body_metric.dart';
import '../body_metrics_copy.dart';

/// Roadmap Phase 9 (C1) · the quick-entry sheet.
///
/// The roadmap sets a hard requirement of "≤ 3 taps from the dashboard —
/// friction here kills the whole feature". This is tap three: Progress
/// tab → the body card → this sheet, open on the weight field with the
/// keyboard already up. Everything below weight is optional and stays
/// collapsed until asked for, because a user who only weighs themselves
/// must not have to scroll past five fields they will never fill.
///
/// **Fields are in display units and storage is metric.** The conversion
/// happens here, at the boundary, which is the whole contract
/// `unit_system.dart` exists to keep.
Future<bool?> showBodyMetricEntrySheet(
  BuildContext context, {
  BodyMetric? existing,
  DateTime? day,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BodyMetricEntrySheet(existing: existing, day: day),
  );
}

class _BodyMetricEntrySheet extends ConsumerStatefulWidget {
  const _BodyMetricEntrySheet({this.existing, this.day});

  final BodyMetric? existing;
  final DateTime? day;

  @override
  ConsumerState<_BodyMetricEntrySheet> createState() =>
      _BodyMetricEntrySheetState();
}

class _BodyMetricEntrySheetState extends ConsumerState<_BodyMetricEntrySheet> {
  late final Map<BodyMeasure, TextEditingController> _controllers;
  late final TextEditingController _note;
  late DateTime _day;

  /// Which measure, if any, failed validation on the last Save attempt.
  /// One at a time: showing six errors at once reads as a rejection of
  /// the person rather than of a value.
  BodyMeasure? _invalid;
  bool _showEmptyError = false;
  bool _saving = false;

  /// Collapsed until the user asks. See the class doc.
  bool _showAllMeasures = false;

  @override
  void initState() {
    super.initState();
    _day = BodyMetric.dayOf(widget.day ?? DateTime.now());
    _controllers = {
      for (final measure in BodyMeasure.values)
        measure: TextEditingController(),
    };
    _note = TextEditingController(text: widget.existing?.note ?? '');
    final existing = widget.existing;
    if (existing != null) {
      // Any tape measurement already logged means the extra fields are
      // relevant to this user — opening collapsed would hide their own
      // data from them.
      _showAllMeasures =
          existing.presentMeasures.any((measure) => !measure.isWeight);
    }
  }

  /// Seeds the fields from the existing entry. Deferred out of
  /// [initState] because the conversion needs the unit preference, and
  /// reading a provider there is not allowed.
  bool _seeded = false;
  void _seed(UnitSystem system, String localeTag) {
    if (_seeded) return;
    _seeded = true;
    final existing = widget.existing;
    if (existing == null) return;
    for (final measure in BodyMeasure.values) {
      final value = existing.valueOf(measure);
      if (value == null) continue;
      _controllers[measure]!.text = formatMeasure(
        value,
        measure,
        system: system,
        localeTag: localeTag,
        withUnit: false,
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _note.dispose();
    super.dispose();
  }

  /// Parses a field in display units and returns the metric value, or
  /// null when the field is blank. Throws [_OutOfRange] when the number
  /// is outside what the measure accepts.
  double? _readField(BodyMeasure measure, UnitSystem system) {
    final raw = _controllers[measure]!.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    final parsed = double.tryParse(raw);
    if (parsed == null) throw _OutOfRange(measure);

    final metric = switch ((measure.isWeight, system)) {
      (true, UnitSystem.imperial) => lbToKg(parsed),
      (false, UnitSystem.imperial) => inchesToCm(parsed),
      _ => parsed,
    };
    final range = measureRangeMetric(measure);
    if (metric < range.min || metric > range.max) throw _OutOfRange(measure);
    return roundTo(metric, 2);
  }

  Future<void> _save() async {
    final system = ref.read(unitSystemProvider);
    final values = <BodyMeasure, double?>{};
    for (final measure in BodyMeasure.values) {
      try {
        values[measure] = _readField(measure, system);
      } on _OutOfRange catch (e) {
        setState(() {
          _invalid = e.measure;
          _showEmptyError = false;
        });
        AppHaptics.warningDoubleTap();
        return;
      }
    }

    final entry = BodyMetric(
      recordedOn: _day,
      weightKg: values[BodyMeasure.weight],
      waistCm: values[BodyMeasure.waist],
      chestCm: values[BodyMeasure.chest],
      armCm: values[BodyMeasure.arm],
      thighCm: values[BodyMeasure.thigh],
      hipCm: values[BodyMeasure.hip],
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );
    if (entry.isEmpty) {
      setState(() {
        _invalid = null;
        _showEmptyError = true;
      });
      AppHaptics.warningDoubleTap();
      return;
    }

    setState(() => _saving = true);
    await ref.read(bodyMetricsRepositoryProvider).save(entry);
    ref.invalidate(bodyMetricsProvider);

    // One event per measure the entry carries, so "how many people track
    // a waist" is answerable without a second event type.
    if (entry.weightKg != null) {
      unawaited(AnalyticsService.instance.weightLogged());
    }
    for (final measure in entry.presentMeasures) {
      if (measure.isWeight) continue;
      unawaited(
        AnalyticsService.instance.measurementLogged(measure: measure.column),
      );
    }

    if (!mounted) return;
    AppHaptics.success();
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;
    final system = ref.watch(unitSystemProvider);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    _seed(system, localeTag);

    final visible =
        _showAllMeasures ? BodyMeasure.values : const [BodyMeasure.weight];

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.bodyMetricsEntryTitle,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              _DateRow(
                day: _day,
                localeTag: localeTag,
                onPick: _pickDate,
              ),
              if (widget.existing != null) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.bodyMetricsEntryReplaceHint,
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              for (final measure in visible) ...[
                _MeasureField(
                  measure: measure,
                  controller: _controllers[measure]!,
                  system: system,
                  autofocus: measure.isWeight && widget.existing == null,
                  errorText: _invalid == measure
                      ? _rangeError(l10n, measure, system, localeTag)
                      : null,
                  onChanged: () {
                    if (_invalid != null || _showEmptyError) {
                      setState(() {
                        _invalid = null;
                        _showEmptyError = false;
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),
              ],
              if (!_showAllMeasures)
                TextButton.icon(
                  onPressed: () => setState(() => _showAllMeasures = true),
                  icon: const Icon(Icons.straighten_rounded, size: 18),
                  label: Text(_moreLabel(l10n)),
                ),
              const SizedBox(height: 6),
              Text(
                l10n.bodyMetricsEntryNoteLabel,
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _note,
                maxLength: kBodyMetricNoteMaxLength,
                decoration: InputDecoration(
                  hintText: l10n.bodyMetricsEntryNoteHint,
                  counterText: '',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              if (_showEmptyError) ...[
                const SizedBox(height: 10),
                Text(
                  l10n.bodyMetricsEntryEmptyError,
                  style: TextStyle(color: scheme.error, fontSize: 12.5),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(l10n.bodyMetricsEntrySave),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The "add the tape measurements" affordance reuses the measure names
  /// rather than earning a key of its own — it names exactly the fields
  /// it reveals, so a separate string could only ever drift from them.
  String _moreLabel(AppLocalizations l10n) => [
        l10n.bodyMeasureWaist,
        l10n.bodyMeasureChest,
        l10n.bodyMeasureArm,
        l10n.bodyMeasureThigh,
        l10n.bodyMeasureHip,
      ].join(' · ');

  String _rangeError(
    AppLocalizations l10n,
    BodyMeasure measure,
    UnitSystem system,
    String localeTag,
  ) {
    final range = measureRangeMetric(measure);
    return l10n.bodyMetricsEntryRangeError(
      formatMeasure(range.min, measure,
          system: system, localeTag: localeTag, withUnit: false),
      formatMeasure(range.max, measure,
          system: system, localeTag: localeTag, withUnit: false),
      measure.isWeight
          ? weightUnitLabel(system)
          : circumferenceUnitLabel(system),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      // Two years back covers any history worth back-filling; no future
      // dates, because a measurement that has not happened yet is not a
      // measurement.
      firstDate: DateTime(now.year - 2),
      lastDate: BodyMetric.dayOf(now),
    );
    if (picked != null) setState(() => _day = BodyMetric.dayOf(picked));
  }
}

class _OutOfRange implements Exception {
  const _OutOfRange(this.measure);
  final BodyMeasure measure;
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.day,
    required this.localeTag,
    required this.onPick,
  });

  final DateTime day;
  final String localeTag;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;
    final isToday = day == BodyMetric.dayOf(DateTime.now());
    // Both children flexible: a Row with two inflexible children and a
    // Spacer between them overflows the moment either one's translation
    // grows, and this row holds a label and a formatted date — two
    // things that vary by locale in opposite directions.
    return Row(
      children: [
        Flexible(
          child: Text(
            l10n.bodyMetricsEntryDateLabel,
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.7),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: TextButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.event_rounded, size: 18),
            label: Text(
              isToday
                  ? l10n.bodyMetricsEntryToday
                  : DateFormat.yMMMd(localeTag).format(day),
              textAlign: TextAlign.end,
            ),
          ),
        ),
      ],
    );
  }
}

class _MeasureField extends StatelessWidget {
  const _MeasureField({
    required this.measure,
    required this.controller,
    required this.system,
    required this.autofocus,
    required this.errorText,
    required this.onChanged,
  });

  final BodyMeasure measure;
  final TextEditingController controller;
  final UnitSystem system;
  final bool autofocus;
  final String? errorText;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      // Digits plus one separator. Both `.` and `,` are allowed on the
      // way in and normalised on parse: a Turkish keyboard offers a
      // comma and a user typing 80,4 means eighty point four.
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: measureLabel(l10n, measure),
        suffixText: measure.isWeight
            ? weightUnitLabel(system)
            : circumferenceUnitLabel(system),
        errorText: errorText,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}
