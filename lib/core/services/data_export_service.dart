import 'dart:convert';

import '../../features/progress/domain/models/body_metric.dart';
import '../../features/workout/models/session_log_model.dart';

/// Roadmap Phase 10 (C48) · take your data with you.
///
/// GDPR Article 20 and KVKK both give a person the right to receive
/// their own data "in a structured, commonly used and machine-readable
/// format". This builds that file.
///
/// **The serialisation is pure and the delivery is not**, and they are
/// split here on purpose. Everything in this file is a `String` in and a
/// `String` out — no filesystem, no share sheet, no plugins — so the
/// format is unit-testable, which for an export is the whole game: a
/// CSV that quotes wrong is a corrupted file in somebody's hands, and
/// there is no server-side copy to fall back on. Writing the file and
/// handing it to the OS is the export sheet's job, in
/// `outcome_report_screen.dart`.
///
/// Two decisions worth stating:
///
///   * **Storage units, not display units.** Kilograms and centimetres,
///     always, with a `units` field saying so. An export that silently
///     converted to pounds because the user happened to have imperial
///     selected would be unmergeable with one taken a month later.
///   * **ISO-8601 dates, never localized ones.** `2026-08-02`, not
///     `2 Ağu`. The file is for machines and for the user's own records,
///     and a locale-formatted date in a CSV is a parsing bug waiting for
///     whoever opens it in a different region.
class DataExport {
  const DataExport({
    required this.sessionLogs,
    required this.bodyMetrics,
    required this.targetWeightKg,
    required this.locale,
    required this.unitSystem,
    required this.generatedAt,
  });

  final Map<int, SessionLog> sessionLogs;
  final List<BodyMetric> bodyMetrics;
  final double? targetWeightKg;
  final String locale;
  final String unitSystem;
  final DateTime generatedAt;

  /// Everything, as one JSON document.
  ///
  /// `schema` is first and is a number rather than a name, so a future
  /// version of this app — or anything else the user hands the file to —
  /// can tell what it is holding without inspecting the shape.
  String toJson() {
    final document = <String, dynamic>{
      'schema': 1,
      'generated_at': generatedAt.toUtc().toIso8601String(),
      'app': 'FormAI', // i18n-ignore — the product name, never translated
      'units': {'weight': 'kg', 'length': 'cm'}, // i18n-ignore — SI symbols
      'preferences': {
        'locale': locale,
        'unit_system': unitSystem,
        'target_weight_kg': targetWeightKg,
      },
      'sessions': [
        for (final day in _orderedDays())
          {
            'day_number': day,
            ...sessionLogs[day]!.toJson(),
          },
      ],
      'body_metrics': [
        for (final metric in _orderedMetrics())
          {
            'recorded_on': metric.recordedOnIso,
            for (final measure in BodyMeasure.values)
              if (metric.valueOf(measure) case final value?)
                measure.column: value,
            if (metric.note != null) 'note': metric.note,
          },
      ],
    };
    return const JsonEncoder.withIndent('  ').convert(document);
  }

  /// One CSV per table, keyed by the filename it should be written as.
  ///
  /// Two files rather than one, because sessions and measurements have
  /// nothing in common but a person — flattening them into a single
  /// sheet would mean a column set that is mostly empty on every row.
  Map<String, String> toCsv() => {
        'formai_sessions.csv': _sessionsCsv(),
        'formai_measurements.csv': _measurementsCsv(),
      };

  String _sessionsCsv() {
    final rows = <List<String>>[
      [
        'day_number',
        'completed_at',
        'duration_seconds',
        'source',
        'sets',
        'reps'
      ],
      for (final day in _orderedDays())
        if (sessionLogs[day] case final log)
          [
            '$day',
            log!.completedAtIso,
            '${log.durationSeconds}',
            log.source.token,
            '${log.exerciseLogs.fold<int>(0, (s, e) => s + e.actualSets)}',
            '${log.totalReps}',
          ],
    ];
    return _csv(rows);
  }

  String _measurementsCsv() {
    final rows = <List<String>>[
      ['recorded_on', for (final m in BodyMeasure.values) m.column, 'note'],
      for (final metric in _orderedMetrics())
        [
          metric.recordedOnIso,
          for (final measure in BodyMeasure.values)
            _number(metric.valueOf(measure)),
          metric.note ?? '',
        ],
    ];
    return _csv(rows);
  }

  List<int> _orderedDays() => sessionLogs.keys.toList()..sort();

  List<BodyMetric> _orderedMetrics() => bodyMetrics.toList()
    ..sort((a, b) => a.recordedOn.compareTo(b.recordedOn));

  /// A trailing `.0` is noise in a spreadsheet, and an empty cell is the
  /// correct representation of a measurement that was never taken —
  /// `0` would be a reading of zero centimetres.
  static String _number(double? value) {
    if (value == null) return '';
    if (value == value.roundToDouble()) return '${value.round()}';
    return value.toString();
  }

  /// RFC 4180. A field is quoted when it contains a comma, a quote or a
  /// newline, and an embedded quote is doubled.
  ///
  /// Hand-rolled rather than pulled in, because the alternative is a
  /// dependency for forty lines and because the note field is free text
  /// a user typed — which is exactly the input that breaks a naive
  /// `join(',')`, and exactly what the tests aim at.
  static String _csv(List<List<String>> rows) {
    final buffer = StringBuffer();
    for (final row in rows) {
      buffer.writeln(row.map(_field).join(','));
    }
    return buffer.toString();
  }

  static String _field(String value) {
    final needsQuotes = value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    if (!needsQuotes) return value;
    return '"${value.replaceAll('"', '""')}"';
  }
}
