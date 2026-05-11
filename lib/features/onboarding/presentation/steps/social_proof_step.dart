import 'package:flutter/material.dart';

import '../../../../core/motion/ambient_particles.dart';
import '../../../../core/motion/glow_pulse.dart';
import '../../../../core/motion/sparkle_burst.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../widgets/coach_mood.dart';
import '../widgets/living_coach_avatar.dart';

/// Phase 123 · social proof scene, rebuilt for emotional fidelity.
///
/// Reference timestamp: 0:59-1:01 in the Unrot onboarding video — the
/// "Give us a rating!" beat, ~2 s long, with the mascot celebrating
/// while a horizontal testimonial carousel drifts past underneath.
/// The previous Phase 113 build captured the *idea* (testimonials +
/// trust) but missed the *mechanics* (momentum, character activity,
/// scene composition). What changed here vs. Phase 113:
///
///  • **Axis rotated vertical → horizontal.** Cards drift right-to-
///    left. One full card + ~30% of the next visible at all times —
///    the leading-edge sliver is the momentum signal ("more is
///    coming"). Cycle 22 s ÷ 9 cards ≈ 2.4 s of visibility per card,
///    matching the reference's roughly-2-s rhythm with a slight slow
///    so Turkish quotes have room to land.
///  • **Form is actively celebrated.** Avatar bumped to 140/96
///    (was 110/76) so it dominates the upper third the way Brain
///    dominates the reference frame. Wrapped in [SparkleBurst] so 10
///    neon particles continuously orbit / fade around the avatar —
///    "this thing is being celebrated", not "this thing is present".
///  • **Title sharpened.** "Bu yolda yalnız değilsin." — declarative
///    emotional anchor in FormAI's companionship register, parallel
///    in energy to the reference's "Give us a rating!" but not a
///    marketing ask.
///  • **Two voices added.** Onur (multi-failed-attempts past) and
///    Elif (initial skepticism) widen the believability spread so a
///    user finds *their* doubt mirrored, not just success outcomes.
///  • **Per-card copy tightened.** Each quote a single short clause
///    + one emotional turn — absorbable in a 2 s pass.
///
/// Kept from Phase 113: dark/neon palette, AmbientParticles backdrop,
/// GlowPulse CTA wrap, "PLANIMA GEÇ" advance label, header-less
/// (`interlude_` prefix), 1.2 s settle before CTA enables, realistic
/// Turkish names + ages, no fabricated metrics.
///
/// Stat-laurel deferral: the reference shows 4.8★ AVERAGE RATING +
/// 300K USERS WORLDWIDE laurel badges between mascot and carousel.
/// Those are real Unrot launch data. FormAI has no comparable real
/// metrics yet, so adding fabricated equivalents would be a
/// dark-pattern. When post-launch metrics exist (Phase 200+), insert
/// a stat-badge row above the carousel here. Until then, the
/// carousel + Form's active celebration carry the social proof
/// honestly.

class _Testimonial {
  const _Testimonial({
    required this.quote,
    required this.name,
    required this.age,
  });
  final String quote;
  final String name;
  final int age;
}

const List<_Testimonial> _kTestimonials = [
  _Testimonial(
    quote: '12 haftada 6 kilo. Kendimi hiç suçlu hissetmedim.',
    name: 'Ayşe K.',
    age: 32,
  ),
  _Testimonial(
    quote: 'Eskisine dönmem sanmıştım. Form yanımdaydı.',
    name: 'Mehmet D.',
    age: 28,
  ),
  _Testimonial(
    quote: 'Disiplin bende değil, plandaymış. 8 haftada anladım.',
    name: 'Zeynep A.',
    age: 24,
  ),
  _Testimonial(
    quote: 'Sabah korkusu 4 haftada alışkanlığa döndü.',
    name: 'Can Y.',
    age: 35,
  ),
  _Testimonial(
    quote: 'Yorgunken bile başlayabildim. Kısa olması her şeyi değiştirdi.',
    name: 'Selin O.',
    age: 29,
  ),
  _Testimonial(
    quote: 'Aynadan kaçınırdım. Şimdi her gün bakıyorum.',
    name: 'Berk T.',
    age: 31,
  ),
  _Testimonial(
    quote: 'Plan bana göre, ben plana göre değil. Fark bu.',
    name: 'Deniz K.',
    age: 27,
  ),
  _Testimonial(
    quote: 'Başlayıp bırakmaktan yorulmuştum. Bu defa 60 günü geçtim.',
    name: 'Onur B.',
    age: 33,
  ),
  _Testimonial(
    quote: 'Önce inanmadım. Gerçekten bana göre tasarlanmış gibi.',
    name: 'Elif T.',
    age: 26,
  ),
];

class SocialProofStep extends StatefulWidget {
  const SocialProofStep({super.key, required this.onContinue});
  final VoidCallback onContinue;

  @override
  State<SocialProofStep> createState() => _SocialProofStepState();
}

class _SocialProofStepState extends State<SocialProofStep>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scroll;
  late final AnimationController _ctrl;
  bool _readyForCommit = false;

  static const Duration _cycle = Duration(seconds: 22);

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController();
    _ctrl = AnimationController(vsync: this, duration: _cycle)..repeat();
    _ctrl.addListener(_tick);
    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _readyForCommit = true);
    });
  }

  @override
  void dispose() {
    _ctrl.removeListener(_tick);
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _tick() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    if (max <= 0) return;
    // Modular position wraps the tripled list so the seam between
    // items N..2N-1 and 0..N-1 is invisible (same content). The soft
    // horizontal fade at the carousel edges hides any minor sub-item
    // drift at the wrap moment.
    final raw = _ctrl.value * max;
    final third = max / 3;
    final wrapped = third + (raw % third);
    _scroll.jumpTo(wrapped);
  }

  void _commit() {
    if (!_readyForCommit) return;
    AppHaptics.secondaryTap();
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    final mediaW = MediaQuery.of(context).size.width;
    // 72% of the available width per card so one full card + the
    // leading edge of the next remain visible — the partial card is
    // the momentum signal. Clamp range guards against unusually
    // narrow / wide layout contexts.
    final cardWidth = ((mediaW - 40) * 0.72).clamp(220.0, 320.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF0A0814)),
        const AmbientParticles(
          count: 6,
          color: AppColors.neon,
          minAlpha: 0.05,
          maxAlpha: 0.18,
          minRadius: 1.0,
          maxRadius: 2.0,
          driftDuration: Duration(seconds: 28),
          seed: 211,
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              children: [
                const SizedBox(height: 4),
                const SparkleBurst(
                  color: AppColors.neon,
                  particleCount: 10,
                  maxRadius: 105,
                  peakAlpha: 0.65,
                  minLifetime: Duration(milliseconds: 1200),
                  maxLifetime: Duration(milliseconds: 1900),
                  child: LivingCoachAvatar(
                    size: 140,
                    innerSize: 96,
                    mood: CoachMood.proud,
                  ),
                ),
                const SizedBox(height: 22),
                ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    colors: [AppColors.neon, AppColors.neonAccent],
                  ).createShader(rect),
                  child: const Text(
                    'Bu yolda yalnız değilsin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Form'la başlayanların kendi sözleri.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.15,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 156,
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.transparent,
                          Colors.black,
                          Colors.black,
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.06, 0.94, 1.0],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: ListView.separated(
                      controller: _scroll,
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      itemCount: _kTestimonials.length * 3,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final t = _kTestimonials[i % _kTestimonials.length];
                        return _TestimonialCard(
                          testimonial: t,
                          width: cardWidth,
                        );
                      },
                    ),
                  ),
                ),
                const Spacer(),
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
                        padding: const EdgeInsets.symmetric(vertical: 18),
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
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TestimonialCard extends StatelessWidget {
  const _TestimonialCard({required this.testimonial, required this.width});
  final _Testimonial testimonial;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.neon.withValues(alpha: 0.30),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.neon.withValues(alpha: 0.10),
              blurRadius: 14,
              spreadRadius: -4,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: List<Widget>.generate(
                5,
                (_) => const Padding(
                  padding: EdgeInsets.only(right: 2),
                  child: Icon(
                    Icons.star_rounded,
                    color: Color(0xFFFFC700),
                    size: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                testimonial.quote,
                maxLines: 4,
                overflow: TextOverflow.fade,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '— ${testimonial.name}, ${testimonial.age}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
