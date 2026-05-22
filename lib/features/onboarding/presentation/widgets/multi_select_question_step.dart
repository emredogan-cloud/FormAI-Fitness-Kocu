import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../onboarding_chrome.dart';

/// One option in a [MultiSelectQuestionStep]. Emoji-leading because the
/// reference video (Unrot ~0:35–0:50) leans on emoji to make
/// emotional self-statements feel *recognisable* — the user reads the
/// emoji before the text and reacts viscerally.
class MultiSelectOption {
  const MultiSelectOption({
    required this.value,
    required this.label,
    required this.emoji,
  });

  final String value;
  final String label;
  final String emoji;
}

/// Phase 111 · scrollable multi-select question.
///
/// Reference timestamp: ~0:35–0:50 (Unrot's "feelings after scrolling"
/// emotional checklist). Mechanic adapted, aesthetic kept FormAI-dark
/// premium. Each option is a tappable tile — tapping toggles selection
/// with a light haptic, the tile lights up neon, the trailing
/// selection-circle fills with a check icon. CTA at the bottom enables
/// when at least one option is selected.
///
/// The widget is a sibling of [InteractiveQuestionStep] / single-select
/// question patterns. Use it when the question is *self-recognition* —
/// users can claim multiple feelings, not just one.
class MultiSelectQuestionStep extends StatefulWidget {
  const MultiSelectQuestionStep({
    super.key,
    required this.title,
    this.subtitle,
    required this.options,
    required this.initialSelected,
    required this.onCommitted,
    this.ctaLabel = 'DEVAM ET',
    this.minSelection = 1,
  });

  final String title;
  final String? subtitle;
  final List<MultiSelectOption> options;
  final Set<String> initialSelected;
  final void Function(Set<String>) onCommitted;
  final String ctaLabel;

  /// Minimum number of options that must be selected for the CTA to
  /// enable. Default 1 — the user has to acknowledge at least one
  /// feeling. Set 0 to allow "skip" (CTA always enabled).
  final int minSelection;

  @override
  State<MultiSelectQuestionStep> createState() =>
      _MultiSelectQuestionStepState();
}

class _MultiSelectQuestionStepState extends State<MultiSelectQuestionStep> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initialSelected};
  }

  void _toggle(String value) {
    AppHaptics.secondaryTap();
    setState(() {
      if (_selected.contains(value)) {
        _selected.remove(value);
      } else {
        _selected.add(value);
      }
    });
  }

  void _commit() {
    if (_selected.length < widget.minSelection) return;
    widget.onCommitted(Set<String>.from(_selected));
  }

  @override
  Widget build(BuildContext context) {
    final ctaEnabled = _selected.length >= widget.minSelection;
    return Column(
      children: [
        StepTitle(title: widget.title, subtitle: widget.subtitle),
        const SizedBox(height: 18),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            physics: const BouncingScrollPhysics(),
            itemCount: widget.options.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final opt = widget.options[i];
              return _MultiSelectTile(
                option: opt,
                selected: _selected.contains(opt.value),
                onTap: () => _toggle(opt.value),
              );
            },
          ),
        ),
        PrimaryOnboardingButton(
          label: widget.ctaLabel,
          onPressed: ctaEnabled ? _commit : null,
        ),
      ],
    );
  }
}

class _MultiSelectTile extends StatelessWidget {
  const _MultiSelectTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final MultiSelectOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Subtle scale-up on selection — tactile feedback. 1.025 is small
    // enough to read as "pressed in", not "popping out."
    return AnimatedScale(
      scale: selected ? 1.025 : 1.0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.neon.withValues(alpha: 0.12),
          highlightColor: AppColors.neon.withValues(alpha: 0.06),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.neon.withValues(alpha: 0.16)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? AppColors.neon
                    : Colors.white.withValues(alpha: 0.14),
                width: selected ? 1.4 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.neon.withValues(alpha: 0.25),
                        blurRadius: 18,
                        spreadRadius: -3,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Text(
                  option.emoji,
                  style: const TextStyle(fontSize: 22, height: 1),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    option.label,
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.85),
                      fontSize: 15,
                      height: 1.3,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
                _SelectionCircle(selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionCircle extends StatelessWidget {
  const _SelectionCircle({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.neon : Colors.transparent,
        border: Border.all(
          color:
              selected ? AppColors.neon : Colors.white.withValues(alpha: 0.45),
          width: 1.5,
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: selected
            ? const Icon(
                Icons.check_rounded,
                key: ValueKey('check'),
                color: Colors.white,
                size: 14,
              )
            : const SizedBox.shrink(key: ValueKey('empty')),
      ),
    );
  }
}
