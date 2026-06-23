// Roadmap B Phase 0 · tests for the form-score heuristic + data-model
// round-trips. These verify the heuristic's MATH (deterministic) and that
// the models serialise against the 005 schema's snake_case columns — NOT
// real-world scoring accuracy, which is DEFERRED (requires labelled video).

import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/video_analysis/domain/form_score.dart';
import 'package:sixpack_ai/features/video_analysis/models/video_analysis_models.dart';

void main() {
  group('FormScore.compute', () {
    test('perfect rom, zero faults → 100', () {
      expect(
        FormScore.compute(
            reps: 10,
            faultFrames: 0,
            totalAnalysedFrames: 120,
            romCompleteness: 1.0),
        100,
      );
    });

    test('no reps → 0', () {
      expect(
        FormScore.compute(
            reps: 0,
            faultFrames: 0,
            totalAnalysedFrames: 120,
            romCompleteness: 1.0),
        0,
      );
    });

    test('no analysed frames → 0', () {
      expect(
        FormScore.compute(
            reps: 5,
            faultFrames: 0,
            totalAnalysedFrames: 0,
            romCompleteness: 1.0),
        0,
      );
    });

    test('half rom, no faults → 70 (0.5*60 + 1.0*40)', () {
      expect(
        FormScore.compute(
            reps: 8,
            faultFrames: 0,
            totalAnalysedFrames: 100,
            romCompleteness: 0.5),
        70,
      );
    });

    test('full rom, every frame faulted → 60 (1.0*60 + 0*40)', () {
      expect(
        FormScore.compute(
            reps: 8,
            faultFrames: 100,
            totalAnalysedFrames: 100,
            romCompleteness: 1.0),
        60,
      );
    });

    test('clamps rom > 1.0 and fault rate > 1.0', () {
      expect(
        FormScore.compute(
            reps: 8,
            faultFrames: 999,
            totalAnalysedFrames: 100,
            romCompleteness: 5.0),
        60, // rom clamps to 1.0 → 60; faultRate clamps to 1.0 → 0
      );
    });
  });

  group('model JSON round-trips', () {
    test('VideoSubmission survives toJson → fromJson', () {
      final s = VideoSubmission(
        id: 'sub-1',
        userId: 'user-1',
        exerciseSlug: 'squat',
        storagePath: 'user-1/sub-1.mp4',
        durationSeconds: 33.5,
        status: SubmissionStatus.processing,
        createdAt: DateTime.utc(2026, 6, 23, 12, 0, 0),
      );
      final back = VideoSubmission.fromJson(s.toJson());
      expect(back.id, 'sub-1');
      expect(back.exerciseSlug, 'squat');
      expect(back.status, SubmissionStatus.processing);
      expect(back.durationSeconds, 33.5);
      expect(back.createdAt, DateTime.utc(2026, 6, 23, 12, 0, 0));
    });

    test('FormAnalysisResult survives toJson → fromJson', () {
      final r = FormAnalysisResult(
        id: 'res-1',
        submissionId: 'sub-1',
        userId: 'user-1',
        exerciseSlug: 'push_up',
        formScore: 82,
        repCount: 12,
        summary: 'Dirsek açın yeterli, kalça hizası iyi.',
        analysedAt: DateTime.utc(2026, 6, 23, 12, 5, 0),
      );
      final back = FormAnalysisResult.fromJson(r.toJson());
      expect(back.formScore, 82);
      expect(back.repCount, 12);
      expect(back.engineVersion, 'rule-v1');
    });

    test('FrameFinding survives toJson → fromJson', () {
      final f = FrameFinding(
        id: 'find-1',
        resultId: 'res-1',
        userId: 'user-1',
        frameIndex: 42,
        timestampMs: 1400,
        joint: 'leftKnee',
        issueCode: 'shallow_depth',
        severity: FindingSeverity.warn,
        measuredAngle: 118.5,
        message: 'Daha derine in.',
      );
      final back = FrameFinding.fromJson(f.toJson());
      expect(back.frameIndex, 42);
      expect(back.severity, FindingSeverity.warn);
      expect(back.measuredAngle, 118.5);
      expect(back.issueCode, 'shallow_depth');
    });
  });
}
