/// FormAI · Roadmap B Phase 0 — video-analysis data models.
///
/// Plain immutable value objects mirroring the `005_video_analysis_schema.sql`
/// tables. JSON maps use the snake_case column names so they round-trip
/// directly against Supabase rows.
library;

enum SubmissionStatus { pending, processing, completed, failed }

SubmissionStatus _statusFrom(String? raw) {
  switch (raw) {
    case 'processing':
      return SubmissionStatus.processing;
    case 'completed':
      return SubmissionStatus.completed;
    case 'failed':
      return SubmissionStatus.failed;
    default:
      return SubmissionStatus.pending;
  }
}

/// One uploaded/recorded clip awaiting or holding an analysis.
class VideoSubmission {
  const VideoSubmission({
    required this.id,
    required this.userId,
    required this.exerciseSlug,
    required this.storagePath,
    required this.createdAt,
    this.durationSeconds,
    this.status = SubmissionStatus.pending,
    this.errorDetail,
  });

  final String id;
  final String userId;
  final String exerciseSlug;
  final String storagePath;
  final double? durationSeconds;
  final SubmissionStatus status;
  final String? errorDetail;
  final DateTime createdAt;

  factory VideoSubmission.fromJson(Map<String, dynamic> json) {
    return VideoSubmission(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      exerciseSlug: json['exercise_slug'] as String,
      storagePath: json['storage_path'] as String,
      durationSeconds: (json['duration_seconds'] as num?)?.toDouble(),
      status: _statusFrom(json['status'] as String?),
      errorDetail: json['error_detail'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'exercise_slug': exerciseSlug,
        'storage_path': storagePath,
        'duration_seconds': durationSeconds,
        'status': status.name,
        'error_detail': errorDetail,
        'created_at': createdAt.toIso8601String(),
      };
}

/// A completed analysis of a [VideoSubmission].
class FormAnalysisResult {
  const FormAnalysisResult({
    required this.id,
    required this.submissionId,
    required this.userId,
    required this.exerciseSlug,
    required this.analysedAt,
    this.formScore,
    this.repCount,
    this.summary,
    this.engineVersion = 'rule-v1',
    this.findings = const [],
  });

  final String id;
  final String submissionId;
  final String userId;
  final String exerciseSlug;
  final int? formScore;
  final int? repCount;
  final String? summary;
  final String engineVersion;
  final DateTime analysedAt;
  final List<FrameFinding> findings;

  factory FormAnalysisResult.fromJson(
    Map<String, dynamic> json, {
    List<FrameFinding> findings = const [],
  }) {
    return FormAnalysisResult(
      id: json['id'] as String,
      submissionId: json['submission_id'] as String,
      userId: json['user_id'] as String,
      exerciseSlug: json['exercise_slug'] as String,
      formScore: (json['form_score'] as num?)?.toInt(),
      repCount: (json['rep_count'] as num?)?.toInt(),
      summary: json['summary'] as String?,
      engineVersion: (json['engine_version'] as String?) ?? 'rule-v1',
      analysedAt: DateTime.parse(json['analysed_at'] as String),
      findings: findings,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'submission_id': submissionId,
        'user_id': userId,
        'exercise_slug': exerciseSlug,
        'form_score': formScore,
        'rep_count': repCount,
        'summary': summary,
        'engine_version': engineVersion,
        'analysed_at': analysedAt.toIso8601String(),
      };
}

enum FindingSeverity { info, warn, critical }

FindingSeverity _severityFrom(String? raw) {
  switch (raw) {
    case 'warn':
      return FindingSeverity.warn;
    case 'critical':
      return FindingSeverity.critical;
    default:
      return FindingSeverity.info;
  }
}

/// A single per-frame fault feeding the correction timeline.
class FrameFinding {
  const FrameFinding({
    required this.id,
    required this.resultId,
    required this.userId,
    required this.frameIndex,
    required this.timestampMs,
    required this.issueCode,
    this.joint,
    this.severity = FindingSeverity.info,
    this.measuredAngle,
    this.message,
  });

  final String id;
  final String resultId;
  final String userId;
  final int frameIndex;
  final int timestampMs;
  final String? joint;
  final String issueCode;
  final FindingSeverity severity;
  final double? measuredAngle;
  final String? message;

  factory FrameFinding.fromJson(Map<String, dynamic> json) {
    return FrameFinding(
      id: json['id'] as String,
      resultId: json['result_id'] as String,
      userId: json['user_id'] as String,
      frameIndex: (json['frame_index'] as num).toInt(),
      timestampMs: (json['timestamp_ms'] as num).toInt(),
      joint: json['joint'] as String?,
      issueCode: json['issue_code'] as String,
      severity: _severityFrom(json['severity'] as String?),
      measuredAngle: (json['measured_angle'] as num?)?.toDouble(),
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'result_id': resultId,
        'user_id': userId,
        'frame_index': frameIndex,
        'timestamp_ms': timestampMs,
        'joint': joint,
        'issue_code': issueCode,
        'severity': severity.name,
        'measured_angle': measuredAngle,
        'message': message,
      };
}
