/// Roadmap Phase 4 (R1.3) · staged capability unlocks.
///
/// The Testers Community's complaint was that FormAI has "many
/// specialized features" and meets a new user with all of them at once.
/// The answer is not to hide things — it is to *introduce* them on a
/// schedule matched to competence, so week one feels focused and weeks
/// two to four deliver a steady drip of "the app just gave me something
/// new".
///
/// Three rules keep that from turning into a restriction, which is the
/// failure mode of every disclosure system that has annoyed you:
///
///   1. **Navigation is never blocked.** This layer decides *emphasis*
///      and *announcement*, never access. A locked capability is one the
///      user hasn't been introduced to yet, not one they are forbidden.
///      The discovery hub makes that literal: anything can be unlocked
///      from it, immediately, with one tap.
///   2. **Effort unlocks faster than time.** A capability opens on
///      days-since-install OR completed-sessions, whichever comes first.
///      Someone who trains three times on day one has demonstrably
///      earned the progress surfaces; making them wait would be
///      punishing engagement.
///   3. **Nobody is ever re-locked.** Users who are mid-journey when
///      this ships, and users who unlocked something manually, keep what
///      they had — see [isUnlocked]'s `manuallyUnlocked` handling and
///      the grandfathering in [DisclosureState].
library;

/// A capability that participates in staged disclosure.
///
/// Deliberately *not* every screen in the app: only the surfaces that a
/// day-one user does not need, and whose arrival is worth announcing.
/// The workout flow and the coach are absent because they are the
/// product — they are available from the first launch.
enum Capability {
  nutrition(
    key: 'nutrition',
    pillar: CapabilityPillar.nutrition,
    title: 'Beslenme',
    blurb: 'Kalori ve makro hedefin, tarif kütüphanesi ve günlük plan.',
    unlockDay: 2,
    unlockSessions: 1,
    route: null,
    tabIndex: 1,
  ),
  progress(
    key: 'progress',
    pillar: CapabilityPillar.progress,
    title: 'Gelişim',
    blurb: 'Haftalık grafiklerin, hacim ve süre istatistiklerin.',
    unlockDay: 3,
    unlockSessions: 2,
    route: null,
    tabIndex: 2,
  ),
  badges(
    key: 'badges',
    pillar: CapabilityPillar.progress,
    title: 'Rozetler ve XP',
    blurb: 'Kazandığın rozetler, seviyen ve XP geçmişin.',
    unlockDay: 5,
    unlockSessions: 3,
    route: '/progress/badges',
    tabIndex: null,
  ),
  calendar(
    key: 'calendar',
    pillar: CapabilityPillar.progress,
    title: 'Takvim ve geri dönüş',
    blurb: 'Hangi günü ne yaptığını gün gün görebilirsin.',
    unlockDay: 7,
    unlockSessions: 5,
    route: null,
    tabIndex: 2,
  ),
  referral(
    key: 'referral',
    pillar: CapabilityPillar.community,
    title: 'Arkadaşını davet et',
    blurb: 'Davet kodunla arkadaşlarını çağır.',
    unlockDay: 10,
    unlockSessions: 7,
    route: '/referral',
    tabIndex: null,
  ),
  advancedSettings(
    key: 'advanced_settings',
    pillar: CapabilityPillar.coach,
    title: 'Gelişmiş ayarlar',
    blurb: 'Hatırlatmalar, sesli koç ve veri tercihlerinin tamamı.',
    unlockDay: 14,
    unlockSessions: 10,
    route: '/account-settings',
    tabIndex: null,
  );

  const Capability({
    required this.key,
    required this.pillar,
    required this.title,
    required this.blurb,
    required this.unlockDay,
    required this.unlockSessions,
    required this.route,
    required this.tabIndex,
  });

  /// Stable persisted key — the manual-unlock ledger entry and the
  /// analytics dimension. Never rename one.
  final String key;

  final CapabilityPillar pillar;
  final String title;
  final String blurb;

  /// Days since install at which this opens on its own.
  final int unlockDay;

  /// Completed sessions at which this opens regardless of elapsed days.
  final int unlockSessions;

  /// Route to open from the hub, when the capability has its own screen.
  final String? route;

  /// Dashboard tab that hosts it, when it lives in a tab.
  final int? tabIndex;

  static Capability? fromKey(String key) {
    for (final c in Capability.values) {
      if (c.key == key) return c;
    }
    return null;
  }
}

/// Grouping for the discovery hub's capability map.
enum CapabilityPillar {
  training('Antrenman'),
  nutrition('Beslenme'),
  progress('Gelişim'),
  coach('Koç'),
  community('Topluluk');

  const CapabilityPillar(this.label);
  final String label;
}

/// The inputs a disclosure decision reads. A plain value object — no
/// providers, no clock, no BuildContext — so every function below is
/// pure and exhaustively testable.
class DisclosureState {
  const DisclosureState({
    required this.daysSinceInstall,
    required this.completedSessions,
    required this.manuallyUnlocked,
    this.enabled = true,
    this.grandfathered = false,
  });

  final int daysSinceInstall;
  final int completedSessions;

  /// Capability keys the user opened from the discovery hub.
  final Set<String> manuallyUnlocked;

  /// `FeatureFlag.progressiveDisclosure`. When false, everything is
  /// unlocked — the kill switch restores exactly the pre-Phase-4
  /// product.
  final bool enabled;

  /// True for a user who was already using the app before disclosure
  /// shipped. They keep everything; introducing a schedule to someone
  /// on day 40 would take away surfaces they already use, which is the
  /// one thing this system must never do.
  final bool grandfathered;
}

/// Whether [capability] is open to the user described by [state].
bool isUnlocked(Capability capability, DisclosureState state) {
  if (!state.enabled) return true;
  if (state.grandfathered) return true;
  if (state.manuallyUnlocked.contains(capability.key)) return true;
  if (state.daysSinceInstall >= capability.unlockDay) return true;
  if (state.completedSessions >= capability.unlockSessions) return true;
  return false;
}

/// Everything currently open, in schedule order.
List<Capability> unlockedCapabilities(DisclosureState state) =>
    Capability.values
        .where((c) => isUnlocked(c, state))
        .toList(growable: false);

/// Everything not yet open, in schedule order — i.e. the order they will
/// arrive in.
List<Capability> lockedCapabilities(DisclosureState state) => Capability.values
    .where((c) => !isUnlocked(c, state))
    .toList(growable: false);

/// Capabilities that are open now but were not open under [previous].
///
/// This is what drives the unlock celebration. Comparing two states
/// rather than tracking "announced" flags per capability means a missed
/// announcement (app killed mid-celebration) simply doesn't fire, rather
/// than firing forever or being lost — the caller records what it has
/// announced and passes it back as [previous].
List<Capability> newlyUnlocked({
  required DisclosureState previous,
  required DisclosureState current,
}) {
  return Capability.values
      .where((c) => isUnlocked(c, current) && !isUnlocked(c, previous))
      .toList(growable: false);
}

/// Human-readable "when does this arrive" copy for a locked capability.
///
/// Phrased as an invitation rather than a countdown: the point is that
/// something is coming, not that the user is being kept waiting. Returns
/// null when [capability] is already open.
String? unlockHint(Capability capability, DisclosureState state) {
  if (isUnlocked(capability, state)) return null;

  final daysLeft = capability.unlockDay - state.daysSinceInstall;
  final sessionsLeft = capability.unlockSessions - state.completedSessions;

  // Whichever path is closer is the one worth naming — and if training
  // is the shorter road, saying so turns the lock into a nudge toward
  // the thing the app actually wants the user to do.
  if (sessionsLeft > 0 && sessionsLeft <= daysLeft) {
    return sessionsLeft == 1
        ? '1 antrenman sonra açılıyor'
        : '$sessionsLeft antrenman sonra açılıyor';
  }
  if (daysLeft > 0) {
    return daysLeft == 1 ? 'Yarın açılıyor' : '$daysLeft gün sonra açılıyor';
  }
  return 'Yakında açılıyor';
}
