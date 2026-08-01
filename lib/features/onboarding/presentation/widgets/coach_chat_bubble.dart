import 'package:flutter/material.dart';

import '../../../../core/motion/kinetic_text_reveal.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

/// Which side of the chat thread a bubble belongs to.
///
///   • `form` — Form is speaking. Left-aligned, dark surface with
///     neon outline + glow, typewriter optional. Reads as the AI's
///     side of the conversation.
///   • `user` — the user is speaking. Right-aligned, neon-tinted
///     fill, no typewriter (user input is presented at full size).
///     Reads as the user's voice in the thread.
enum ChatBubbleSide { form, user }

/// A single chat bubble in the Form ↔ user conversation.
///
/// Phase 109 · chat-format restructure of name capture (ref video
/// ~0:06–0:15). Form's old centered-prompt + input + CTA layout
/// becomes a sequential 4-message thread:
///
///   1. Form: "Bu yolculukta sana nasıl sesleneyim?"
///   2. Form: "Bu plan boyunca seninle bu isimle konuşacağım."
///   3. User: `<name>`  (after submit)
///   4. Form: "Tamam, [Name]. Şimdi seni biraz daha tanıyayım."
///
/// Each bubble: tail-corner asymmetry signals which side; Form
/// bubbles carry an outer neon shadow for "AI is speaking" presence.
/// User bubbles use a brighter fill + heavier outline so the user's
/// own voice stands out against the dark background.
///
/// Pass [typewriter] = true on Form bubbles so each one types itself
/// in (with an optional [startDelay] to chain after a previous
/// message). User bubbles render their text immediately at full
/// size — replicating "the user already typed this before sending"
/// behaviour from real chat apps.
class CoachChatBubble extends StatelessWidget {
  const CoachChatBubble({
    super.key,
    required this.text,
    required this.side,
    this.typewriter = false,
    this.charDuration = const Duration(milliseconds: 28),
    this.startDelay = Duration.zero,
    this.onTypingComplete,
  });

  final String text;
  final ChatBubbleSide side;

  /// Form bubbles type their text character-by-character; user
  /// bubbles render full text immediately. Defaults to `false` (no
  /// typewriter) so user bubbles get the right behaviour by default.
  final bool typewriter;

  final Duration charDuration;
  final Duration startDelay;
  final VoidCallback? onTypingComplete;

  @override
  Widget build(BuildContext context) {
    final isForm = side == ChatBubbleSide.form;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.78;
    return Align(
      alignment: isForm
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: isForm
                ? Colors.white.withValues(alpha: 0.06)
                : AppColors.neon.withValues(alpha: 0.20),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              // Tail-corner asymmetry: Form bubbles taper at the
              // bottom-left (anchored to Form's side); user bubbles
              // taper at the bottom-right (anchored to the user's
              // side). Mirrors iOS Messages.
              bottomLeft: Radius.circular(isForm ? 4 : 18),
              bottomRight: Radius.circular(isForm ? 18 : 4),
            ),
            border: Border.all(
              color: isForm
                  ? AppColors.neon.withValues(alpha: 0.4)
                  : AppColors.neon.withValues(alpha: 0.7),
              width: 1,
            ),
            boxShadow: isForm
                ? [
                    BoxShadow(
                      color: AppColors.neon.withValues(alpha: 0.18),
                      blurRadius: 22,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          child: typewriter
              ? KineticTextReveal(
                  text: text,
                  charDuration: charDuration,
                  startDelay: startDelay,
                  onComplete: onTypingComplete,
                  caret: true,
                  caretColor: AppColors.neon,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                )
              : Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Compact chat header — small Form avatar + "Form" + online status
/// dot. Sits above the chat thread, replacing the empty space the
/// wizard chrome would normally occupy. Matches the pattern in the
/// reference (Unrot ~0:10) where Brain sits in the chat header at a
/// reduced size while the conversation scrolls below.
class CoachChatHeader extends StatelessWidget {
  const CoachChatHeader({
    super.key,
    required this.avatar,
    this.name = 'Form', // i18n-ignore — the coach's name
    this.statusLabel,
  });

  /// Pre-built avatar widget (typically a small [LivingCoachAvatar]).
  /// Caller controls size + mood so the header can match the screen
  /// it lives on.
  final Widget avatar;
  final String name;

  /// Null resolves to the localized default at build time. A literal
  /// default would bake one language into the constructor signature.
  final String? statusLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.neonGreen,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.neonGreen.withValues(alpha: 0.55),
                          blurRadius: 6,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    statusLabel ??
                        AppLocalizations.of(context).coachStatusOnline,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
