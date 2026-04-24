import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/app_preferences.dart';
import '../../../onboarding/presentation/widgets/photo_option_card.dart';
import '../../../onboarding/providers/wizard_provider.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _success = Color(0xFF22C55E);

// Food + meal-frequency photos — duplicated from `onboarding_screen.dart`
// (where the nutrition steps used to live) so the deferred flow keeps
// the same visual identity. URLs are exercised in production via
// `supabase_seed_recipes.sql` so they are guaranteed to resolve.
const String _dietStandardImg =
    'https://images.unsplash.com/photo-1544025162-d76694265947?w=800&q=80';
const String _dietVegetarianImg =
    'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800&q=80';
const String _dietVeganImg =
    'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=800&q=80';
const String _dietKetoImg =
    'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=800&q=80';
const String _mealFreq2Img =
    'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=800&q=80';
const String _mealFreq3Img =
    'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=800&q=80';
const String _mealFreq4Img =
    'https://images.unsplash.com/photo-1525351484163-7529414344d8?w=800&q=80';

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
// ============================================================================

/// Phase 48 · fixed minimum card height for the four nutrition steps so
/// short Android screens (e.g. 5"-class devices, ~640 px logical height
/// after status / nav bars) can scroll instead of throwing a 17 px
/// `RenderFlex` overflow when four cards + the page title don't fit.
const double _kNutritionCardMinHeight = 110;

class _DietPreferencePage extends ConsumerWidget {
  const _DietPreferencePage({required this.onSelected});
  final VoidCallback onSelected;

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              children: [
                _NutritionCardSlot(
                  child: PhotoOptionCard(
                    image: _dietStandardImg,
                    fallbackIcon: Icons.restaurant_menu,
                    title: 'Standart',
                    subtitle: 'Her şeyi yiyebilirim.',
                    selected: selected == 'standart',
                    onTap: () => pick('standart'),
                  ),
                ),
                const SizedBox(height: 10),
                _NutritionCardSlot(
                  child: PhotoOptionCard(
                    image: _dietVegetarianImg,
                    fallbackIcon: Icons.grass,
                    title: 'Vejetaryen',
                    subtitle: 'Et yemem, yumurta/süt olabilir.',
                    selected: selected == 'vejetaryen',
                    onTap: () => pick('vejetaryen'),
                  ),
                ),
                const SizedBox(height: 10),
                _NutritionCardSlot(
                  child: PhotoOptionCard(
                    image: _dietVeganImg,
                    fallbackIcon: Icons.eco,
                    title: 'Vegan',
                    subtitle: 'Hiçbir hayvansal ürün tüketmem.',
                    selected: selected == 'vegan',
                    onTap: () => pick('vegan'),
                  ),
                ),
                const SizedBox(height: 10),
                _NutritionCardSlot(
                  child: PhotoOptionCard(
                    image: _dietKetoImg,
                    fallbackIcon: Icons.local_fire_department,
                    title: 'Ketojenik',
                    subtitle: 'Düşük karbonhidrat, yüksek yağ.',
                    selected: selected == 'ketojenik',
                    onTap: () => pick('ketojenik'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Wrapper that stamps a deterministic minimum height on every option
/// card inside the four nutrition wizard pages. Without it the cards
/// shrink to fit and lose their photographic anchoring; with it the
/// page either fits exactly or scrolls — never overflows.
class _NutritionCardSlot extends StatelessWidget {
  const _NutritionCardSlot({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: _kNutritionCardMinHeight, child: child);
  }
}

class _AllergiesPage extends ConsumerWidget {
  const _AllergiesPage({required this.onSelected});
  final VoidCallback onSelected;

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              children: [
                _NutritionCardSlot(
                  child: PhotoOptionCard(
                    fallbackIcon: Icons.verified_user,
                    title: 'Yok',
                    subtitle: 'Bilinen bir alerjim yok.',
                    selected: selected == 'yok',
                    onTap: () => pick('yok'),
                  ),
                ),
                const SizedBox(height: 10),
                _NutritionCardSlot(
                  child: PhotoOptionCard(
                    fallbackIcon: Icons.emoji_nature,
                    title: 'Kuruyemiş',
                    subtitle: 'Badem, fıstık, ceviz vb.',
                    selected: selected == 'kuruyemis',
                    onTap: () => pick('kuruyemis'),
                  ),
                ),
                const SizedBox(height: 10),
                _NutritionCardSlot(
                  child: PhotoOptionCard(
                    fallbackIcon: Icons.icecream,
                    title: 'Süt Ürünleri',
                    subtitle: 'Süt, peynir, yoğurt vb.',
                    selected: selected == 'sut_urunleri',
                    onTap: () => pick('sut_urunleri'),
                  ),
                ),
                const SizedBox(height: 10),
                _NutritionCardSlot(
                  child: PhotoOptionCard(
                    fallbackIcon: Icons.bakery_dining,
                    title: 'Glüten',
                    subtitle: 'Buğday, arpa, çavdar vb.',
                    selected: selected == 'gluten',
                    onTap: () => pick('gluten'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MealFrequencyPage extends ConsumerWidget {
  const _MealFrequencyPage({required this.onSelected});
  final VoidCallback onSelected;

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              children: [
                _NutritionCardSlot(
                  child: PhotoOptionCard(
                    image: _mealFreq2Img,
                    fallbackIcon: Icons.hourglass_top,
                    title: '2 Öğün',
                    subtitle: 'Aralıklı oruç (16:8) tarzı beslenirim.',
                    selected: selected == '2_ogun',
                    onTap: () => pick('2_ogun'),
                  ),
                ),
                const SizedBox(height: 10),
                _NutritionCardSlot(
                  child: PhotoOptionCard(
                    image: _mealFreq3Img,
                    fallbackIcon: Icons.restaurant,
                    title: '3 Öğün',
                    subtitle: 'Standart — kahvaltı, öğle, akşam.',
                    selected: selected == '3_ogun',
                    onTap: () => pick('3_ogun'),
                  ),
                ),
                const SizedBox(height: 10),
                _NutritionCardSlot(
                  child: PhotoOptionCard(
                    image: _mealFreq4Img,
                    fallbackIcon: Icons.lunch_dining,
                    title: '4+ Öğün',
                    subtitle: 'Atıştırmalık severim.',
                    selected: selected == '4_ogun',
                    onTap: () => pick('4_ogun'),
                  ),
                ),
              ],
            ),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              children: [
                _NutritionCardSlot(
                  child: PhotoOptionCard(
                    fallbackIcon: Icons.timer,
                    title: 'Hızlı & Pratik',
                    subtitle: '10-15 dakika içinde hazırlanan tarifler.',
                    selected: selected == 'hizli',
                    onTap: busy ? () {} : () => pick('hizli'),
                  ),
                ),
                const SizedBox(height: 10),
                _NutritionCardSlot(
                  child: PhotoOptionCard(
                    fallbackIcon: Icons.soup_kitchen,
                    title: 'Mutfakta Vakit',
                    subtitle: '30+ dakika. Pişirmekten keyif alırım.',
                    selected: selected == 'yavas',
                    onTap: busy ? () {} : () => pick('yavas'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
