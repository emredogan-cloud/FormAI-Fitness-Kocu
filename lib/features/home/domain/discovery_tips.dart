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
  });

  final int completedDays;
  final int currentStreak;

  /// Tab indices opened at least once.
  final Set<int> visitedTabs;

  final bool hasUsedCoach;
  final bool nutritionOnboarded;
  final int daysSinceInstall;
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

  final String body;
  final String? ctaLabel;
  final String? route;

  final bool Function(TipContext ctx) matches;
}

/// Declaration order is priority order.
final List<DiscoveryTip> kDiscoveryTips = [
  // The coach is the app's strongest differentiator and the easiest to
  // walk past. Fires once the user has trained but never opened it.
  DiscoveryTip(
    id: 'coach_unused',
    body: 'Antrenmanın hakkında bana soru sorabilirsin — '
        'planını ve geçmişini biliyorum.',
    ctaLabel: 'Form ile konuş',
    route: '/coach',
    matches: (c) => c.completedDays >= 1 && !c.hasUsedCoach,
  ),

  // Nutrition is freemium and genuinely useful, but it sits behind a
  // tab the user may never tap.
  DiscoveryTip(
    id: 'nutrition_unvisited',
    body: 'Kalori ve makro hedefin hazır. '
        'Beslenme sekmesinden tarifleri de görebilirsin.',
    ctaLabel: null,
    route: null,
    matches: (c) => c.completedDays >= 1 && !c.visitedTabs.contains(1),
  ),

  // A user with a streak has earned the progress surfaces; showing them
  // the badge/chart layer at this point converts effort into feedback.
  DiscoveryTip(
    id: 'progress_unvisited',
    body: 'Serin büyüyor. Gelişim sekmesinde '
        'rozetlerini ve haftalık grafiklerini görebilirsin.',
    ctaLabel: null,
    route: null,
    matches: (c) => c.currentStreak >= 2 && !c.visitedTabs.contains(2),
  ),

  // Reminders are the single highest-leverage retention setting and are
  // buried two levels deep.
  DiscoveryTip(
    id: 'reminder_setup',
    body: 'Günlük hatırlatma saati seçersen '
        'antrenmanı atlamak zorlaşır.',
    ctaLabel: 'Ayarla',
    route: '/account-settings',
    matches: (c) => c.completedDays >= 2 && c.daysSinceInstall >= 3,
  ),

  // Camera framing is the most common source of a bad first impression
  // of the form engine.
  DiscoveryTip(
    id: 'camera_framing',
    body: 'Analizin en iyi çalışması için telefonu '
        'yaklaşık 2 metre uzağa, dikey olarak yerleştir.',
    ctaLabel: null,
    route: null,
    matches: (c) => c.completedDays >= 1 && c.completedDays <= 3,
  ),
];

/// The tip to show now, or `null`. Pure.
DiscoveryTip? selectTip({
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
