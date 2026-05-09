import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../onboarding_chrome.dart';
import 'interactive_question_step.dart';

/// Generic hybrid question — tap a preset card OR type a longer answer.
///
/// Used by the experience and pain-point steps so they share identical
/// animation timings, focus management, and DEVAM ET visibility logic.
/// The activity step has its own variant (it stores an enum instead of
/// a string) and stays separate.
class HybridQuestionStep extends StatefulWidget {
  const HybridQuestionStep({
    super.key,
    required this.title,
    required this.subtitle,
    required this.options,
    required this.feedbackText,
    required this.initialCardValue,
    required this.initialDescription,
    required this.onCardCommitted,
    required this.onTextCommitted,
    required this.inputLabel,
    required this.inputHint,
  });

  final String title;
  final String? subtitle;
  final List<InteractiveOption> options;
  final String feedbackText;
  final String? initialCardValue;
  final String? initialDescription;

  /// Fires when the user taps one of the [options]. The string is the
  /// `value` of the picked option — the caller writes it into whichever
  /// wizard slot owns this step.
  final ValueChanged<String> onCardCommitted;

  /// Fires when the user types into the free-text field and taps DEVAM ET.
  /// The string is the trimmed text the caller writes into the matching
  /// `*Description` slot.
  final ValueChanged<String> onTextCommitted;

  final String inputLabel;
  final String inputHint;

  @override
  State<HybridQuestionStep> createState() => _HybridQuestionStepState();
}

class _HybridQuestionStepState extends State<HybridQuestionStep>
    with TickerProviderStateMixin {
  String? _selectedCardValue;
  bool _committingCard = false;

  late final TextEditingController _textCtrl;
  late final FocusNode _focusNode;
  // Once the user enters at least one character we keep DEVAM ET mounted;
  // the disabled state takes over if they later clear the field.
  bool _hasStartedTyping = false;

  late final AnimationController _feedbackCtrl;
  late final Animation<double> _feedbackFade;
  late final Animation<Offset> _feedbackSlide;

  late final AnimationController _ctaCtrl;
  late final Animation<double> _ctaFade;
  late final Animation<Offset> _ctaSlide;

  @override
  void initState() {
    super.initState();
    _selectedCardValue = widget.initialCardValue;
    _textCtrl = TextEditingController(text: widget.initialDescription ?? '');
    _focusNode = FocusNode();
    _hasStartedTyping = _textCtrl.text.isNotEmpty;
    _textCtrl.addListener(_onTextChange);

    _feedbackCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _feedbackFade =
        CurvedAnimation(parent: _feedbackCtrl, curve: Curves.easeOutCubic);
    _feedbackSlide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _feedbackCtrl, curve: Curves.easeOutCubic),
    );

    _ctaCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _ctaFade = CurvedAnimation(parent: _ctaCtrl, curve: Curves.easeOutCubic);
    _ctaSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _ctaCtrl, curve: Curves.easeOutCubic),
    );
    if (_hasStartedTyping) {
      _ctaCtrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _textCtrl.removeListener(_onTextChange);
    _textCtrl.dispose();
    _focusNode.dispose();
    _feedbackCtrl.dispose();
    _ctaCtrl.dispose();
    super.dispose();
  }

  void _onTextChange() {
    final hasText = _textCtrl.text.isNotEmpty;
    if (!_hasStartedTyping && hasText) {
      setState(() => _hasStartedTyping = true);
      _ctaCtrl.forward();
    } else {
      setState(() {});
    }
  }

  Future<void> _pickCard(String value) async {
    if (_committingCard) return;
    AppHaptics.secondaryTap();
    _focusNode.unfocus();
    setState(() {
      _selectedCardValue = value;
      _committingCard = true;
    });
    _feedbackCtrl.forward();
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    widget.onCardCommitted(value);
  }

  void _commitCustom() {
    if (_committingCard) return;
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    AppHaptics.secondaryTap();
    widget.onTextCommitted(text);
  }

  @override
  Widget build(BuildContext context) {
    final ctaEnabled = _textCtrl.text.trim().isNotEmpty;
    return Column(
      children: [
        StepTitle(title: widget.title, subtitle: widget.subtitle),
        const SizedBox(height: 14),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final opt in widget.options) ...[
                  OptionCard(
                    option: opt,
                    selected: _selectedCardValue == opt.value,
                    dimmed:
                        _committingCard && _selectedCardValue != opt.value,
                    onTap: () => _pickCard(opt.value),
                  ),
                  if (opt != widget.options.last) const SizedBox(height: 8),
                ],
                const SizedBox(height: 12),
                FeedbackBanner(
                  fade: _feedbackFade,
                  slide: _feedbackSlide,
                  text: widget.feedbackText,
                ),
                const SizedBox(height: 14),
                _HybridDescriptionInput(
                  controller: _textCtrl,
                  focusNode: _focusNode,
                  enabled: !_committingCard,
                  label: widget.inputLabel,
                  hint: widget.inputHint,
                ),
                const SizedBox(height: 10),
                if (_hasStartedTyping)
                  FadeTransition(
                    opacity: _ctaFade,
                    child: SlideTransition(
                      position: _ctaSlide,
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: ctaEnabled ? _commitCustom : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.neon,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                AppColors.neon.withValues(alpha: 0.35),
                            disabledForegroundColor: Colors.white60,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.5,
                              fontSize: 14,
                            ),
                          ),
                          child: const Text('DEVAM ET'),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Free-text input shared by every hybrid step. Same chrome as the
/// activity-step input but parameterised for label and hint so each step
/// can supply its own coach-voice copy.
class _HybridDescriptionInput extends StatelessWidget {
  const _HybridDescriptionInput({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.label,
    required this.hint,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.edit_note_rounded,
              color: AppColors.neonAccent,
              size: 18,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          maxLines: 3,
          minLines: 3,
          maxLength: 280,
          textInputAction: TextInputAction.done,
          style:
              const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
          cursorColor: AppColors.neon,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Colors.white38,
              fontSize: 13,
              height: 1.4,
            ),
            counterText: '',
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.04),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.neon, width: 1.4),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
