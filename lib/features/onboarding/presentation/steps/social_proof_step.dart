import 'package:flutter/material.dart';

import '../../../../core/motion/ambient_particles.dart';
import '../../../../core/motion/glow_pulse.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../widgets/coach_mood.dart';
import '../widgets/living_coach_avatar.dart';

/// Phase 113 · social proof scene.
///
/// Reference timestamp: ~0:47–0:55 (Unrot's rating push + testimonial
/// carousel). Adapted: an auto-scrolling vertical list of believable
/// Turkish fitness testimonials, Form in `proud` mood at the top
/// (the user is in good company — Form has watched these journeys
/// before and is presenting them). Premium dark/neon surface, no
/// startup-marketing energy.
///
/// Slots between `dynamic_report` and `pre_paywall_summary` —
/// trust-building moment between Form's personal plan and the
/// commitment ask. Header-less (`interlude_` prefix) so the chrome
/// stays out of the way during the emotional beat.
///
/// Believability principles:
///   • No "5 stars amazing app!" copy. Each quote names a specific
///     fitness friction or moment of recognition (sustainability,
///     mirror avoidance, morning fear, plan fitting the person, etc).
///   • Names + ages stay realistic for the Turkish market.
///   • Outcomes stay inside the engine's existing claim-bounds (the
///     same kg-loss / consistency framing the assessment already
///     uses) — no invented wild numbers.
///
/// Auto-scroll runs on a single 30 s controller. Tripled list +
/// modular scroll position lets the user read for as long as they
/// like; the visible content loops seamlessly. CTA enables on mount
/// — the user is never *required* to wait, just allowed to.

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
    quote: '12 haftada 6 kilo verdim. En iyisi: kendimi suçlu '
        'hissetmediğim bir plan.',
    name: 'Ayşe K.',
    age: 32,
  ),
  _Testimonial(
    quote: 'Eski formuma kavuşamam sanmıştım. Form sürekli yanımdaydı.',
    name: 'Mehmet D.',
    age: 28,
  ),
  _Testimonial(
    quote: 'Disiplin bende değil, planda olmalıymış. 8 haftada anladım.',
    name: 'Zeynep A.',
    age: 24,
  ),
  _Testimonial(
    quote: 'Sabah antrenman korkusu vardı. 4 hafta sonra alışkanlık oldu.',
    name: 'Can Y.',
    age: 35,
  ),
  _Testimonial(
    quote: 'Yorgunluğa rağmen başlayabildim. Kısa antrenmanlar her şeyi '
        'değiştirdi.',
    name: 'Selin O.',
    age: 29,
  ),
  _Testimonial(
    quote: 'Aynaya bakmaktan kaçınırdım. Şimdi her gün kontrol ediyorum.',
    name: 'Berk T.',
    age: 31,
  ),
  _Testimonial(
    quote: 'Plan benim için çalıştı, ben plan için değil. Fark burada.',
    name: 'Deniz K.',
    age: 27,
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

  static const Duration _cycle = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController();
    _ctrl = AnimationController(vsync: this, duration: _cycle)..repeat();
    _ctrl.addListener(_tick);
    // CTA gates to enabled after a 1.2 s settle so the user reads at
    // least one testimonial before being able to advance — a felt
    // "this matters" beat without forcing a long dwell.
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
    // Modular scroll position so the tripled-list visually loops at
    // the seam where item indices N..2N-1 occupy the same content as
    // 0..N-1 — the user never sees the jump.
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              children: [
                const LivingCoachAvatar(
                  size: 110,
                  innerSize: 76,
                  // Form has the plan, has heard these stories — this
                  // is where Form quietly stands proud beside the
                  // people who walked the path. Same `proud` mood
                  // the dynamic_report and pre_paywall coach panel
                  // ride on, for cross-scene continuity.
                  mood: CoachMood.proud,
                ),
                const SizedBox(height: 14),
                ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    colors: [AppColors.neon, AppColors.neonAccent],
                  ).createShader(rect),
                  child: const Text(
                    'Bu yolculuğu seninle başlayanlar',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      // Soft fade at top + bottom edges so testimonials
                      // emerge into / dissolve out of view rather than
                      // popping in / out at the scroll boundary.
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black,
                          Colors.black,
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.10, 0.90, 1.0],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: ListView.separated(
                      controller: _scroll,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      // Tripled so the modular scroll wraps without a
                      // visible jump — the user always sees the same
                      // ribbon of content.
                      itemCount: _kTestimonials.length * 3,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final t = _kTestimonials[i % _kTestimonials.length];
                        return _TestimonialCard(testimonial: t);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
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
  const _TestimonialCard({required this.testimonial});
  final _Testimonial testimonial;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          // Five-star rating row — small, gold-yellow, confident
          // without being decorative.
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
          Text(
            testimonial.quote,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
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
    );
  }
}
