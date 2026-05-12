/// Phase 138 · H-2 · KVKK consent state, accessible from non-Riverpod
/// boot code.
///
/// Sentry's `beforeSend` hook and the bootstrap PostHog `init` call
/// both run before any Riverpod ProviderScope exists, so they can't
/// `ref.watch` a consent provider. We mirror the SharedPreferences
/// values into these static fields once at boot and update them
/// whenever the consent screen flips a switch.
///
/// Defaults are `false` — KVKK Article 5 (6698) requires explicit
/// opt-in, so any code path that reads these before the consent
/// screen has run must treat absence-of-consent as denial.
class ConsentState {
  ConsentState._();

  /// True iff the user explicitly granted permission for anonymous
  /// product analytics (PostHog).
  static bool analyticsGranted = false;

  /// True iff the user explicitly granted permission for crash + ANR
  /// reporting (Sentry).
  static bool crashReportingGranted = false;

  /// True iff the user has interacted with the consent dialog and
  /// the two flags above reflect their choice. Until this flips,
  /// callers must not assume the defaults are intentional.
  static bool decided = false;

  /// Sets the trio in one shot. Called from the consent screen and
  /// from the bootstrap mirror in `main.dart`.
  static void apply({
    required bool decided,
    required bool analytics,
    required bool crash,
  }) {
    ConsentState.decided = decided;
    analyticsGranted = analytics;
    crashReportingGranted = crash;
  }
}
