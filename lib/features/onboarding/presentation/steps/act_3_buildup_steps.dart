import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/app_preferences.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../l10n/app_localizations.dart';
import '../../providers/wizard_provider.dart';
import '../onboarding_chrome.dart';
import '../widgets/ai_insight_card.dart';
import '../widgets/hybrid_question_step.dart';
import '../widgets/interactive_question_step.dart';

/// Act 3 · Transformation buildup.
///
/// All seven data-collection steps live in one file: gender, goal,
/// experience (hybrid), daily-minutes, activity (hybrid), physical-data
/// (Cupertino wheels), pain-point (hybrid). They share the same
/// "InteractiveQuestionStep / HybridQuestionStep" contract, so grouping
/// them keeps related copy + tokens in a single file.

// ─────────────────────────── gender ─────────────────────────────────────────

class GenderStep extends ConsumerWidget {
  const GenderStep({super.key, required this.onCommitted});
  final VoidCallback onCommitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(wizardProvider).gender;
    final l10n = AppLocalizations.of(context);
    return InteractiveQuestionStep(
      title: l10n.onbGenderTitle,
      subtitle: l10n.onbGenderSubtitle,
      initialValue: current?.name,
      feedbackText: l10n.onbGenderFeedback,
      options: [
        InteractiveOption(
          value: 'female',
          label: l10n.onbGenderFemale,
          icon: Icons.female_rounded,
          imageAsset: 'photos/cinsiyetseçimikadın.webp', // i18n-ignore
        ),
        InteractiveOption(
          value: 'male',
          label: l10n.onbGenderMale,
          icon: Icons.male_rounded,
          imageAsset: 'photos/cinsiyetseçimierkek.webp', // i18n-ignore
        ),
        InteractiveOption(
          value: 'other',
          label: l10n.onbGenderOther,
          icon: Icons.transgender_rounded,
        ),
      ],
      bottomSlot: AiInsightCard(
        headline: l10n.onbAiNoteHeadline,
        body: l10n.onbGenderAiNote,
      ),
      onCommitted: (value) {
        final picked = Gender.values.firstWhere(
          (g) => g.name == value,
          orElse: () => Gender.other,
        );
        ref.read(wizardProvider.notifier).setGender(picked);
        onCommitted();
      },
    );
  }
}

// ─────────────────────────── goal ───────────────────────────────────────────

class GoalStep extends ConsumerWidget {
  const GoalStep({super.key, required this.onCommitted});
  final VoidCallback onCommitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(wizardProvider).goal;
    final l10n = AppLocalizations.of(context);
    return InteractiveQuestionStep(
      title: l10n.onbGoalTitle,
      subtitle: l10n.onbGoalSubtitle,
      initialValue: current,
      feedbackText: l10n.onbGoalFeedback,
      // Phase 104 · predictive empathy. Form observes the choice
      // rather than just confirming it — each answer reads as Form
      // already understanding what kind of plan suits this user.
      feedbackTextBuilder: (value) => switch (value) {
        'belly_burn' => l10n.onbGoalFeedbackBellyBurn,
        'muscle_gain' => l10n.onbGoalFeedbackMuscleGain,
        'fitness_look' => l10n.onbGoalFeedbackFitnessLook,
        'strength' => l10n.onbGoalFeedbackStrength,
        _ => null,
      },
      options: [
        InteractiveOption(
          value: 'belly_burn',
          label: l10n.goalBellyBurnLower,
          icon: Icons.local_fire_department_rounded,
          imageAsset: 'photos/hedefinneSıkılaşmak.webp', // i18n-ignore
        ),
        InteractiveOption(
          value: 'muscle_gain',
          label: l10n.goalMuscleGainLower,
          icon: Icons.fitness_center_rounded,
          imageAsset: 'photos/hedefinneHacimKazanmak.webp',
        ),
        InteractiveOption(
          value: 'fitness_look',
          label: l10n.goalFitnessLookLower,
          icon: Icons.auto_awesome_rounded,
          imageAsset: 'photos/hedefinneSadeceSix-Pack.webp',
        ),
        InteractiveOption(
          value: 'strength',
          label: l10n.goalStrengthLower,
          icon: Icons.bolt_rounded,
          imageAsset: 'photos/hedef_guclenmek.webp',
        ),
      ],
      onCommitted: (value) {
        ref.read(wizardProvider.notifier).setGoal(value);
        onCommitted();
      },
    );
  }
}

// ─────────────────────────── experience (hybrid) ────────────────────────────

class ExperienceStep extends ConsumerWidget {
  const ExperienceStep({super.key, required this.onCommitted});
  final VoidCallback onCommitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wizard = ref.watch(wizardProvider);
    final l10n = AppLocalizations.of(context);
    return HybridQuestionStep(
      title: l10n.onbExperienceTitle,
      subtitle: l10n.onbExperienceSubtitle,
      feedbackText: l10n.onbExperienceFeedback,
      feedbackTextBuilder: (value) => switch (value) {
        'none' => l10n.onbExperienceFeedbackNone,
        'occasional' => l10n.onbExperienceFeedbackOccasional,
        'regular' => l10n.onbExperienceFeedbackRegular,
        _ => null,
      },
      initialCardValue: wizard.experienceLevel,
      initialDescription: wizard.experienceDescription,
      options: [
        InteractiveOption(
          value: 'none',
          label: l10n.onbExperienceNone,
          icon: Icons.spa_rounded,
          helper: l10n.onbExperienceNoneHelper,
        ),
        InteractiveOption(
          value: 'occasional',
          label: l10n.onbExperienceOccasional,
          icon: Icons.directions_walk_rounded,
          helper: l10n.onbExperienceOccasionalHelper,
        ),
        InteractiveOption(
          value: 'regular',
          label: l10n.onbExperienceRegular,
          icon: Icons.fitness_center_rounded,
          helper: l10n.onbExperienceRegularHelper,
        ),
      ],
      inputLabel: l10n.onbExperienceInputLabel,
      inputHint: l10n.onbExperienceInputHint,
      onCardCommitted: (value) {
        ref.read(wizardProvider.notifier).setExperienceLevel(value);
        onCommitted();
      },
      onTextCommitted: (text) {
        ref.read(wizardProvider.notifier).setExperienceDescription(text);
        onCommitted();
      },
    );
  }
}

// ─────────────────────────── daily-minutes ──────────────────────────────────

class DailyMinutesStep extends ConsumerWidget {
  const DailyMinutesStep({super.key, required this.onCommitted});
  final VoidCallback onCommitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(wizardProvider).dailyMinutes;
    final l10n = AppLocalizations.of(context);
    return InteractiveQuestionStep(
      title: l10n.onbMinutesTitle,
      subtitle: l10n.onbMinutesSubtitle,
      initialValue: current,
      feedbackText: l10n.onbMinutesFeedback,
      feedbackTextBuilder: (value) => switch (value) {
        '10_15' => l10n.onbMinutesFeedbackShort,
        '20_30' => l10n.onbMinutesFeedbackMedium,
        '45_plus' => l10n.onbMinutesFeedbackLong,
        _ => null,
      },
      options: [
        InteractiveOption(
          value: '10_15',
          label: l10n.onbMinutesShort,
          icon: Icons.timer_outlined,
          helper: l10n.onbMinutesShortHelper,
        ),
        InteractiveOption(
          value: '20_30',
          label: l10n.onbMinutesMedium,
          icon: Icons.access_time_rounded,
          helper: l10n.onbMinutesMediumHelper,
        ),
        InteractiveOption(
          value: '45_plus',
          label: l10n.onbMinutesLong,
          icon: Icons.local_fire_department_outlined,
          helper: l10n.onbMinutesLongHelper,
        ),
      ],
      bottomSlot: AiInsightCard(
        headline: l10n.onbFormNoteHeadline,
        body: l10n.onbMinutesAiNote,
      ),
      onCommitted: (value) {
        ref.read(wizardProvider.notifier).setDailyMinutes(value);
        onCommitted();
      },
    );
  }
}

// ─────────────────────────── activity (hybrid, enum-backed) ─────────────────

class ActivityStep extends ConsumerStatefulWidget {
  const ActivityStep({super.key, required this.onCommitted});
  final VoidCallback onCommitted;

  @override
  ConsumerState<ActivityStep> createState() => _ActivityStepState();
}

class _ActivityStepState extends ConsumerState<ActivityStep>
    with TickerProviderStateMixin {
  /// Hoisted so the path fits on one line with its `i18n-ignore`
  /// marker — the asset filename is Turkish, which is enough for the
  /// hardcoded-string gate to read it as copy.
  static const String _lightActivityImage =
      'photos/günlükaktivitenhafifhareketli.webp'; // i18n-ignore

  /// The option list carries copy, so it is built per-locale rather
  /// than held as a `const` field. The `value` tokens are the wizard
  /// state identities and never move.
  static List<InteractiveOption> _optionsFor(AppLocalizations l10n) => [
        InteractiveOption(
          value: 'sedentary',
          label: l10n.activityDesk,
          icon: Icons.chair_outlined,
          imageAsset: 'photos/günlükaktivitenmasabaşı.webp', // i18n-ignore
        ),
        InteractiveOption(
          value: 'light',
          label: l10n.activityLight,
          icon: Icons.directions_walk_rounded,
          imageAsset: _lightActivityImage, // i18n-ignore
        ),
        InteractiveOption(
          value: 'active',
          label: l10n.activityVeryActive,
          icon: Icons.directions_run_rounded,
          imageAsset: 'photos/günlükaktivitenneÇokAktif.webp', // i18n-ignore
        ),
      ];

  /// Phase 104 · activity-step empathy. Each lifestyle answer gets a
  /// reading-back observation from Form rather than a generic
  /// confirmation. Falls back to a neutral line before a card is
  /// picked (the banner is invisible then, but the slot is built).
  String _resolveFeedbackText(AppLocalizations l10n) {
    return switch (_selectedCardValue) {
      'sedentary' => l10n.onbActivityFeedbackSedentary,
      'light' => l10n.onbActivityFeedbackLight,
      'active' => l10n.onbActivityFeedbackActive,
      _ => l10n.onbActivityFeedback,
    };
  }

  String? _selectedCardValue;
  bool _committingCard = false;

  late final TextEditingController _textCtrl;
  late final FocusNode _focusNode;
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
    final w = ref.read(wizardProvider);
    _selectedCardValue = w.activityLevel?.name;
    _textCtrl = TextEditingController(text: w.activityDescription ?? '');
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
    final level = ActivityLevel.values.firstWhere(
      (a) => a.name == value,
      orElse: () => ActivityLevel.light,
    );
    ref.read(wizardProvider.notifier).setActivityLevel(level);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    widget.onCommitted();
  }

  void _commitCustom() {
    if (_committingCard) return;
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    AppHaptics.secondaryTap();
    ref.read(wizardProvider.notifier).setActivityDescription(text);
    widget.onCommitted();
  }

  @override
  Widget build(BuildContext context) {
    final ctaEnabled = _textCtrl.text.trim().isNotEmpty;
    final l10n = AppLocalizations.of(context);
    final options = _optionsFor(l10n);
    return Column(
      children: [
        StepTitle(
          title: l10n.onbActivityTitle,
          subtitle: l10n.onbActivitySubtitle,
        ),
        const SizedBox(height: 14),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final opt in options) ...[
                  OptionCard(
                    option: opt,
                    selected: _selectedCardValue == opt.value,
                    dimmed: _committingCard && _selectedCardValue != opt.value,
                    onTap: () => _pickCard(opt.value),
                  ),
                  if (opt != options.last) const SizedBox(height: 8),
                ],
                const SizedBox(height: 12),
                FeedbackBanner(
                  fade: _feedbackFade,
                  slide: _feedbackSlide,
                  text: _resolveFeedbackText(l10n),
                ),
                const SizedBox(height: 14),
                _ActivityFreeTextInput(
                  controller: _textCtrl,
                  focusNode: _focusNode,
                  enabled: !_committingCard,
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
                          child: Text(l10n.onbContinueCta),
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

class _ActivityFreeTextInput extends StatelessWidget {
  const _ActivityFreeTextInput({
    required this.controller,
    required this.focusNode,
    required this.enabled,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                l10n.onbActivityInputLabel,
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
            hintText: l10n.onbActivityInputHint,
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

// ─────────────────────────── physical-data (Cupertino wheels) ───────────────

/// The stored birth year, or null if preferences are not available.
///
/// Guarded because this is a **convenience default for one wheel**, and
/// a convenience must not decide whether the screen renders at all.
/// `appPreferencesProvider` is built on `sharedPreferencesProvider`,
/// which throws unless a host overrides it — the layout sweeps, the RTL
/// sweep and the English sweep all mount this step without one, and
/// making them provide it would mean every future host has to know that
/// a wheel's initial value has a dependency.
int? _birthYearOrNull(WidgetRef ref) {
  try {
    return ref.read(appPreferencesProvider).birthYear;
  } catch (_) {
    return null;
  }
}

/// Whole years between [birthYear] and now, or null when the age gate
/// never ran (a legacy install) or stored something implausible.
///
/// Deliberately a year subtraction and not a birthday calculation: the
/// gate only ever collected a year, so pretending to know the month
/// would be inventing precision. Off by at most one, which is inside the
/// wheel's own granularity.
int? _ageFromBirthYear(int? birthYear) {
  if (birthYear == null) return null;
  final age = DateTime.now().year - birthYear;
  return (age >= 13 && age <= 100) ? age : null;
}

class PhysicalDataStep extends ConsumerStatefulWidget {
  const PhysicalDataStep({super.key, required this.onContinue});
  final VoidCallback onContinue;

  @override
  ConsumerState<PhysicalDataStep> createState() => _PhysicalDataStepState();
}

class _PhysicalDataStepState extends ConsumerState<PhysicalDataStep>
    with SingleTickerProviderStateMixin {
  static const int _minAge = 18;
  static const int _maxAge = 80;
  static const int _minHeight = 120;
  static const int _maxHeight = 220;
  static const int _minWeight = 30;
  static const int _maxWeight = 200;

  late final FixedExtentScrollController _ageCtrl;
  late final FixedExtentScrollController _heightCtrl;
  late final FixedExtentScrollController _weightCtrl;

  late final AnimationController _feedbackCtrl;
  bool _calculating = false;

  @override
  void initState() {
    super.initState();
    final w = ref.read(wizardProvider);
    // The age gate two screens ago asked for a birth year and stored it.
    // This wheel then opened on a flat 25 regardless, so somebody who
    // had just said 2000 was shown 25 and had to scroll to 26 — the app
    // asking the same question twice and disagreeing with itself about
    // the answer. Prefer what the user already told us; 25 stays as the
    // floor for installs from before the gate existed.
    final fromGate = _ageFromBirthYear(_birthYearOrNull(ref));
    final initialAge =
        (w.age ?? fromGate ?? 25).clamp(_minAge, _maxAge) - _minAge;
    final initialHeight =
        (w.heightCm ?? 170).clamp(_minHeight, _maxHeight) - _minHeight;
    final initialWeight =
        (w.weightKg ?? 70).clamp(_minWeight, _maxWeight) - _minWeight;
    _ageCtrl = FixedExtentScrollController(initialItem: initialAge);
    _heightCtrl = FixedExtentScrollController(initialItem: initialHeight);
    _weightCtrl = FixedExtentScrollController(initialItem: initialWeight);
    _feedbackCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    // Pre-populate state with the initial pickers so a user who taps
    // DEVAM without scrolling still gets a well-formed wizard payload.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(wizardProvider.notifier);
      notifier.setAge(_minAge + initialAge);
      notifier.setHeight(_minHeight + initialHeight);
      notifier.setWeight(_minWeight + initialWeight);
    });
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _feedbackCtrl.dispose();
    super.dispose();
  }

  Future<void> _commit() async {
    if (_calculating) return;
    AppHaptics.secondaryTap();
    setState(() => _calculating = true);
    _feedbackCtrl.forward();
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        StepTitle(
          title: l10n.onbBodyTitle,
          subtitle: l10n.onbBodySubtitle,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _CupertinoWheel(
                    label: l10n.profileFieldAge,
                    controller: _ageCtrl,
                    min: _minAge,
                    max: _maxAge,
                    onChanged: (v) =>
                        ref.read(wizardProvider.notifier).setAge(v),
                  ),
                ),
                Expanded(
                  child: _CupertinoWheel(
                    label: l10n.profileFieldHeight,
                    suffix: 'cm',
                    controller: _heightCtrl,
                    min: _minHeight,
                    max: _maxHeight,
                    onChanged: (v) =>
                        ref.read(wizardProvider.notifier).setHeight(v),
                  ),
                ),
                Expanded(
                  child: _CupertinoWheel(
                    label: l10n.profileFieldWeight,
                    suffix: 'kg',
                    controller: _weightCtrl,
                    min: _minWeight,
                    max: _maxWeight,
                    onChanged: (v) =>
                        ref.read(wizardProvider.notifier).setWeight(v),
                  ),
                ),
              ],
            ),
          ),
        ),
        FadeTransition(
          opacity: _feedbackCtrl,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation(AppColors.neon),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    l10n.onbBodyCalculating,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        PrimaryOnboardingButton(
          label: _calculating ? l10n.onbBodyCtaBusy : l10n.onbBodyCta,
          onPressed: _calculating ? null : _commit,
        ),
      ],
    );
  }
}

class _CupertinoWheel extends StatelessWidget {
  const _CupertinoWheel({
    required this.label,
    required this.controller,
    required this.min,
    required this.max,
    required this.onChanged,
    this.suffix,
  });

  final String label;
  final String? suffix;
  final FixedExtentScrollController controller;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.2,
            ),
          ),
        ),
        Expanded(
          child: CupertinoPicker(
            scrollController: controller,
            itemExtent: 44,
            squeeze: 1.1,
            diameterRatio: 1.5,
            magnification: 1.08,
            useMagnifier: true,
            backgroundColor: Colors.transparent,
            selectionOverlay: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppColors.neon.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                  bottom: BorderSide(
                    color: AppColors.neon.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                ),
              ),
            ),
            onSelectedItemChanged: (i) {
              HapticFeedback.selectionClick();
              onChanged(min + i);
            },
            children: [
              for (int v = min; v <= max; v++)
                Center(
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                      children: [
                        TextSpan(text: '$v'),
                        if (suffix != null)
                          TextSpan(
                            text: ' $suffix',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── pain-point (hybrid) ────────────────────────────

class PainPointStep extends ConsumerWidget {
  const PainPointStep({super.key, required this.onCommitted});
  final VoidCallback onCommitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wizard = ref.watch(wizardProvider);
    final l10n = AppLocalizations.of(context);
    return HybridQuestionStep(
      title: l10n.onbPainTitle,
      subtitle: l10n.onbPainSubtitle,
      feedbackText: l10n.onbPainFeedback,
      feedbackTextBuilder: (value) => switch (value) {
        'motivation' => l10n.onbPainFeedbackMotivation,
        'consistency' => l10n.onbPainFeedbackConsistency,
        'no_idea' => l10n.onbPainFeedbackNoIdea,
        'diet' => l10n.onbPainFeedbackDiet,
        _ => null,
      },
      initialCardValue: wizard.painPoint,
      initialDescription: wizard.painPointDescription,
      // Phase 114 · option order tuned per audit §3.6 to put the
      // shame-trigger answer ("Ne yapacağımı bilmiyorum") last so
      // the user has already normalised the choice through the
      // first three options before considering it. Order:
      // consistency (most common, normalising) → motivation
      // (acceptable everyday struggle) → diet (concrete) →
      // no_idea (the answer that requires the most courage).
      options: [
        InteractiveOption(
          value: 'consistency',
          label: l10n.onbPainConsistency,
          icon: Icons.repeat_rounded,
        ),
        InteractiveOption(
          value: 'motivation',
          label: l10n.onbPainMotivation,
          icon: Icons.local_fire_department_outlined,
        ),
        InteractiveOption(
          value: 'diet',
          label: l10n.onbPainDiet,
          icon: Icons.restaurant_menu_rounded,
        ),
        InteractiveOption(
          value: 'no_idea',
          label: l10n.onbPainNoIdea,
          icon: Icons.help_outline_rounded,
        ),
      ],
      inputLabel: l10n.onbPainInputLabel,
      inputHint: l10n.onbPainInputHint,
      onCardCommitted: (value) {
        ref.read(wizardProvider.notifier).setPainPoint(value);
        onCommitted();
      },
      onTextCommitted: (text) {
        ref.read(wizardProvider.notifier).setPainPointDescription(text);
        onCommitted();
      },
    );
  }
}
