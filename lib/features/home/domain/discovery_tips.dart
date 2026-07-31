/// Roadmap Phase 2 (C28 · C37) · the contextual tip catalogue.
///
/// The tour (R1.1) teaches the map once. Tips carry the long tail: the
/// capabilities a user only needs to hear about when they're in a
/// position to use them. Together they cover the "many specialized
/// features" problem the Testers Community named.
///
/// Rules encoded here rather than in the widget, so the whole selection
/// policy is one pure function and exhaustively testable:
///
///   * **Relevance over recency.** A tip only fires when its condition
///     holds, and the first matching tip in declaration order wins — so
///     declaration order is priority order.
///   * **Dismissal is permanent.** Re-showing a dismissed tip is how tip
///     systems become nagging.
///   * **Never during a tour.** The caller suppresses tips while the
///     dashboard tour is pending, so the two never compete.
library;

import '../../../l10n/app_localizations.dart';

/// The signals a tip decision reads. A plain value object — no providers,
/// no clock, no BuildContext — so [selectTip] is pure.
class TipContext {
  const TipContext({
    required this.completedDays,
    required this.currentStreak,
    required this.visitedTabs,
    required this.hasUsedCoach,
    required this.nutritionOnboarded,
    required this.daysSinceInstall,
    this.pausedMidWorkout = false,
    this.manualModeUser = false,
  });

  final int completedDays;
  final int currentStreak;

  /// Tab indices opened at least once.
  final Set<int> visitedTabs;

  final bool hasUsedCoach;
  final bool nutritionOnboarded;
  final int daysSinceInstall;

  /// Roadmap Phase 4 · the user left their last session paused rather
  /// than finishing it.
  final bool pausedMidWorkout;

  /// Roadmap Phase 4 · the user is on the camera-free path.
  final bool manualModeUser;
}

/// A dashboard tip. [route] is optional — a tip with no route is pure
/// information and renders without a CTA.
class DiscoveryTip {
  const DiscoveryTip({
    required this.id,
    required this.body,
    required this.matches,
    this.ctaLabel,
    this.route,
  });

  /// Stable id. Also the dismissal-ledger key — never rename one.
  final String id;

  /// Copy as lookups — [kDiscoveryTips] is built before a locale
  /// exists, and the `id` (the dismissal-ledger key) must never move
  /// when the words change.
  final String Function(AppLocalizations) body;
  final String Function(AppLocalizations)? ctaLabel;
  final String? route;

  final bool Function(TipContext ctx) matches;
}

/// Declaration order is priority order.
final List<DiscoveryTip> kDiscoveryTips = [
  // Roadmap Phase 4 · reassurance beats discovery. A user who abandoned
  // a session mid-way is the one most likely to not come back, and the
  // most likely to read a feature suggestion as the app missing the
  // point. Declared first so it outranks everything below it.
  DiscoveryTip(
    id: 'paused_reassurance',
    body: _tipPaused,
    ctaLabel: null,
    route: null,
    matches: (c) => c.pausedMidWorkout,
  ),

  // The coach is the app's strongest differentiator and the easiest to
  // walk past. Fires once the user has trained but never opened it.
  DiscoveryTip(
    id: 'coach_unused',
    body: _tipCoach,
    ctaLabel: _tipCoachCta,
    route: '/coach',
    matches: (c) => c.completedDays >= 1 && !c.hasUsedCoach,
  ),

  // Nutrition is freemium and genuinely useful, but it sits behind a
  // tab the user may never tap.
  DiscoveryTip(
    id: 'nutrition_unvisited',
    body: _tipNutrition,
    ctaLabel: null,
    route: null,
    matches: (c) => c.completedDays >= 1 && !c.visitedTabs.contains(1),
  ),

  // A user with a streak has earned the progress surfaces; showing them
  // the badge/chart layer at this point converts effort into feedback.
  DiscoveryTip(
    id: 'progress_unvisited',
    body: _tipProgress,
    ctaLabel: null,
    route: null,
    matches: (c) => c.currentStreak >= 2 && !c.visitedTabs.contains(2),
  ),

  // Reminders are the single highest-leverage retention setting and are
  // buried two levels deep.
  DiscoveryTip(
    id: 'reminder_setup',
    body: _tipReminder,
    ctaLabel: _tipReminderCta,
    route: '/account-settings',
    matches: (c) => c.completedDays >= 2 && c.daysSinceInstall >= 3,
  ),

  // Camera framing is the most common source of a bad first impression
  // of the form engine, and its window is only the first three days —
  // which is why it outranks the nutrition nudge below despite being
  // declared later than the older tips. Not shown to camera-free users,
  // for whom it is advice about a feature they turned off on purpose.
  DiscoveryTip(
    id: 'camera_framing',
    body: _tipCamera,
    ctaLabel: null,
    route: null,
    matches: (c) =>
        !c.manualModeUser && c.completedDays >= 1 && c.completedDays <= 3,
  ),

  // Roadmap Phase 4 · the nutrition wizard is the gate to the useful
  // half of that tab. Someone who opened the tab but never finished it
  // has shown intent and hit friction — a different situation from
  // never having looked, and a different tip.
  DiscoveryTip(
    id: 'nutrition_wizard_incomplete',
    body: _tipWizard,
    ctaLabel: null,
    route: null,
    matches: (c) => c.visitedTabs.contains(1) && !c.nutritionOnboarded,
  ),

  // Roadmap Phase 4 · the capability map, once there is something in it
  // the user hasn't met. Last in priority: it is the least urgent tip
  // and the most permanent surface.
  DiscoveryTip(
    id: 'discovery_hub',
    body: _tipHub,
    ctaLabel: _tipHubCta,
    route: '/discover',
    matches: (c) => c.completedDays >= 2 && c.daysSinceInstall >= 2,
  ),
];

// Named lookups so the catalogue stays a plain list of declarations.
String _tipPaused(AppLocalizations l) => l.tipPausedSession;
String _tipCoach(AppLocalizations l) => l.tipAskCoach;
String _tipCoachCta(AppLocalizations l) => l.tipAskCoachCta;
String _tipNutrition(AppLocalizations l) => l.tipNutritionReady;
String _tipProgress(AppLocalizations l) => l.tipStreakGrowing;
String _tipReminder(AppLocalizations l) => l.tipSetReminder;
String _tipReminderCta(AppLocalizations l) => l.tipReminderCta;
String _tipCamera(AppLocalizations l) => l.tipCameraFraming;
String _tipWizard(AppLocalizations l) => l.tipNutritionWizard;
String _tipHub(AppLocalizations l) => l.tipDiscoveryHub;
String _tipHubCta(AppLocalizations l) => l.tipDiscoveryHubCta;

/// Roadmap Phase 4 (C28) · minimum gap between two *different* tips.
///
/// Dismissal already stops any single tip repeating. This is the other
/// half: it stops the catalogue as a whole from becoming a conveyor
/// belt, where dismissing one tip immediately produces the next and the
/// dashboard turns into a queue of advice. A day's gap makes each tip
/// read as an observation rather than a campaign.
const Duration kTipFrequencyCap = Duration(hours: 20);

/// The tip to show now, or `null`. Pure.
///
/// [lastShownAt] and [now] enforce [kTipFrequencyCap]. Passing null for
/// [lastShownAt] means "nothing shown yet", which never suppresses.
/// Both are parameters rather than reads so this stays a pure function
/// of its inputs — the property that lets the whole policy be tested
/// without a clock.
DiscoveryTip? selectTip({
  required TipContext context,
  required Set<String> dismissedIds,
  List<DiscoveryTip>? catalog,
  DateTime? lastShownAt,
  DateTime? now,
  String? currentTipId,
}) {
  final candidate = _firstMatch(
    context: context,
    dismissedIds: dismissedIds,
    catalog: catalog,
  );
  if (candidate == null) return null;

  // The tip already on screen is exempt: the cap governs how often a
  // NEW tip may appear, and re-suppressing the visible one would make
  // it flicker away on the next rebuild.
  if (candidate.id == currentTipId) return candidate;

  if (lastShownAt != null && now != null) {
    if (now.difference(lastShownAt) < kTipFrequencyCap) return null;
  }
  return candidate;
}

DiscoveryTip? _firstMatch({
  required TipContext context,
  required Set<String> dismissedIds,
  List<DiscoveryTip>? catalog,
}) {
  for (final tip in catalog ?? kDiscoveryTips) {
    if (dismissedIds.contains(tip.id)) continue;
    if (tip.matches(context)) return tip;
  }
  return null;
}
