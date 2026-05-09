import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/motion/ambient_particles.dart';
import '../../../../core/motion/glow_pulse.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../providers/wizard_provider.dart';
import '../widgets/coach_chat_bubble.dart';
import '../widgets/coach_mood.dart';
import '../widgets/living_coach_avatar.dart';

/// Act 2.5 · Name capture (chat-format relationship moment, Phase 109).
///
/// Reference video timestamp: ~0:06–0:15. The Unrot reference treats
/// the early bonding as a literal chat thread — Brain in the header,
/// messages cascading, user replies as right-aligned bubbles. We
/// adapt that mechanic to FormAI without the cartoon aesthetic: same
/// chat-thread structure, dark/neon palette, premium bubble surfaces.
///
/// Sequence (4 messages):
///
///   1. **Form (typewriter):** "Bu yolculukta sana nasıl sesleneyim?"
///   2. **Form (typewriter, after 1):** "Bu plan boyunca seninle bu
///      isimle konuşacağım."
///   3. (Input pill enables, autofocus.)
///   4. **User (instant):** the entered name, right-aligned, neon-fill.
///   5. **Form (typewriter, after 400 ms beat):** "Tamam, [Name].
///      Şimdi seni biraz daha tanıyayım."
///   6. Soft success haptic on Form's acknowledgment landing, 1.4 s
///      dwell, auto-advance.
///
/// Bonding-zone screen (`_hookSteps = 3`), so the chrome wizard
/// header stays hidden — replaced by a [CoachChatHeader] showing a
/// small mood-aware Form avatar + "Form · Online" status. The whole
/// scene reads as a conversation, not a form.
///
/// Re-entry: when `wizardProvider.name` is already set (back-nav),
/// the typewriters are skipped — both Form messages render instantly,
/// the input pre-fills, focus moves to it. User can edit and
/// re-submit; the flow then proceeds normally.

class NameCaptureStep extends ConsumerStatefulWidget {
  const NameCaptureStep({super.key, required this.onContinue});
  final VoidCallback onContinue;

  @override
  ConsumerState<NameCaptureStep> createState() => _NameCaptureStepState();
}

class _NameCaptureStepState extends ConsumerState<NameCaptureStep> {
  static const String _prompt1 = 'Bu yolculukta sana nasıl sesleneyim?';
  static const String _prompt2 =
      'Bu plan boyunca seninle bu isimle konuşacağım.';

  late final TextEditingController _textCtrl;
  late final FocusNode _focusNode;
  late final ScrollController _scrollCtrl;

  /// True when the user has visited this step before — pre-filled
  /// field, typewriters skipped, immediate focus.
  late final bool _isReturning;

  /// Sequential reveal flags. Each Form bubble's typewriter
  /// completion advances the chat to the next message.
  bool _msg1Done = false;
  bool _msg2Done = false;
  bool _userMsgPosted = false;

  String _capturedName = '';

  @override
  void initState() {
    super.initState();
    final existingName = ref.read(wizardProvider).name ?? '';
    _isReturning = existingName.isNotEmpty;
    _textCtrl = TextEditingController(text: existingName);
    _focusNode = FocusNode();
    _scrollCtrl = ScrollController();
    _textCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    if (_isReturning) {
      // Returning user — collapse the typewriter cascade so the chat
      // is ready immediately. Keep the same bubble structure so the
      // visual continuity holds across navigations.
      _msg1Done = true;
      _msg2Done = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onMsg1Done() {
    if (!mounted || _msg1Done) return;
    setState(() => _msg1Done = true);
    _scrollToEnd();
  }

  void _onMsg2Done() {
    if (!mounted || _msg2Done) return;
    setState(() => _msg2Done = true);
    _focusNode.requestFocus();
    _scrollToEnd();
  }

  void _onMsg3Done() {
    if (!mounted) return;
    // Soft confirmation — Form acknowledged. Auto-advance after a
    // dwell so the user reads the line without having to tap.
    AppHaptics.success();
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) widget.onContinue();
    });
  }

  void _submit() {
    final name = _textCtrl.text.trim();
    if (name.isEmpty) return;
    AppHaptics.success();
    _focusNode.unfocus();
    ref.read(wizardProvider.notifier).setName(name);
    setState(() {
      _capturedName = name;
      _userMsgPosted = true;
    });
    _scrollToEnd();
  }

  /// Smooth-scroll the chat to the bottom whenever a new message
  /// lands. Lets the cascade feel like a real chat — newest message
  /// always visible.
  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String _normalizeForGreeting(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.length == 1) return trimmed.toUpperCase();
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final ctaEnabled = _textCtrl.text.trim().isNotEmpty;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF0A0814)),
        const AmbientParticles(
          count: 6,
          color: AppColors.neon,
          minAlpha: 0.06,
          maxAlpha: 0.20,
          minRadius: 1.0,
          maxRadius: 2.0,
          driftDuration: Duration(seconds: 26),
          seed: 17,
        ),
        SafeArea(
          child: Column(
            children: [
              CoachChatHeader(
                avatar: LivingCoachAvatar(
                  size: 44,
                  innerSize: 32,
                  // Listening throughout the asking phase, proud the
                  // moment we acknowledge the name. Same character
                  // language Form uses on every other Form-speaking
                  // surface — cross-scene presence continuity.
                  mood: _userMsgPosted
                      ? CoachMood.proud
                      : CoachMood.listening,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CoachChatBubble(
                        text: _prompt1,
                        side: ChatBubbleSide.form,
                        typewriter: !_isReturning,
                        startDelay: const Duration(milliseconds: 250),
                        onTypingComplete: _onMsg1Done,
                      ),
                      if (_msg1Done) ...[
                        const SizedBox(height: 8),
                        CoachChatBubble(
                          text: _prompt2,
                          side: ChatBubbleSide.form,
                          typewriter: !_isReturning,
                          startDelay:
                              const Duration(milliseconds: 250),
                          onTypingComplete: _onMsg2Done,
                        ),
                      ],
                      if (_userMsgPosted) ...[
                        const SizedBox(height: 8),
                        CoachChatBubble(
                          text: _capturedName,
                          side: ChatBubbleSide.user,
                        ),
                        const SizedBox(height: 8),
                        CoachChatBubble(
                          text:
                              'Tamam, ${_normalizeForGreeting(_capturedName)}. '
                              'Şimdi seni biraz daha tanıyayım.',
                          side: ChatBubbleSide.form,
                          typewriter: true,
                          // 400 ms beat after the user posts — reads
                          // as Form taking a moment before replying.
                          startDelay:
                              const Duration(milliseconds: 400),
                          onTypingComplete: _onMsg3Done,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Input pill only renders during the "asking" phase;
              // hidden once the user submits so the screen reads as
              // pure chat during the acknowledgment beat.
              if (!_userMsgPosted)
                AnimatedOpacity(
                  opacity: _msg2Done ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  child: _ChatInputPill(
                    controller: _textCtrl,
                    focusNode: _focusNode,
                    enabled: _msg2Done && !_userMsgPosted,
                    canSubmit: ctaEnabled,
                    onSubmit: _submit,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bottom-anchored chat input pill. Rounded TextField on the left,
/// a [GlowPulse] send button on the right that lights up when the
/// input is non-empty. Sticky to SafeArea bottom; rises with the
/// keyboard via Scaffold's default behaviour (NameCaptureStep is
/// hosted inside the wizard's Scaffold which has
/// `resizeToAvoidBottomInset: true` by default).
class _ChatInputPill extends StatelessWidget {
  const _ChatInputPill({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.canSubmit,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool canSubmit;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: AppColors.neon.withValues(alpha: 0.4),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.neon.withValues(alpha: 0.10),
                    blurRadius: 18,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
                autofocus: false,
                maxLength: 32,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => canSubmit ? onSubmit() : null,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                ),
                cursorColor: AppColors.neon,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Adın',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  counterText: '',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GlowPulse(
            enabled: canSubmit,
            color: AppColors.neon,
            minAlpha: 0.40,
            maxAlpha: 0.65,
            minBlur: 18,
            maxBlur: 26,
            spread: 0,
            duration: const Duration(milliseconds: 2400),
            child: Material(
              color: canSubmit
                  ? AppColors.neon
                  : AppColors.neon.withValues(alpha: 0.30),
              shape: const CircleBorder(),
              child: InkWell(
                onTap: canSubmit ? onSubmit : null,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color: canSubmit
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
