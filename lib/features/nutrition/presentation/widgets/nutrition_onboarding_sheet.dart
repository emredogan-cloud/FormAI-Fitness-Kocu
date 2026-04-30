import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/app_preferences.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../onboarding/presentation/widgets/interactive_question_step.dart';
import '../../../onboarding/providers/wizard_provider.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _neonAccent = Color(0xFF4DA6FF);
const Color _success = Color(0xFF22C55E);

// Phase 62 · the deferred nutrition sheet now mirrors the main AI
// onboarding 1:1: seven Fitify-style cards (every option has a side
// image with the dark left-blend gradient), AI-coach micro-copy on
// every step, a "Son N adım" countdown, and a five-phrase pulsing
// illusion screen with a 1/5 → 5/5 progress strip + trust booster.
// Asset paths point at bundled `photos/...` placeholders; the shared
// `OnboardingImage` falls back to the neon gradient + option icon
// until curated photography ships.

const List<String> _stepNames = [
  'nutrition_goal',
  'nutrition_diet_preference',
  'nutrition_allergies',
  'nutrition_meal_frequency',
  'nutrition_prep_time',
  'nutrition_water_intake',
  'nutrition_taste_preference',
];

/// Phase 46 · deferred nutrition onboarding.
///
/// The four nutrition questions used to live at the tail of the main
/// 13-step wizard. Phase 46 moved them into this sheet so the primary
/// onboarding can ship in 9 steps and the user sees their first big
/// win (the prediction screen) sooner. Phase 62 expanded the set to
/// seven cards (goal / diet / allergies / meals / prep / water /
/// taste) and brought the visual language up to parity with the main
/// AI onboarding. The sheet is presented the first time the user
/// opens the Beslenme tab; on completion the selections are merged
/// into `user_metrics` and the `hasCompletedNutritionPrefs` flag is
/// set so this never re-prompts.
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
///   `questions` → `calculating` (the V2 illusion screen) → `ready`.
/// Closing only happens when the calculating screen finishes its
/// "Hazır!" beat and fades the whole sheet out — no explicit CTA tap
/// needed, since the fade-to-tab transition is the reward.
enum _OnboardingPhase { questions, calculating }

class _NutritionOnboardingSheetState
    extends ConsumerState<NutritionOnboardingSheet> {
  // Phase 62 · seven-step flow. Order is locked by the PM brief:
  //   goal → diet → allergies → meals → prep → water → taste.
  static const int _total = 7;
  final PageController _controller = PageController();
  int _index = 0;
  bool _busy = false;
  _OnboardingPhase _phase = _OnboardingPhase.questions;

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

  /// Phase 62 · the V2 illusion screen owns its own lifecycle:
  /// pulsing AI core, 5-phrase cycle (1.5s each), 1/5 → 5/5 progress
  /// strip and trust booster. When the screen reaches "Hazır!" it
  /// fires a heavy haptic, flashes the glow, then calls `onFinished`
  /// to fade the sheet away. Persistence runs concurrently so the
  /// visible labor never adds real latency.
  void _enterCalculating() {
    if (_busy) return;
    setState(() {
      _busy = true;
      _phase = _OnboardingPhase.calculating;
    });
    unawaited(_persistPreferences());
  }

  Future<void> _persistPreferences() async {
    final wizard = ref.read(wizardProvider);
    final prefs = ref.read(appPreferencesProvider);
    // Merge the seven nutrition fields into whatever `user_metrics`
    // already holds — the fitness fields were saved at the end of
    // primary onboarding and must not be overwritten here.
    final existing = Map<String, dynamic>.from(prefs.userMetrics ?? const {});
    existing['nutritionGoal'] = wizard.nutritionGoal;
    existing['dietPreference'] = wizard.dietPreference;
    existing['allergies'] = wizard.allergies;
    existing['mealFrequency'] = wizard.mealFrequency;
    existing['prepTime'] = wizard.prepTime;
    existing['waterIntake'] = wizard.waterIntake;
    existing['tastePreference'] = wizard.tastePreference;
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
        return _AiIllusionScreen(onFinished: _dismiss);
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
              _NutritionGoalPage(onSelected: _next),
              _DietPreferencePage(onSelected: _next),
              _AllergiesPage(onSelected: _next),
              _MealFrequencyPage(onSelected: _next),
              _PrepTimePage(onSelected: _next),
              _WaterIntakePage(onSelected: _next),
              _TastePreferencePage(onSelected: _next, busy: _busy),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Phase 62 · AI Illusion Screen.
//
// Replaces the Phase-48 calculating + ready pair with a single screen
// that mirrors the main onboarding's `_AnalysisIllusionStep`: a
// continuously pulsing AI core, a 5-phrase cycle every 1.5s, a 1/5 →
// 5/5 segmented progress strip and a "10.000+ kişi…" trust booster
// at the bottom. When the closing "Hazır!" line lands the screen
// flashes the glow, fires `HapticFeedback.heavyImpact()` and triggers
// a smooth fade-out (`onFinished`) instead of a hard cut.
// ============================================================================

class _AiIllusionScreen extends StatefulWidget {
  const _AiIllusionScreen({required this.onFinished});
  final VoidCallback onFinished;

  @override
  State<_AiIllusionScreen> createState() => _AiIllusionScreenState();
}

class _AiIllusionScreenState extends State<_AiIllusionScreen>
    with TickerProviderStateMixin {
  /// 5 phrases × 1.5s = 7.5s before the smooth fade-out kicks in.
  /// Spec'd by the PM in first-person voice so the loading reads as
  /// the AI doing real work rather than a generic spinner caption.
  static const List<String> _phrases = [
    'Beslenme alışkanlıkların analiz ediliyor...',
    'Kalori ve makrolar hesaplanıyor...',
    'En uygun tarifler seçiliyor...',
    'Planın optimize ediliyor...',
    'Hazır!',
  ];
  static const Duration _phraseDuration = Duration(milliseconds: 1500);
  static const Duration _fadeOutDuration = Duration(milliseconds: 520);

  // Continuous "breathing" pulse for the orb — alpha + scale together
  // so it reads as a living core rather than a static disc.
  late final AnimationController _pulseCtrl;
  // Sheet-wide fade controller used for the final dismiss. Starts at
  // 1.0 (fully visible) and reverses to 0.0 the moment "Hazır!" lands.
  late final AnimationController _fadeCtrl;
  // One-shot flash overlay layered above the orb when "Hazır!" is
  // reached so the user sees a brief brightening before the fade.
  late final AnimationController _flashCtrl;

  Timer? _phraseTimer;
  int _phraseIndex = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: _fadeOutDuration,
      value: 1.0,
    );
    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    // Ladder timer (not modulo-cycling) — each tick advances by one
    // phrase; once we land on "Hazır!" we cancel and trigger the
    // finishing sequence so the closing line has a moment on screen
    // before the fade.
    _phraseTimer = Timer.periodic(_phraseDuration, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_phraseIndex >= _phrases.length - 1) {
        timer.cancel();
        return;
      }
      setState(() => _phraseIndex += 1);
      if (_phraseIndex == _phrases.length - 1) {
        _onReachReady();
      }
    });
  }

  void _onReachReady() {
    if (_finished) return;
    _finished = true;
    AppHaptics.heavyImpact();
    _flashCtrl.forward();
    // Hold on the "Hazır!" line for a beat so the user reads it
    // before the sheet starts fading away.
    Future<void>.delayed(_phraseDuration, () {
      if (!mounted) return;
      _fadeCtrl.reverse().whenComplete(() {
        if (mounted) widget.onFinished();
      });
    });
  }

  @override
  void dispose() {
    _phraseTimer?.cancel();
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    _flashCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeCtrl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: Column(
          children: [
            const SizedBox(height: 24),
            const Text(
              'Senin için en iyi plan hazırlanıyor',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
                height: 1.25,
              ),
            ),
            const Spacer(flex: 2),
            _IllusionCore(
              pulse: _pulseCtrl,
              flash: _flashCtrl,
            ),
            const SizedBox(height: 36),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.25),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  ),
                );
              },
              child: Text(
                _phrases[_phraseIndex],
                key: ValueKey<int>(_phraseIndex),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _phraseIndex == _phrases.length - 1
                      ? _success
                      : Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(height: 18),
            _IllusionProgressStrip(
              current: _phraseIndex + 1,
              total: _phrases.length,
            ),
            const Spacer(flex: 3),
            const _TrustBooster(),
          ],
        ),
      ),
    );
  }
}

/// Pulsing AI core: layered radial halo, gradient orb, and one-shot
/// flash overlay driven by the parent's `flash` controller. Kept as a
/// pure widget (no internal state) so the parent can coordinate the
/// breathing pulse with the finishing flash.
class _IllusionCore extends StatelessWidget {
  const _IllusionCore({required this.pulse, required this.flash});
  final Animation<double> pulse;
  final Animation<double> flash;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([pulse, flash]),
      builder: (context, _) {
        final t = pulse.value;
        final f = flash.value;
        // Breathing scale: 1.0 → 1.07. Capped low enough that the
        // motion never feels jittery on a 60Hz display.
        final scale = 1.0 + t * 0.07;
        // Glow alpha pulses with the breath; the flash adds an
        // additional one-shot brighten when "Hazır!" is reached.
        final glow = 0.35 + t * 0.4 + f * 0.45;
        final innerGlow = 0.25 + t * 0.25 + f * 0.5;
        return Transform.scale(
          scale: scale,
          child: SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer halo — soft radial wash that grows with the
                // breath so the orb looks like it's projecting light.
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _neon.withValues(alpha: 0.32 + f * 0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [_neon, _neonAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _neon.withValues(alpha: glow),
                        blurRadius: 32 + f * 16,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: _neonAccent.withValues(alpha: innerGlow),
                        blurRadius: 20,
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
                // Selection-style spinner ring around the orb so the
                // user feels active processing on top of the breath.
                SizedBox(
                  width: 156,
                  height: 156,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Segmented progress strip — five rounded bars that fill in lockstep
/// with the phrase cycle. Reads as "1/5 → 5/5" without needing a
/// separate counter underneath.
class _IllusionProgressStrip extends StatelessWidget {
  const _IllusionProgressStrip({
    required this.current,
    required this.total,
  });

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < total; i++) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            width: 36,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: i < current ? _neon : Colors.white.withValues(alpha: 0.14),
              boxShadow: i < current
                  ? [
                      BoxShadow(
                        color: _neon.withValues(alpha: 0.55),
                        blurRadius: 8,
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
          ),
          if (i != total - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

/// "Very bottom" trust booster strip per PM brief. Quiet styling — a
/// faint pill with low-contrast text so it reinforces credibility
/// without competing with the orb above.
class _TrustBooster extends StatelessWidget {
  const _TrustBooster();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: const Text(
        '🔥 10.000+ kişi bu sistemi kullanıyor',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
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
    // Phase 61B / 62 · "Son N adım" countdown reads as a finish-line
    // ladder ("last 3 steps") rather than the older assignment-counter
    // framing.
    final copy = remaining > 0 ? 'Son $remaining adım' : 'Son adım';
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
// Phase 62 · option-list builder + tap-press wrapper.
//
// `_NutritionOptionCard` wraps the shared [OptionCard] in a
// `GestureDetector` that briefly scales the card to ~1.04 and
// brightens the surrounding glow on press, then advances. The press
// feedback is what makes the card feel "committed" before the page
// flips — without it the tap reads as too-instant on the V2 flow.
// ============================================================================

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
          _NutritionOptionCard(
            option: opt,
            selected: selectedValue == opt.value,
            disabled: disabled,
            onPicked: onPicked,
          ),
          if (opt != options.last) const SizedBox(height: 10),
        ],
      ],
    ),
  );
}

class _NutritionOptionCard extends StatefulWidget {
  const _NutritionOptionCard({
    required this.option,
    required this.selected,
    required this.disabled,
    required this.onPicked,
  });

  final InteractiveOption option;
  final bool selected;
  final bool disabled;
  final ValueChanged<String> onPicked;

  @override
  State<_NutritionOptionCard> createState() => _NutritionOptionCardState();
}

class _NutritionOptionCardState extends State<_NutritionOptionCard> {
  bool _pressed = false;

  void _handlePick() {
    if (widget.disabled) return;
    AppHaptics.secondaryTap();
    setState(() => _pressed = true);
    // Hold the press scale + glow for one easeOut beat so the user
    // sees the card commit before the page advances. 220 ms keeps the
    // total tap-to-flip latency in line with the main onboarding's
    // commit window without feeling slow.
    Future<void>.delayed(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      widget.onPicked(widget.option.value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final glow = widget.selected || _pressed;
    return AnimatedScale(
      scale: _pressed ? 1.04 : (widget.selected ? 1.02 : 1.0),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: glow
              ? [
                  BoxShadow(
                    color: _neon.withValues(alpha: _pressed ? 0.55 : 0.32),
                    blurRadius: _pressed ? 28 : 18,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: OptionCard(
          option: widget.option,
          selected: widget.selected,
          dimmed: false,
          onTap: _handlePick,
        ),
      ),
    );
  }
}

// ============================================================================
// Pages — Phase 62 · seven Fitify-style cards.
//
// Order: nutritionGoal → dietPreference → allergies → mealFrequency →
//        prepTime → waterIntake → tastePreference.
// Every option carries a bundled `photos/...` placeholder so
// `OnboardingImage` renders the side-image layout. Where the asset
// hasn't shipped, the gradient + icon fallback keeps the cards on
// the same visual rhythm as the rest of the flow.
// ============================================================================

class _NutritionGoalPage extends ConsumerWidget {
  const _NutritionGoalPage({required this.onSelected});
  final VoidCallback onSelected;

  static const List<InteractiveOption> _options = [
    InteractiveOption(
      value: 'yag_yakimi',
      label: 'Yağ Yakımı',
      helper: 'Daha sıkı bir vücuda doğru.',
      icon: Icons.local_fire_department_rounded,
      imageAsset: 'photos/nutrition_goal_fat_loss.webp',
    ),
    InteractiveOption(
      value: 'kas_kazanimi',
      label: 'Kas Kazanımı',
      helper: 'Hacim ve güç odaklı beslen.',
      icon: Icons.fitness_center_rounded,
      imageAsset: 'photos/nutrition_goal_muscle.webp',
    ),
    InteractiveOption(
      value: 'dengeli',
      label: 'Dengeli Beslenme',
      helper: 'Sağlıklı ve sürdürülebilir bir düzen.',
      icon: Icons.spa_rounded,
      imageAsset: 'photos/nutrition_goal_balanced.webp',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(wizardProvider).nutritionGoal;
    void pick(String value) {
      ref.read(wizardProvider.notifier).setNutritionGoal(value);
      onSelected();
    }

    return Column(
      children: [
        const _PageTitle(
          title: 'Beslenme hedefin nedir?',
          subtitle: 'Sana en uygun makro dengesini buradan kuracağım.',
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

class _DietPreferencePage extends ConsumerWidget {
  const _DietPreferencePage({required this.onSelected});
  final VoidCallback onSelected;

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
      onSelected();
    }

    return Column(
      children: [
        const _PageTitle(
          title: 'Diyet tercihin nedir?',
          subtitle: 'Senin yaşam tarzına uygun tarifleri seçeceğim.',
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
      onSelected();
    }

    return Column(
      children: [
        const _PageTitle(
          title: 'Herhangi bir gıda alerjin var mı?',
          subtitle: 'Sana zarar verebilecek içerikleri tamamen çıkarıyorum.',
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
      onSelected();
    }

    return Column(
      children: [
        const _PageTitle(
          title: 'Günde kaç öğün yersin?',
          subtitle: 'Günlük enerjini en verimli şekilde dağıtıyorum.',
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
  const _PrepTimePage({required this.onSelected});
  final VoidCallback onSelected;

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
      onSelected();
    }

    return Column(
      children: [
        const _PageTitle(
          title: 'Yemek hazırlamak için ne kadar vaktin var?',
          subtitle: 'Hayat temposuna uygun tarifler seçiyorum.',
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

class _WaterIntakePage extends ConsumerWidget {
  const _WaterIntakePage({required this.onSelected});
  final VoidCallback onSelected;

  static const List<InteractiveOption> _options = [
    InteractiveOption(
      value: 'cok_az',
      label: 'Çok az (0-1L)',
      helper: 'Gün içinde nadiren su içerim.',
      icon: Icons.water_drop_outlined,
      imageAsset: 'photos/water_low.webp',
    ),
    InteractiveOption(
      value: 'orta',
      label: 'Orta (1-2L)',
      helper: 'Düzenli ama yeterli olmayabilir.',
      icon: Icons.water_drop_rounded,
      imageAsset: 'photos/water_medium.webp',
    ),
    InteractiveOption(
      value: 'iyi',
      label: 'İyi (2L+)',
      helper: 'Hidrasyon önceliğim.',
      icon: Icons.water_rounded,
      imageAsset: 'photos/water_high.webp',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(wizardProvider).waterIntake;
    void pick(String value) {
      ref.read(wizardProvider.notifier).setWaterIntake(value);
      onSelected();
    }

    return Column(
      children: [
        const _PageTitle(
          title: 'Günlük su tüketimin nasıl?',
          subtitle: 'Hidrasyon hedefini buna göre ayarlıyorum.',
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

class _TastePreferencePage extends ConsumerWidget {
  const _TastePreferencePage({
    required this.onSelected,
    required this.busy,
  });
  final VoidCallback onSelected;
  final bool busy;

  static const List<InteractiveOption> _options = [
    InteractiveOption(
      value: 'tatli',
      label: 'Tatlı seviyorum',
      helper: 'Meyveli ve hafif tatlı tarifleri öne çıkar.',
      icon: Icons.cake_rounded,
      imageAsset: 'photos/taste_sweet.webp',
    ),
    InteractiveOption(
      value: 'tuzlu',
      label: 'Tuzlu seviyorum',
      helper: 'Etli, baharatlı ve doyurucu tarifler.',
      icon: Icons.kebab_dining_rounded,
      imageAsset: 'photos/taste_savory.webp',
    ),
    InteractiveOption(
      value: 'karisik',
      label: 'Karışık',
      helper: 'İkisini de dengeli şekilde severim.',
      icon: Icons.swap_horiz_rounded,
      imageAsset: 'photos/taste_mixed.webp',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(wizardProvider).tastePreference;
    void pick(String value) {
      ref.read(wizardProvider.notifier).setTastePreference(value);
      onSelected();
    }

    return Column(
      children: [
        const _PageTitle(
          title: 'Tat tercihin nedir?',
          subtitle: 'Eşit puanlı tarifler arasında bunu önceliklendiriyorum.',
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
