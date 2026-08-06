import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/motion/ambient_particles.dart';
import '../../../../core/motion/glow_pulse.dart';
import '../../../../core/motion/sparkle_burst.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../l10n/app_localizations.dart';
import '../widgets/coach_mood.dart';
import '../widgets/living_coach_avatar.dart';

/// Honesty rebuild of the Phase 124 social-proof scene.
///
/// The previous iteration rendered nine invented reviewers with star
/// ratings, recency stamps, a "4.8 KULLANICI MEMNUNİYETİ" badge and
/// "binlerce kişi" momentum copy — for a pre-launch app with zero
/// users. That is fabricated social proof (Apple 2.3.1 / Google Play
/// Misrepresentation) and it lied to our very first users.
///
/// This scene keeps the cinematic composition (hero avatar, layered
/// hierarchy, center-emphasis carousel, glow CTA) but every claim on
/// screen is now a verifiable product fact:
///
///   • "130+ egzersiz" — the analyzer factory routes 138 exercise
///     slugs to real form analyzers (locked by unit tests).
///   • "%100 cihazında" — pose analysis runs on-device via ML Kit;
///     camera frames never leave the phone.
///   • The carousel shows what the product actually does (rep
///     counting, voice coaching, personalized plan, privacy) instead
///     of who allegedly used it.
///   • The momentum strip frames early access honestly instead of
///     implying an existing crowd.
///
/// No user counts, no ratings, no testimonials until we have real
/// ones (the in_app_review flow can earn them post-launch).
class _Highlight {
  const _Highlight({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;
}

List<_Highlight> _highlightsFor(AppLocalizations l10n) => [
      _Highlight(
        icon: Icons.videocam_rounded,
        title: l10n.socialProofRepCountTitle,
        body: l10n.socialProofRepCountBody,
      ),
      _Highlight(
        icon: Icons.record_voice_over_rounded,
        title: l10n.socialProofVoiceTitle,
        body: l10n.socialProofVoiceBody,
      ),
      _Highlight(
        icon: Icons.tune_rounded,
        title: l10n.socialProofPlanTitle,
        body: l10n.socialProofPlanBody,
      ),
      _Highlight(
        icon: Icons.lock_rounded,
        title: l10n.socialProofPrivacyTitle,
        body: l10n.socialProofPrivacyBody,
      ),
    ];

/// Stacks two whole ARB strings into a two-line caption.
///
/// The join used to be written inline as `'$first\n'  '$second'`, which
/// put a literal containing `\n` directly under a `caption:` argument —
/// the exact shape the hardcoded-string gate now treats as a rendering.
/// It was never copy: a newline between two translated strings is a
/// layout decision, not a sentence. Naming it says so once instead of
/// twice, and keeps the gate's signal free of a false positive it would
/// otherwise have to be taught to ignore.
String _twoLine(String first, String second) => '$first\n$second';

class SocialProofStep extends StatefulWidget {
  const SocialProofStep({super.key, required this.onContinue});
  final VoidCallback onContinue;

  @override
  State<SocialProofStep> createState() => _SocialProofStepState();
}

class _SocialProofStepState extends State<SocialProofStep> {
  bool _readyForCommit = false;

  @override
  void initState() {
    super.initState();
    // CTA gates after a 1.2 s settle so the user reads at least one
    // highlight before being able to advance.
    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _readyForCommit = true);
    });
  }

  void _commit() {
    if (!_readyForCommit) return;
    AppHaptics.secondaryTap();
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF0A0814)),
        const AmbientParticles(
          count: 10,
          color: AppColors.neon,
          minAlpha: 0.06,
          maxAlpha: 0.22,
          minRadius: 1.0,
          maxRadius: 2.2,
          driftDuration: Duration(seconds: 30),
          seed: 211,
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Everything above the CTA scrolls; the CTA and its
                // caption stay pinned below. Same shape as the RC-18
                // Başla fix and the Phase-3b report — a fixed column
                // here overran the bottom by 202 px on a 320×640 phone
                // once the copy got 40% longer.
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _HeroZone(),
                        const SizedBox(height: 4),
                        ShaderMask(
                          shaderCallback: (rect) => const LinearGradient(
                            colors: [AppColors.neon, AppColors.neonAccent],
                          ).createShader(rect),
                          child: Text(
                            l10n.socialProofHeadline,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              height: 1.25,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.trainAnywhereBlurb,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.62),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.1,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _StatBadge(
                              number: '130+',
                              caption: _twoLine(
                                l10n.act5StatExercises,
                                l10n.liveFormAnalysisEyebrow,
                              ),
                            ),
                            const SizedBox(width: 10),
                            _StatBadge(
                              number: 'AI',
                              caption: _twoLine(
                                l10n.act5StatAiPowered,
                                l10n.act5StatOnDevice,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          // 160 clipped the English privacy card's last
                          // line on a 393 dp phone — "…the analysis runs
                          // entirely" with the "on your phone" gone, and
                          // no ellipsis to show it had happened. That
                          // sentence is a claim about what the app does
                          // with your camera, so it does not get to be
                          // half-rendered.
                          height: 176,
                          child: _HighlightCarousel(
                            highlights: _highlightsFor(l10n),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const _EarlyAccessStrip(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                GlowPulse(
                  enabled: _readyForCommit,
                  color: AppColors.neon,
                  minAlpha: 0.40,
                  maxAlpha: 0.65,
                  minBlur: 22,
                  maxBlur: 32,
                  spread: 1,
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(18),
                  duration: const Duration(milliseconds: 2900),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _readyForCommit ? _commit : null,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(l10n.commitCta),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.neon,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            AppColors.neon.withValues(alpha: 0.35),
                        disabledForegroundColor: Colors.white60,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.5,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.commitLastStep,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Hero zone: Form avatar wrapped in SparkleBurst, with a small
/// speech bubble pinned to the upper-right of the zone.
class _HeroZone extends StatelessWidget {
  const _HeroZone();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SparkleBurst(
            color: AppColors.neon,
            particleCount: 12,
            maxRadius: 95,
            peakAlpha: 0.70,
            minLifetime: Duration(milliseconds: 1100),
            maxLifetime: Duration(milliseconds: 1800),
            child: LivingCoachAvatar(
              size: 140,
              innerSize: 96,
              mood: CoachMood.excited,
            ),
          ),
          Positioned(
            top: 6,
            right: 0,
            child: _SpeechBubble(
              text: AppLocalizations.of(context).act5HeroBubble,
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating tag visually anchored to the avatar — narrative voice of
/// Form's presence on this scene without needing actual TTS.
class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        constraints: const BoxConstraints(maxWidth: 130),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.neon.withValues(alpha: 0.20),
              AppColors.neonAccent.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.neon.withValues(alpha: 0.45),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.neon.withValues(alpha: 0.18),
              blurRadius: 12,
              spreadRadius: -3,
            ),
          ],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}

/// One half of the stat-anchor row. Laurel-pill shape with gradient
/// fill + neon border + soft glow. Number on top, caption underneath
/// in muted uppercase. Only verifiable product facts belong here.
class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.number,
    required this.caption,
  });
  final String number;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.neon.withValues(alpha: 0.18),
              AppColors.neonAccent.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.neon.withValues(alpha: 0.50),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.neon.withValues(alpha: 0.18),
              blurRadius: 16,
              spreadRadius: -3,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                height: 1.0,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 4),
            // "LIVE FORM ANALYSIS" ellipsised to "LIVE FORM ANALY…" in
            // English on a 393 dp phone. The caption is two authored
            // lines, so wrapping it further is not an option and a
            // shorter English string would be losing the claim to fit a
            // badge — it scales instead.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                caption,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Center-emphasis capability carousel. PageView with viewportFraction
/// 0.72 so the centered card occupies the middle while the leading
/// edges of left/right cards are visible. Each card's apparent scale +
/// opacity is driven by its PageController page offset → centered card
/// reads big and bright, side cards recede.
///
/// Auto-advance via [Timer.periodic] on a 2.4 s cadence:
/// 720 ms easeInOutCubic animation + 1.68 s dwell.
class _HighlightCarousel extends StatefulWidget {
  const _HighlightCarousel({required this.highlights});
  final List<_Highlight> highlights;

  @override
  State<_HighlightCarousel> createState() => _HighlightCarouselState();
}

class _HighlightCarouselState extends State<_HighlightCarousel> {
  late final PageController _pageCtrl;
  Timer? _timer;

  static const Duration _advanceInterval = Duration(milliseconds: 2400);
  static const Duration _animateDuration = Duration(milliseconds: 720);

  @override
  void initState() {
    super.initState();
    // Start deep into a virtually infinite list (× 500) so we never
    // hit either end during the user's dwell on this step. We use
    // modulo for the highlight lookup, so any page index resolves to
    // a real card.
    _pageCtrl = PageController(
      viewportFraction: 0.72,
      initialPage: widget.highlights.length * 500,
    );
    _timer = Timer.periodic(_advanceInterval, (_) {
      if (!mounted || !_pageCtrl.hasClients) return;
      _pageCtrl.nextPage(
        duration: _animateDuration,
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageCtrl,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, i) {
        final h = widget.highlights[i % widget.highlights.length];
        return _AnimatedCard(
          page: i,
          controller: _pageCtrl,
          child: _HighlightCard(highlight: h),
        );
      },
    );
  }
}

/// Wraps a card with scale + opacity driven by its distance from the
/// PageController's current page. Uses one [AnimatedBuilder] per card
/// (cheap — only the Transform + Opacity render objects re-evaluate
/// per frame; the card body is the `child` so it's built once and
/// passed through). Wrapped in RepaintBoundary so a card's paint
/// pass doesn't bubble to adjacent cards.
class _AnimatedCard extends StatelessWidget {
  const _AnimatedCard({
    required this.page,
    required this.controller,
    required this.child,
  });
  final int page;
  final PageController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, c) {
        double diff = 0.0;
        if (controller.position.haveDimensions) {
          diff = ((controller.page ?? page.toDouble()) - page);
        }
        final absDiff = diff.abs().clamp(0.0, 1.0);
        // 1.0 at center → 0.86 at the edge of the viewport.
        final scale = 1.0 - absDiff * 0.14;
        // 1.0 at center → 0.45 at the edge. Floor at 0.30 so the
        // card silhouette never fully disappears — momentum signal.
        final opacity = (1.0 - absDiff * 0.55).clamp(0.30, 1.0);
        return Center(
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: Opacity(opacity: opacity, child: c),
          ),
        );
      },
      child: RepaintBoundary(child: child),
    );
  }
}

/// One capability card: neon icon medallion above the title + body.
/// Gradient fill + neon border + soft outer shadow — same chrome as
/// the old cards, honest content.
class _HighlightCard extends StatelessWidget {
  const _HighlightCard({required this.highlight});
  final _Highlight highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.neon.withValues(alpha: 0.38),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.neon.withValues(alpha: 0.18),
            blurRadius: 18,
            spreadRadius: -4,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.neon.withValues(alpha: 0.55),
                  AppColors.neonAccent.withValues(alpha: 0.35),
                ],
              ),
              border: Border.all(
                color: AppColors.neon.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            child: Icon(highlight.icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 8),
          // Flexible, because the card is a fixed 160 px tall inside a
          // PageView: a longer title at a large text scale has to
          // shorten rather than push the body out of the card.
          Flexible(
            child: Text(
              highlight.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Center(
              child: Text(
                highlight.body,
                textAlign: TextAlign.center,
                maxLines: 4,
                // `fade` was hiding the cut. An ellipsis makes a future
                // overflow visible in a screenshot instead of reading as
                // a shorter sentence that happens to be wrong.
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 11.5,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Early-access strip beneath the carousel. Replaces the fabricated
/// "Binlerce kişi · dönüşüm yapıyor" crowd claim with the truthful
/// early-access framing — no invented users, no invented counts.
class _EarlyAccessStrip extends StatelessWidget {
  const _EarlyAccessStrip();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.rocket_launch_rounded,
          size: 16,
          color: AppColors.neon.withValues(alpha: 0.9),
        ),
        const SizedBox(width: 8),
        // Both labels are Flexible: the badge and its sub-line sit on
        // one centred row, and a longer language ran 433 px past the
        // right edge under pseudo-localisation.
        Flexible(
          child: Text(
            AppLocalizations.of(context).trainAnywhereBadge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.15,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '·',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            AppLocalizations.of(context).trainAnywhereSubline,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.neon.withValues(alpha: 0.35),
            border: Border.all(color: AppColors.neon, width: 1),
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 10,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
