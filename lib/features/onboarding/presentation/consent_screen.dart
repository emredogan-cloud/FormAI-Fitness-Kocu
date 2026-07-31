import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/services/consent_state.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/utils/legal_urls.dart';
import '../../../l10n/app_localizations.dart';

/// Phase 138 · H-2 · KVKK / GDPR consent screen.
///
/// Sits between the 18+ age gate and the PII-collecting onboarding
/// wizard. KVKK Article 5 (Law 6698) requires explicit opt-in for
/// any analytics or telemetry that could be linked back to the user,
/// even when the linking is anonymous. Same answer is preserved
/// across re-installs for the same Google Play account is not a
/// concern here because SharedPreferences is wiped on uninstall.
///
/// The flow:
///   • Two toggles (anonim analytics + crash reporting) default to
///     OFF. The user has to actively flip them.
///   • "Devam Et" persists the choice and routes to /onboarding.
///   • "Sadece zorunlu" persists both as `false` and routes
///     forward — the user explicitly rejected non-essential data.
///   • PostHog `Posthog().disable()` was already called at boot
///     (see `AnalyticsService.init`). If the user grants analytics
///     consent here, the screen calls `setEnabled(true)` to flip
///     the SDK back on without an app restart.
///   • Sentry stays initialised but its `beforeSend` hook drops
///     every event until `ConsentState.crashReportingGranted` flips.
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _analyticsChecked = false;
  bool _crashChecked = false;
  bool _busy = false;

  static const Color _neon = Color(0xFF8E5BFF);

  Future<void> _persist({required bool analytics, required bool crash}) async {
    if (_busy) return;
    setState(() => _busy = true);
    AppHaptics.primaryCta();
    final prefs = ref.read(appPreferencesProvider);
    await prefs.setConsent(analytics: analytics, crash: crash);
    ConsentState.apply(
      decided: true,
      analytics: analytics,
      crash: crash,
    );
    // Flip the live SDK state. PostHog was disabled at boot when
    // consent was missing; toggling here matches the user's choice
    // without forcing them to restart. Sentry's beforeSend reads
    // `ConsentState.crashReportingGranted` on every event so the
    // ConsentState.apply() call above is enough on that side.
    await AnalyticsService.instance.setEnabled(analytics);
    // Drop a single transparency breadcrumb so future Sentry events
    // (after consent flips on) carry context about when consent
    // was granted. Idempotent — if crashReportingGranted is false
    // the breadcrumb is still buffered locally but never sent.
    Sentry.addBreadcrumb(Breadcrumb(
      category: 'consent',
      message: 'analytics=$analytics, crash=$crash',
      level: SentryLevel.info,
    ));
    if (!mounted) return;
    context.go(AppRoutes.onboarding);
  }

  void _openPrivacyPolicy() {
    AppHaptics.secondaryTap();
    openLegalUrl(LegalUrls.privacy);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The disclosures scroll; the three actions stay pinned
                // below. A fixed column ran 549 px past the bottom once
                // the legal copy got 40% longer — and this screen cannot
                // be dismissed, so an unreachable CTA is a dead end.
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),
                        Text(
                          l10n.consentTitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.consentIntro,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 28),
                        _ConsentTile(
                          title: l10n.consentAnalyticsTitle,
                          description: l10n.consentAnalyticsBody,
                          value: _analyticsChecked,
                          onChanged: (v) =>
                              setState(() => _analyticsChecked = v),
                        ),
                        const SizedBox(height: 14),
                        _ConsentTile(
                          title: l10n.consentCrashTitle,
                          description: l10n.consentCrashBody,
                          value: _crashChecked,
                          onChanged: (v) => setState(() => _crashChecked = v),
                        ),
                        const SizedBox(height: 20),
                        // Phase 138 · H-5 health disclaimer. Surfaced once before
                        // any data collection so the Play Console "Health
                        // declaration" attestation ("Disclaimer shown in
                        // onboarding") is honestly answerable. Same copy is
                        // mirrored in the Play Store listing footer per the
                        // master plan §8.5.
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: Colors.orange,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  l10n.consentHealthDisclaimer,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _openPrivacyPolicy,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                  ),
                  child: Text(
                    l10n.consentReadPrivacy,
                    style: const TextStyle(
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _persist(
                            analytics: _analyticsChecked,
                            crash: _crashChecked,
                          ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _neon,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _analyticsChecked || _crashChecked
                        ? l10n.consentSavePrefs
                        : l10n.consentEssentialOnly,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _persist(analytics: true, crash: true),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white60,
                    // U4 · 48dp minimum touch target (was 40).
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(
                    l10n.consentAcceptAll,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConsentTile extends StatelessWidget {
  const _ConsentTile({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  static const Color _neon = Color(0xFF8E5BFF);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: _neon,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
