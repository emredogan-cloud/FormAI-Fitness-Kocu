import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/core/services/experiments.dart';

/// Roadmap Phase 4 (C36 · P3) · deterministic experiment bucketing.
///
/// One property carries the whole feature: the same user always lands in
/// the same bucket. If that ever wavers — across launches, across
/// devices, between client and server — the experiment's results are
/// not merely noisy, they are meaningless, and nothing downstream can
/// detect it.
const _e = Experiment(id: 'test_experiment', buckets: ['control', 'variant']);

void main() {
  group('determinism', () {
    test('the same user always gets the same bucket', () {
      const id = 'e3b0c442-98fc-1c14-9afb-f4c8996fb924';
      final first = bucketFor(_e, id);
      for (var i = 0; i < 200; i++) {
        expect(bucketFor(_e, id), first);
      }
    });

    test('a different experiment can bucket the same user differently', () {
      // The experiment id salts the hash, so two experiments are
      // independent. Without that, every experiment would enrol the same
      // half of the userbase and their results would be correlated.
      const id = 'user-1234';
      const other = Experiment(id: 'other_experiment', buckets: [
        'control',
        'variant',
      ]);
      final a = List.generate(400, (i) => bucketFor(_e, 'u$i'));
      final b = List.generate(400, (i) => bucketFor(other, 'u$i'));
      expect(a, isNot(equals(b)));
      // Both are still individually stable.
      expect(bucketFor(other, id), bucketFor(other, id));
    });

    test('bucketing does not depend on process state', () {
      // Same inputs, interleaved with other calls — still identical.
      const id = 'stable-user';
      final a = bucketFor(_e, id);
      bucketFor(_e, 'someone-else');
      bucketFor(_e, 'another-person');
      expect(bucketFor(_e, id), a);
    });
  });

  group('anonymous users', () {
    test('a null id gets the control bucket', () {
      expect(bucketFor(_e, null), _e.control);
    });

    test('an empty or whitespace id gets the control bucket', () {
      // Not "random" and not "variant": a user whose behaviour cannot be
      // attributed must never be counted as having received a variant.
      expect(bucketFor(_e, ''), _e.control);
      expect(bucketFor(_e, '   '), _e.control);
    });

    test('isInVariant is false for an anonymous user', () {
      expect(isInVariant(_e, null), isFalse);
      expect(isInVariant(_e, ''), isFalse);
    });
  });

  group('distribution', () {
    test('two buckets split roughly evenly over many users', () {
      final counts = <String, int>{};
      for (var i = 0; i < 4000; i++) {
        final bucket = bucketFor(_e, 'user-$i');
        counts[bucket] = (counts[bucket] ?? 0) + 1;
      }
      expect(counts.keys.toSet(), _e.buckets.toSet());
      for (final bucket in _e.buckets) {
        // Generous band: this asserts "not badly skewed", not a precise
        // uniformity the hash never promised.
        expect(counts[bucket]! / 4000, closeTo(0.5, 0.06), reason: bucket);
      }
    });

    test('three buckets also split evenly — not just powers of two', () {
      const three = Experiment(id: 'three_way', buckets: ['a', 'b', 'c']);
      final counts = <String, int>{};
      for (var i = 0; i < 4500; i++) {
        final bucket = bucketFor(three, 'person-$i');
        counts[bucket] = (counts[bucket] ?? 0) + 1;
      }
      for (final bucket in three.buckets) {
        expect(counts[bucket]! / 4500, closeTo(1 / 3, 0.06), reason: bucket);
      }
    });

    test('sequential ids do not produce sequential buckets', () {
      // The reason for hashing at all: bucketing on a raw id would
      // correlate assignment with signup order.
      final runs = List.generate(20, (i) => bucketFor(_e, 'seq-$i'));
      expect(runs.toSet().length, greaterThan(1));
    });
  });

  group('the shipped experiment', () {
    test('has a control and a variant, control first', () {
      expect(kOnboardingLengthExperiment.buckets.length, 2);
      expect(kOnboardingLengthExperiment.control, 'full');
      expect(kOnboardingLengthExperiment.buckets, ['full', 'short']);
    });

    test('always returns one of its declared buckets', () {
      for (var i = 0; i < 500; i++) {
        expect(
          kOnboardingLengthExperiment.buckets,
          contains(bucketFor(kOnboardingLengthExperiment, 'u$i')),
        );
      }
    });

    test('an anonymous user stays on the full funnel', () {
      // The safe side: the shipped, tested onboarding.
      expect(bucketFor(kOnboardingLengthExperiment, null), 'full');
    });
  });
}
