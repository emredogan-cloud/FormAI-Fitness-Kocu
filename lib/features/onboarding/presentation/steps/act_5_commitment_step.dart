import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/motion/ambient_particles.dart';
import '../../../../core/motion/breathing_box.dart';
import '../../../../core/motion/glow_pulse.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../core/utils/text_span_split.dart';
import '../../../../l10n/app_localizations.dart';

/// Act 5 · Commitment.
///
/// The user has just read their personalised report. This screen is
/// the *commitment moment* — not the billing moment. The CTA carries
/// "begin the journey" framing rather than "view a plan." Trust the
/// dense plan card to do the convincing; cinematic motion stays
/// deliberately subtle here so the eye can read.
///
/// Cinematic atmosphere (Phase 101):
///   • Low-density [AmbientParticles] (4 motes, 30s drift, alpha
///     0.04→0.15) behind the entire scene — barely perceptible, but
///     keeps the screen from feeling static.
///   • Plan card wrapped in [BreathingBox] (0.96→1.0 over 6 s) once
///     the entrance settles. Reads as "the plan is alive, waiting."
///   • Coach panel inside the plan card carries its own [GlowPulse]
///     so Form's presence stays consistent with Act 2 — cross-scene
///     identity continuity.
///   • Trust-booster confidence bar uses easeOutBack on its fill so
///     the % lands with a slight overshoot (matches the dynamic-
///     report's confidence pattern).
///   • CTA wrapped in [GlowPulse] gated on `_trustLanded` so the
///     pulse only ambients after the % has finished landing.
///
/// Copy reframe: "PLANIMI GÖR" → "YOLCULUĞA BAŞLA". Audit §3.9 flagged
/// the original as bait-and-switch (user thinks they're seeing a plan,
/// they actually land on a paywall). The new label commits to a
/// journey, doesn't promise the plan is about to render. Subtitle
/// "paketi" → "yolculuğunu" carries the same reframe.

class PrePaywallSummaryStep extends ConsumerStatefulWidget {
  const PrePaywallSummaryStep({super.key, required this.onComplete});
  final VoidCallback onComplete;

  @override
  ConsumerState<PrePaywallSummaryStep> createState() =>
      _PrePaywallSummaryStepState();
}

class _PrePaywallSummaryStepState extends ConsumerState<PrePaywallSummaryStep>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final Animation<double> _cardFade;
  late final Animation<Offset> _cardSlide;

  late final AnimationController _trustCtrl;

  /// Flips when the entrance fades complete; gates the plan card's
  /// ambient breathing so the breath doesn't compete with the
  /// entrance choreography.
  bool _entranceDone = false;

  /// Flips when the CTA-pacing controller lands. Gates the CTA's ambient
  /// GlowPulse so the pulse waits its turn.
  bool _trustLanded = false;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _cardFade = CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic);
    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic));
    _intro.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted && !_entranceDone) {
        setState(() => _entranceDone = true);
      }
    });

    // RC-1 P10/P11 · the trust bar is gone (the %92 confidence already
    // landed on the report screen); the controller now only paces the
    // CTA's glow so the button "wakes up" a beat after the content.
    _trustCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _trustCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted && !_trustLanded) {
        setState(() => _trustLanded = true);
        // Soft confirmation — the plan is "approved" and the user
        // is now invited to begin.
        AppHaptics.success();
      }
    });
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _trustCtrl.forward();
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _trustCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Lowest-density ambient layer in the wizard — the screen
          // is content-dense, motion stays at the threshold of
          // perception. 4 motes, 30s drift.
          const AmbientParticles(
            count: 4,
            color: AppColors.neon,
            minAlpha: 0.04,
            maxAlpha: 0.15,
            minRadius: 1.0,
            maxRadius: 1.8,
            driftDuration: Duration(seconds: 30),
            seed: 121,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              children: [
                Expanded(
                  child: FadeTransition(
                    opacity: _cardFade,
                    child: SlideTransition(
                      position: _cardSlide,
                      child: SingleChildScrollView(
                        // RC-1 P10/P11 · rebuilt per photos/planıma_geç.png:
                        // Form hero + speech bubble, the form-coach promise
                        // headline, honest capability cards, voice-coaching
                        // card, benefit icon row, early-access line. The
                        // plan-summary card moved OUT — the report screen
                        // immediately before this one already presents the
                        // plan data; repeating it here dulled the close.
                        child: Column(
                          children: [
                            const _FormHeroWithBubble(),
                            const SizedBox(height: 16),
                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  height: 1.22,
                                  letterSpacing: 0.3,
                                ),
                                children: splitHighlighted(
                                  l10n.act5Headline(
                                    l10n.act5HeadlineHighlight,
                                  ),
                                  l10n.act5HeadlineHighlight,
                                  TextStyle(
                                    foreground: Paint()
                                      ..shader = const LinearGradient(
                                        colors: [
                                          AppColors.neon,
                                          AppColors.neonAccent,
                                        ],
                                      ).createShader(
                                        const Rect.fromLTWH(0, 0, 220, 40),
                                      ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.earlyAccessBlurb,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: _StatMiniCard(
                                    icon: Icons.monitor_heart_outlined,
                                    big: '130+',
                                    line1: l10n.act5StatExercises,
                                    line2: l10n.liveFormAnalysisEyebrow,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _StatMiniCard(
                                    icon: Icons.memory_rounded,
                                    big: 'AI',
                                    line1: l10n.act5StatAiPowered,
                                    line2: l10n.act5StatOnDevice,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const _VoiceCoachCard(),
                            const SizedBox(height: 14),
                            const _BenefitIconRow(),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.rocket_launch_rounded,
                                    color: AppColors.neon, size: 15),
                                const SizedBox(width: 6),
                                // Same reason as the report card's AI
                                // pill: a centred Row gives its Text no
                                // room to wrap, so a longer language
                                // overflows rather than reflows.
                                Flexible(
                                  child: Text(
                                    l10n.earlyAccessBadge,
                                    style: const TextStyle(
                                      color: AppColors.neon,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const Text(
                                  '  ·  ',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    l10n.earlyAccessSubline,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                GlowPulse(
                  enabled: _trustLanded,
                  color: AppColors.neon,
                  minAlpha: 0.42,
                  maxAlpha: 0.68,
                  minBlur: 24,
                  maxBlur: 34,
                  spread: 1,
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(18),
                  duration: const Duration(milliseconds: 2900),
                  // Reference CTA: full-width pill, circled arrow left,
                  // 'PLANIMA GEÇ' centered.
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.neon.withValues(alpha: 0.28),
                            AppColors.neon.withValues(alpha: 0.14),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.neon.withValues(alpha: 0.8),
                          width: 1.4,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () {
                          AppHaptics.secondaryTap();
                          widget.onComplete();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.neon.withValues(alpha: 0.35),
                                  border: Border.all(
                                    color:
                                        AppColors.neon.withValues(alpha: 0.9),
                                  ),
                                ),
                                child: const Icon(Icons.arrow_forward_rounded,
                                    color: Colors.white, size: 22),
                              ),
                              Expanded(
                                child: Text(
                                  l10n.commitCta,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 3,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 46),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.commitLastStep,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// RC-1 P11 · Form portrait in a glow ring with a floating speech bubble
/// ('Her tekrarında yanındayım.') anchored top-right — the reference's hero.
class _FormHeroWithBubble extends StatelessWidget {
  const _FormHeroWithBubble();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 128,
            height: 128,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.neon.withValues(alpha: 0.75),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.neon.withValues(alpha: 0.45),
                  blurRadius: 34,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'photos/PT_FORM.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.smart_toy,
                    color: AppColors.neon, size: 48),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF17102B),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                  bottomLeft: Radius.circular(4),
                ),
                border: Border.all(
                  color: AppColors.neon.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt_rounded, color: AppColors.neon, size: 14),
                  SizedBox(width: 4),
                  Text(
                    AppLocalizations.of(context).act5HeroBubble,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
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

/// Small honest-capability card (130+ exercises / on-device AI).
class _StatMiniCard extends StatelessWidget {
  const _StatMiniCard({
    required this.icon,
    required this.big,
    required this.line1,
    required this.line2,
  });

  final IconData icon;
  final String big;
  final String line1;
  final String line2;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.neon.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: AppColors.neon.withValues(alpha: 0.16),
            blurRadius: 18,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.neonAccent, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    colors: [AppColors.neon, AppColors.neonAccent],
                  ).createShader(rect),
                  child: Text(
                    big,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  line1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  line2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 'SESLİ FORM KOÇLUĞU' card — copy left, glowing mic badge right.
class _VoiceCoachCard extends StatelessWidget {
  const _VoiceCoachCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.neon.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: AppColors.neon.withValues(alpha: 0.16),
            blurRadius: 18,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                    children: splitHighlighted(
                      l10n.act5VoiceCoachTitle(l10n.act5VoiceCoachHighlight),
                      l10n.act5VoiceCoachHighlight,
                      const TextStyle(color: AppColors.neon),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.act5VoiceCoachBody,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.neon.withValues(alpha: 0.12),
              border: Border.all(
                color: AppColors.neonAccent.withValues(alpha: 0.8),
                width: 1.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.neonAccent.withValues(alpha: 0.35),
                  blurRadius: 18,
                ),
              ],
            ),
            child: const Icon(Icons.mic_rounded, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }
}

/// Four-benefit icon row from the reference (goal · live progress ·
/// motivation · data safety).
class _BenefitIconRow extends StatelessWidget {
  const _BenefitIconRow();

  static List<(IconData, String)> _itemsFor(AppLocalizations l10n) => [
        (Icons.track_changes_rounded, l10n.act5BenefitGoals),
        (Icons.bar_chart_rounded, l10n.act5BenefitProgress),
        (Icons.military_tech_rounded, l10n.act5BenefitMotivation),
        (Icons.shield_outlined, l10n.act5BenefitPrivacy),
      ];

  @override
  Widget build(BuildContext context) {
    final items = _itemsFor(AppLocalizations.of(context));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            Expanded(
              child: Column(
                children: [
                  Icon(items[i].$1, color: AppColors.neonAccent, size: 22),
                  const SizedBox(height: 6),
                  Text(
                    items[i].$2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 9.5,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
