/// Phase 48 · centralised numeric constants.
///
/// Was scattered as `_programLength`, `_kcalPerDay`,
/// `_kcalPerCompletedDay`, `_freeDayLimit` across multiple feature
/// files (some matching, some accidentally diverging — `_kcalPerDay`
/// vs `_kcalPerCompletedDay` were both `250` but lived in two places).
/// Pulling them into one module means a single change here propagates
/// everywhere a value is read.
class AppConstants {
  const AppConstants._();

  /// Total days in the FormAI 30-day program. Drives the dashboard
  /// progress ring, the day grid (5×6), the badges screen, and the
  /// plan-detail header. Bumping this requires re-seeding the rule-
  /// based generator's day count and updating the day grid layout.
  static const int programLength = 30;

  /// Estimated kilocalories burned per completed program day. Used by
  /// the Gelişim weekly stats card and by the badges screen's
  /// "Kalori Avcısı" unlock predicate. Keep the two read sites in
  /// sync — was previously two separate `_kcalPerDay = 250` /
  /// `_kcalPerCompletedDay = 250` constants that could (and did)
  /// drift apart.
  static const int kcalPerCompletedDay = 250;

  /// Number of program days a free user can run before the paywall
  /// gate engages on day N+1. Phase 134 widened this from 3 → 5 so
  /// the free preview reaches the first habit-formation milestone
  /// (Day 5 is where momentum starts feeling self-sustaining) before
  /// the locked-future-day cinematic kicks in. Plan-detail screen and
  /// today_task_card both consume this — no surface should hard-code
  /// the number.
  static const int freeDayLimit = 5;
}
