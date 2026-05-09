import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';

/// Act 2 · AI companion bonding.
///
/// The named coach (Form) introduces itself with a typewriter chat bubble
/// over a pulsing neon halo. Tapping anywhere skips the typewriter; the
/// CTA stays disabled until the line is fully revealed. Three audit-§2.3
/// beats: identity, 12-week promise, 90-second effort transparency.

class CoachIntroStep extends StatefulWidget {
  const CoachIntroStep({super.key, required this.onContinue});
  final VoidCallback onContinue;

  @override
  State<CoachIntroStep> createState() => _CoachIntroStepState();
}

class _CoachIntroStepState extends State<CoachIntroStep>
    with SingleTickerProviderStateMixin {
  // Cinematic rebuild · the coach now has a name (Form) and the line is
  // structured as three beats per the audit (§2.3): identity, promise,
  // effort-transparency. The "90 saniye" line sets a time-budget
  // expectation so the user mentally commits before the wizard starts —
  // norm-of-reciprocity + time-boxing psychology.
  static const String _coachLine =
      'Merhaba, ben Form. '
      '12 haftada vücudunu nasıl değiştireceğini sana göstereceğim. '
      'Önce seni tanıyalım — bu 90 saniye sürüyor.';
  // ~28ms/char keeps the line under ~4s — long enough to feel deliberate,
  // short enough that nobody waits long for the CTA to enable.
  static const Duration _perChar = Duration(milliseconds: 28);

  late final AnimationController _typer;
  bool _typingDone = false;

  @override
  void initState() {
    super.initState();
    _typer = AnimationController(
      vsync: this,
      duration: _perChar * _coachLine.length,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _typingDone = true);
        }
      });
    _typer.forward();
  }

  @override
  void dispose() {
    _typer.dispose();
    super.dispose();
  }

  void _skipTyping() {
    if (_typingDone) return;
    _typer.value = 1.0;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'photos/merhababenseninkişiselyapayzekakoçunumyeniarkaplan.webp',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const ColoredBox(color: Color(0xFF0E0729)),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.25),
                Colors.black.withValues(alpha: 0.6),
                Colors.black.withValues(alpha: 0.95),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            child: Column(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _skipTyping,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const _PulsingCoachAvatar(),
                        const SizedBox(height: 28),
                        _TerminalBubble(
                          typer: _typer,
                          fullText: _coachLine,
                          isTypingDone: _typingDone,
                        ),
                        const SizedBox(height: 10),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 240),
                          opacity: _typingDone ? 0.0 : 1.0,
                          child: const Text(
                            'Geçmek için ekrana dokun',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 280),
                  opacity: _typingDone ? 1.0 : 0.45,
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _typingDone
                          ? () {
                              AppHaptics.secondaryTap();
                              widget.onContinue();
                            }
                          : null,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('DEVAM ET'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.neon,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            AppColors.neon.withValues(alpha: 0.45),
                        disabledForegroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
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

/// Chat-bubble container that progressively reveals the coach's line as
/// [typer] advances 0→1. Blinking neon caret trails the cursor while
/// typing is in flight; disappears the moment the line completes.
class _TerminalBubble extends StatelessWidget {
  const _TerminalBubble({
    required this.typer,
    required this.fullText,
    required this.isTypingDone,
  });
  final Animation<double> typer;
  final String fullText;
  final bool isTypingDone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(20),
        ),
        border: Border.all(
          color: AppColors.neon.withValues(alpha: 0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.neon.withValues(alpha: 0.18),
            blurRadius: 24,
            spreadRadius: -2,
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: typer,
        builder: (context, _) {
          final int chars =
              (typer.value * fullText.length).round().clamp(0, fullText.length);
          final String visible = fullText.substring(0, chars);
          return Text.rich(
            TextSpan(
              children: [
                TextSpan(text: visible),
                if (!isTypingDone)
                  const TextSpan(
                    text: '▍',
                    style: TextStyle(color: AppColors.neon),
                  ),
              ],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.55,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The coach avatar — circular face inside a pulsing neon halo. Static
/// asset (`kişiselyapayzekakoçfoto.webp`) for now; the cinematic pass
/// will swap this for a Rive-driven multi-state avatar once the artist
/// delivers the .riv file.
class _PulsingCoachAvatar extends StatefulWidget {
  const _PulsingCoachAvatar();

  @override
  State<_PulsingCoachAvatar> createState() => _PulsingCoachAvatarState();
}

class _PulsingCoachAvatarState extends State<_PulsingCoachAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = _pulse.value;
        final glowAlpha = 0.35 + (0.40 * t);
        return SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.neon.withValues(alpha: glowAlpha),
                      AppColors.neonAccent.withValues(alpha: glowAlpha * 0.5),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.neon.withValues(alpha: 0.7),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.neon.withValues(alpha: 0.45),
                      blurRadius: 26,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'photos/kişiselyapayzekakoçfoto.webp',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [AppColors.neon, AppColors.neonAccent],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.smart_toy_rounded,
                        color: Colors.white,
                        size: 56,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
