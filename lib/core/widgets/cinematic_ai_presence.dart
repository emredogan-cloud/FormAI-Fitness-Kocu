import 'package:flutter/material.dart';

import '../../features/onboarding/presentation/widgets/coach_mood.dart';
import '../../features/onboarding/presentation/widgets/living_coach_avatar.dart';
import '../motion/ambient_particles.dart';
import '../motion/kinetic_text_reveal.dart';
import '../motion/neon_ring_stack.dart';
import '../theme/app_colors.dart';
import '../utils/app_haptics.dart';

/// Phase 125 · the cinematic AI-presence system.
///
/// Visual target: `docs/reference-imagery/AI_messagesing.png`. Full-screen surface that
/// reads as "Form is actively present + working on something for you."
/// Replaces the Phase-110 single-bubble approach with a directed
/// hierarchy:
///
///   [background atmosphere] → [neon ring stack around avatar]
///                           → [bold title] → [subtitle]
///                           → [chat-input bar with composing + typed
///                              illusion]
///
/// Reusable across:
///   • onboarding interludes (replaces `SetupThinkingStep` body)
///   • first dashboard entry after paywall
///   • first nutrition tab entry
///   • first workout completion celebration
///   • any future "Form has something to say" moment
///
/// Construction contract:
///
///   CinematicAiPresence(
///     title: '...',                    // big bold headline
///     subtitle: '...',                 // smaller muted support line
///     subtitleTypewriter: false,       // if true, subtitle types out
///                                      //  character-by-character
///     composingPlaceholder: '...',     // shown in chat-input bar
///                                      //  with blinking cursor —
///                                      //  the AI-writing illusion
///     mood: CoachMood.thinking,        // drives avatar behavior
///     autoCloseAfter: Duration(...),   // fixed dwell, then onComplete
///     onComplete: () { ... },          // null = scene stays mounted
///   )
///
/// Why this split: the reference image's chat bar is *always* in
/// composing state — that's the "Form is writing" metaphor. It never
/// reveals a typed message. Per-character bonding moments (like the
/// existing onboarding step's name-personalized setup line) go in
/// the subtitle slot via `subtitleTypewriter: true`.
///
/// Auto-close is a hard timer — predictable and easy to tune per
/// caller. For typewriter subtitles, match `autoCloseAfter` to
/// roughly `subtitle.length × _charPaceMs + tailDwell` (~6.5 s for a
/// 60-char Turkish line).
///
/// Performance:
///   • One [AnimationController] for atmosphere, one for cursor blink,
///     one inside [NeonRingStack]. No more.
///   • The avatar's existing internal RepaintBoundary plus the ring
///     stack's RepaintBoundary keep the two animation domains from
///     bubbling repaints into each other.
///   • Background is a fixed gradient + AmbientParticles — both
///     RepaintBoundary-isolated.
class CinematicAiPresence extends StatefulWidget {
  const CinematicAiPresence({
    super.key,
    required this.title,
    required this.subtitle,
    required this.composingPlaceholder,
    required this.mood,
    required this.autoCloseAfter,
    this.subtitleTypewriter = false,
    this.onComplete,
    this.bottomActions,
  });

  /// Dominant headline — typically the AI's status ("Düşünüyorum...",
  /// "Hoş geldin", "Tebrikler"). White, 28 sp, w800.
  final String title;

  /// Supporting line under the title. When [subtitleTypewriter] is
  /// false: rendered as static muted text. When true: typed out
  /// character-by-character via the kinetic-text-reveal primitive.
  final String subtitle;

  /// If true, [subtitle] types out character-by-character on mount.
  /// Use for personalized / bonding messages where the user should
  /// feel the words *arrive*. Use false for status / informational
  /// subtitles where the text should just be present.
  final bool subtitleTypewriter;

  /// Text shown inside the chat-input bar — never reveals, stays in
  /// cursor-blink composing state for the full scene. This is the
  /// "Form is writing" illusion; the message-writing isn't *the*
  /// content, it's the *presence signal*.
  ///
  /// Ignored when [bottomActions] is provided — the actions widget
  /// owns the bottom area instead.
  final String composingPlaceholder;

  /// Avatar mood for this scene. `thinking` for AI-processing,
  /// `excited` / `proud` / `celebratory` for completion / welcome
  /// beats.
  final CoachMood mood;

  /// Total scene duration. After this, `onComplete` fires (once).
  /// Pass `null` for scenes that wait on explicit user input (the
  /// equipment question, future yes/no decisions) — the scene then
  /// stays mounted indefinitely and the caller dismisses by calling
  /// `onComplete` itself from a [bottomActions] callback.
  final Duration? autoCloseAfter;

  /// Called once when [autoCloseAfter] elapses, or invoked manually
  /// by a [bottomActions] callback. Null = scene stays mounted
  /// indefinitely (caller manages its own dismiss flow).
  final VoidCallback? onComplete;

  /// Phase 133 · optional decision affordance rendered in place of the
  /// chat-input pill. When non-null, the scene reads as "Form just
  /// asked you something" and waits for the user's tap. The widget
  /// is responsible for invoking [onComplete] (or otherwise advancing
  /// flow) when the user makes a choice.
  final Widget? bottomActions;

  @override
  State<CinematicAiPresence> createState() => _CinematicAiPresenceState();
}

class _CinematicAiPresenceState extends State<CinematicAiPresence>
    with TickerProviderStateMixin {
  late final AnimationController _atmosphere;
  late final AnimationController _cursor;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _atmosphere = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6200),
    )..repeat(reverse: true);

    // Blink period: 900 ms full cycle (450 ms on, 450 ms off via
    // reverse). Matches the iOS / Android system text-input cursor
    // cadence — feels native.
    _cursor = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..repeat(reverse: true);

    final closeAfter = widget.autoCloseAfter;
    if (closeAfter != null) {
      Future<void>.delayed(closeAfter, () {
        if (!mounted || _completed) return;
        _completed = true;
        // Closing haptic — soft "Form done speaking" signal. Same call
        // setup_thinking_step's _onAutoClose used to fire inline before
        // the Phase 125 refactor moved this responsibility into the
        // shared widget.
        AppHaptics.success();
        widget.onComplete?.call();
      });
    }
  }

  @override
  void dispose() {
    _atmosphere.dispose();
    _cursor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Phase 130 · wrap in Material(transparency) so the scene has a
    // Material ancestor wherever it's mounted. Without one, Flutter's
    // debug fallback renders every Text in the subtree with a yellow
    // double-underline (visible in the route-pushed first-time scenes
    // that don't traverse through a Scaffold). MaterialType.transparency
    // means no background fill + no elevation — purely a context fix.
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF050410)),
          // Slowly breathing radial glow centered behind the avatar.
          // Two-stop gradient (neon → neonAccent → background) gives
          // the screen a sense of focal warmth without ever feeling
          // light/bright.
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _atmosphere,
              builder: (context, _) {
                final t = Curves.easeInOutSine.transform(_atmosphere.value);
                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.25),
                      radius: 1.1,
                      colors: [
                        AppColors.neon.withValues(alpha: 0.20 + 0.08 * t),
                        AppColors.neonAccent.withValues(alpha: 0.08 + 0.05 * t),
                        const Color(0xFF050410),
                      ],
                      stops: const [0.0, 0.42, 1.0],
                    ),
                  ),
                );
              },
            ),
          ),
          const AmbientParticles(
            count: 14,
            color: AppColors.neon,
            minAlpha: 0.08,
            maxAlpha: 0.24,
            minRadius: 1.0,
            maxRadius: 2.2,
            driftDuration: Duration(seconds: 28),
            seed: 333,
          ),
          // Soft vignette at the edges — focuses the eye on the
          // centered content without darkening the middle.
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.25,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF050410).withValues(alpha: 0.75),
                  ],
                  stops: const [0.55, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  NeonRingStack(
                    size: 234,
                    primaryColor: AppColors.neonAccent,
                    accentColor: AppColors.neon,
                    child: LivingCoachAvatar(
                      size: 132,
                      innerSize: 92,
                      mood: widget.mood,
                    ),
                  ),
                  const Spacer(flex: 1),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.18,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  widget.subtitleTypewriter
                      ? KineticTextReveal(
                          text: widget.subtitle,
                          charDuration: const Duration(milliseconds: 35),
                          caret: false,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.45,
                            letterSpacing: 0.1,
                          ),
                        )
                      : Text(
                          widget.subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.68),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.45,
                            letterSpacing: 0.1,
                          ),
                        ),
                  const Spacer(flex: 1),
                  widget.bottomActions ??
                      _ChatInputBar(
                        placeholder: widget.composingPlaceholder,
                        cursorCtrl: _cursor,
                      ),
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Glassmorphism chat-input pill at the bottom of the scene. Renders
/// the placeholder + blinking cursor permanently — this is the
/// "Form is writing" *illusion*, not an actual chat input. The bar
/// never reveals a message; the message content lives in the
/// subtitle slot above. A purple-gradient circular paper-plane
/// button anchors the right edge as the chat-affordance completer.
class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({
    required this.placeholder,
    required this.cursorCtrl,
  });

  final String placeholder;
  final AnimationController cursorCtrl;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(18, 10, 8, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.07),
              Colors.white.withValues(alpha: 0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppColors.neon.withValues(alpha: 0.40),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.neon.withValues(alpha: 0.22),
              blurRadius: 22,
              spreadRadius: -4,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _PlaceholderWithCursor(
                placeholder: placeholder,
                cursorCtrl: cursorCtrl,
              ),
            ),
            const SizedBox(width: 8),
            const _SendButton(),
          ],
        ),
      ),
    );
  }
}

/// Composing-state row: placeholder text + a thin blinking cursor.
/// The cursor is a 2 × 14 neon rectangle (not the "|" char) so it
/// renders identically across every device font.
class _PlaceholderWithCursor extends StatelessWidget {
  const _PlaceholderWithCursor({
    required this.placeholder,
    required this.cursorCtrl,
  });

  final String placeholder;
  final AnimationController cursorCtrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            placeholder,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.35,
              letterSpacing: 0.1,
            ),
          ),
        ),
        const SizedBox(width: 4),
        AnimatedBuilder(
          animation: cursorCtrl,
          builder: (context, _) {
            return Opacity(
              opacity: cursorCtrl.value,
              child: Container(
                width: 2,
                height: 14,
                color: AppColors.neon,
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Circular purple gradient paper-plane button. Non-interactive — the
/// chat bar is an AI-writing illusion, not a real text field.
class _SendButton extends StatelessWidget {
  const _SendButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.neon, AppColors.neonDeep],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.neon.withValues(alpha: 0.55),
            blurRadius: 12,
            spreadRadius: -2,
          ),
        ],
      ),
      child: const Icon(
        Icons.send_rounded,
        color: Colors.white,
        size: 17,
      ),
    );
  }
}
