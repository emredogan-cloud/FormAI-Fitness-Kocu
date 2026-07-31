import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/onboarding/presentation/widgets/coach_mood.dart';
import '../utils/app_haptics.dart';
import '../utils/app_logger.dart';
import '../widgets/cinematic_ai_presence.dart';
import 'analytics_service.dart';
import 'app_preferences.dart';
import 'disclosure_providers.dart';
import 'feature_flags.dart';
import 'progressive_disclosure.dart';
import '../../features/home/presentation/unlock_hint_copy.dart';
import '../../l10n/app_localizations.dart';

/// Roadmap Phase 4 (R1.3) · the unlock moment.
///
/// "Each unlock is a small coach-delivered celebration, not a silent
/// appearance." That distinction is the entire point of staged
/// disclosure: a capability that quietly shows up is a UI change, while
/// one the coach hands you is a reward. The former is why disclosure
/// systems feel like restrictions; the latter is why they feel like
/// progress.
///
/// Reuses `CinematicAiPresence` — the same scene system as the first-run
/// beats — at a much shorter dwell. This is punctuation, not a cutscene:
/// it interrupts once, for about three seconds, and never again for that
/// capability.
class UnlockAnnouncer {
  const UnlockAnnouncer._();

  /// Short enough that it reads as a beat rather than an interruption.
  static const Duration _dwell = Duration(milliseconds: 3000);

  /// Same watchdog reasoning as `FirstTimeAiScenes`: this is a
  /// full-screen route with no visible exit, so a second timer removes
  /// it if its own close doesn't fire.
  static const Duration _watchdogGrace = Duration(seconds: 3);

  /// Announces at most ONE newly-unlocked capability.
  ///
  /// One, not all pending: a user returning after a week could cross
  /// three thresholds at once, and three cinematics back-to-back is a
  /// cutscene nobody asked for. The rest stay pending and arrive on
  /// subsequent visits, which also spreads the reward out — which is
  /// the mechanic's whole purpose.
  ///
  /// Safe to call on every dashboard appearance; it no-ops when there is
  /// nothing to announce.
  ///
  /// Returns true when a celebration was shown, so the caller can treat
  /// it as this visit's one interruption and hold back anything else.
  static Future<bool> announceIfNeeded(
    BuildContext context,
    WidgetRef ref, {
    String? firstName,
    int streakDays = 0,
  }) async {
    final flags = ref.read(featureFlagsProvider);
    if (!flags.isEnabled(FeatureFlag.progressiveDisclosure)) return false;
    if (!flags.isEnabled(FeatureFlag.unlockCelebrations)) return false;

    final prefs = ref.read(appPreferencesProvider);
    final state = ref.read(disclosureStateProvider);

    // Grandfathered users have everything already; announcing it would
    // be telling them about surfaces they have been using for weeks.
    if (state.grandfathered) {
      await _markAllAnnounced(prefs);
      return false;
    }

    final announced = prefs.announcedUnlocks;
    final pending = unlockedCapabilities(state)
        .where((c) => !announced.contains(c.key))
        .toList(growable: false);
    if (pending.isEmpty) return false;

    final capability = pending.first;
    // Marked BEFORE the route is pushed, so an app kill mid-celebration
    // costs the user one announcement rather than replaying it forever.
    await prefs.markUnlockAnnounced(capability.key);

    AnalyticsService.instance.featureUnlocked(
      feature: capability.key,
      day: state.daysSinceInstall,
      sessions: state.completedSessions,
    );

    if (!context.mounted) return false;
    await _present(context, capability, firstName, streakDays);
    return true;
  }

  /// Records every currently-open capability as announced without
  /// showing anything. Used for grandfathered users and at the end of
  /// onboarding, so the day-0 set never arrives as a pile of
  /// celebrations.
  static Future<void> markCurrentStateAnnounced(WidgetRef ref) async {
    final prefs = ref.read(appPreferencesProvider);
    final state = ref.read(disclosureStateProvider);
    for (final capability in unlockedCapabilities(state)) {
      await prefs.markUnlockAnnounced(capability.key);
    }
  }

  static Future<void> _markAllAnnounced(AppPreferences prefs) async {
    for (final capability in Capability.values) {
      await prefs.markUnlockAnnounced(capability.key);
    }
  }

  /// The coach's line. Personalised with the name and, when there is
  /// one, the streak — a celebration that could have been written for
  /// anyone doesn't feel like a coach.
  static String announcementBody(
    Capability capability,
    AppLocalizations l10n, {
    String? firstName,
    int streakDays = 0,
  }) {
    final name = (firstName ?? '').trim();
    final title = capability.title(l10n);
    // Whole sentences rather than assembled fragments: Turkish puts the
    // name in front of a comma, English can put it anywhere, and a
    // translator handed "opener + rest" can fix neither.
    final lead = name.isEmpty
        ? l10n.unlockAnnouncementLeadAnon(title)
        : l10n.unlockAnnouncementLeadNamed(name, title);
    final streakLine =
        streakDays >= 2 ? ' ${l10n.unlockAnnouncementStreak(streakDays)}' : '';
    return '$lead$streakLine\n${capability.blurb(l10n)}';
  }

  static Future<void> _present(
    BuildContext context,
    Capability capability,
    String? firstName,
    int streakDays,
  ) async {
    AppHaptics.milestone();
    final navigator = Navigator.of(context, rootNavigator: true);

    late final PageRouteBuilder<void> route;
    route = PageRouteBuilder<void>(
      opaque: true,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, __, ___) => Builder(
        builder: (innerContext) => CinematicAiPresence(
          title: AppLocalizations.of(innerContext).unlockAnnouncementTitle,
          subtitle: announcementBody(
            capability,
            AppLocalizations.of(innerContext),
            firstName: firstName,
            streakDays: streakDays,
          ),
          subtitleTypewriter: false,
          composingPlaceholder:
              capability.title(AppLocalizations.of(innerContext)),
          mood: CoachMood.proud,
          autoCloseAfter: _dwell,
          onComplete: () {
            if (innerContext.mounted) {
              Navigator.of(innerContext, rootNavigator: true).pop();
            }
          },
        ),
      ),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: child,
      ),
    );

    final pushed = navigator.push<void>(route);
    var closed = false;
    unawaited(pushed.whenComplete(() => closed = true));
    unawaited(
      Future<void>.delayed(_dwell + _watchdogGrace, () {
        if (closed || !route.isActive) return;
        AppLogger.warning(
          'unlock announcement for ${capability.key} did not auto-close; '
          'watchdog removed it',
          category: 'disclosure',
        );
        navigator.removeRoute(route);
      }),
    );
    await pushed;
  }
}
