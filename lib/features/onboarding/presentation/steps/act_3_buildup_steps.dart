import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
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
    return InteractiveQuestionStep(
      title: 'Cinsiyetin?',
      subtitle: 'Programını sana göre kalibre edelim.',
      initialValue: current?.name,
      feedbackText: 'Programını sana özel kalibre ediyorum.',
      options: const [
        InteractiveOption(
          value: 'female',
          label: 'Kadın',
          icon: Icons.female_rounded,
          imageAsset: 'photos/cinsiyetseçimikadın.webp',
        ),
        InteractiveOption(
          value: 'male',
          label: 'Erkek',
          icon: Icons.male_rounded,
          imageAsset: 'photos/cinsiyetseçimierkek.webp',
        ),
        InteractiveOption(
          value: 'other',
          label: 'Diğer',
          icon: Icons.transgender_rounded,
        ),
      ],
      bottomSlot: const AiInsightCard(
        headline: '💡 Yapay Zeka Notu',
        body: 'Fiziksel özelliklerine ve biyomekaniğine en uygun '
            'antrenman iskeletini kurabilmek için cinsiyet verini '
            'analiz ediyoruz.',
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
    return InteractiveQuestionStep(
      title: 'Hedefin ne?',
      subtitle: 'Sana en uygun planı bunun üzerine inşa edeceğim.',
      initialValue: current,
      feedbackText:
          '🔥 Harika seçim! Bu hedefle başlayanların çoğu 30 gün içinde '
          'fark görüyor.',
      options: const [
        InteractiveOption(
          value: 'belly_burn',
          label: 'Göbek eritmek',
          icon: Icons.local_fire_department_rounded,
          imageAsset: 'photos/hedefinneSıkılaşmak.webp',
        ),
        InteractiveOption(
          value: 'muscle_gain',
          label: 'Kas yapmak',
          icon: Icons.fitness_center_rounded,
          imageAsset: 'photos/hedefinneHacimKazanmak.webp',
        ),
        InteractiveOption(
          value: 'fitness_look',
          label: 'Daha fit görünmek',
          icon: Icons.auto_awesome_rounded,
          imageAsset: 'photos/hedefinneSadeceSix-Pack.webp',
        ),
        InteractiveOption(
          value: 'strength',
          label: 'Güçlenmek',
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
    return HybridQuestionStep(
      title: 'Daha önce spor yaptın mı?',
      subtitle: 'Programın zorluğunu seviyene göre kalibre edeceğim.',
      feedbackText: 'Tamam, programını buna göre ayarlıyorum.',
      initialCardValue: wizard.experienceLevel,
      initialDescription: wizard.experienceDescription,
      options: const [
        InteractiveOption(
          value: 'none',
          label: 'Hiç yapmadım',
          icon: Icons.spa_rounded,
          helper:
              'Hiç sorun değil. Sıfırdan başlayıp hızlı gelişim sağlayacağız.',
        ),
        InteractiveOption(
          value: 'occasional',
          label: 'Ara sıra yaptım',
          icon: Icons.directions_walk_rounded,
          helper: 'Harika, temelini güçlendirip daha iyi sonuç alacağız.',
        ),
        InteractiveOption(
          value: 'regular',
          label: 'Düzenli yapıyorum',
          icon: Icons.fitness_center_rounded,
          helper: 'Seviyeni bir üst noktaya taşıyacağız.',
        ),
      ],
      inputLabel: 'Spor geçmişinizi anlatırsanız daha iyi yardımcı oluruz',
      inputHint: 'Örn: Lisede basketbol oynardım ama 2 yıldır spor '
          'yapmıyorum...',
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
    return InteractiveQuestionStep(
      title: 'Günde ne kadar zaman ayırabilirsin?',
      subtitle: 'Antrenman uzunluğunu buna göre planlayacağım.',
      initialValue: current,
      feedbackText: 'Bu süreyle bile ciddi sonuç alabilirsin.',
      options: const [
        InteractiveOption(
          value: '10_15',
          label: '10–15 dakika',
          icon: Icons.timer_outlined,
          helper: 'Kısa sürede maksimum verim alacağız.',
        ),
        InteractiveOption(
          value: '20_30',
          label: '20–30 dakika',
          icon: Icons.access_time_rounded,
          helper: 'En ideal aralık. Hızlı gelişim mümkün.',
        ),
        InteractiveOption(
          value: '45_plus',
          label: '45+ dakika',
          icon: Icons.local_fire_department_outlined,
          helper: 'Daha agresif ilerleyebiliriz.',
        ),
      ],
      bottomSlot: const AiInsightCard(
        headline: '💡 Form Diyor ki:',
        body: 'Günde sadece 15 dakika bile, hiç yapmamaktan %100 daha '
            'etkilidir. İstikrar, süreden çok daha önemlidir.',
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
  static const List<InteractiveOption> _options = [
    InteractiveOption(
      value: 'sedentary',
      label: 'Masa başı',
      icon: Icons.chair_outlined,
      imageAsset: 'photos/günlükaktivitenmasabaşı.webp',
    ),
    InteractiveOption(
      value: 'light',
      label: 'Hafif hareketli',
      icon: Icons.directions_walk_rounded,
      imageAsset: 'photos/günlükaktivitenhafifhareketli.webp',
    ),
    InteractiveOption(
      value: 'active',
      label: 'Çok aktif',
      icon: Icons.directions_run_rounded,
      imageAsset: 'photos/günlükaktivitenneÇokAktif.webp',
    ),
  ];
  static const String _feedbackText =
      'Kişisel kalori ve program yoğunluğunu buna göre ayarlıyorum.';

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
    return Column(
      children: [
        const StepTitle(
          title: 'Günlük aktiviten?',
          subtitle: 'Kalori ihtiyacını buna göre hesaplıyorum.',
        ),
        const SizedBox(height: 14),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final opt in _options) ...[
                  OptionCard(
                    option: opt,
                    selected: _selectedCardValue == opt.value,
                    dimmed:
                        _committingCard && _selectedCardValue != opt.value,
                    onTap: () => _pickCard(opt.value),
                  ),
                  if (opt != _options.last) const SizedBox(height: 8),
                ],
                const SizedBox(height: 12),
                FeedbackBanner(
                  fade: _feedbackFade,
                  slide: _feedbackSlide,
                  text: _feedbackText,
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
                'Gününü açıklarsan daha iyi yardımcı olabiliriz',
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
            hintText: 'Günüm genelde masa başında geçiyor ama akşam yürüyüş '
                'yapıyorum...',
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
    final initialAge = (w.age ?? 25).clamp(_minAge, _maxAge) - _minAge;
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
    return Column(
      children: [
        const StepTitle(
          title: 'Vücut bilgilerin',
          subtitle: 'Tam kişiselleştirme için kısa bir veri girişi.',
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _CupertinoWheel(
                    label: 'YAŞ',
                    controller: _ageCtrl,
                    min: _minAge,
                    max: _maxAge,
                    onChanged: (v) =>
                        ref.read(wizardProvider.notifier).setAge(v),
                  ),
                ),
                Expanded(
                  child: _CupertinoWheel(
                    label: 'BOY',
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
                    label: 'KİLO',
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
          child: const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation(AppColors.neon),
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Metabolizmanı hesaplıyorum…',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
        PrimaryOnboardingButton(
          label: _calculating ? 'HESAPLANIYOR…' : 'DEVAM',
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
    return HybridQuestionStep(
      title: 'Seni en çok zorlayan ne?',
      subtitle: 'Programın bu noktayı çözecek şekilde kurulacak.',
      feedbackText: 'Bunu çözmek için planını optimize edeceğim.',
      initialCardValue: wizard.painPoint,
      initialDescription: wizard.painPointDescription,
      options: const [
        InteractiveOption(
          value: 'motivation',
          label: 'Motivasyon',
          icon: Icons.local_fire_department_outlined,
        ),
        InteractiveOption(
          value: 'consistency',
          label: 'Süreklilik',
          icon: Icons.repeat_rounded,
        ),
        InteractiveOption(
          value: 'no_idea',
          label: 'Ne yapacağımı bilmiyorum',
          icon: Icons.help_outline_rounded,
        ),
        InteractiveOption(
          value: 'diet',
          label: 'Diyet',
          icon: Icons.restaurant_menu_rounded,
        ),
      ],
      inputLabel: 'Seni tam olarak neyin zorladığını detaylandırabilirsin',
      inputHint: 'Örn: Akşamları çok yorgun oluyorum ve diyeti '
          'bozuyorum...',
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
