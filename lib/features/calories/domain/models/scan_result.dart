import 'meal_entry.dart';

/// What the scanner returned for one photograph.
class FoodScanResult {
  const FoodScanResult({
    required this.recognized,
    required this.items,
    this.clarification,
    this.scanLimit = 0,
    this.remaining = 0,
  });

  factory FoodScanResult.fromJson(Map<String, dynamic> json) => FoodScanResult(
        recognized: (json['recognized'] as bool?) ?? false,
        clarification: _nonEmpty(json['clarification']),
        scanLimit: (json['scan_limit'] as num?)?.toInt() ?? 0,
        remaining: (json['remaining'] as num?)?.toInt() ?? 0,
        items: ((json['items'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(MealItem.fromJson)
            .toList(growable: false),
      );

  /// False when the photo held no identifiable food.
  final bool recognized;

  /// A question for the user when something was genuinely ambiguous —
  /// "Is this rice or bulgur?".
  ///
  /// The research doc (§6) makes this a first-class outcome rather than
  /// an error state: for a low-confidence plate, asking is the correct
  /// answer and a number would be a worse one.
  final String? clarification;

  final List<MealItem> items;

  /// Quota as it stood *after* this scan, so the UI can update its
  /// counter without a second round trip.
  final int scanLimit;
  final int remaining;

  int get totalKcal => items.fold(0, (s, i) => s + i.kcal);

  static String? _nonEmpty(Object? raw) {
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    return null;
  }
}

/// Today's scan allowance.
class ScanQuota {
  const ScanQuota({
    required this.limit,
    required this.used,
    required this.remaining,
  });

  final int limit;
  final int used;
  final int remaining;

  /// Before the first successful read. Distinguished from "0 remaining"
  /// so the UI can stay quiet rather than announce a limit it has not
  /// actually confirmed.
  static const unknown = ScanQuota(limit: 0, used: 0, remaining: 0);

  bool get isKnown => limit > 0;
  bool get isExhausted => isKnown && remaining <= 0;

  /// A free account's allowance. Used only to decide whether to offer an
  /// upgrade — the limit itself is always the server's number.
  bool get looksFree => limit > 0 && limit <= 2;
}

/// Why a scan did not produce a result.
///
/// Enumerated rather than free-text because every one of these needs a
/// different sentence and a different action, and the roadmap's quality
/// gate is explicit that a user must never be able to get stuck: each
/// kind below maps to a terminal state with a way out.
enum ScanFailureKind {
  /// Out of scans for today. The only failure that is not a fault.
  quotaExhausted,

  /// Signed out, or the session expired mid-scan.
  unauthenticated,

  /// The image was rejected before it was sent.
  imageTooLarge,

  /// The model declined the request.
  refused,

  /// Timed out, 5xx, or a malformed reply. Ours, not the user's — the
  /// server refunds the scan slot for these.
  upstream,

  /// The key or project config is missing.
  unconfigured,

  /// Never reached the server.
  network,
}

class ScanFailure {
  const ScanFailure({required this.kind, this.scanLimit});

  factory ScanFailure.fromCode(String? code, {int? status, int? scanLimit}) {
    switch (code) {
      case 'scan_limit_reached':
        return ScanFailure(
          kind: ScanFailureKind.quotaExhausted,
          scanLimit: scanLimit,
        );
      case 'unauthenticated':
        return const ScanFailure(kind: ScanFailureKind.unauthenticated);
      case 'image_too_large':
        return const ScanFailure(kind: ScanFailureKind.imageTooLarge);
      case 'refused':
        return const ScanFailure(kind: ScanFailureKind.refused);
      case 'scanner_unconfigured':
        return const ScanFailure(kind: ScanFailureKind.unconfigured);
      case 'model_error':
      case 'upstream_failure':
      case 'empty_reply':
      case 'malformed_reply':
      case 'quota_unavailable':
        return const ScanFailure(kind: ScanFailureKind.upstream);
      default:
        // Fall back on the status when the body carried no code — a
        // gateway that never reached our function still produces a
        // sensible message this way.
        if (status == 429) {
          return ScanFailure(
            kind: ScanFailureKind.quotaExhausted,
            scanLimit: scanLimit,
          );
        }
        if (status == 401 || status == 403) {
          return const ScanFailure(kind: ScanFailureKind.unauthenticated);
        }
        return const ScanFailure(kind: ScanFailureKind.upstream);
    }
  }

  final ScanFailureKind kind;

  /// Present on [ScanFailureKind.quotaExhausted] so the message can name
  /// the limit the user hit rather than saying "you hit the limit".
  final int? scanLimit;

  /// Whether offering "try again" makes sense. Retrying a quota refusal
  /// or a refusal just fails again, and a retry button that never works
  /// is worse than no button.
  bool get isRetryable =>
      kind == ScanFailureKind.upstream || kind == ScanFailureKind.network;
}

/// Success or a typed failure. Deliberately not an exception: a scan
/// failing is an expected branch of a normal flow, not an error path.
class ScanOutcome {
  const ScanOutcome.success(FoodScanResult this.result) : failure = null;
  const ScanOutcome.failure(ScanFailure this.failure) : result = null;

  final FoodScanResult? result;
  final ScanFailure? failure;

  bool get isSuccess => result != null;
}
