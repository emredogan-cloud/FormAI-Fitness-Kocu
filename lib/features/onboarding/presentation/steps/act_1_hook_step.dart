import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../core/utils/legal_urls.dart';

/// Act 1 · Emotional hook.
///
/// Immersive welcome screen — full-bleed photo background, neon-gradient
/// title, staggered subtitle + CTA + legal line. The very first surface
/// the user sees on a cold launch into onboarding. Stays static now;
/// motion-primitive upgrades land in the follow-up cinematic pass.

class WelcomeStep extends StatefulWidget {
  const WelcomeStep({super.key, required this.onStart});
  final VoidCallback onStart;

  @override
  State<WelcomeStep> createState() => _WelcomeStepState();
}

class _WelcomeStepState extends State<WelcomeStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _subtitleFade;
  late final Animation<Offset> _subtitleSlide;
  late final Animation<double> _ctaFade;
  late final Animation<Offset> _ctaSlide;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();

    Animation<double> fade(double a, double b) => CurvedAnimation(
          parent: _intro,
          curve: Interval(a, b, curve: Curves.easeOutCubic),
        );
    Animation<Offset> slide(double a, double b) =>
        Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _intro,
            curve: Interval(a, b, curve: Curves.easeOutCubic),
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
        Image.asset(
          'photos/ilkkarşılamaanaekranarkaplanı.webp',
          fit: BoxFit.cover,
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
                const SizedBox(height: 16),
                _appear(
                  fade: _subtitleFade,
                  slide: _subtitleSlide,
                  child: const Text(
                    'Sana özel antrenman ve beslenme planıyla 30 günde '
                    'hedefine ulaş.',
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
                  child: SizedBox(
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.neon.withValues(alpha: 0.55),
                            blurRadius: 28,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
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
