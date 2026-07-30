/// Roadmap Phase 3 (C21) · how the user runs a workout.
///
/// The camera-free path exists because the camera requirement is itself
/// an exclusion. Users who decline the permission, train in a shared
/// space, have no way to prop a phone at 2 metres, or simply don't want
/// to be filmed are not edge cases — and before this, the app's answer
/// to all of them was "no workout".
///
/// The mode is a persisted preference rather than a per-session
/// question: asking every time would be its own friction, and a user who
/// chose manual once has told us something durable. It is changeable
/// from the workout screen at any time.
enum WorkoutMode {
  /// Live pose analysis. Reps counted by the ML pipeline, form cues
  /// spoken in real time.
  camera('camera'),

  /// Manual rep logging. The plan, timer, session logging, XP, streak
  /// and badges all behave identically — only form analysis is absent,
  /// and the UI says so plainly rather than pretending otherwise.
  manual('manual');

  const WorkoutMode(this.token);

  /// Stable identifier for persistence and analytics. Never localised.
  final String token;

  static WorkoutMode fromToken(String? token) {
    for (final mode in WorkoutMode.values) {
      if (mode.token == token) return mode;
    }
    // Camera is the default: it's the product's differentiator, and a
    // user with no stored preference hasn't opted out of anything.
    return WorkoutMode.camera;
  }
}
