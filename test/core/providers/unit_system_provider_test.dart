import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/providers/unit_system_provider.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/core/utils/unit_system.dart';

/// Phase 6 polish · the metric/imperial switch.
///
/// The conversion maths was already tested in `unit_system_test.dart`.
/// What is new is the *preference* and, more importantly, the promise
/// that turning it on and off again costs nothing: storage stays metric,
/// so a round trip is a display change and not a rewrite.
Future<ProviderContainer> _container(
    [Map<String, Object> seed = const {}]) async {
  SharedPreferences.setMockInitialValues(seed);
  final raw = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(raw)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('defaults to metric', () async {
    final c = await _container();
    expect(c.read(unitSystemProvider), UnitSystem.metric);
  });

  test('a choice persists', () async {
    SharedPreferences.setMockInitialValues({});
    final raw = await SharedPreferences.getInstance();
    final first = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(raw)],
    );
    await first.read(unitSystemProvider.notifier).set(UnitSystem.imperial);
    first.dispose();

    final second = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(raw)],
    );
    addTearDown(second.dispose);
    expect(second.read(unitSystemProvider), UnitSystem.imperial);
  });

  test('a corrupted token resolves to metric rather than throwing', () async {
    final c = await _container({UnitSystemNotifier.storageKey: 'furlongs'});
    expect(c.read(unitSystemProvider), UnitSystem.metric);
  });

  test('re-selecting the active system is a no-op', () async {
    final c = await _container();
    var notifications = 0;
    c.listen(unitSystemProvider, (_, __) => notifications++);

    await c.read(unitSystemProvider.notifier).set(UnitSystem.metric);
    expect(notifications, 0);

    await c.read(unitSystemProvider.notifier).set(UnitSystem.imperial);
    expect(notifications, 1);
  });

  group('the switch is lossless', () {
    test('changing units does not touch the stored value', () async {
      // The whole design in one assertion: the preference key is the
      // ONLY thing that changes. If a future refactor ever rewrites the
      // stored metrics into pounds, this fails.
      final c = await _container({
        'sixpack.user_metrics': '{"heightCm":178,"weightKg":74}',
      });
      final prefs = await SharedPreferences.getInstance();
      final before = prefs.getString('sixpack.user_metrics');

      await c.read(unitSystemProvider.notifier).set(UnitSystem.imperial);
      await c.read(unitSystemProvider.notifier).set(UnitSystem.metric);

      expect(prefs.getString('sixpack.user_metrics'), before);
    });

    test('the edit sheet round-trips a height through feet and inches', () {
      // What the profile editor does on open and on save. A user who
      // opens the sheet in imperial and saves without touching anything
      // must not drift.
      for (var cm = 140.0; cm <= 210.0; cm += 1) {
        final split = cmToFeetInches(cm);
        final back = feetInchesToCm(split.feet, split.inches);
        expect((back - cm).abs(), lessThan(1.3),
            reason: '$cm cm -> ${split.feet}ft ${split.inches}in -> $back cm');
      }
    });

    test('the edit sheet round-trips a weight through pounds', () {
      for (var kg = 40.0; kg <= 180.0; kg += 1) {
        final back = lbToKg(double.parse(kgToLb(kg).toStringAsFixed(0)));
        expect((back - kg).abs(), lessThan(0.5), reason: '$kg kg');
      }
    });

    test('the imperial field bounds cover the metric ones', () {
      // The editor swaps its min/max with the units. If the imperial
      // range were NARROWER than the metric one, a value the user had
      // already saved would fail validation the moment they flipped the
      // toggle — they would open the sheet and be unable to save it.
      //
      // The first version of this test asserted the covering property
      // backwards and passed on a coincidence: 30 kg is 66.14 lb, and
      // 66 lb happened to round in the right direction.
      expect(kMinWeightLb, lessThanOrEqualTo(kgToLb(kMinWeightKg.toDouble())));
      expect(
        kMaxWeightLb,
        greaterThanOrEqualTo(kgToLb(kMaxWeightKg.toDouble())),
      );
      expect(
        kMinHeightFeet,
        lessThanOrEqualTo(cmToFeetInches(kMinHeightCm.toDouble()).feet),
      );
      expect(
        kMaxHeightFeet,
        greaterThanOrEqualTo(cmToFeetInches(kMaxHeightCm.toDouble()).feet),
      );
    });
  });
}
