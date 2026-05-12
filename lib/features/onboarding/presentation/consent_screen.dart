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
                const SizedBox(height: 16),
                const Text(
                  'Gizlilik Tercihlerin',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'FormAI deneyimini iyileştirmek için anonim kullanım '
                  'verileri toplayabilir. Her ikisi de kapalı başlar — '
                  'istediğin zaman ayarlardan değiştirebilirsin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 28),
                _ConsentTile(
                  title: 'Anonim Kullanım Verileri',
                  description:
                      'Hangi ekranların ne sıklıkla kullanıldığını ölçer. '
                      'İsim, e-posta veya hassas bilgiler gönderilmez.',
                  value: _analyticsChecked,
                  onChanged: (v) => setState(() => _analyticsChecked = v),
                ),
                const SizedBox(height: 14),
                _ConsentTile(
                  title: 'Anonim Çökme Raporları',
                  description:
                      'Uygulama çökerse hata izini gönderir. Kişisel veri '
                      'gönderilmez — sadece teknik stack trace.',
                  value: _crashChecked,
                  onChanged: (v) => setState(() => _crashChecked = v),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _openPrivacyPolicy,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                  ),
                  child: const Text(
                    'Gizlilik Politikasını Oku',
                    style: TextStyle(
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
                        ? 'Tercihlerimi Kaydet'
                        : 'Sadece Zorunlu — Devam Et',
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
                    minimumSize: const Size.fromHeight(40),
                  ),
                  child: const Text(
                    'Hepsini Kabul Et',
                    style: TextStyle(
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
