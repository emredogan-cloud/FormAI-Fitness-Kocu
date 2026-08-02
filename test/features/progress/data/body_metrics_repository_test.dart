import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/features/progress/data/body_metrics_repository.dart';
import 'package:sixpack_ai/features/progress/domain/models/body_metric.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Every test here runs the OFFLINE path, and that is the point.
///
/// `auth.currentUser` is null against a client with no session, which is
/// the same branch a signed-out user, an anonymous first run and a phone
/// in a lift all take. The roadmap's integration requirement — "offline
/// log → sync on reconnect → no duplicates" — is exactly this: the local
/// write must be complete on its own, and the pending queue must carry
/// the day forward without the entry ever depending on the network
/// having worked.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Constructs without a network round-trip; every call it makes fails,
  // which is what puts the repository on its offline branch. Built per
  // test rather than once at the top of the file: `SupabaseClient`
  // creates an `HttpClient`, and Flutter's test harness only allows that
  // inside a test zone.
  late SupabaseClient client;
  setUp(() {
    client = SupabaseClient('https://offline.supabase.co', 'test-anon-key');
  });

  final today = DateTime(2026, 8, 2);
  DateTime daysAgo(int n) => today.subtract(Duration(days: n));

  Future<BodyMetricsRepository> repo([
    Map<String, Object> seed = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(seed);
    final prefs = await SharedPreferences.getInstance();
    return BodyMetricsRepository(prefs, client: client);
  }

  group('an empty store', () {
    test('loads to nothing rather than throwing', () async {
      expect(await (await repo()).loadAll(), isEmpty);
    });

    test('a corrupted payload is treated as empty, not fatal', () async {
      final r = await repo({'sixpack.body_metrics_v1': 'not json at all'});
      expect(await r.loadAll(), isEmpty);
    });

    test('one malformed entry is dropped and the rest survive', () async {
      final r = await repo({
        'sixpack.body_metrics_v1': jsonEncode([
          {'recorded_on': 'not-a-date', 'weight_kg': 80},
          {'recorded_on': '2026-08-01', 'weight_kg': 79},
        ]),
      });
      final all = await r.loadAll();
      expect(all, hasLength(1));
      expect(all.single.weightKg, 79);
    });
  });

  group('saving', () {
    test('a saved entry comes back', () async {
      final r = await repo();
      await r.save(BodyMetric(recordedOn: today, weightKg: 80.5));
      final all = await r.loadAll();
      expect(all, hasLength(1));
      expect(all.single.weightKg, 80.5);
      expect(all.single.recordedOn, today);
    });

    test('re-logging a day replaces it instead of adding a second point',
        () async {
      final r = await repo();
      await r.save(BodyMetric(recordedOn: today, weightKg: 80));
      await r.save(BodyMetric(recordedOn: today, weightKg: 81));
      final all = await r.loadAll();
      expect(all, hasLength(1));
      expect(all.single.weightKg, 81);
    });

    test('a time component does not create a second entry for the day',
        () async {
      final r = await repo();
      await r.save(BodyMetric(recordedOn: today, weightKg: 80));
      await r.save(
        BodyMetric(
          recordedOn: BodyMetric.dayOf(today.add(const Duration(hours: 22))),
          weightKg: 81,
        ),
      );
      expect(await r.loadAll(), hasLength(1));
    });

    test('entries come back oldest first however they were written', () async {
      final r = await repo();
      await r.save(BodyMetric(recordedOn: daysAgo(1), weightKg: 81));
      await r.save(BodyMetric(recordedOn: daysAgo(9), weightKg: 83));
      await r.save(BodyMetric(recordedOn: daysAgo(5), weightKg: 82));
      expect(
        (await r.loadAll()).map((e) => e.weightKg).toList(),
        [83, 82, 81],
      );
    });

    test('a measurement-free entry is refused', () async {
      final r = await repo();
      expect(
        () => r.save(BodyMetric(recordedOn: today)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('a waist-only entry is perfectly valid', () async {
      final r = await repo();
      await r.save(BodyMetric(recordedOn: today, waistCm: 88));
      final all = await r.loadAll();
      expect(all.single.waistCm, 88);
      expect(all.single.weightKg, isNull);
    });

    test('every measure and the note survive a round-trip', () async {
      final r = await repo();
      await r.save(BodyMetric(
        recordedOn: today,
        weightKg: 80.4,
        waistCm: 88.5,
        chestCm: 102,
        armCm: 35.5,
        thighCm: 58,
        hipCm: 96,
        note: 'morning, fasted',
      ));
      final stored = (await r.loadAll()).single;
      expect(stored.weightKg, 80.4);
      expect(stored.waistCm, 88.5);
      expect(stored.chestCm, 102);
      expect(stored.armCm, 35.5);
      expect(stored.thighCm, 58);
      expect(stored.hipCm, 96);
      expect(stored.note, 'morning, fasted');
    });
  });

  group('the offline queue', () {
    test('a write that cannot reach the server queues its day', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final r = BodyMetricsRepository(prefs, client: client);
      await r.save(BodyMetric(recordedOn: today, weightKg: 80));
      expect(
        prefs.getStringList('sixpack.body_metrics_pending_v1'),
        ['2026-08-02'],
      );
    });

    test('the entry is complete locally regardless of the queue', () async {
      final r = await repo();
      await r.save(BodyMetric(recordedOn: today, weightKg: 80));
      expect((await r.loadAll()).single.weightKg, 80);
    });

    test('re-logging a queued day does not queue it twice', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final r = BodyMetricsRepository(prefs, client: client);
      await r.save(BodyMetric(recordedOn: today, weightKg: 80));
      await r.save(BodyMetric(recordedOn: today, weightKg: 81));
      expect(
        prefs.getStringList('sixpack.body_metrics_pending_v1'),
        hasLength(1),
      );
    });

    test('deleting a queued day clears it from the queue', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final r = BodyMetricsRepository(prefs, client: client);
      await r.save(BodyMetric(recordedOn: today, weightKg: 80));
      await r.delete(today);
      expect(
        prefs.getStringList('sixpack.body_metrics_pending_v1'),
        isNull,
        reason: 'a queued write for a day that no longer exists would '
            'resurrect it on the next flush',
      );
    });
  });

  group('deleting', () {
    test('removes the day', () async {
      final r = await repo();
      await r.save(BodyMetric(recordedOn: daysAgo(1), weightKg: 81));
      await r.save(BodyMetric(recordedOn: today, weightKg: 80));
      await r.delete(today);
      final all = await r.loadAll();
      expect(all, hasLength(1));
      expect(all.single.weightKg, 81);
    });

    test('a day that was never logged is a no-op', () async {
      final r = await repo();
      await r.save(BodyMetric(recordedOn: today, weightKg: 80));
      await r.delete(daysAgo(30));
      expect(await r.loadAll(), hasLength(1));
    });

    test('a time component still finds the day', () async {
      final r = await repo();
      await r.save(BodyMetric(recordedOn: today, weightKg: 80));
      await r.delete(today.add(const Duration(hours: 17)));
      expect(await r.loadAll(), isEmpty);
    });
  });

  group('the day-zero backfill', () {
    // A user who onboarded at 84 kg a fortnight ago and is logging for
    // the first time today.
    Map<String, Object> onboarded({int installedDaysAgo = 14}) => {
          'sixpack.user_metrics': jsonEncode({'weightKg': 84}),
          'sixpack.installed_at': daysAgo(installedDaysAgo).toIso8601String(),
        };

    test('the first weight log produces a line, not a dot', () async {
      final r = await repo(onboarded());
      await r.save(BodyMetric(recordedOn: today, weightKg: 80));
      final all = await r.loadAll();
      expect(all, hasLength(2));
      expect(all.first.weightKg, 84);
      expect(all.first.recordedOn, daysAgo(14));
      expect(all.last.weightKg, 80);
    });

    test('it seeds weight only — onboarding never asked for a waist', () async {
      final r = await repo(onboarded());
      await r.save(BodyMetric(recordedOn: today, weightKg: 80));
      expect((await r.loadAll()).first.waistCm, isNull);
    });

    test('it runs once, so deleting the seed does not bring it back', () async {
      final r = await repo(onboarded());
      await r.save(BodyMetric(recordedOn: today, weightKg: 80));
      await r.delete(daysAgo(14));
      await r.save(BodyMetric(recordedOn: daysAgo(1), weightKg: 79));
      final all = await r.loadAll();
      expect(all, hasLength(2));
      expect(all.map((e) => e.weightKg), [79, 80]);
    });

    test('it never appears in the middle of an existing series', () async {
      final r = await repo(onboarded());
      await r.save(BodyMetric(recordedOn: daysAgo(20), waistCm: 90));
      await r.save(BodyMetric(recordedOn: today, weightKg: 80));
      final all = await r.loadAll();
      expect(all, hasLength(2), reason: 'the store was not empty');
      expect(all.any((e) => e.recordedOn == daysAgo(14)), isFalse);
    });

    test('onboarding and weighing in on the same day yields one point',
        () async {
      final r = await repo(onboarded(installedDaysAgo: 0));
      await r.save(BodyMetric(recordedOn: today, weightKg: 80));
      final all = await r.loadAll();
      expect(all, hasLength(1));
      expect(all.single.weightKg, 80,
          reason: 'the seed would have been the same day at a stale value');
    });

    test('a waist-only first log does not seed a weight', () async {
      final r = await repo(onboarded());
      await r.save(BodyMetric(recordedOn: today, waistCm: 88));
      expect(await r.loadAll(), hasLength(1));
    });

    test('a user with no onboarding weight simply gets their one point',
        () async {
      final r = await repo({
        'sixpack.installed_at': daysAgo(14).toIso8601String(),
      });
      await r.save(BodyMetric(recordedOn: today, weightKg: 80));
      expect(await r.loadAll(), hasLength(1));
    });

    test('the seed is queued for sync like any other write', () async {
      SharedPreferences.setMockInitialValues(onboarded());
      final prefs = await SharedPreferences.getInstance();
      final r = BodyMetricsRepository(prefs, client: client);
      await r.save(BodyMetric(recordedOn: today, weightKg: 80));
      expect(
        prefs.getStringList('sixpack.body_metrics_pending_v1'),
        containsAll(['2026-07-19', '2026-08-02']),
      );
    });
  });

  group('clearAll', () {
    test('wipes the entries, the queue and the backfill flag', () async {
      SharedPreferences.setMockInitialValues({
        'sixpack.user_metrics': jsonEncode({'weightKg': 84}),
        'sixpack.installed_at': daysAgo(14).toIso8601String(),
      });
      final prefs = await SharedPreferences.getInstance();
      final r = BodyMetricsRepository(prefs, client: client);
      await r.save(BodyMetric(recordedOn: today, weightKg: 80));
      await r.clearAll();

      expect(await r.loadAll(), isEmpty);
      expect(prefs.getStringList('sixpack.body_metrics_pending_v1'), isNull);
      expect(prefs.getBool('sixpack.body_metrics_backfilled'), isNull);
    });
  });

  group('the wire format', () {
    test('a date is written as yyyy-MM-dd with no locale in sight', () {
      final entry = BodyMetric(
        recordedOn: DateTime(2026, 1, 5),
        weightKg: 80,
      );
      expect(entry.recordedOnIso, '2026-01-05');
      expect(entry.toJson()['recorded_on'], '2026-01-05');
    });

    test('absent measures are omitted rather than written as null', () {
      final json =
          BodyMetric(recordedOn: DateTime(2026, 1, 5), weightKg: 80).toJson();
      expect(json.containsKey('waist_cm'), isFalse);
      expect(json['weight_kg'], 80);
    });

    test('a numeric arriving as a string is parsed — PostgREST does that', () {
      final entry = BodyMetric.fromJson(const {
        'recorded_on': '2026-01-05',
        'weight_kg': '80.40',
      });
      expect(entry.weightKg, 80.4);
    });

    test('an empty note is read back as absent, not as an empty string', () {
      final entry = BodyMetric.fromJson(const {
        'recorded_on': '2026-01-05',
        'weight_kg': 80,
        'note': '',
      });
      expect(entry.note, isNull);
    });
  });
}
