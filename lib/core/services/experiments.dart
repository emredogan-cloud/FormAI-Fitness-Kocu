import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Roadmap Phase 4 (C36 · P3) · deterministic experiment bucketing.
///
/// The one property that matters: **the same user always lands in the
/// same bucket**. Not "usually" — always, on every launch, on every
/// device, before and after a reinstall that preserves the id, and
/// without a network round-trip or a stored assignment that could drift
/// out of sync with the server's.
///
/// That rules out `Random`, and it rules out storing the assignment and
/// hoping. What it leaves is a pure function of (experiment, user id):
/// hash the pair, take the value modulo the bucket count. Two clients
/// computing it independently agree by construction, which is what makes
/// client-side and server-side analysis of the same experiment
/// comparable.
///
/// Hashing rather than using the id directly also removes the accidental
/// correlation you get from sequential or time-ordered ids: bucketing on
/// a raw uuid's first hex digit would silently correlate assignment with
/// signup order.

/// A running experiment.
class Experiment {
  const Experiment({
    required this.id,
    required this.buckets,
  });

  /// Stable id. Also the salt — changing it re-randomises every
  /// assignment, so never rename a live experiment.
  final String id;

  /// Bucket names in a fixed order. Order is part of the contract:
  /// reordering reassigns users. Must hold at least two entries — not
  /// asserted in the constructor because that would make the canonical
  /// experiments non-const; `bucketFor` is tested against the invariant
  /// instead.
  final List<String> buckets;

  /// The control bucket, by convention the first.
  String get control => buckets.first;
}

/// Roadmap Phase 4 (C36) · the onboarding-length A/B.
///
/// Answers whether the 19-step funnel helps or hurts activation with
/// data instead of opinion. Gated behind
/// `FeatureFlag.onboardingLengthExperiment`, which defaults **off** —
/// an experiment that starts itself is an experiment nobody agreed to
/// run.
const kOnboardingLengthExperiment = Experiment(
  id: 'onboarding_length_v1',
  buckets: ['full', 'short'],
);

/// The bucket [userId] belongs to for [experiment].
///
/// Returns the control bucket for a null or empty id — an anonymous or
/// not-yet-signed-in user must not be silently enrolled into a variant,
/// because their behaviour cannot be attributed to it.
String bucketFor(Experiment experiment, String? userId) {
  final id = userId?.trim() ?? '';
  if (id.isEmpty) return experiment.control;

  final digest = sha256.convert(utf8.encode('${experiment.id}:$id')).bytes;

  // Fold the first 4 bytes into an unsigned 32-bit value. Using several
  // bytes rather than one keeps the distribution even for experiments
  // with a bucket count that isn't a power of two.
  final value =
      (digest[0] << 24) | (digest[1] << 16) | (digest[2] << 8) | digest[3];

  return experiment.buckets[value.abs() % experiment.buckets.length];
}

/// True when [userId] is in a non-control bucket.
bool isInVariant(Experiment experiment, String? userId) =>
    bucketFor(experiment, userId) != experiment.control;
