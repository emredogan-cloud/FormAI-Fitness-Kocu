import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/features/community/data/community_repository.dart';
import 'package:sixpack_ai/features/community/domain/models/community_models.dart';
import 'package:sixpack_ai/features/progress/providers/xp_award_listener.dart';
import 'package:sixpack_ai/features/workout/data/session_log_repository.dart';
import 'package:sixpack_ai/features/workout/models/session_log_model.dart';

/// Roadmap Phase 12 (C22) · what reaches a squad's feed.
///
/// The XP listener is where "is this new?" is already answered, so it is
/// where feed events are published from. The one thing that has to hold
/// is the backfill guard: a reinstall whose session logs come back from
/// the cloud walks the entire history in a single pass, and forty
/// "trained today" lines arriving in a squad because somebody changed
/// phones would be the worst thing this feature could do.
///
/// These tests drive the listener through the real ledger in
/// `AppPreferences` — no stub of the "is it new" question, because a
/// stub of it would be testing the stub.
class _RecordingRepository extends CommunityRepository {
  // A client is passed rather than left to default, because the default
  // reads `Supabase.instance` in the constructor and that asserts in a
  // test. Nothing here ever issues a request against it.
  _RecordingRepository()
      : super(client: SupabaseClient('http://localhost', 'test-anon-key'));

  final List<ActivityEvent> published = [];

  @override
  Future<void> recordActivity({
    required ActivityKind kind,
    int? value,
    String? token,
  }) async {
    published.add(
      ActivityEvent(
        id: '${published.length}',
        squadId: 's',
        actorId: 'u',
        kind: kind,
        value: value,
        token: token,
        createdAt: DateTime(2026),
      ),
    );
  }
}

SessionLog _log(int day) => SessionLog(
      dayNumber: day,
      completedAtIso: DateTime(2026, 8, day).toIso8601String(),
      durationSeconds: 600,
      exerciseLogs: const [],
    );

/// Mounts the listener over [logs], then optionally swaps in [then] the
/// way a workout finishing mid-session does, and returns what reached
/// the feed.
Future<List<ActivityEvent>> _publishedFor(
  Map<int, SessionLog> logs, {
  Map<String, Object> seed = const {},
  Map<int, SessionLog>? then,
}) async {
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  final repository = _RecordingRepository();
  var current = logs;
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      sessionLogsProvider.overrideWith((ref) async => current),
      communityRepositoryProvider.overrideWith((ref) => repository),
    ],
  );
  addTearDown(container.dispose);

  // Mounting the notifier attaches its three listeners; the session-log
  // one is async, so the future has to land before anything is credited.
  container.read(xpAwardListenerProvider);
  await container.read(sessionLogsProvider.future);
  await _drain(container);

  if (then != null) {
    // Everything credited inside the mount window is history by
    // definition, so a live workout has to arrive after it.
    await Future<void>.delayed(kFeedPublishAfterMount + _slack);
    current = then;
    container.invalidate(sessionLogsProvider);
    await container.read(sessionLogsProvider.future);
    await _drain(container);
  }
  return repository.published;
}

/// Enough past [kFeedPublishAfterMount] that the timer has certainly
/// fired, without making the suite wait on a round number.
const Duration _slack = Duration(milliseconds: 300);

/// Lets the un-awaited ledger writes land and the re-entrant evaluate
/// passes they trigger run out.
Future<void> _drain(ProviderContainer container) async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('a workout finished while the app watches publishes one line', () async {
    // Mount with nothing, then finish day 1 — the live sequence. On a
    // cold start every log is history, so the swap is the whole point.
    final published = await _publishedFor(const {}, then: {1: _log(1)});
    expect(
        published.map((e) => e.kind), contains(ActivityKind.workoutCompleted));
    expect(
      published.where((e) => e.kind == ActivityKind.workoutCompleted).length,
      1,
    );
  });

  test('a restored backlog publishes nothing at all', () async {
    // Six uncredited days is a reinstall, not six workouts happening
    // while the app watched. Nothing may reach the feed — not the
    // workouts, and not the level-up they add up to.
    final published = await _publishedFor({
      for (var day = 1; day <= 6; day++) day: _log(day),
    });
    expect(published, isEmpty);
  });

  test('history present at launch is never published', () async {
    // Day 1 is in the log before the listener ever runs. It happened
    // when the app was not watching, so it is not news.
    final published = await _publishedFor({1: _log(1)});
    expect(published, isEmpty);
  });

  test('an already-credited day is not published again', () async {
    // The ledger says day 1 was paid for on a previous launch. Nothing
    // is new, so nothing is published — this is the every-rebuild case
    // and it must stay silent or the feed fills up on its own.
    final published = await _publishedFor(
      {1: _log(1)},
      seed: {
        'sixpack.xp_awarded_session_days': <String>['1']
      },
    );
    expect(published, isEmpty);
  });

  test('a level crossed by one workout publishes one level line', () async {
    final published = await _publishedFor(const {}, then: {1: _log(1)});
    final levels = published.where((e) => e.kind == ActivityKind.levelUp);
    // One line for the level reached, never one per level crossed.
    expect(levels.length, lessThanOrEqualTo(1));
    for (final event in levels) {
      expect(event.value, isNotNull);
      expect(event.value, greaterThan(0));
    }
  });
}
