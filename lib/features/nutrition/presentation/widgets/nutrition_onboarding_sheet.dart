import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/app_preferences.dart';
import '../../../onboarding/presentation/widgets/interactive_question_step.dart';
import '../../../onboarding/providers/wizard_provider.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _success = Color(0xFF22C55E);

// Phase 61A · the four nutrition pages now standardise on the
// Phase-60H Fitify-style [OptionCard], pointing at bundled
// `photos/...` paths instead of the previous Unsplash URLs. Until the
// PM ships the curated food photography (diet_standard.webp etc.),
// `OnboardingImage`'s placeholder gradient + the option's icon stand
// in — that fallback is the same the rest of the onboarding uses, so
// the sheet stays visually coherent with the main wizard whether or
// not the assets have landed yet.

const List<String> _stepNames = [
  'nutrition_diet_preference',
  'nutrition_allergies',
  'nutrition_meal_frequency',
  'nutrition_prep_time',
];

/// Phase 46 · deferred nutrition onboarding.
///
/// The four nutrition questions used to live at the tail of the main
/// 13-step wizard. Phase 46 moved them into this sheet so the primary
/// onboarding can ship in 9 steps and the user sees their first big
/// win (the prediction screen) sooner. The sheet is presented the
/// first time the user opens the Beslenme tab; on completion the
/// selections are merged into `user_metrics` and the
/// `hasCompletedNutritionPrefs` flag is set so this never re-prompts.
///
/// Visually the sheet is a bottom-anchored modal at 95% of the
/// screen height with a purple top seam, so it reads as a panel
/// surfacing *over* the nutrition tab rather than a new screen
/// replacing it.
Future<void> showNutritionOnboardingSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    enableDrag: false,
    isDismissible: false,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _NutritionOnboardingSheetShell(),
  );
}

class _NutritionOnboardingSheetShell extends StatelessWidget {
  const _NutritionOnboardingSheetShell();

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.95,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A0B3D), Colors.black],
              stops: [0.0, 0.4],
            ),
            border: Border(
              top: BorderSide(color: _neon, width: 1.2),
            ),
          ),
          child: const SafeArea(
            top: false,
            child: NutritionOnboardingSheet(),
          ),
        ),
      ),
    );
  }
}

class NutritionOnboardingSheet extends ConsumerStatefulWidget {
  const NutritionOnboardingSheet({super.key});

  @override
  ConsumerState<NutritionOnboardingSheet> createState() =>
      _NutritionOnboardingSheetState();
}

/// Phase 48.1 · the sheet's overall lifecycle. The user moves linearly:
///   `questions` → `calculating` (2.5 s "labor illusion") → `ready`.
/// Closing only happens when the user taps the explicit "Menüye Git"
/// CTA on the `ready` panel — closing on the timer would feel abrupt
/// and short-circuit the feeling of value the labor illusion creates.
enum _OnboardingPhase { questions, calculating, ready }

class _NutritionOnboardingSheetState
    extends ConsumerState<NutritionOnboardingSheet> {
  static const int _total = 4;
  static const Duration _laborIllusionDuration = Duration(milliseconds: 2500);
  final PageController _controller = PageController();
  int _index = 0;
  bool _busy = false;
  _OnboardingPhase _phase = _OnboardingPhase.questions;
  Timer? _laborTimer;

  @override
  void initState() {
    super.initState();
    // Step index 0 fires immediately — the PageView never emits an
    // `onPageChanged` for the first page, so without this the funnel
    // would miss the "sheet opened" event.
    AnalyticsService.instance.nutritionOnboardingStepCompleted(
      stepIndex: 0,
      stepName: _stepNames.first,
    );
  }

  @override
  void dispose() {
    _laborTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index >= _total - 1) {
      _enterCalculating();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_index == 0) return;
    _controller.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  /// Phase 48.1 · "labor illusion".
  ///
  /// The user has answered all four nutrition questions; we now show a
  /// calculating panel for ~2.5 seconds before flipping to the ready
  /// state. Persistence (saveUserMetrics + completeNutritionOnboarding
  /// + analytics) runs concurrently with the visible delay so the
  /// transition feels like real work, not artificial latency. The
  /// sheet does NOT close yet — only the explicit "Menüye Git" tap on
  /// the ready panel triggers `_dismiss`.
  void _enterCalculating() {
    if (_busy) return;
    setState(() {
      _busy = true;
      _phase = _OnboardingPhase.calculating;
    });
    unawaited(_persistPreferences());
    _laborTimer?.cancel();
    _laborTimer = Timer(_laborIllusionDuration, () {
      if (!mounted) return;
      setState(() => _phase = _OnboardingPhase.ready);
    });
  }

  Future<void> _persistPreferences() async {
    final wizard = ref.read(wizardProvider);
    final prefs = ref.read(appPreferencesProvider);
    // Merge the four nutrition fields into whatever `user_metrics`
    // already holds — the fitness fields were saved at the end of
    // primary onboarding and must not be overwritten here.
    final existing = Map<String, dynamic>.from(prefs.userMetrics ?? const {});
    existing['dietPreference'] = wizard.dietPreference;
    existing['allergies'] = wizard.allergies;
    existing['mealFrequency'] = wizard.mealFrequency;
    existing['prepTime'] = wizard.prepTime;
    await prefs.saveUserMetrics(existing);
    await prefs.completeNutritionOnboarding();
    AnalyticsService.instance.nutritionOnboardingCompleted();
  }

  void _dismiss() {
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _OnboardingPhase.questions:
        return _buildQuestions();
      case _OnboardingPhase.calculating:
        return const _CalculatingPanel();
      case _OnboardingPhase.ready:
        return _ReadyPanel(onContinue: _dismiss);
    }
  }

  Widget _buildQuestions() {
    return Column(
      children: [
        _SheetHeader(
          step: _index + 1,
          total: _total,
          onBack: _index == 0 ? null : _back,
        ),
        Expanded(
          child: PageView(
            controller: _controller,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (i) {
              setState(() => _index = i);
              AnalyticsService.instance.nutritionOnboardingStepCompleted(
                stepIndex: i,
                stepName: i < _stepNames.length ? _stepNames[i] : 'unknown_$i',
              );
            },
            children: [
              _DietPreferencePage(onSelected: _next),
              _AllergiesPage(onSelected: _next),
              _MealFrequencyPage(onSelected: _next),
              _PrepTimePage(onSelected: _next, busy: _busy),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Phase 48.1 · Labor Illusion + Ready panels.
//
// `_CalculatingPanel` runs for `_laborIllusionDuration` (~2.5 s) and
// rotates two reassuring status lines so the user feels work happening
// instead of an instantaneous-but-jarring sheet close. The animation
// is a pulsing neon halo around the FormAI logo + a CircularProgress
// indicator at the top — kept self-contained so a future redesign can
// swap the visual without touching the lifecycle code.
//
// `_ReadyPanel` lands the moment after with a green checkmark, the
// "Planınız Hazır!" headline, and a single "Menüye Git" CTA. The
// sheet does not auto-dismiss; the CTA is the only exit so the user
// always feels they completed the flow themselves.
// ============================================================================

class _CalculatingPanel extends StatefulWidget {
  const _CalculatingPanel();

  @override
  State<_CalculatingPanel> createState() => _CalculatingPanelState();
}

class _CalculatingPanelState extends State<_CalculatingPanel>
    with SingleTickerProviderStateMixin {
  static const List<String> _statusLines = [
    'Makrolarınız hesaplanıyor...',
    'Size özel tarifler seçiliyor...',
    'Beslenme planınız hazırlanıyor...',
  ];

  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  Timer? _statusTimer;
  int _statusIndex = 0;

  @override
  void initState() {
    super.initState();
    // Cycle through the status lines so the panel reads as "multiple
    // things happening" instead of a single static spinner.
    _statusTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (!mounted) return;
      setState(() => _statusIndex = (_statusIndex + 1) % _statusLines.length);
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              final glow = 0.35 + _ctrl.value * 0.45;
              return Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [_neon, Color(0xFF4DA6FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _neon.withValues(alpha: glow),
                      blurRadius: 32,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 28),
          const Text(
            'Planın Hazırlanıyor',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: Text(
              _statusLines[_statusIndex],
              key: ValueKey<int>(_statusIndex),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: _neon.withValues(alpha: 0.12),
              border: Border.all(color: _neon.withValues(alpha: 0.45)),
            ),
            child: const Text(
              'Lütfen bekle',
              style: TextStyle(
                color: _neon,
                fontSize: 11,
                letterSpacing: 2,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadyPanel extends StatelessWidget {
  const _ReadyPanel({required this.onContinue});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  _success.withValues(alpha: 0.85),
                  _success.withValues(alpha: 0.45),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _success.withValues(alpha: 0.55),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 64,
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Planınız Hazır!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Tercihlerine göre tarifler ve makrolar seçildi. '
            'Beslenme menünü hemen incelemeye başlayabilirsin.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onContinue,
              icon: const Icon(Icons.restaurant_rounded, size: 18),
              label: const Text('Menüye Git'),
              style: FilledButton.styleFrom(
                backgroundColor: _success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Shared chrome
// ============================================================================

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.step,
    required this.total,
    required this.onBack,
  });

  final int step;
  final int total;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final progress = step / total;
    final remaining = total - step;
    final copy = remaining <= 1 ? 'Neredeyse bitti!' : '$remaining soru kaldı';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: onBack == null
                    ? null
                    : Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: onBack,
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white70,
                            size: 18,
                          ),
                        ),
                      ),
              ),
              Expanded(
                child: Text(
                  'Beslenme Tercihlerin',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                  ),
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(_neon),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            copy,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _PageTitle extends StatelessWidget {
  const _PageTitle({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// Pages — adapted from the removed `_DietPreferenceStep`, `_AllergiesStep`,
// `_MealFrequencyStep` and `_PrepTimeStep` widgets in onboarding_screen.dart.
//
// Phase 61A · all four pages share the same Fitify-style [OptionCard]
// the main onboarding uses, with bundled `photos/...` paths on every
// option (including allergies + prep-time, which were icon-only before).
// Where the bundled asset hasn't shipped yet, `OnboardingImage`'s
// gradient + icon fallback stands in — same fallback the rest of the
// onboarding shows, so the sheet stays visually coherent.
// ============================================================================

/// Compact builder shared by all four pages. Renders a column of
/// [OptionCard]s with consistent spacing and the existing 220 ms quick
/// commit (deliberately shorter than the main wizard's 1.5 s window
/// since this sheet is a deferred *post-onboarding* surface).
Widget _nutritionOptionsList({
  required List<InteractiveOption> options,
  required String? selectedValue,
  required ValueChanged<String> onPicked,
  bool disabled = false,
}) {
  return SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
    child: Column(
      children: [
        for (final opt in options) ...[
          OptionCard(
            option: opt,
            selected: selectedValue == opt.value,
            dimmed: false,
            onTap: disabled ? () {} : () => onPicked(opt.value),
          ),
          if (opt != options.last) const SizedBox(height: 10),
        ],
      ],
    ),
  );
}

class _DietPreferencePage extends ConsumerWidget {
  const _DietPreferencePage({required this.onSelected});
  final VoidCallback onSelected;

  // Visual concepts the PM provided in the brief: grilled meat / plant
  // bowl / vibrant plant plate / high-fat keto plate. Asset paths are
  // bundled `photos/diet_*.webp` placeholders that fall back to a
  // gradient + the option icon until the curated photography lands.
  static const List<InteractiveOption> _options = [
    InteractiveOption(
      value: 'standart',
      label: 'Standart',
      helper: 'Her şeyi yiyebilirim.',
      icon: Icons.restaurant_menu_rounded,
      imageAsset: 'photos/diet_standard.webp',
    ),
    InteractiveOption(
      value: 'vejetaryen',
      label: 'Vejetaryen',
      helper: 'Et yemem, yumurta/süt olabilir.',
      icon: Icons.grass_rounded,
      imageAsset: 'photos/diet_vegetarian.webp',
    ),
    InteractiveOption(
      value: 'vegan',
      label: 'Vegan',
      helper: 'Hiçbir hayvansal ürün tüketmem.',
      icon: Icons.eco_rounded,
      imageAsset: 'photos/diet_vegan.webp',
    ),
    InteractiveOption(
      value: 'ketojenik',
      label: 'Ketojenik',
      helper: 'Düşük karbonhidrat, yüksek yağ.',
      icon: Icons.local_fire_department_rounded,
      imageAsset: 'photos/diet_keto.webp',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(wizardProvider).dietPreference;
    void pick(String value) {
      ref.read(wizardProvider.notifier).setDietPreference(value);
      Future<void>.delayed(const Duration(milliseconds: 220), onSelected);
    }

    return Column(
      children: [
        const _PageTitle(
          title: 'Diyet Tercihin Nedir?',
          subtitle: 'Tarifleri bu tercihine göre filtreleyeceğiz.',
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _nutritionOptionsList(
            options: _options,
            selectedValue: selected,
            onPicked: pick,
          ),
        ),
      ],
    );
  }
}

class _AllergiesPage extends ConsumerWidget {
  const _AllergiesPage({required this.onSelected});
  final VoidCallback onSelected;

  // Phase 61A · was icon-only / empty gradient in pre-60H. Each option
  // now points at a bundled `photos/allergy_*.webp` placeholder per PM
  // brief (none / nuts / dairy / gluten visuals). Until the photos
  // ship, OnboardingImage's gradient + icon fallback keeps the cards
  // looking like the rest of the flow.
  static const List<InteractiveOption> _options = [
    InteractiveOption(
      value: 'yok',
      label: 'Yok',
      helper: 'Bilinen bir alerjim yok.',
      icon: Icons.verified_user_rounded,
      imageAsset: 'photos/allergy_none.webp',
    ),
    InteractiveOption(
      value: 'kuruyemis',
      label: 'Kuruyemiş',
      helper: 'Badem, fıstık, ceviz vb.',
      icon: Icons.emoji_nature_rounded,
      imageAsset: 'photos/allergy_nuts.webp',
    ),
    InteractiveOption(
      value: 'sut_urunleri',
      label: 'Süt Ürünleri',
      helper: 'Süt, peynir, yoğurt vb.',
      icon: Icons.icecream_rounded,
      imageAsset: 'photos/allergy_dairy.webp',
    ),
    InteractiveOption(
      value: 'gluten',
      label: 'Glüten',
      helper: 'Buğday, arpa, çavdar vb.',
      icon: Icons.bakery_dining_rounded,
      imageAsset: 'photos/allergy_gluten.webp',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(wizardProvider).allergies;
    void pick(String value) {
      ref.read(wizardProvider.notifier).setAllergies(value);
      Future<void>.delayed(const Duration(milliseconds: 220), onSelected);
    }

    return Column(
      children: [
        const _PageTitle(
          title: 'Herhangi bir gıda alerjin var mı?',
          subtitle: 'Tariflerden bu içeriği çıkaracağız.',
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _nutritionOptionsList(
            options: _options,
            selectedValue: selected,
            onPicked: pick,
          ),
        ),
      ],
    );
  }
}

class _MealFrequencyPage extends ConsumerWidget {
  const _MealFrequencyPage({required this.onSelected});
  final VoidCallback onSelected;

  static const List<InteractiveOption> _options = [
    InteractiveOption(
      value: '2_ogun',
      label: '2 Öğün',
      helper: 'Aralıklı oruç (16:8) tarzı beslenirim.',
      icon: Icons.hourglass_top_rounded,
      imageAsset: 'photos/meals_2.webp',
    ),
    InteractiveOption(
      value: '3_ogun',
      label: '3 Öğün',
      helper: 'Standart — kahvaltı, öğle, akşam.',
      icon: Icons.restaurant_rounded,
      imageAsset: 'photos/meals_3.webp',
    ),
    InteractiveOption(
      value: '4_ogun',
      label: '4+ Öğün',
      helper: 'Atıştırmalık severim.',
      icon: Icons.lunch_dining_rounded,
      imageAsset: 'photos/meals_4.webp',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(wizardProvider).mealFrequency;
    void pick(String value) {
      ref.read(wizardProvider.notifier).setMealFrequency(value);
      Future<void>.delayed(const Duration(milliseconds: 220), onSelected);
    }

    return Column(
      children: [
        const _PageTitle(
          title: 'Günde kaç öğün yersin?',
          subtitle: 'Kalori dağılımını öğün sayına göre planlayacağız.',
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _nutritionOptionsList(
            options: _options,
            selectedValue: selected,
            onPicked: pick,
          ),
        ),
      ],
    );
  }
}

class _PrepTimePage extends ConsumerWidget {
  const _PrepTimePage({required this.onSelected, required this.busy});
  final VoidCallback onSelected;
  final bool busy;

  // Phase 61A · was icon-only previously. PM's visual concepts: quick
  // = simple yogurt/salad shot; slow = kitchen cooking scene. Until
  // those photos ship, the OnboardingImage fallback keeps the cards
  // consistent with the rest of the flow.
  static const List<InteractiveOption> _options = [
    InteractiveOption(
      value: 'hizli',
      label: 'Hızlı & Pratik',
      helper: '10-15 dakika içinde hazırlanan tarifler.',
      icon: Icons.timer_rounded,
      imageAsset: 'photos/prep_quick.webp',
    ),
    InteractiveOption(
      value: 'yavas',
      label: 'Mutfakta Vakit',
      helper: '30+ dakika. Pişirmekten keyif alırım.',
      icon: Icons.soup_kitchen_rounded,
      imageAsset: 'photos/prep_slow.webp',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(wizardProvider).prepTime;
    void pick(String value) {
      ref.read(wizardProvider.notifier).setPrepTime(value);
      Future<void>.delayed(const Duration(milliseconds: 220), onSelected);
    }

    return Column(
      children: [
        const _PageTitle(
          title: 'Yemek hazırlamak için ne kadar vaktin var?',
          subtitle: 'Tarifleri süresine göre dengeleyeceğiz.',
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _nutritionOptionsList(
            options: _options,
            selectedValue: selected,
            onPicked: pick,
            disabled: busy,
          ),
        ),
      ],
    );
  }
}
