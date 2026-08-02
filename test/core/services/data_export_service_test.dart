import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/core/services/data_export_service.dart';
import 'package:sixpack_ai/features/progress/domain/models/body_metric.dart';
import 'package:sixpack_ai/features/workout/models/session_log_model.dart';

/// Roadmap Phase 10 (C48) · the portability export.
///
/// The format IS the feature here. There is no server-side copy to fall
/// back on, so a CSV that quotes wrong is a corrupted file in somebody's
/// hands and a JSON document that drops a field is data they no longer
/// have. Most of this file aims at the free-text note, because that is
/// the one field a user types and therefore the one that contains the
/// commas, quotes and newlines a naive `join(',')` breaks on.
void main() {
  final generatedAt = DateTime.utc(2026, 8, 2, 12, 30);

  SessionLog session(int day) => SessionLog(
        dayNumber: day,
        completedAtIso: '2026-07-${20 + day}T09:00:00.000Z',
        durationSeconds: 600,
        exerciseLogs: const [
          ExerciseLog(
            exerciseId: 'ex1',
            exerciseName: 'Push-up',
            targetMuscle: 'chest',
            isCardio: false,
            plannedSets: 3,
            plannedReps: 10,
            actualSets: 3,
            actualReps: 31,
            durationSeconds: 200,
          ),
        ],
      );

  DataExport export({
    Map<int, SessionLog> logs = const {},
    List<BodyMetric> metrics = const [],
    double? target,
  }) =>
      DataExport(
        sessionLogs: logs,
        bodyMetrics: metrics,
        targetWeightKg: target,
        locale: 'tr',
        unitSystem: 'imperial',
        generatedAt: generatedAt,
      );

  group('JSON', () {
    test('is valid JSON even with nothing in it', () {
      final decoded = jsonDecode(export().toJson()) as Map<String, dynamic>;

      expect(decoded['schema'], 1);
      expect(decoded['sessions'], isEmpty);
      expect(decoded['body_metrics'], isEmpty);
    });

    test('carries storage units regardless of the display preference', () {
      final decoded = jsonDecode(
        export(
          metrics: [
            BodyMetric(recordedOn: DateTime(2026, 7, 20), weightKg: 82.4),
          ],
          target: 78.0,
        ).toJson(),
      ) as Map<String, dynamic>;

      expect(decoded['units'], {'weight': 'kg', 'length': 'cm'});
      // The user has imperial selected; the file is still kilograms.
      expect(decoded['preferences']['unit_system'], 'imperial');
      expect(decoded['preferences']['target_weight_kg'], 78.0);
      expect((decoded['body_metrics'] as List).first['weight_kg'], 82.4);
    });

    test('omits a measurement that was never taken rather than writing 0', () {
      final decoded = jsonDecode(
        export(metrics: [
          BodyMetric(recordedOn: DateTime(2026, 7, 20), weightKg: 82.4),
        ]).toJson(),
      ) as Map<String, dynamic>;

      final row = (decoded['body_metrics'] as List).first as Map;
      expect(row.containsKey('weight_kg'), isTrue);
      expect(row.containsKey('waist_cm'), isFalse,
          reason: '0 cm is a reading, not an absence');
    });

    test('orders sessions and measurements chronologically', () {
      final decoded = jsonDecode(
        export(
          logs: {3: session(3), 1: session(1), 2: session(2)},
          metrics: [
            BodyMetric(recordedOn: DateTime(2026, 7, 25), weightKg: 82.0),
            BodyMetric(recordedOn: DateTime(2026, 7, 20), weightKg: 84.0),
          ],
        ).toJson(),
      ) as Map<String, dynamic>;

      expect(
        (decoded['sessions'] as List).map((s) => s['day_number']),
        [1, 2, 3],
      );
      expect(
        (decoded['body_metrics'] as List).map((m) => m['recorded_on']),
        ['2026-07-20', '2026-07-25'],
      );
    });
  });

  group('CSV', () {
    test('produces one file per table, each with a header', () {
      final files = export(logs: {1: session(1)}).toCsv();

      expect(files.keys, ['formai_sessions.csv', 'formai_measurements.csv']);
      expect(files['formai_sessions.csv']!.split('\n').first,
          'day_number,completed_at,duration_seconds,source,sets,reps');
    });

    test('sums the sets and reps a session actually recorded', () {
      final rows = export(logs: {1: session(1)})
          .toCsv()['formai_sessions.csv']!
          .trim()
          .split('\n');

      expect(rows.length, 2);
      expect(rows[1].endsWith(',3,31'), isTrue, reason: rows[1]);
    });

    test(
        'an empty cell is how a measurement that was never taken is '
        'written — 0 would be a reading of zero centimetres', () {
      final csv = export(metrics: [
        BodyMetric(recordedOn: DateTime(2026, 7, 20), weightKg: 82.0),
      ]).toCsv()['formai_measurements.csv']!;

      expect(csv.trim().split('\n')[1], '2026-07-20,82,,,,,,');
    });

    test('a round value loses its trailing zero, a fractional one keeps it',
        () {
      final csv = export(metrics: [
        BodyMetric(recordedOn: DateTime(2026, 7, 20), weightKg: 82.0),
        BodyMetric(recordedOn: DateTime(2026, 7, 21), weightKg: 82.4),
      ]).toCsv()['formai_measurements.csv']!;

      final rows = csv.trim().split('\n');
      expect(rows[1].contains(',82,'), isTrue, reason: rows[1]);
      expect(rows[2].contains(',82.4,'), isTrue, reason: rows[2]);
    });

    group('the note field, which is the only text a user types', () {
      String noteCell(String note) {
        final csv = export(metrics: [
          BodyMetric(
            recordedOn: DateTime(2026, 7, 20),
            weightKg: 82.0,
            note: note,
          ),
        ]).toCsv()['formai_measurements.csv']!;
        return csv.trim().split('\n')[1].split(',').last;
      }

      test('a plain note is written bare', () {
        expect(noteCell('sabah'), 'sabah');
      });

      test('a note with a comma is quoted, or the row gains a column', () {
        final csv = export(metrics: [
          BodyMetric(
            recordedOn: DateTime(2026, 7, 20),
            weightKg: 82.0,
            note: 'sabah, kahvaltıdan önce',
          ),
        ]).toCsv()['formai_measurements.csv']!;

        expect(csv, contains('"sabah, kahvaltıdan önce"'));
      });

      test('an embedded quote is doubled, per RFC 4180', () {
        final csv = export(metrics: [
          BodyMetric(
            recordedOn: DateTime(2026, 7, 20),
            weightKg: 82.0,
            note: 'so-called "rest" day',
          ),
        ]).toCsv()['formai_measurements.csv']!;

        expect(csv, contains('"so-called ""rest"" day"'));
      });

      test('a newline is quoted rather than breaking the row', () {
        final csv = export(metrics: [
          BodyMetric(
            recordedOn: DateTime(2026, 7, 20),
            weightKg: 82.0,
            note: 'line one\nline two',
          ),
        ]).toCsv()['formai_measurements.csv']!;

        expect(csv, contains('"line one\nline two"'));
      });
    });
  });
}
