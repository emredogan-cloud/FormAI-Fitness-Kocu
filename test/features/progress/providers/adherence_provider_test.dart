import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/features/progress/providers/adherence_provider.dart';

/// Roadmap Phase 9 (C3) · adherence.
///
/// The interesting cases are all refusals. An adherence figure is the
/// easiest number in a fitness app to compute and the easiest to make
/// cruel, and every guard below exists because the naive version tells
/// somebody they have failed at something they have not yet had the
/// chance to do.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.now();
  DateTime daysAgo(int n) => now.subtract(Duration(days: n));

  /// One session log for a day, in the shape `SessionLogRepository`
  /// persists. `dayNumber` only has to be unique — adherence buckets by
  /// the real completion timestamp, not by program day.
  Map<String, dynamic> log(int dayNumber, DateTime at) => {
        'dayNumber': dayNumber,
        'completedAtIso': at.toIso8601String(),
        'durationSeconds': 1200,
        'exerciseLogs': const <Map<String, dynamic>>[],
      };

  Future<ProviderContainer> container({
    int installedDaysAgo = 60,
    String? experienceLevel,
    List<Map<String, dynamic>> logs = const [],
    int maxStreak = 0,
  }) async {
    SharedPreferences.setMockInitialValues({
      'sixpack.installed_at': daysAgo(installedDaysAgo).toIso8601String(),
      if (experienceLevel != null)
        'sixpack.user_metrics':
            jsonEncode({'experienceLevel': experienceLevel}),
      if (logs.isNotEmpty) 'sixpack.session_logs_v1': jsonEncode(logs),
      if (maxStreak > 0) 'sixpack.max_streak': maxStreak,
    });
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    // The session-log provider is async and `adherenceProvider` reads it
    // synchronously through `.value`. Subscribe first so the load starts,
    // then yield so it lands before any assertion.
    c.listen(adherenceProvider, (_, __) {});
    await Future<void>.delayed(Duration.zero);
    return c;
  }

  group('the cadence is the one onboarding promised', () {
    test('a beginner is measured against four sessions a week', () async {
      final c = await container(experienceLevel: 'none');
      expect(c.read(adherenceProvider).weekPlanned, 4);
    });

    test('a self-reported regular against five', () async {
      final c = await container(experienceLevel: 'regular');
      expect(c.read(adherenceProvider).weekPlanned, 5);
    });

    test('an unknown experience level falls back to four, not to zero',
        () async {
      final c = await container();
      expect(c.read(adherenceProvider).weekPlanned, 4);
    });
  });

  group('what a fresh install is allowed to say', () {
    test(
        'under a week of history there is no 30-day percentage — it would '
        'be an artefact of which weekday somebody installed on', () async {
      final c = await container(installedDaysAgo: 2);
      expect(c.read(adherenceProvider).rollingThirtyDay, isNull);
    });

    test('exactly a week of history is enough', () async {
      final c = await container(installedDaysAgo: 6);
      expect(c.read(adherenceProvider).rollingThirtyDay, isNotNull);
    });

    test(
        'the week is never prorated — a Tuesday does not shrink the plan, '
        'it just has not finished it', () async {
      final c = await container(installedDaysAgo: 60);
      expect(c.read(adherenceProvider).weekPlanned, 4);
    });
  });

  group('counting completions', () {
    test('nothing logged is zero completed, not a null', () async {
      final c = await container();
      final summary = c.read(adherenceProvider);
      expect(summary.weekCompleted, 0);
      expect(summary.rollingThirtyDay, 0);
    });

    test('two sessions on the same day count once', () async {
      final today = DateTime(now.year, now.month, now.day, 9);
      final c = await container(
        logs: [
          log(1, today),
          log(2, today.add(const Duration(hours: 9))),
        ],
      );
      expect(c.read(adherenceProvider).weekCompleted, 1);
    });

    test('a session outside the thirty-day window is not counted', () async {
      final c = await container(logs: [log(1, daysAgo(45))]);
      expect(c.read(adherenceProvider).rollingThirtyDay, 0);
    });

    test('training more than prescribed clamps at 100%, not 150%', () async {
      final c = await container(
        logs: [for (var i = 0; i < 29; i++) log(i, daysAgo(i))],
      );
      expect(c.read(adherenceProvider).rollingThirtyDay, 1.0);
    });
  });

  group('the longest streak', () {
    test('is the stored high-water mark when no streak is running', () async {
      final c = await container(maxStreak: 9);
      expect(c.read(adherenceProvider).longestStreak, 9);
    });

    test(
        'a streak still running beats the mark, because the mark is only '
        'bumped on completion', () async {
      final c = await container(
        maxStreak: 1,
        logs: [
          for (var i = 0; i < 3; i++)
            log(
                i,
                DateTime(now.year, now.month, now.day, 18)
                    .subtract(Duration(days: i))),
        ],
      );
      final summary = c.read(adherenceProvider);
      expect(summary.currentStreak, greaterThan(1));
      expect(summary.longestStreak, summary.currentStreak);
    });
  });
}
