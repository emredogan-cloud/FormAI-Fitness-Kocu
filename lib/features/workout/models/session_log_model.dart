/// Progress redesign Phase 2.A · per-day session log.
///
/// Captured passively at the moment the last set of the last exercise
/// finishes (`workout_provider.dart` `completeCurrentExercise`). Persists
/// as a JSON list under `sixpack.session_logs_v1`. Local-only in Phase 2;
/// Supabase mirroring is Phase 3 territory.
///
/// The log is the truth-substrate the new stats cards plot — without it
/// the only available signal was binary completion (`isCompleted`), which
/// the masterplan correctly identified as the most damaging UX failure
/// in the prior Gelişim surface.
library;

/// How a session's reps were counted.
///
/// Roadmap Phase 3 asked for this explicitly: with the camera-free path
/// (C21) shipped, a rep total is no longer uniformly camera-derived, and
/// a stats surface that averages pose-counted and self-counted reps
/// without saying so is quietly dishonest. Recording the provenance is
/// what keeps later form-score reporting truthful — a manual session has
/// no form data at all, and must never be shown as though it scored
/// perfectly.
enum SessionSource {
  camera('camera'),
  manual('manual');

  const SessionSource(this.token);

  /// Stable persisted token. Never derive this from [name] — a rename
  /// would silently orphan every log already on disk.
  final String token;

  /// Unknown, absent or malformed tokens resolve to [camera]: logs
  /// written before this field existed were all camera sessions, so that
  /// is the historically accurate default rather than a guess.
  static SessionSource fromToken(String? token) {
    for (final source in SessionSource.values) {
      if (source.token == token) return source;
    }
    return SessionSource.camera;
  }
}

class SessionLog {
  const SessionLog({
    required this.dayNumber,
    required this.completedAtIso,
    required this.durationSeconds,
    required this.exerciseLogs,
    this.source = SessionSource.camera,
  });

  /// Program day this log corresponds to. Always > 0 — ad-hoc runs
  /// (`dayNumber == 0`) are not logged because they don't move the
  /// 30-day completion ledger and would pollute the program-arc charts.
  final int dayNumber;

  /// ISO-8601 wall-clock moment the day's last set finished. The new
  /// stats cards bucket logs into weekly slots off this timestamp; the
  /// calendar drilldown reads it for "X gün önce" copy.
  final String completedAtIso;

  /// Total active duration across every set in the session, in seconds.
  /// "Active" here means the wall-clock time from a set's start (after
  /// the prep countdown) to its completion — does not include rest
  /// intervals. The MET-based kcal helper at
  /// `lib/features/progress/domain/volume_metrics.dart` divides this by
  /// 3600 before multiplying out, so be careful if a future change
  /// switches it to milliseconds.
  final int durationSeconds;

  final List<ExerciseLog> exerciseLogs;

  /// Whether the reps were counted by pose detection or by the user.
  /// Defaults to [SessionSource.camera] for logs written before the
  /// camera-free path existed.
  final SessionSource source;

  /// Total reps across every exercise in the session — the headline
  /// number rendered by the HACİM stats card.
  int get totalReps =>
      exerciseLogs.fold<int>(0, (sum, e) => sum + e.actualReps);

  Map<String, dynamic> toJson() => {
        'dayNumber': dayNumber,
        'completedAtIso': completedAtIso,
        'durationSeconds': durationSeconds,
        'exerciseLogs':
            exerciseLogs.map((e) => e.toJson()).toList(growable: false),
        'source': source.token,
      };

  /// Parser is intentionally tolerant: missing optional fields collapse
  /// to safe defaults so a forward-compatible v1.x schema (e.g. adding
  /// formScore later) never blocks v1 reads. A genuinely malformed
  /// entry — missing `dayNumber` or `exerciseLogs` not a List —
  /// throws [FormatException] so the repository can drop it on load
  /// without taking down the whole list.
  factory SessionLog.fromJson(Map<String, dynamic> json) {
    final dayNumber = json['dayNumber'];
    if (dayNumber is! int) {
      throw const FormatException('SessionLog.dayNumber missing or not int');
    }
    final rawLogs = json['exerciseLogs'];
    if (rawLogs is! List) {
      throw const FormatException('SessionLog.exerciseLogs not a List');
    }
    return SessionLog(
      dayNumber: dayNumber,
      completedAtIso: (json['completedAtIso'] as String?) ?? '',
      durationSeconds: (json['durationSeconds'] as int?) ?? 0,
      exerciseLogs: rawLogs
          .whereType<Map<String, dynamic>>()
          .map(ExerciseLog.fromJson)
          .toList(growable: false),
      source: SessionSource.fromToken(json['source'] as String?),
    );
  }
}

class ExerciseLog {
  const ExerciseLog({
    required this.exerciseId,
    required this.exerciseName,
    required this.targetMuscle,
    required this.isCardio,
    required this.plannedSets,
    required this.plannedReps,
    required this.actualSets,
    required this.actualReps,
    required this.durationSeconds,
  });

  final String exerciseId;
  final String exerciseName;

  /// One of: `core`, `upper_body`, `lower_body`, `cardio`, `full_body`.
  /// The MET helper keys off this to pick the cardio vs strength MET.
  final String targetMuscle;

  /// True for exercises the catalogue tagged as cardio. The MET model
  /// uses this as a tiebreaker — a `core` movement that's also flagged
  /// cardio (e.g. mountain climbers) gets the cardio MET (~7.0) rather
  /// than the core MET (~4.0).
  final bool isCardio;

  /// What the program prescribed.
  final int plannedSets;
  final int plannedReps;

  /// What the user actually did. `actualReps` may be lower than
  /// `plannedSets * plannedReps` for a user who walked through reps
  /// without pose detection — in that case the capture hook falls back
  /// to plannedReps for any set where `currentReps == 0`.
  final int actualSets;
  final int actualReps;

  /// Sum of per-set durations, in seconds.
  final int durationSeconds;

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'exerciseName': exerciseName,
        'targetMuscle': targetMuscle,
        'isCardio': isCardio,
        'plannedSets': plannedSets,
        'plannedReps': plannedReps,
        'actualSets': actualSets,
        'actualReps': actualReps,
        'durationSeconds': durationSeconds,
      };

  factory ExerciseLog.fromJson(Map<String, dynamic> json) {
    return ExerciseLog(
      exerciseId: (json['exerciseId'] as String?) ?? '',
      exerciseName: (json['exerciseName'] as String?) ?? '',
      targetMuscle: (json['targetMuscle'] as String?) ?? 'full_body',
      isCardio: (json['isCardio'] as bool?) ?? false,
      plannedSets: (json['plannedSets'] as int?) ?? 0,
      plannedReps: (json['plannedReps'] as int?) ?? 0,
      actualSets: (json['actualSets'] as int?) ?? 0,
      actualReps: (json['actualReps'] as int?) ?? 0,
      durationSeconds: (json['durationSeconds'] as int?) ?? 0,
    );
  }
}
