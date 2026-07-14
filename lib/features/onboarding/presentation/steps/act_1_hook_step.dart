import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/motion/breathing_box.dart';
import '../../../../core/motion/glow_pulse.dart';
import '../../../../core/motion/motion_tokens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../core/utils/legal_urls.dart';

/// Act 1 · Emotional hook.
///
/// The very first surface a user sees on a cold launch into onboarding.
/// Stays composed of the same elements as before — full-bleed photo,
/// gradient title, subtitle, CTA, legal line — but layers in cinematic
/// atmosphere:
///
///   • A 16-second background parallax (gentle vertical translate +
///     scale, easeInOutCubic). Imperceptible per-frame; the screen
///     feels "alive" without anyone being able to point at the motion.
///   • Title wrapped in [BreathingBox] (0.92 → 1.0, 4.2 s) once the
///     entrance settles. Reads as "the brand is breathing", not
///     "something is fading."
///   • CTA wrapped in [GlowPulse] (alpha 0.45 → 0.70, blur 24 → 36
///     over 3 s) once the entrance settles. Says "I'm waiting for
///     you" without competing for attention.
///
/// Ambient effects gate on `_entranceDone` so the entrance timing isn't
/// muddied by overlapping pulses. After the title settles, the screen
/// shifts from "introducing itself" to "waiting for the user."

class WelcomeStep extends StatefulWidget {
  const WelcomeStep({super.key, required this.onStart});
  final VoidCallback onStart;

  @override
  State<WelcomeStep> createState() => _WelcomeStepState();
}

class _WelcomeStepState extends State<WelcomeStep>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _subtitleFade;
  late final Animation<Offset> _subtitleSlide;
  late final Animation<double> _ctaFade;
  late final Animation<Offset> _ctaSlide;

  /// Slow vertical pan of the background hero — 16 s up + 16 s down.
  /// Imperceptible per-frame; the user feels the screen breathing
  /// without consciously noticing why.
  late final AnimationController _bgPan;

  /// Flips true when the entrance choreography settles. Gates the
  /// ambient breathing/glow so they don't compete with the entrance.
  bool _entranceDone = false;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    _intro.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _entranceDone = true);
      }
    });

    _bgPan = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat(reverse: true);

    Animation<double> fade(double a, double b) => CurvedAnimation(
          parent: _intro,
          curve: Interval(a, b, curve: MotionTokens.enterEase),
        );
    Animation<Offset> slide(double a, double b) =>
        Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _intro,
            curve: Interval(a, b, curve: MotionTokens.enterEase),
          ),
        );

    _titleFade = fade(0.0, 0.55);
    _titleSlide = slide(0.0, 0.55);
    _subtitleFade = fade(0.2, 0.75);
    _subtitleSlide = slide(0.2, 0.75);
    _ctaFade = fade(0.45, 1.0);
    _ctaSlide = slide(0.45, 1.0);
  }

  @override
  void dispose() {
    _intro.dispose();
    _bgPan.dispose();
    super.dispose();
  }

  Widget _appear({
    required Animation<double> fade,
    required Animation<Offset> slide,
    required Widget child,
  }) {
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background hero with slow ambient parallax. Translates up to
        // 10 px and scales 1.04 → 1.065 over the 16 s loop. The
        // RepaintBoundary keeps the rest of the screen from re-painting
        // when only the background transforms.
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _bgPan,
            builder: (context, child) {
              final t = MotionTokens.reassuranceEase.transform(_bgPan.value);
              return Transform.translate(
                offset: Offset(0, -10.0 * t),
                child: Transform.scale(
                  scale: 1.04 + (0.025 * t),
                  alignment: Alignment.center,
                  child: child,
                ),
              );
            },
            // RC-1 P6 · the background was the SQUARE app-icon artwork
            // (photos/APP_ICON.png) center-cropped by BoxFit.cover — on a
            // 9:19.5 phone that amputated both sides and misplaced the
            // composition. Replaced with the portrait hero from the design
            // reference (First_opening.png, imagery-only crop — title/CTA
            // stay native Flutter below), anchored topCenter so the FormAI
            // logo + robot stay framed while cover absorbs every aspect
            // ratio without gaps or distortion.
            child: Image.asset(
              'photos/onboarding_hero_start.webp',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, __, ___) => const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.4,
                    colors: [Color(0xFF1A0B3D), Colors.black],
                  ),
                ),
              ),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.5),
                Colors.black.withValues(alpha: 0.95),
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
            child: Column(
              children: [
                const Spacer(flex: 3),
                _appear(
                  fade: _titleFade,
                  slide: _titleSlide,
                  child: BreathingBox(
                    enabled: _entranceDone,
                    minAlpha: 0.92,
                    maxAlpha: 1.0,
                    duration: const Duration(milliseconds: 4200),
                    child: ShaderMask(
                      shaderCallback: (rect) => const LinearGradient(
                        colors: [AppColors.neon, AppColors.neonAccent],
                      ).createShader(rect),
                      child: const Text(
                        'Vücudunu Yapay Zeka ile Şekillendir',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          height: 1.12,
                          letterSpacing: 0.4,
                          shadows: [
                            Shadow(blurRadius: 24, color: Colors.black87),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _appear(
                  fade: _subtitleFade,
                  slide: _subtitleSlide,
                  child: const Text(
                    '12 hafta · 4 antrenman/hafta · AI ile kalibre. '
                    'Sana özel bir yol haritası.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      height: 1.5,
                      shadows: [Shadow(blurRadius: 18, color: Colors.black87)],
                    ),
                  ),
                ),
                const Spacer(flex: 2),
                _appear(
                  fade: _ctaFade,
                  slide: _ctaSlide,
                  child: GlowPulse(
                    enabled: _entranceDone,
                    color: AppColors.neon,
                    minAlpha: 0.45,
                    maxAlpha: 0.70,
                    minBlur: 24,
                    maxBlur: 36,
                    spread: 1,
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(20),
                    duration: const Duration(milliseconds: 3000),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          AppHaptics.secondaryTap();
                          widget.onStart();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.neon,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 22),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                            fontSize: 18,
                          ),
                        ),
                        child: const Text('BAŞLA'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _appear(
                  fade: _ctaFade,
                  slide: _ctaSlide,
                  child: const _WelcomeLegalLine(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WelcomeLegalLine extends StatefulWidget {
  const _WelcomeLegalLine();

  @override
  State<_WelcomeLegalLine> createState() => _WelcomeLegalLineState();
}

class _WelcomeLegalLineState extends State<_WelcomeLegalLine> {
  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()
      ..onTap = () => openLegalUrl(LegalUrls.terms);
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => openLegalUrl(LegalUrls.privacy);
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const baseStyle = TextStyle(
      color: Colors.white70,
      fontSize: 11,
      shadows: [Shadow(blurRadius: 12, color: Colors.black)],
    );
    final linkStyle = baseStyle.copyWith(
      color: const Color(0xFF00F0FF),
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: const Color(0xFF00F0FF).withValues(alpha: 0.8),
    );
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          const TextSpan(text: 'Devam ederek '),
          TextSpan(
            text: 'Kullanım Şartları',
            style: linkStyle,
            recognizer: _termsTap,
          ),
          const TextSpan(text: ' ve '),
          TextSpan(
            text: 'Gizlilik Politikası',
            style: linkStyle,
            recognizer: _privacyTap,
          ),
          const TextSpan(text: '’nı kabul edersin.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
