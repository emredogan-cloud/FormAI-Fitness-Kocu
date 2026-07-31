import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../core/widgets/cinematic_ai_presence.dart';
import '../../providers/wizard_provider.dart';
import '../widgets/coach_mood.dart';
import '../../../../l10n/app_localizations.dart';

/// Phase 133 · the first onboarding step that directly changes the
/// generated 30-day workout plan.
///
/// Form asks one binary equipment question right before the
/// pre-paywall summary. The answer persists to
/// `wizardProvider.hasEquipment`, gets saved into AppPreferences at
/// `onFinish`, and is read by the workout generator (via the
/// repository's fingerprint + filter pipeline) when it builds the
/// plan on the user's first dashboard visit.
///
/// Visual register: same cinematic AI-presence atmosphere the rest of
/// the product uses, with two large tap-target chip buttons in the
/// `bottomActions` slot instead of the chat-input pill. The "Form
/// is composing" illusion doesn't fit here — Form just asked
/// something explicit, and the user is being invited to answer.
///
/// Re-entry: if `wizardProvider.hasEquipment` is already set (back-
/// nav), still renders the question so the user can change their
/// answer. The current value is highlighted; tap to confirm or
/// switch.
class EquipmentCaptureStep extends ConsumerStatefulWidget {
  const EquipmentCaptureStep({super.key, required this.onContinue});
  final VoidCallback onContinue;

  @override
  ConsumerState<EquipmentCaptureStep> createState() =>
      _EquipmentCaptureStepState();
}

class _EquipmentCaptureStepState extends ConsumerState<EquipmentCaptureStep> {
  bool _advanced = false;

  void _select(bool hasEquipment) {
    if (_advanced) return;
    _advanced = true;
    AppHaptics.success();
    ref.read(wizardProvider.notifier).setHasEquipment(hasEquipment);
    // Tiny dwell so the chip's tap state registers visually before
    // the scene transition out. Mirrors the haptic-then-advance
    // cadence used by the other commitment beats.
    Future<void>.delayed(const Duration(milliseconds: 180), () {
      if (mounted) widget.onContinue();
    });
  }

  String _composeSubtitle(AppLocalizations l10n, WizardState s) {
    final name = _capitaliseFirst(s.name);
    return name != null
        ? l10n.equipmentQuestionNamed(name)
        : l10n.equipmentQuestion;
  }

  String? _capitaliseFirst(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length == 1) return trimmed.toUpperCase();
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final wizard = ref.watch(wizardProvider);
    final currentValue = wizard.hasEquipment;
    return CinematicAiPresence(
      title: AppLocalizations.of(context).equipmentOneMoreThing,
      subtitle: _composeSubtitle(AppLocalizations.of(context), wizard),
      subtitleTypewriter: true,
      composingPlaceholder: '',
      mood: CoachMood.thinking,
      // No auto-close — Form waits for the user to tap an option.
      autoCloseAfter: null,
      bottomActions: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _EquipmentOption(
              icon: Icons.fitness_center_rounded,
              label: AppLocalizations.of(context).equipmentYes,
              selected: currentValue == true,
              onTap: () => _select(true),
            ),
            const SizedBox(height: 12),
            _EquipmentOption(
              icon: Icons.self_improvement_rounded,
              label: AppLocalizations.of(context).equipmentNo,
              selected: currentValue == false,
              onTap: () => _select(false),
            ),
          ],
        ),
      ),
    );
  }
}

/// Large rounded tap target — matches the chip surface language used
/// elsewhere in the chat steps, sized larger because there are only
/// two options and the question is plan-affecting (deserves visual
/// weight). When the user is mid-edit (back-nav) and their previous
/// answer is the selection, the option highlights brighter so they
/// see what they previously chose.
class _EquipmentOption extends StatelessWidget {
  const _EquipmentOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderAlpha = selected ? 0.85 : 0.42;
    final glowAlpha = selected ? 0.28 : 0.14;
    final bgAlpha = selected ? 0.10 : 0.05;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        splashColor: AppColors.neon.withValues(alpha: 0.20),
        highlightColor: AppColors.neon.withValues(alpha: 0.08),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: bgAlpha),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.neon.withValues(alpha: borderAlpha),
              width: selected ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.neon.withValues(alpha: glowAlpha),
                blurRadius: 18,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.85),
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.95),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
