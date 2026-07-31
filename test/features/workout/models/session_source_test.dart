import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/workout/models/session_log_model.dart';

/// Roadmap Phase 3 · rep provenance on the session log.
///
/// With the camera-free path shipped, a rep total is no longer uniformly
/// pose-derived. These tests pin the two properties that keep later stats
/// honest: the token never drifts, and a log written before the field
/// existed is read as what it actually was.
ExerciseLog _exLog({int actualReps = 10}) => ExerciseLog(
      exerciseId: 'squat',
      exerciseName: 'Squat',
      targetMuscle: 'lower_body',
      isCardio: false,
      plannedSets: 3,
      plannedReps: 12,
      actualSets: 3,
      actualReps: actualReps,
      durationSeconds: 90,
    );

SessionLog _log({SessionSource source = SessionSource.camera}) => SessionLog(
      dayNumber: 3,
      completedAtIso: '2026-07-31T09:00:00.000Z',
      durationSeconds: 600,
      exerciseLogs: [_exLog()],
      source: source,
    );

void main() {
  group('SessionSource tokens', () {
    test('tokens are the exact strings persisted on disk', () {
      // Pinned as literals: these end up in stored JSON, so a rename
      // would orphan every log already written.
      expect(SessionSource.camera.token, 'camera');
      expect(SessionSource.manual.token, 'manual');
    });

    test('tokens are unique across the enum', () {
      final tokens = SessionSource.values.map((s) => s.token).toSet();
      expect(tokens.length, SessionSource.values.length);
    });

    test('fromToken round-trips every value', () {
      for (final source in SessionSource.values) {
        expect(SessionSource.fromToken(source.token), source);
      }
    });

    test('null, unknown and empty tokens resolve to camera', () {
      // Not an arbitrary default: every log written before this field
      // existed WAS a camera session, so camera is the historically
      // accurate read rather than a guess.
      expect(SessionSource.fromToken(null), SessionSource.camera);
      expect(SessionSource.fromToken(''), SessionSource.camera);
      expect(SessionSource.fromToken('webcam'), SessionSource.camera);
      expect(SessionSource.fromToken('CAMERA'), SessionSource.camera);
    });
  });

  group('SessionLog.source', () {
    test('defaults to camera when the constructor omits it', () {
      final log = SessionLog(
        dayNumber: 1,
        completedAtIso: '2026-07-31T09:00:00.000Z',
        durationSeconds: 60,
        exerciseLogs: const [],
      );
      expect(log.source, SessionSource.camera);
    });

    test('survives a JSON round-trip for both values', () {
      for (final source in SessionSource.values) {
        final decoded = SessionLog.fromJson(
          jsonDecode(jsonEncode(_log(source: source).toJson()))
              as Map<String, dynamic>,
        );
        expect(decoded.source, source);
      }
    });

    test('a v1 log with no source field parses as camera, not as an error', () {
      // Forward-compatibility guarantee the repository relies on: an old
      // entry must survive the read, or a schema addition silently wipes
      // a user's history.
      final legacy = {
        'dayNumber': 4,
        'completedAtIso': '2026-05-01T08:00:00.000Z',
        'durationSeconds': 500,
        'exerciseLogs': [_exLog().toJson()],
      };
      final decoded = SessionLog.fromJson(legacy);
      expect(decoded.source, SessionSource.camera);
      expect(decoded.dayNumber, 4);
      expect(decoded.totalReps, 10);
    });

    test('a malformed source value degrades to camera without throwing', () {
      final broken = {
        'dayNumber': 5,
        'completedAtIso': '2026-05-02T08:00:00.000Z',
        'durationSeconds': 500,
        'exerciseLogs': [_exLog().toJson()],
        'source': 'nonsense',
      };
      expect(SessionLog.fromJson(broken).source, SessionSource.camera);
    });

    test('toJson always writes the token so later reads are unambiguous', () {
      expect(_log(source: SessionSource.manual).toJson()['source'], 'manual');
      expect(_log().toJson()['source'], 'camera');
    });
  });
}
