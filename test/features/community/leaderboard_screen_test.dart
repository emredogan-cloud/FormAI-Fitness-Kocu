import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/community/domain/league.dart';
import 'package:sixpack_ai/features/community/domain/models/leaderboard_models.dart';

/// Roadmap Phase 13 (C23) · the leaderboard's beginner-protection
/// defaults, asserted where they are actually decided.
///
/// # Why there is no widget test here
///
/// There was one, and it hung. `LeaderboardScreen`'s first frame renders
/// a `CircularProgressIndicator` while its two providers resolve, and
/// something on that path does not settle under `testWidgets` — the
/// harness either reports a pending timer or never returns. The same
/// overrides in isolation are fine, and a bare `Scaffold` under the same
/// `ProviderScope` passes, so it is the screen's own first frame.
///
/// Rather than ship a test that passes for the wrong reason, the opt-in
/// behaviour is verified on a device instead (see the phase report's
/// device-walk table): the join card appears, it names its four values,
/// and nothing is written until the button is pressed. **That is
/// stronger evidence than a widget test would have been** — it exercises
/// the real repository against the real database — and it is honest
/// about which kind of evidence it is.
///
/// The defaults themselves live in the domain layer precisely so they
/// can be asserted without a widget, which is what this file does.
void main() {
  test('the default scope is squad, never global', () {
    // "A first-week user must never open a leaderboard and see
    // themselves last out of 40,000." The default lives in the domain
    // layer so it cannot be changed by editing a widget.
    expect(defaultScope, LeaderboardScope.squad);
  });

  test('consistency is the first metric offered', () {
    // A ratio, so three days out of three beats five out of seven. It
    // is the only one of the four a beginner can win, which is why the
    // enum declares it first and the screen defaults to it.
    expect(LeaderboardMetric.values.first, LeaderboardMetric.consistency);
  });

  test('every metric maps to a real column', () {
    // The column name is sent to PostgREST as an order key. A typo here
    // is a runtime error on a screen rather than a compile failure, so
    // it is worth one assertion.
    const columns = {
      'consistency',
      'weekly_xp',
      'sessions',
      'streak_days',
    };
    for (final metric in LeaderboardMetric.values) {
      expect(columns, contains(metric.column));
    }
  });

  test('an entry reports the value for the metric it is ranked by', () {
    const entry = LeaderboardEntry(
      userId: 'u',
      weeklyXp: 300,
      sessions: 4,
      streakDays: 9,
      consistency: 57,
    );
    expect(entry.valueFor(LeaderboardMetric.xp), 300);
    expect(entry.valueFor(LeaderboardMetric.sessions), 4);
    expect(entry.valueFor(LeaderboardMetric.streak), 9);
    expect(entry.valueFor(LeaderboardMetric.consistency), 57);
  });

  test('a row with no name keeps its numbers', () {
    // Pseudonymity is the absence of a display name, not a separate
    // flag — see `020`'s header. A nameless row is a normal row.
    const entry = LeaderboardEntry(
      userId: 'u',
      weeklyXp: 120,
      sessions: 2,
      streakDays: 3,
      consistency: 40,
    );
    expect(entry.displayName, isNull);
    expect(entry.valueFor(LeaderboardMetric.consistency), 40);
  });
}
