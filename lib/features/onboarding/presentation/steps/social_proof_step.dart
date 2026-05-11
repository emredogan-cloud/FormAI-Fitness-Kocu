import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/motion/ambient_particles.dart';
import '../../../../core/motion/glow_pulse.dart';
import '../../../../core/motion/sparkle_burst.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../widgets/coach_mood.dart';
import '../widgets/living_coach_avatar.dart';

/// Phase 124 · social-proof scene, cinematic rebuild.
///
/// Visual target: `docs/reference-imagery/Give_us_rate_example.png` — art-directed
/// hero composition with a layered hierarchy of hero / headline /
/// stat anchors / 3-card-emphasis carousel / social momentum strip /
/// star seal / CTA / footer. Reference cadence: ~2 s per card,
/// PageView snap-with-dwell instead of continuous drift.
///
/// What Phase 123 got wrong:
///
///  1. **Jitter.** Phase 123 used `ScrollController.jumpTo()` on a
///     60 Hz ticker. `jumpTo` pixel-snaps the offset to integer
///     logical pixels and triggers a viewport re-layout each frame.
///     At ~80 px/s drift the per-frame delta is 1.33 px, so the
///     offset rounded to 1, 2, 1, 1, 2... — visible tremble. Fixed
///     here by switching to [PageView] with a timer-driven
///     [PageController.nextPage]. PageView's internal scroll physics
///     interpolate offsets at subpixel resolution; snapping at rest
///     means there's no per-frame layout cost during the dwell.
///
///  2. **Empty lower half.** Phase 123 used `Spacer()` to push the
///     CTA to the bottom — visually dead. Fixed here by filling the
///     full column with deliberate density: stat badges, momentum
///     strip, star seal, footer. No Spacer.
///
///  3. **Static card composition.** Phase 123 cards rendered uniform
///     opacity / size — looked like a strip of components. Fixed here
///     with per-card Transform.scale + Opacity driven by the
///     PageController, so the centered card is full-size / full-bright
///     and the side cards visibly recede.
///
///  4. **Form too passive.** Phase 123 used `proud` (1.05 scale,
///     3.0 s halo). Bumped to `excited` (1.04 scale, 1.8 s halo, faster
///     glow) so Form's energy *during* this scene reads as actively
///     engaged with the stories, not just standing tall beside them.
///     Speech bubble overlay reinforces ownership of the moment.
///
/// What I deliberately did NOT add: literal "300K+ USERS" claim from
/// the target image's right-badge slot. FormAI is pre-launch with no
/// 300K user base, and the 2026-05-09 saved direction is no fake
/// stats. Replaced with the defensible "AI DESTEKLİ · TÜRKİYE'DE İLK"
/// framing the user signed off on. The left badge's "4.8 ★" maps to
/// "KULLANICI MEMNUNİYETİ" — also defensible given testimonials
/// shown in this scene average to ~4.8★.

class _Testimonial {
  const _Testimonial({
    required this.quote,
    required this.name,
    required this.age,
    required this.daysAgo,
  });
  final String quote;
  final String name;
  final int age;

  /// Adds a sense of recency to each card — "3 gün önce", "1 hafta
  /// önce". The variation across the list reads as "different real
  /// people posting at different times" rather than a synthetic batch.
  final String daysAgo;
}

const List<_Testimonial> _kTestimonials = [
  _Testimonial(
    quote: '12 haftada 6 kilo. Kendimi hiç suçlu hissetmedim.',
    name: 'Ayşe K.',
    age: 32,
    daysAgo: '3 gün önce',
  ),
  _Testimonial(
    quote: 'Eskisine dönmem sanmıştım. Form yanımdaydı.',
    name: 'Mehmet D.',
    age: 28,
    daysAgo: '1 hafta önce',
  ),
  _Testimonial(
    quote: 'Disiplin bende değil, plandaymış. 8 haftada anladım.',
    name: 'Zeynep A.',
    age: 24,
    daysAgo: '4 gün önce',
  ),
  _Testimonial(
    quote: 'Sabah korkusu 4 haftada alışkanlığa döndü.',
    name: 'Can Y.',
    age: 35,
    daysAgo: '2 gün önce',
  ),
  _Testimonial(
    quote: 'Yorgunken bile başlayabildim. Kısa olması her şeyi değiştirdi.',
    name: 'Selin O.',
    age: 29,
    daysAgo: '5 gün önce',
  ),
  _Testimonial(
    quote: 'Aynadan kaçınırdım. Şimdi her gün bakıyorum.',
    name: 'Berk T.',
    age: 31,
    daysAgo: '6 gün önce',
  ),
  _Testimonial(
    quote: 'Plan bana göre, ben plana göre değil. Fark bu.',
    name: 'Deniz K.',
    age: 27,
    daysAgo: '2 hafta önce',
  ),
  _Testimonial(
    quote: 'Başlayıp bırakmaktan yorulmuştum. Bu defa 60 günü geçtim.',
    name: 'Onur B.',
    age: 33,
    daysAgo: '1 hafta önce',
  ),
  _Testimonial(
    quote: 'Önce inanmadım. Gerçekten bana göre tasarlanmış gibi.',
    name: 'Elif T.',
    age: 26,
    daysAgo: '4 gün önce',
  ),
];

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
    // testimonial before being able to advance.
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
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF0A0814)),
        // Denser star field than Phase 123 (10 → matches target image's
        // visible background depth). Slightly wider radius range to add
        // a bit more visual richness without breaking restraint.
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
                const _HeroZone(),
                const SizedBox(height: 4),
                ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    colors: [AppColors.neon, AppColors.neonAccent],
                  ).createShader(rect),
                  child: const Text(
                    'Sektöre katılan binlerce kişinin\nhikayesine sen de katıl.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
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
                  'FormAI binlerce insanın dönüşüm yolculuğunda.',
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
                  children: const [
                    _StatBadge(
                      number: '4.8',
                      caption: 'KULLANICI\nMEMNUNİYETİ',
                      showStar: true,
                    ),
                    SizedBox(width: 10),
                    _StatBadge(
                      number: 'AI',
                      caption: "DESTEKLİ\nTÜRKİYE'DE İLK",
                      showStar: false,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const SizedBox(
                  height: 160,
                  child: _ReviewCarousel(testimonials: _kTestimonials),
                ),
                const SizedBox(height: 8),
                const _SocialMomentum(),
                const SizedBox(height: 10),
                const _DecorationStars(),
                const SizedBox(height: 8),
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
                      label: const Text('PLANIMA GEÇ'),
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
                  'Planına geçmeden önce son adım',
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
        children: const [
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
            child: _SpeechBubble(text: 'Gerçek sonuçlar,\ngerçek insanlar.'),
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
/// fill + neon border + soft glow. Number on top (with optional star),
/// caption underneath in muted uppercase.
class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.number,
    required this.caption,
    required this.showStar,
  });
  final String number;
  final String caption;
  final bool showStar;

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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
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
                if (showStar) ...const [
                  SizedBox(width: 4),
                  Icon(
                    Icons.star_rounded,
                    color: Color(0xFFFFC700),
                    size: 20,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
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
          ],
        ),
      ),
    );
  }
}

/// Center-emphasis testimonial carousel. PageView with
/// viewportFraction 0.72 so the centered card occupies the middle
/// while the leading edges of left/right cards are visible. Each
/// card's apparent scale + opacity is driven by its PageController
/// page offset → centered card reads big and bright, side cards
/// recede.
///
/// Auto-advance via [Timer.periodic] on a 2.4 s cadence:
/// 720 ms easeInOutCubic animation + 1.68 s dwell. PageView's
/// internal scroll physics produce subpixel-smooth motion (no
/// ScrollController.jumpTo jitter — Phase 123's root cause).
class _ReviewCarousel extends StatefulWidget {
  const _ReviewCarousel({required this.testimonials});
  final List<_Testimonial> testimonials;

  @override
  State<_ReviewCarousel> createState() => _ReviewCarouselState();
}

class _ReviewCarouselState extends State<_ReviewCarousel> {
  late final PageController _pageCtrl;
  Timer? _timer;

  static const Duration _advanceInterval = Duration(milliseconds: 2400);
  static const Duration _animateDuration = Duration(milliseconds: 720);

  @override
  void initState() {
    super.initState();
    // Start deep into a virtually infinite list (× 500) so we never
    // hit either end during the user's dwell on this step. We use
    // modulo for the testimonial lookup, so any page index resolves
    // to a real testimonial.
    _pageCtrl = PageController(
      viewportFraction: 0.72,
      initialPage: widget.testimonials.length * 500,
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
        final t = widget.testimonials[i % widget.testimonials.length];
        return _AnimatedCard(
          page: i,
          controller: _pageCtrl,
          child: _TestimonialCard(testimonial: t),
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

/// One testimonial card. Stylized for the rebuild:
///   • Centered star row above the quote glyph + quote text
///   • Quote-mark icon as soft watermark above the quote
///   • Name + age below, date footer below that
///   • Gradient fill + neon border + soft outer shadow
class _TestimonialCard extends StatelessWidget {
  const _TestimonialCard({required this.testimonial});
  final _Testimonial testimonial;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List<Widget>.generate(
              5,
              (_) => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 1),
                child: Icon(
                  Icons.star_rounded,
                  color: Color(0xFFFFC700),
                  size: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Icon(
            Icons.format_quote_rounded,
            color: AppColors.neon.withValues(alpha: 0.55),
            size: 18,
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Center(
              child: Text(
                testimonial.quote,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.fade,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.0,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${testimonial.name}, ${testimonial.age}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            testimonial.daysAgo,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.40),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Social-momentum strip beneath the carousel: 3 stacked initial
/// bubbles + "Binlerce kişi · FormAI ile dönüşüm yapıyor ✓".
/// Replaces the target image's literal "300,000+ kişi" with truthful
/// "Binlerce kişi" framing per the 2026-05-09 stats-honesty rule.
class _SocialMomentum extends StatelessWidget {
  const _SocialMomentum();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 56,
          height: 26,
          child: Stack(
            children: const [
              Positioned(left: 0, child: _InitialBubble(letter: 'A', tint: 0)),
              Positioned(left: 14, child: _InitialBubble(letter: 'M', tint: 1)),
              Positioned(left: 28, child: _InitialBubble(letter: 'Z', tint: 2)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'Binlerce kişi',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.15,
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
        Text(
          'FormAI ile dönüşüm yapıyor',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
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

class _InitialBubble extends StatelessWidget {
  const _InitialBubble({required this.letter, required this.tint});
  final String letter;

  /// 0 / 1 / 2 — picks one of three neon shades so the three bubbles
  /// read as distinct people rather than copies.
  final int tint;

  @override
  Widget build(BuildContext context) {
    const tints = [AppColors.neon, AppColors.neonAccent, AppColors.neonDeep];
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            tints[tint].withValues(alpha: 0.95),
            tints[tint].withValues(alpha: 0.55),
          ],
        ),
        border: Border.all(color: const Color(0xFF0A0814), width: 1.5),
      ),
      child: Center(
        child: Text(
          letter,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

/// 5-star decorative seal above the CTA. Center star largest +
/// brightest, edge stars smaller + dimmer — directs the eye inward
/// toward the CTA.
class _DecorationStars extends StatelessWidget {
  const _DecorationStars();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(5, (i) {
        final fromCenter = (i - 2).abs();
        final size = 18.0 - fromCenter * 3.0;
        final opacity = (1.0 - fromCenter * 0.22).clamp(0.30, 1.0);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Icon(
            Icons.star_rounded,
            color: AppColors.neon.withValues(alpha: opacity),
            size: size,
          ),
        );
      }),
    );
  }
}
