import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/widgets/cinematic_ai_presence.dart';
import '../../feedback/presentation/feedback_sheet.dart';
import '../../feedback/services/feedback_service.dart';
import '../../onboarding/presentation/widgets/coach_mood.dart';
import '../domain/rating_trigger.dart';
import '../../../l10n/app_localizations.dart';

/// Play Store listing URL, used as the fallback path when the In-App
/// Review API is unavailable (non-Play devices, sideloaded builds,
/// emulators without Play Services).
const String _kPlayListingUrl =
    'https://play.google.com/store/apps/details?id=com.emredogan.formaifit';
const String _kPlayMarketUri = 'market://details?id=com.emredogan.formaifit';

/// Phase 136, rebuilt in roadmap Phase 1 (R2.1 · R2.2 · C9 · C10) ·
/// the cinematic rating moment.
///
/// What changed and why:
///
///   * **No more `isPro` gate** (C10). The original scene fired only
///     for subscribers, which inverted the intent — a new listing is
///     built on reviews from its whole user base, not its payers.
///   * **Multiple contextual triggers** (R2.2) via [RatingTrigger],
///     replacing the single "3rd workout" moment. Each fires once;
///     a shared 90-day cooldown and a 3-prompt lifetime cap keep the
///     larger trigger set from ever reading as nagging.
///   * **Sentiment routing** (C9). The five stars are no longer
///     decorative. 4–5 launches the platform review dialog; 1–3 opens
///     the feedback sheet instead, so a disappointed user is heard
///     privately rather than publicly. This raises review volume and
///     average rating at the same time, because it separates two
///     populations that were previously funnelled to one place.
///   * **A user-initiated path** (R2.1) via [openStoreListing], wired
///     to the new Settings row. The Testers Community observation was
///     exactly this: a user who wants to rate had nowhere to go.
///
/// Idempotency contract matches [FirstTimeAiScenes] and
/// [ConversionMomentService]: state is stamped *before* the route is
/// pushed, so a scene interrupted by backgrounding never replays.
class RatingMomentService {
  RatingMomentService(this._ref);

  final Ref _ref;

  /// Evaluates every trigger against [context] and presents the scene
  /// for the best eligible one. Returns the trigger that fired, or
  /// `null` when the user was not asked.
  ///
  /// Idempotent and cheap — safe to call on every dashboard return.
  Future<RatingTrigger?> maybeShow(
    BuildContext context, {
    required RatingContext ratingContext,
  }) async {
    final prefs = _ref.read(appPreferencesProvider);
    await _migrateLegacyFlag(prefs);

    final trigger = selectRatingTrigger(
      context: ratingContext,
      firedTokens: prefs.firedRatingTriggers,
      promptCount: prefs.ratingPromptCount,
      lastPromptAt: prefs.lastRatingPromptAt,
      now: DateTime.now(),
      maxLifetimePrompts: AppPreferences.kMaxLifetimeRatingPrompts,
      cooldown: AppPreferences.kRatingPromptCooldown,
    );
    if (trigger == null) return null;

    // Stamp before presenting — a scene the user backgrounds mid-render
    // is treated as shown. We accept losing one impression in exchange
    // for a guaranteed no-replay.
    await prefs.markRatingTriggerFired(trigger.token);
    await prefs.recordRatingPromptShown(DateTime.now());

    if (!context.mounted) return null;
    AnalyticsService.instance.ratingPromptShown(trigger: trigger.token);
    AppHaptics.lightImpact();
    await _presentRatingScene(context, trigger);
    return trigger;
  }

  /// One-time forward-migration of the Phase 136 Pro-only flag into the
  /// new trigger ledger. Without this, a user who already saw (and
  /// perhaps declined) the Pro 3rd-workout scene would be asked again
  /// by the `thirdWorkout` trigger on their next dashboard return.
  Future<void> _migrateLegacyFlag(AppPreferences prefs) async {
    if (!prefs.seenPro3rdWorkoutRating) return;
    if (prefs.firedRatingTriggers.contains(RatingTrigger.thirdWorkout.token)) {
      return;
    }
    await prefs.markRatingTriggerFired(RatingTrigger.thirdWorkout.token);
  }

  /// R2.1 · user-initiated rating from the Settings row. Always
  /// available, never gated, never one-shot — a user who wants to rate
  /// must always have a path.
  ///
  /// Prefers the platform store-listing intent; falls back to
  /// `market://` and then to the https listing so the tap does
  /// something useful even on a device without Play Services.
  Future<void> openStoreListing() async {
    AnalyticsService.instance.rateTapped(source: 'settings');
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await review.openStoreListing();
        return;
      }
    } catch (e, st) {
      AppLogger.warning(
        'openStoreListing via in_app_review failed: $e',
        category: 'monetization',
        data: {'stack': st.toString()},
      );
    }
    for (final url in const [_kPlayMarketUri, _kPlayListingUrl]) {
      try {
        final ok = await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
        if (ok) return;
      } catch (_) {
        // Try the next candidate; the https listing works everywhere a
        // browser exists.
      }
    }
    AppLogger.warning(
      'no store-listing path succeeded',
      category: 'monetization',
    );
  }

  Future<void> _presentRatingScene(
    BuildContext context,
    RatingTrigger trigger,
  ) async {
    await Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 600),
        reverseTransitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) {
          return Builder(
            builder: (innerContext) => CinematicAiPresence(
              title: _copyFor(AppLocalizations.of(context), trigger).title,
              subtitle:
                  _copyFor(AppLocalizations.of(context), trigger).subtitle,
              subtitleTypewriter: true,
              composingPlaceholder: '',
              mood: CoachMood.proud,
              autoCloseAfter: null,
              bottomActions: _RatingStars(
                onRate: (stars) => _onRate(innerContext, trigger, stars),
                onDismiss: () => _onDismiss(innerContext, trigger),
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

  /// C9 · sentiment routing. A happy user goes to the store; an unhappy
  /// one goes to the feedback sheet with the subject pre-selected, so
  /// the friction of explaining themselves is as low as possible.
  Future<void> _onRate(
    BuildContext context,
    RatingTrigger trigger,
    int stars,
  ) async {
    final positive = stars >= 4;
    AnalyticsService.instance.ratingSentimentCaptured(
      stars: stars,
      trigger: trigger.token,
      routedToStore: positive,
    );
    AppHaptics.primaryCta();

    // Pop the cinematic scene FIRST so whatever comes next lands on a
    // clean stack — on Android the Play In-App Review API refuses to
    // draw over a still-mounted PageRouteBuilder.
    Navigator.of(context, rootNavigator: true).pop();
    if (!context.mounted) return;

    if (positive) {
      await _launchPlatformReview();
      return;
    }
    await _openImprovementFeedback(context);
  }

  Future<void> _launchPlatformReview() async {
    AnalyticsService.instance.ratingPromptLaunched();
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
        return;
      }
      AppLogger.info(
        'InAppReview unavailable — falling back to the store listing',
        category: 'monetization',
      );
      await openStoreListing();
    } catch (e, st) {
      // Non-blocking: the user already expressed intent, so a failure
      // here costs us a review, not the session.
      AppLogger.error(
        'InAppReview.requestReview failed',
        e,
        stackTrace: st,
        category: 'monetization',
      );
    }
  }

  Future<void> _openImprovementFeedback(BuildContext context) async {
    final result = await showFeedbackSheet(
      context,
      initialSubject: FeedbackSubject.suggestion,
      introOverride: AppLocalizations.of(context).ratingFeedbackIntro,
    );
    if (result == null || !context.mounted) return;
    final l10n = AppLocalizations.of(context);
    final message = result.transport == FeedbackTransport.supabase
        ? l10n.profileFeedbackSent
        : l10n.profileFeedbackMailOpened;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _onDismiss(BuildContext context, RatingTrigger trigger) async {
    final l10n = AppLocalizations.of(context);
    AnalyticsService.instance.ratingPromptDismissed(trigger: trigger.token);
    AppHaptics.secondaryTap();
    // Two sequenced scenes rather than one mount — keeps the typewriter
    // reveal and auto-close behaviour clean.
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
              title: l10n.ratingDismissTitle,
              subtitle: l10n.ratingDismissSubtitle,
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

/// Per-trigger scene copy. Each moment gets wording that names what the
/// user actually just did — a generic "rate us" prompt at five
/// different moments would read as a template.
_RatingCopy _copyFor(AppLocalizations l10n, RatingTrigger trigger) {
  switch (trigger) {
    case RatingTrigger.programComplete:
      return _RatingCopy(
        title: l10n.ratingProgramCompleteTitle,
        subtitle: l10n.ratingProgramCompleteSubtitle,
      );
    case RatingTrigger.streakSeven:
      return _RatingCopy(
        title: l10n.ratingStreakSevenTitle,
        subtitle: l10n.ratingStreakSevenSubtitle,
      );
    case RatingTrigger.thirdWorkout:
      return _RatingCopy(
        title: l10n.ratingThirdWorkoutTitle,
        subtitle: l10n.ratingThirdWorkoutSubtitle,
      );
    case RatingTrigger.badgeUnlocked:
      return _RatingCopy(
        title: l10n.ratingBadgeTitle,
        subtitle: l10n.ratingBadgeSubtitle,
      );
    case RatingTrigger.firstWorkout:
      return _RatingCopy(
        title: l10n.ratingFirstWorkoutTitle,
        subtitle: l10n.ratingFirstWorkoutSubtitle,
      );
  }
}

class _RatingCopy {
  const _RatingCopy({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
}

final ratingMomentProvider =
    Provider<RatingMomentService>(RatingMomentService.new);

/// Five stars + "Daha sonra". Unlike the Phase 136 version, the star
/// *index* is now meaningful and is reported back to the caller so the
/// sentiment routing in [RatingMomentService._onRate] can act on it.
///
/// Selection is confirmed with a brief fill animation before routing,
/// so the user sees their answer register rather than the screen
/// vanishing under their finger.
class _RatingStars extends StatefulWidget {
  const _RatingStars({
    required this.onRate,
    required this.onDismiss,
  });

  final ValueChanged<int> onRate;
  final VoidCallback onDismiss;

  @override
  State<_RatingStars> createState() => _RatingStarsState();
}

class _RatingStarsState extends State<_RatingStars> {
  int _selected = 0;
  bool _routing = false;

  Future<void> _handleTap(int stars) async {
    if (_routing) return;
    setState(() {
      _selected = stars;
      _routing = true;
    });
    AppHaptics.lightImpact();
    // Let the fill land before we navigate away. Skipped entirely when
    // the user has asked for reduced motion — they still get the state
    // change, just without the deliberate pause.
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!reduceMotion) {
      await Future<void>.delayed(const Duration(milliseconds: 420));
    }
    if (!mounted) return;
    widget.onRate(stars);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          container: true,
          label: AppLocalizations.of(context).ratingStarsSemantics,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final stars = index + 1;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _GlowingStar(
                  filled: stars <= _selected,
                  stars: stars,
                  onTap: () => _handleTap(stars),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 18),
        TextButton(
          onPressed: _routing ? null : widget.onDismiss,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white.withValues(alpha: 0.55),
            padding: const EdgeInsets.symmetric(vertical: 10),
            // 48dp minimum target — accessibility baseline the app
            // already holds elsewhere.
            minimumSize: const Size(88, 48),
          ),
          child: Text(
            AppLocalizations.of(context).commonLater,
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
  const _GlowingStar({
    required this.filled,
    required this.stars,
    required this.onTap,
  });

  final bool filled;
  final int stars;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Semantics(
      button: true,
      label: '$stars yıldız',
      selected: filled,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: AnimatedScale(
              scale: filled ? 1.12 : 1.0,
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.neon.withValues(
                        alpha: filled ? 0.7 : 0.45,
                      ),
                      blurRadius: filled ? 26 : 18,
                      spreadRadius: filled ? 2 : 1,
                    ),
                  ],
                ),
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: const Color(0xFFFFD55C),
                  size: 38,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
