import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/core/utils/unit_system.dart';

/// Roadmap Phase 5 (C12) · unit conversion, at 100% coverage.
///
/// The property that protects users' data: **storage is always metric**,
/// and toggling the display unit must never change the stored value. A
/// conversion that loses precision on the round trip would make a user's
/// weight drift every time they flipped the switch — slowly, invisibly,
/// and irreversibly.
void main() {
  group('tokens', () {
    test('are stable and unique — they are persisted preference values', () {
      expect(UnitSystem.metric.token, 'metric');
      expect(UnitSystem.imperial.token, 'imperial');
      expect(
        UnitSystem.values.map((s) => s.token).toSet().length,
        UnitSystem.values.length,
      );
    });

    test('fromToken round-trips every value', () {
      for (final system in UnitSystem.values) {
        expect(UnitSystem.fromToken(system.token), system);
      }
    });

    test('unknown, null and empty resolve to metric — the storage unit', () {
      expect(UnitSystem.fromToken(null), UnitSystem.metric);
      expect(UnitSystem.fromToken(''), UnitSystem.metric);
      expect(UnitSystem.fromToken('stones'), UnitSystem.metric);
      expect(UnitSystem.fromToken('METRIC'), UnitSystem.metric);
    });
  });

  group('weight conversion', () {
    test('uses the exact internationally-defined pound', () {
      expect(kKgPerPound, 0.45359237);
    });

    test('known values convert correctly', () {
      expect(kgToLb(100), closeTo(220.462, 0.001));
      expect(lbToKg(220.462), closeTo(100, 0.001));
      expect(kgToLb(1), closeTo(2.20462, 0.00001));
    });

    test('round-trips without drift', () {
      // The whole point: a user toggling the unit switch twice must see
      // the same number they started with.
      for (final kg in [30.0, 55.5, 70.0, 82.3, 120.0, 249.9]) {
        expect(lbToKg(kgToLb(kg)), closeTo(kg, 1e-9), reason: '$kg kg');
      }
      for (final lb in [66.0, 150.5, 200.0, 551.0]) {
        expect(kgToLb(lbToKg(lb)), closeTo(lb, 1e-9), reason: '$lb lb');
      }
    });

    test('zero and negatives pass through arithmetically', () {
      // Not a supported input, but must not throw or produce NaN.
      expect(kgToLb(0), 0);
      expect(lbToKg(0), 0);
      expect(kgToLb(-10), lessThan(0));
    });
  });

  group('height conversion', () {
    test('uses the exact internationally-defined inch', () {
      expect(kCmPerInch, 2.54);
    });

    test('known values convert correctly', () {
      expect(cmToInches(170), closeTo(66.929, 0.001));
      expect(inchesToCm(66), closeTo(167.64, 0.001));
    });

    test('round-trips without drift', () {
      for (final cm in [120.0, 155.0, 170.0, 183.5, 229.0]) {
        expect(inchesToCm(cmToInches(cm)), closeTo(cm, 1e-9), reason: '$cm cm');
      }
    });

    test('cmToFeetInches splits correctly', () {
      expect(cmToFeetInches(182.88), const FeetInches(6, 0));
      expect(cmToFeetInches(170), const FeetInches(5, 7));
      expect(cmToFeetInches(152.4), const FeetInches(5, 0));
    });

    test('the 12-inch carry becomes another foot, never "5 feet 12"', () {
      // 181.5 cm ≈ 71.46 in → 71 in → 5'11". 182.5 cm ≈ 71.85 in → 72 in,
      // which must read as 6'0" and not 5'12".
      final tall = cmToFeetInches(182.5);
      expect(tall.inches, lessThan(12));
      expect(tall, const FeetInches(6, 0));

      for (var cm = 120.0; cm <= 230.0; cm += 0.5) {
        expect(cmToFeetInches(cm).inches, inRange(0, 11), reason: '$cm cm');
      }
    });

    test('feetInchesToCm inverts cmToFeetInches to within half an inch', () {
      // Exact inversion is impossible — feet-and-inches is a lossy
      // rendering — but it must land inside the rounding window.
      for (var cm = 120.0; cm <= 230.0; cm += 1.0) {
        final split = cmToFeetInches(cm);
        final back = feetInchesToCm(split.feet, split.inches);
        expect((back - cm).abs(), lessThanOrEqualTo(kCmPerInch / 2 + 1e-9),
            reason: '$cm cm');
      }
    });

    test('FeetInches has value equality and readable toString', () {
      expect(const FeetInches(5, 9), const FeetInches(5, 9));
      expect(const FeetInches(5, 9).hashCode, const FeetInches(5, 9).hashCode);
      expect(const FeetInches(5, 9) == const FeetInches(5, 10), isFalse);
      expect(const FeetInches(5, 9).toString(), '5\'9"');
    });
  });

  group('weight formatting', () {
    test('metric renders kilograms', () {
      expect(formatWeight(70, system: UnitSystem.metric), '70 kg');
      expect(formatWeight(70.4, system: UnitSystem.metric), '70 kg');
      expect(formatWeight(70.6, system: UnitSystem.metric), '71 kg');
    });

    test('imperial renders pounds', () {
      expect(formatWeight(70, system: UnitSystem.imperial), '154 lb');
      expect(formatWeight(100, system: UnitSystem.imperial), '220 lb');
    });

    test('decimals are opt-in, and trailing zeros are trimmed', () {
      expect(formatWeight(70.25, system: UnitSystem.metric, decimals: 1),
          '70.3 kg');
      expect(
          formatWeight(70.0, system: UnitSystem.metric, decimals: 2), '70 kg');
    });

    test('the unit can be omitted for surfaces that render it separately', () {
      expect(
          formatWeight(70, system: UnitSystem.metric, withUnit: false), '70');
    });

    test('labels match the system', () {
      expect(weightUnitLabel(UnitSystem.metric), 'kg');
      expect(weightUnitLabel(UnitSystem.imperial), 'lb');
    });
  });

  group('height formatting', () {
    test('metric renders centimetres', () {
      expect(formatHeight(170, system: UnitSystem.metric), '170 cm');
      expect(
          formatHeight(170, system: UnitSystem.metric, withUnit: false), '170');
    });

    test('imperial renders feet and inches, never decimal feet', () {
      expect(formatHeight(170, system: UnitSystem.imperial), '5\'7"');
      expect(formatHeight(182.88, system: UnitSystem.imperial), '6\'0"');
      expect(
        formatHeight(170, system: UnitSystem.imperial),
        isNot(contains('.')),
      );
    });

    test('labels match the system', () {
      expect(heightUnitLabel(UnitSystem.metric), 'cm');
      expect(heightUnitLabel(UnitSystem.imperial), 'ft');
    });
  });

  group('distance formatting', () {
    test('metric switches from metres to kilometres at 1000', () {
      expect(formatDistance(999, system: UnitSystem.metric), '999 m');
      expect(formatDistance(1000, system: UnitSystem.metric), '1 km');
      expect(formatDistance(5500, system: UnitSystem.metric), '5.5 km');
    });

    test('imperial switches from feet to miles at a mile', () {
      expect(formatDistance(100, system: UnitSystem.imperial), '328 ft');
      expect(formatDistance(1609.344, system: UnitSystem.imperial), '1 mi');
    });

    test('zero renders without a crash or a stray decimal', () {
      expect(formatDistance(0, system: UnitSystem.metric), '0 m');
      expect(formatDistance(0, system: UnitSystem.imperial), '0 ft');
    });
  });

  group('picker ranges', () {
    test('metric ranges are the stored bounds', () {
      expect(weightRange(UnitSystem.metric), (min: 30.0, max: 250.0));
      expect(heightRange(UnitSystem.metric), (min: 120.0, max: 230.0));
    });

    test('imperial ranges cover the same real-world span', () {
      final w = weightRange(UnitSystem.imperial);
      expect(lbToKg(w.min), closeTo(30, 1));
      expect(lbToKg(w.max), closeTo(250, 1));
      final h = heightRange(UnitSystem.imperial);
      expect(inchesToCm(h.min), closeTo(120, 2));
      expect(inchesToCm(h.max), closeTo(230, 2));
    });

    test('min is always below max', () {
      for (final system in UnitSystem.values) {
        expect(weightRange(system).min, lessThan(weightRange(system).max));
        expect(heightRange(system).min, lessThan(heightRange(system).max));
      }
    });
  });

  group('roundTo', () {
    test('rounds to the requested precision', () {
      expect(roundTo(70.456, 1), 70.5);
      expect(roundTo(70.444, 2), 70.44);
      expect(roundTo(70.5, 0), 71);
    });

    test('is a no-op on already-round values', () {
      expect(roundTo(70, 2), 70);
    });
  });
}

Matcher inRange(int min, int max) =>
    allOf(greaterThanOrEqualTo(min), lessThanOrEqualTo(max));
