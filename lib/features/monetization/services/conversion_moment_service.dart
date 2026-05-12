import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/widgets/cinematic_ai_presence.dart';
import '../../onboarding/presentation/widgets/coach_mood.dart';
import '../models/locked_feature_type.dart';
import '../widgets/premium_cta_button.dart';

/// Phase 135 · the cinematic conversion-moment orchestrator.
///
/// Every locked-tap in the app routes through
/// [PremiumGateService.handleLockedTap], which delegates here. The
/// service picks the right contextual [CinematicAiPresence] scene per
/// [LockedFeatureType], renders it with a [PremiumCtaButton] + dismiss
/// affordance in the `bottomActions` slot (Phase 133), and emits the
/// PostHog analytics triplet (`conversion_moment_shown` /
/// `_cta_tapped` / `_dismissed`) so the funnel is measurable.
///
/// Two flavours of scene:
///
///   • **Locked-tap** — fires on every locked interaction. Stateless;
///     no SharedPreferences gate. The point is contextual education
///     ("here's what's behind this lock and why it matters for your
///     transformation").
///
///   • **First-workout Pro invitation** — fires exactly once, on the
///     user's first return-to-dashboard after at least one completed
///     workout. Gated by [AppPreferences.seenFirstWorkoutProInvitation]
///     so the moment can't replay.
///
/// Tone is supportive + aspirational, never salesy — matches the
/// emotional-monetization spec's "the user wants Pro because it will
/// help their transformation" north star.
class ConversionMomentService {
  ConversionMomentService(this._ref);

  final Ref _ref;

  /// Present the cinematic scene for a locked tap. Returns when the
  /// user dismisses (back gesture / "Daha sonra") or taps the CTA
  /// (which navigates to the paywall before the scene closes).
  Future<void> show(BuildContext context, LockedFeatureType type) {
    final config = _lockedConfigs[type]!;
    return _present(
      context,
      config: config,
      source: type.analyticsSource,
    );
  }

  /// One-shot post-first-workout Pro invitation. Caller passes the
  /// current `completedDays` count so the gate fires only when the
  /// user has at least one session under their belt. Pro users are
  /// no-ops; the SharedPreferences flag still gets marked so a
  /// downgrade-then-completion doesn't replay the scene.
  Future<void> maybeShowFirstWorkoutProInvitation(
    BuildContext context, {
    required int completedDays,
    required bool isPro,
  }) async {
    if (completedDays < 1) return;
    final prefs = _ref.read(appPreferencesProvider);
    if (prefs.seenFirstWorkoutProInvitation) return;
    // Mark seen *before* the route push, so a backgrounded scene
    // doesn't replay on app resume — same idempotency pattern as
    // [FirstTimeAiScenes]. Pro users still get the mark so the scene
    // stays one-shot if they ever downgrade.
    await prefs.markSeenFirstWorkoutProInvitation();
    if (isPro) return;
    if (!context.mounted) return;
    await _present(
      context,
      config: _firstWorkoutInvitation,
      source: 'first_workout_pro_invitation',
    );
  }

  Future<void> _present(
    BuildContext context, {
    required _ConversionConfig config,
    required String source,
  }) async {
    AnalyticsService.instance.conversionMomentShown(source: source);
    AppHaptics.lightImpact();
    var ctaTapped = false;
    await Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 600),
        reverseTransitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) {
          return Builder(
            builder: (innerContext) => CinematicAiPresence(
              title: config.title,
              subtitle: config.subtitle,
              subtitleTypewriter: true,
              composingPlaceholder: '',
              mood: config.mood,
              autoCloseAfter: null,
              bottomActions: _ConversionActions(
                ctaLabel: config.ctaLabel,
                onCtaTap: () {
                  ctaTapped = true;
                  AnalyticsService.instance
                      .conversionMomentCtaTapped(source: source);
                  // Pop the scene first so the paywall lands on a
                  // clean stack; this preserves back-gesture behaviour.
                  Navigator.of(innerContext, rootNavigator: true).pop();
                  if (innerContext.mounted) {
                    innerContext.push(AppRoutes.paywall);
                  }
                },
                onDismiss: () {
                  Navigator.of(innerContext, rootNavigator: true).pop();
                },
              ),
            ),
          );
        },
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          child: child,
        ),
      ),
    );
    // Whichever path closed the scene, we know if it was CTA or
    // dismiss by the captured flag. Fire dismissal analytics for the
    // back-gesture case so silent-bounce is observable.
    if (!ctaTapped) {
      AnalyticsService.instance.conversionMomentDismissed(source: source);
    }
  }
}

final conversionMomentProvider =
    Provider<ConversionMomentService>(ConversionMomentService.new);

/// Per-locked-type scene config. Copy here is the *only* place the
/// product voice for these scenes lives — tweak in one spot, ship to
/// every callsite.
const Map<LockedFeatureType, _ConversionConfig> _lockedConfigs = {
  LockedFeatureType.nutritionTab: _ConversionConfig(
    title: 'Beslenmen, dönüşümün anahtarı.',
    subtitle: 'Antrenman gücü artırır.\n'
        'Beslenme görünür değişiklik yaratır.',
    ctaLabel: 'Tam Potansiyelini Aç',
    mood: CoachMood.thinking,
  ),
  LockedFeatureType.equipmentExercise: _ConversionConfig(
    title: 'Daha derin gelişim seni bekliyor.',
    subtitle: 'Premium ekipman egzersizleri\n'
        'yeni güç katmanlarını açar.',
    ctaLabel: 'Dönüşümünü Tam Aç',
    mood: CoachMood.proud,
  ),
  LockedFeatureType.regionNewExercise: _ConversionConfig(
    title: 'Yeni egzersizler, derin şekillendirme.',
    subtitle: 'Her bölgenin yeni varyasyonları\n'
        'kaslarını farklı açılardan çalıştırır.',
    ctaLabel: 'Dönüşümünü Tam Aç',
    mood: CoachMood.thinking,
  ),
  LockedFeatureType.futureDay: _ConversionConfig(
    title: 'Yolculuğunun devamı hazır.',
    subtitle: '30 günlük plan boyunca\n'
        'seninle her gün ilerleyeceğiz.',
    ctaLabel: 'Dönüşümünü Tam Aç',
    mood: CoachMood.proud,
  ),
};

/// Standalone — not keyed by [LockedFeatureType] because it's not a
/// locked-tap. Triggered from dashboard `didPopNext` after the first
/// completed workout.
const _ConversionConfig _firstWorkoutInvitation = _ConversionConfig(
  title: 'İlk adımı attın.',
  subtitle: 'Bu hissi yakaladın mı?\n'
      'Dönüşümünü hızlandırmaya hazır mısın?',
  ctaLabel: 'Tam Potansiyelini Aç',
  mood: CoachMood.celebratory,
);

class _ConversionConfig {
  const _ConversionConfig({
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.mood,
  });

  final String title;
  final String subtitle;
  final String ctaLabel;
  final CoachMood mood;
}

/// Bottom actions for the conversion scene. Pinned to the slot
/// [CinematicAiPresence.bottomActions] (Phase 133); replaces the
/// composing chat-input pill with an explicit decision affordance —
/// "this scene is asking you something."
class _ConversionActions extends StatelessWidget {
  const _ConversionActions({
    required this.ctaLabel,
    required this.onCtaTap,
    required this.onDismiss,
  });

  final String ctaLabel;
  final VoidCallback onCtaTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PremiumCtaButton(
          label: ctaLabel,
          onTap: onCtaTap,
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: onDismiss,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white.withValues(alpha: 0.55),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: const Text(
            'Daha sonra',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ],
    );
  }
}
