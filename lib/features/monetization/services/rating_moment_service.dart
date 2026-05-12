import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/widgets/cinematic_ai_presence.dart';
import '../../onboarding/presentation/widgets/coach_mood.dart';

/// Phase 136 · the Pro 3rd-workout cinematic rating moment.
///
/// Triggered from `DashboardScreen.didPopNext` once a Pro user has
/// completed their third workout — the moment the habit starts to
/// feel self-sustaining. The scene reuses [CinematicAiPresence] with
/// a glowing-stars affordance in the [bottomActions] slot. Tapping
/// any star launches `InAppReview.requestReview` (the platform-native
/// rating dialog) and closes the scene; tapping "Daha sonra" cross-
/// fades to a brief warm acknowledgment ("Sorun değil. Belki başka
/// bir gün.") before dismissing.
///
/// Gated by [AppPreferences.seenPro3rdWorkoutRating] so the moment is
/// strictly one-shot per install — re-prompting a user who has
/// already declined would violate the spec's "no guilt-tripping"
/// constraint. Non-pro users are excluded entirely (the rating
/// moment is reserved for users who have ALREADY committed to the
/// platform via subscription).
class RatingMomentService {
  RatingMomentService(this._ref);

  final Ref _ref;

  /// Single entry point. Caller passes the current `completedDays`
  /// count and the user's pro state; the service decides whether to
  /// fire. Returns immediately for non-pro users, users with fewer
  /// than 3 completed sessions, or users who have already seen the
  /// scene. Idempotent — safe to call from every dashboard return.
  Future<void> maybeShow(
    BuildContext context, {
    required int completedDays,
    required bool isPro,
  }) async {
    if (!isPro) return;
    if (completedDays < 3) return;
    final prefs = _ref.read(appPreferencesProvider);
    if (prefs.seenPro3rdWorkoutRating) return;
    // Mark seen first — same idempotency contract as
    // [FirstTimeAiScenes] + [ConversionMomentService]. A scene that
    // crashes mid-render is treated as shown, which we accept in
    // exchange for guaranteed no-replay on app resume.
    await prefs.markSeenPro3rdWorkoutRating();
    if (!context.mounted) return;
    AnalyticsService.instance.ratingPromptShown();
    AppHaptics.lightImpact();
    await _presentRatingScene(context);
  }

  Future<void> _presentRatingScene(BuildContext context) async {
    await Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 600),
        reverseTransitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) {
          return Builder(
            builder: (innerContext) => CinematicAiPresence(
              title: 'Seninle gurur duyuyorum.',
              subtitle: 'Üç antrenmanı tamamladın.\n'
                  'Eğer dönüşümün başladıysa,\n'
                  'belki bir başkasının da başlamasına yardımcı olabilirsin.',
              subtitleTypewriter: true,
              composingPlaceholder: '',
              mood: CoachMood.proud,
              autoCloseAfter: null,
              bottomActions: _RatingStars(
                onStarTap: () => _onStarTap(innerContext),
                onDismiss: () => _onDismiss(innerContext),
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
  }

  Future<void> _onStarTap(BuildContext context) async {
    AnalyticsService.instance.ratingPromptLaunched();
    AppHaptics.primaryCta();
    // Pop the cinematic scene FIRST so the OS dialog lands on a clean
    // stack — otherwise on Android the Play In-App Review API tries
    // to draw on top of the still-mounted PageRouteBuilder and either
    // refuses to show or stacks awkwardly.
    Navigator.of(context, rootNavigator: true).pop();
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
      } else {
        AppLogger.info(
          'InAppReview unavailable on this platform — skipping prompt',
          category: 'monetization',
        );
      }
    } catch (e, st) {
      // Failure here is non-blocking — the user already tapped a
      // star, so the intent was captured. Just log and move on.
      AppLogger.error(
        'InAppReview.requestReview failed',
        e,
        stackTrace: st,
        category: 'monetization',
      );
    }
  }

  Future<void> _onDismiss(BuildContext context) async {
    AnalyticsService.instance.ratingPromptDismissed();
    AppHaptics.secondaryTap();
    // Pop the main rating scene, then push the brief warm-dismissal
    // beat. Sequencing as two scenes keeps the typewriter reveal +
    // auto-close behaviour clean — would have been messy to splice
    // into the same CinematicAiPresence mount.
    Navigator.of(context, rootNavigator: true).pop();
    if (!context.mounted) return;
    await Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, __, ___) {
          return Builder(
            builder: (innerContext) => CinematicAiPresence(
              title: 'Sorun değil.',
              subtitle: 'Belki başka bir gün.\n'
                  'Antrenmanına devam et.',
              subtitleTypewriter: true,
              composingPlaceholder: '',
              mood: CoachMood.thinking,
              autoCloseAfter: const Duration(milliseconds: 3800),
              onComplete: () {
                if (innerContext.mounted) {
                  Navigator.of(innerContext, rootNavigator: true).pop();
                }
              },
            ),
          );
        },
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          child: child,
        ),
      ),
    );
  }
}

final ratingMomentProvider =
    Provider<RatingMomentService>(RatingMomentService.new);

/// Five glowing stars + "Daha sonra" dismiss. Renders inside
/// [CinematicAiPresence.bottomActions]. The stars carry a soft outer
/// glow on idle (premium aesthetic, restrained) and brighten on tap.
/// Any star tap routes through [onStarTap] — the OS dialog handles
/// the actual rating selection, so the in-app star index doesn't
/// need to map to a specific score.
class _RatingStars extends StatelessWidget {
  const _RatingStars({
    required this.onStarTap,
    required this.onDismiss,
  });

  final VoidCallback onStarTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _GlowingStar(onTap: onStarTap),
            );
          }),
        ),
        const SizedBox(height: 18),
        TextButton(
          onPressed: onDismiss,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white.withValues(alpha: 0.55),
            padding: const EdgeInsets.symmetric(vertical: 10),
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

class _GlowingStar extends StatelessWidget {
  const _GlowingStar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.neon.withValues(alpha: 0.45),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(
              Icons.star_rounded,
              color: Color(0xFFFFD55C),
              size: 38,
            ),
          ),
        ),
      ),
    );
  }
}
