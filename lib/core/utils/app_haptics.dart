import 'dart:async';

import 'package:flutter/services.dart';

/// Phase 49 · single fasad over `HapticFeedback` with semantic helpers.
///
/// Was scattered as direct `HapticFeedback.lightImpact()` /
/// `mediumImpact()` / `heavyImpact()` / `selectionClick()` calls all
/// over the codebase, with no consistent intent mapping (some CTAs
/// got light, others medium; some success events got medium, others
/// selection-click). Funneling everything through this class:
///
///   • encodes the policy in one place — bumping the warning pattern
///     from "two lights" to "single heavy" is now a single edit;
///   • makes call sites readable — `AppHaptics.primaryCta()` over
///     `unawaited(HapticFeedback.mediumImpact())`;
///   • gives tests a single hook to mock if a future widget test
///     wants to assert "this CTA fired a medium tap".
///
/// All methods are fire-and-forget — the underlying platform-channel
/// calls return `Future<void>` but we never need to await them, and
/// `unawaited(...)` keeps the analyzer's `discarded_futures` lint quiet.
class AppHaptics {
  const AppHaptics._();

  // ===========================================================================
  // Semantic intents — prefer these over the raw `*Impact` helpers below.
  // ===========================================================================

  /// Primary CTA tap — "Antrenmana Başla", "Devam", "Hemen Ekle",
  /// "Plana Ekle". Produces a satisfying medium thump that confirms
  /// the user actually pushed something important.
  static void primaryCta() => mediumImpact();

  /// Secondary action — filter chips, minor toggles, tab switches,
  /// non-destructive list taps. Subtle so the user gets confirmation
  /// without the device shaking on every tap.
  static void secondaryTap() => lightImpact();

  /// Success / confirmation event — "Yedim" tapped, recipe added,
  /// SnackBar surfacing a positive result. Snappy selection-click so
  /// it reads as "done" rather than "another button press".
  static void success() => selectionClick();

  /// Workout-completion celebration. Used only at meaningful
  /// milestones (badge unlocks, full session done) so the user
  /// associates the heavy thump with real wins.
  static void milestone() => heavyImpact();

  /// Workout form-warning pulse — two quick `lightImpact`s separated
  /// by 80 ms. Distinct from the rep / cta haptics so the user can
  /// feel the difference between "good rep" and "fix your form"
  /// without having to look at the screen.
  static Future<void> warningDoubleTap() async {
    await HapticFeedback.lightImpact();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.lightImpact();
  }

  /// Pull-to-refresh trigger — fires the moment the user crosses the
  /// distance threshold and the spinner commits. Distinct from a
  /// generic CTA tap because the gesture itself is bigger and
  /// deserves a meatier confirmation. Routes to `mediumImpact` so
  /// the policy ("refresh = medium") stays in this fasad.
  static void refreshTrigger() => mediumImpact();

  // ===========================================================================
  // Raw passthroughs — kept for sites that genuinely need the unsemanticised
  // call (e.g. the per-rep tick where we just want a literal light tap).
  // New code should prefer the semantic helpers above so the policy can be
  // tuned in one place.
  // ===========================================================================

  static void lightImpact() => unawaited(HapticFeedback.lightImpact());
  static void mediumImpact() => unawaited(HapticFeedback.mediumImpact());
  static void heavyImpact() => unawaited(HapticFeedback.heavyImpact());
  static void selectionClick() => unawaited(HapticFeedback.selectionClick());
}
