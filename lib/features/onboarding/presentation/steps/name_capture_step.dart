import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/motion/ambient_particles.dart';
import '../../../../core/motion/glow_pulse.dart';
import '../../../../core/motion/kinetic_text_reveal.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../providers/wizard_provider.dart';
import '../widgets/coach_mood.dart';
import '../widgets/living_coach_avatar.dart';

/// Act 2.5 · Name capture (relationship moment).
///
/// Lives between coach intro and gender. The screen is *not* a form
/// field — it's Form asking the user a personal question and then
/// acknowledging the answer. Two visual states:
///
///   1. asking — Form's avatar pulses, the prompt types in via
///      [KineticTextReveal] ("Bu yolculukta sana nasıl sesleneyim?"),
///      a soft subtitle fades in once typing settles, the input
///      autofocuses, and the CTA enables the moment a non-empty
///      answer is typed.
///   2. acknowledging — the input + CTA fade out, the avatar
///      brightens, and Form's acknowledgment types in
///      ("Tamam, [Name]. Şimdi seni biraz daha tanıyayım."). On
///      typing-complete, a soft success haptic fires, then the wizard
///      auto-advances after a 1.4 s dwell so the user can read the
///      acknowledgment without having to tap.
///
/// Re-entry from back-navigation: if `wizardProvider.name` is already
/// set, we pre-fill the field, skip the asking-prompt typewriter, and
/// focus immediately. The user can edit and re-submit; we don't
/// auto-advance into a loop because the back-nav user lands in the
/// asking state.
///
/// Stays inside the wizard's `_hookSteps` window so the chrome header
/// stays hidden — the bonding zone (welcome → coach intro → name
/// capture) reads as one continuous conversation, not "form + chrome."

enum _NameCaptureState { asking, acknowledging }

class NameCaptureStep extends ConsumerStatefulWidget {
  const NameCaptureStep({super.key, required this.onContinue});
  final VoidCallback onContinue;

  @override
  ConsumerState<NameCaptureStep> createState() => _NameCaptureStepState();
}

class _NameCaptureStepState extends ConsumerState<NameCaptureStep>
    with SingleTickerProviderStateMixin {
  static const String _prompt = 'Bu yolculukta sana nasıl sesleneyim?';
  static const String _subtitle =
      'Bu plan boyunca seninle bu isimle konuşacağım.';

  late final TextEditingController _textCtrl;
  late final FocusNode _focusNode;

  /// True when the user has visited this step before — pre-filled
  /// field, skipped typewriter, immediate focus.
  late final bool _isReturning;

  /// True after the asking-state typewriter completes; gates the
  /// subtitle fade-in and the input's auto-focus.
  bool _promptDone = false;

  _NameCaptureState _state = _NameCaptureState.asking;
  String _capturedName = '';

  @override
  void initState() {
    super.initState();
    final existingName = ref.read(wizardProvider).name ?? '';
    _isReturning = existingName.isNotEmpty;
    _textCtrl = TextEditingController(text: existingName);
    _focusNode = FocusNode();
    _textCtrl.addListener(() {
      // Triggers rebuild so the CTA's enabled state tracks the input.
      if (mounted) setState(() {});
    });
    if (_isReturning) {
      _promptDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onPromptTypingComplete() {
    if (!mounted || _promptDone) return;
    setState(() => _promptDone = true);
    _focusNode.requestFocus();
  }

  void _submit() {
    final name = _textCtrl.text.trim();
    if (name.isEmpty) return;
    AppHaptics.success();
    _focusNode.unfocus();
    ref.read(wizardProvider.notifier).setName(name);
    setState(() {
      _capturedName = name;
      _state = _NameCaptureState.acknowledging;
    });
  }

  void _onAcknowledgmentTypingComplete() {
    if (!mounted) return;
    // Soft completion haptic — Form has acknowledged the user.
    AppHaptics.success();
    // Dwell so the user reads the acknowledgment, then auto-advance.
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) widget.onContinue();
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 380),
              switchInCurve: Curves.easeOutCubic,
              child: _state == _NameCaptureState.asking
                  ? _buildAsking(ctaEnabled)
                  : _buildAcknowledging(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAsking(bool ctaEnabled) {
    return SingleChildScrollView(
      key: const ValueKey('asking'),
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Smaller avatar than coach intro — shares vertical space
          // with the prompt + input + CTA. Mood is `listening`: faster
          // pulse, slight forward lean — Form is attentively waiting
          // for the user's name.
          const LivingCoachAvatar(
            size: 156,
            innerSize: 100,
            mood: CoachMood.listening,
          ),
          const SizedBox(height: 28),
          // Prompt: typewriter on first visit, static on re-entry.
          if (_isReturning)
            const Text(
              _prompt,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                height: 1.25,
                letterSpacing: 0.2,
              ),
            )
          else
            KineticTextReveal(
              text: _prompt,
              onComplete: _onPromptTypingComplete,
              caret: false,
              charDuration: const Duration(milliseconds: 32),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                height: 1.25,
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 12),
          AnimatedOpacity(
            opacity: _promptDone ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutCubic,
            child: const Text(
              _subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white60,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 28),
          AnimatedOpacity(
            opacity: _promptDone ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            child: _NameInputField(
              controller: _textCtrl,
              focusNode: _focusNode,
              onSubmitted: (_) => ctaEnabled ? _submit() : null,
              enabled: _state == _NameCaptureState.asking,
            ),
          ),
          const SizedBox(height: 16),
          AnimatedOpacity(
            opacity: _promptDone ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 480),
            curve: Curves.easeOutCubic,
            child: GlowPulse(
              enabled: ctaEnabled,
              color: AppColors.neon,
              minAlpha: 0.40,
              maxAlpha: 0.65,
              minBlur: 22,
              maxBlur: 32,
              spread: 1,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(18),
              duration: const Duration(milliseconds: 2800),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: ctaEnabled ? _submit : null,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('DEVAM ET'),
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
                      letterSpacing: 3,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcknowledging() {
    final greetingName = _normalizeForGreeting(_capturedName);
    return Column(
      key: const ValueKey('acknowledging'),
      children: [
        const Spacer(flex: 1),
        // Mood shifts to `proud` for the acknowledgment beat — chest
        // forward (scale 1.05), brighter halo, faster glow. Reads as
        // "Form is satisfied with what it just heard." The 500ms
        // cross-fade inside LivingCoachAvatar handles the transition
        // from `listening` to `proud` smoothly.
        const LivingCoachAvatar(
          size: 196,
          innerSize: 132,
          mood: CoachMood.proud,
        ),
        const SizedBox(height: 32),
        KineticTextReveal(
          text: 'Tamam, $greetingName. Şimdi seni biraz daha tanıyayım.',
          onComplete: _onAcknowledgmentTypingComplete,
          caret: false,
          charDuration: const Duration(milliseconds: 30),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            height: 1.4,
            letterSpacing: 0.2,
          ),
          textAlign: TextAlign.center,
        ),
        const Spacer(flex: 2),
      ],
    );
  }
}

/// The name input — single line, neon focus border, autofocused once
/// the asking-state prompt finishes typing. Submission on keyboard
/// done / tap maps to the parent's `_submit`.
class _NameInputField extends StatelessWidget {
  const _NameInputField({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.enabled,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      autofocus: false,
      maxLength: 32,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.done,
      onSubmitted: onSubmitted,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 17,
        height: 1.3,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
      ),
      cursorColor: AppColors.neon,
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        hintText: 'Adın',
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.35),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        counterText: '',
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.14),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.neon, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
    );
  }
}
