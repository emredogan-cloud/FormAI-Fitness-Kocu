import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/video_analysis/models/video_analysis_models.dart';

void main() {
  final createdAt = DateTime.utc(2026, 6, 23, 10, 30);

  group('VideoSubmission', () {
    VideoSubmission build({
      double? durationSeconds = 32.5,
      SubmissionStatus status = SubmissionStatus.processing,
      String? errorDetail = 'none',
    }) =>
        VideoSubmission(
          id: 'sub1',
          userId: 'u1',
          exerciseSlug: 'squat',
          storagePath: 'videos/u1/sub1.mp4',
          createdAt: createdAt,
          durationSeconds: durationSeconds,
          status: status,
          errorDetail: errorDetail,
        );

    test('toJson → fromJson round-trips (incl. status + createdAt)', () {
      final original = build();
      final restored = VideoSubmission.fromJson(original.toJson());
      expect(restored.toJson(), original.toJson());
      expect(restored.status, SubmissionStatus.processing);
      expect(restored.createdAt.isAtSameMomentAs(createdAt), isTrue);
    });

    test('round-trips with null optionals', () {
      final original = build(durationSeconds: null, errorDetail: null);
      final restored = VideoSubmission.fromJson(original.toJson());
      expect(restored.durationSeconds, isNull);
      expect(restored.errorDetail, isNull);
    });

    test('parses every known status string', () {
      for (final s in SubmissionStatus.values) {
        final json = build().toJson()..['status'] = s.name;
        expect(VideoSubmission.fromJson(json).status, s);
      }
    });

    test('an unknown / missing status falls back to pending', () {
      final unknown = build().toJson()..['status'] = 'banana';
      expect(
          VideoSubmission.fromJson(unknown).status, SubmissionStatus.pending);
      final missing = build().toJson()..remove('status');
      expect(
          VideoSubmission.fromJson(missing).status, SubmissionStatus.pending);
    });

    test('an integer duration is coerced to double', () {
      final json = build().toJson()..['duration_seconds'] = 30;
      expect(VideoSubmission.fromJson(json).durationSeconds, 30.0);
    });
  });

  group('FormAnalysisResult', () {
    FormAnalysisResult build({
      int? formScore = 88,
      int? repCount = 15,
      String? summary = 'Solid form',
      String engineVersion = 'rule-v1',
    }) =>
        FormAnalysisResult(
          id: 'res1',
          submissionId: 'sub1',
          userId: 'u1',
          exerciseSlug: 'squat',
          analysedAt: createdAt,
          formScore: formScore,
          repCount: repCount,
          summary: summary,
          engineVersion: engineVersion,
        );

    test('toJson → fromJson round-trips (findings serialised separately)', () {
      final original = build();
      final restored = FormAnalysisResult.fromJson(original.toJson());
      expect(restored.toJson(), original.toJson());
      expect(restored.findings, isEmpty); // toJson omits findings by design
    });

    test('coerces a double form_score to int', () {
      final json = build().toJson()..['form_score'] = 91.0;
      expect(FormAnalysisResult.fromJson(json).formScore, 91);
    });

    test('defaults engineVersion to rule-v1 when absent', () {
      final json = build().toJson()..remove('engine_version');
      expect(FormAnalysisResult.fromJson(json).engineVersion, 'rule-v1');
    });

    test('round-trips with null score / rep / summary', () {
      final original = build(formScore: null, repCount: null, summary: null);
      final restored = FormAnalysisResult.fromJson(original.toJson());
      expect(restored.formScore, isNull);
      expect(restored.repCount, isNull);
      expect(restored.summary, isNull);
    });

    test('attaches findings passed alongside the row', () {
      final finding = FrameFinding(
        id: 'f1',
        resultId: 'res1',
        userId: 'u1',
        frameIndex: 3,
        timestampMs: 1000,
        issueCode: 'knee_valgus',
      );
      final result =
          FormAnalysisResult.fromJson(build().toJson(), findings: [finding]);
      expect(result.findings, hasLength(1));
      expect(result.findings.single.issueCode, 'knee_valgus');
    });
  });

  group('FrameFinding', () {
    FrameFinding build({
      FindingSeverity severity = FindingSeverity.warn,
      double? measuredAngle = 165.5,
      String? joint = 'knee',
      String? message = 'Knees caving in',
    }) =>
        FrameFinding(
          id: 'f1',
          resultId: 'res1',
          userId: 'u1',
          frameIndex: 42,
          timestampMs: 1400,
          issueCode: 'knee_valgus',
          severity: severity,
          measuredAngle: measuredAngle,
          joint: joint,
          message: message,
        );

    test('toJson → fromJson round-trips (incl. severity)', () {
      final original = build();
      final restored = FrameFinding.fromJson(original.toJson());
      expect(restored.toJson(), original.toJson());
      expect(restored.severity, FindingSeverity.warn);
    });

    test('parses every known severity string', () {
      for (final s in FindingSeverity.values) {
        final json = build().toJson()..['severity'] = s.name;
        expect(FrameFinding.fromJson(json).severity, s);
      }
    });

    test('an unknown / missing severity falls back to info', () {
      final unknown = build().toJson()..['severity'] = 'meltdown';
      expect(FrameFinding.fromJson(unknown).severity, FindingSeverity.info);
      final missing = build().toJson()..remove('severity');
      expect(FrameFinding.fromJson(missing).severity, FindingSeverity.info);
    });

    test('coerces numeric frame/timestamp/angle types', () {
      final json = build().toJson()
        ..['frame_index'] = 7.0
        ..['timestamp_ms'] = 2000.0
        ..['measured_angle'] = 90; // int where a double is expected
      final f = FrameFinding.fromJson(json);
      expect(f.frameIndex, 7);
      expect(f.timestampMs, 2000);
      expect(f.measuredAngle, 90.0);
    });

    test('round-trips with null optionals', () {
      final original = build(measuredAngle: null, joint: null, message: null);
      final restored = FrameFinding.fromJson(original.toJson());
      expect(restored.measuredAngle, isNull);
      expect(restored.joint, isNull);
      expect(restored.message, isNull);
    });
  });
}
