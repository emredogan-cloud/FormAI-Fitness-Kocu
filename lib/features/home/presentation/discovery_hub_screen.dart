import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/services/disclosure_providers.dart';
import '../../../core/services/progressive_disclosure.dart';
import 'unlock_hint_copy.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_haptics.dart';
import 'dashboard_screen.dart';
import '../../../l10n/app_localizations.dart';

/// Roadmap Phase 4 (C28 · R1.3) · the "Keşfet" capability map.
///
/// This screen is what keeps staged disclosure honest. A schedule that
/// only *withholds* is a restriction dressed up as onboarding; a
/// schedule the user can see in full, and opt out of in one tap, is an
/// introduction. Everything FormAI can do is listed here from day one —
/// what changes over time is whether a row says "hazır" or "3 gün sonra
/// açılıyor", and either way the row is right there, described, and
/// openable.
///
/// The manual-unlock rate this produces is also the honest measurement
/// of whether the schedule is well-paced. If lots of people unlock
/// early, the pacing is wrong — not the users.
class DiscoveryHubScreen extends ConsumerStatefulWidget {
  const DiscoveryHubScreen({super.key});

  @override
  ConsumerState<DiscoveryHubScreen> createState() => _DiscoveryHubScreenState();
}

class _DiscoveryHubScreenState extends ConsumerState<DiscoveryHubScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.discoveryHubOpened();
  }

  Future<void> _unlock(Capability capability) async {
    AppHaptics.primaryCta();
    final prefs = ref.read(appPreferencesProvider);
    AnalyticsService.instance.manualUnlock(
      feature: capability.key,
      day: prefs.daysSinceInstall,
    );
    await prefs.markManuallyUnlocked(capability.key);
    // The unlock is permanent, so it must also count as announced —
    // otherwise the celebration would fire later for something the user
    // opened themselves, which reads as the app taking credit.
    await prefs.markUnlockAnnounced(capability.key);
    if (!mounted) return;
    // `AppPreferences` mutates in place, so the provider that reads it
    // has no way to know its inputs changed. Without this invalidation
    // the row the user just unlocked keeps saying "Şimdi aç" until the
    // screen is rebuilt from scratch — found by test, and it would have
    // read as the button doing nothing.
    ref.invalidate(disclosureStateProvider);
  }

  void _open(Capability capability) {
    AppHaptics.secondaryTap();
    final route = capability.route;
    if (route != null) {
      context.push(route);
      return;
    }
    final tab = capability.tabIndex;
    if (tab != null) {
      DashboardScreen.requestTab(ref, tab);
      // Pop back to the dashboard so the requested tab is what the user
      // lands on, rather than sitting behind this screen.
      if (context.canPop()) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(disclosureStateProvider);
    final unlocked = unlockedCapabilities(state);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0612),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          AppLocalizations.of(context).discoveryHubTitle,
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.4),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            _HubHeader(
              unlockedCount: unlocked.length,
              totalCount: Capability.values.length,
            ),
            const SizedBox(height: 20),
            for (final pillar in CapabilityPillar.values)
              ..._pillarSection(pillar, state),
          ],
        ),
      ),
    );
  }

  List<Widget> _pillarSection(
    CapabilityPillar pillar,
    DisclosureState state,
  ) {
    final items = Capability.values.where((c) => c.pillar == pillar).toList();
    if (items.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Text(
          pillar.label(AppLocalizations.of(context)).toUpperCase(),
          style: TextStyle(
            color: AppColors.neon.withValues(alpha: 0.9),
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
          ),
        ),
      ),
      for (final capability in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _CapabilityCard(
            capability: capability,
            unlocked: isUnlocked(capability, state),
            hint: unlockHint(capability, state),
            onOpen: () => _open(capability),
            onUnlock: () => _unlock(capability),
          ),
        ),
      const SizedBox(height: 10),
    ];
  }
}

class _HubHeader extends StatelessWidget {
  const _HubHeader({required this.unlockedCount, required this.totalCount});

  final int unlockedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: AppColors.neon.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FormAI neler yapabiliyor?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).discoveryHubIntro,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Semantics(
            label: AppLocalizations.of(context)
                .hubUnlockedOf(unlockedCount, totalCount),
            child: ExcludeSemantics(
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: totalCount == 0 ? 0 : unlockedCount / totalCount,
                        minHeight: 6,
                        backgroundColor: Colors.white12,
                        valueColor:
                            const AlwaysStoppedAnimation(AppColors.neon),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$unlockedCount / $totalCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({
    required this.capability,
    required this.unlocked,
    required this.hint,
    required this.onOpen,
    required this.onUnlock,
  });

  final Capability capability;
  final bool unlocked;
  final UnlockHint? hint;
  final VoidCallback onOpen;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    // Locked rows render at reduced emphasis — never greyed to
    // unreadability, and never behind a paywall-style block. That
    // pattern is reserved for Pro; this is "not introduced yet".
    final titleAlpha = unlocked ? 1.0 : 0.72;
    final borderAlpha = unlocked ? 0.32 : 0.12;
    final l10n = AppLocalizations.of(context);

    return Semantics(
      container: true,
      label: unlocked
          ? l10n.discoveryCardOpenSemantics(capability.title(l10n))
          : l10n.discoveryCardLockedSemantics(
              capability.title(l10n),
              (hint ?? const UnlockSoon()).text(l10n),
            ),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 14, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withValues(alpha: unlocked ? 0.05 : 0.025),
          border:
              Border.all(color: AppColors.neon.withValues(alpha: borderAlpha)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  unlocked ? Icons.check_circle_rounded : Icons.lock_outline,
                  size: 18,
                  color: unlocked
                      ? const Color(0xFF39FF14)
                      : Colors.white.withValues(alpha: 0.45),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    capability.title(l10n),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: titleAlpha),
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              capability.blurb(l10n),
              style: TextStyle(
                color: Colors.white.withValues(alpha: unlocked ? 0.62 : 0.5),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            if (unlocked)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: onOpen,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.neon,
                    minimumSize: const Size(88, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: Text(
                    AppLocalizations.of(context).discoveryHubOpen,
                    style:
                        TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (hint ?? const UnlockSoon()).text(l10n),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  // The escape hatch that makes disclosure a default
                  // rather than a restriction.
                  TextButton(
                    onPressed: onUnlock,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.neon,
                      minimumSize: const Size(88, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: Text(
                      AppLocalizations.of(context).discoveryHubUnlockNow,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
