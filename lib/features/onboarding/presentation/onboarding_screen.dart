import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/legal_urls.dart';
import '../providers/wizard_provider.dart';
import 'widgets/illusion_step.dart';
import 'widgets/photo_option_card.dart';
import 'widgets/wheel_column.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _neonAccent = Color(0xFF4DA6FF);
// 13 pages total: 2 hook screens + 7 body/fitness questions + 4 nutrition
// questions (phase 21) + 1 illusion/finish screen.
const int _totalSteps = 13;
const int _hookSteps = 2;

/// Phase 42 · analytics labels per onboarding page. Index-aligned with
/// the `PageView.children` list below so the funnel reads the same
/// names the code uses.
const List<String> _stepNames = [
  'welcome',
  'coach_intro',
  'gender',
  'age',
  'body_metrics',
  'current_physique',
  'target_physique',
  'activity',
  'diet_preference',
  'allergies',
  'meal_frequency',
  'prep_time',
  'illusion',
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index >= _totalSteps - 1) return;
    _controller.nextPage(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_index == 0) return;
    _controller.previousPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    final wizard = ref.read(wizardProvider);
    final prefs = ref.read(appPreferencesProvider);
    // Persist the full wizard payload BEFORE flipping the firstTime flag
    // so the workout generator (which reads `userMetrics['targetPhysique']`
    // and `userMetrics['activityLevel']`) has everything it needs on the
    // very first /prediction render — without this save, guests complete
    // onboarding with an empty `user_metrics` and the generator silently
    // falls back to sixpack + beginner.
    await prefs.saveUserMetrics(wizard.toJson());
    await prefs.completeOnboarding(goal: wizard.targetPhysique?.name);
    if (!mounted) return;

    // Frictionless auth: silently create an anonymous Supabase session so
    // the user can preview their personalized prediction without being
    // shoved into a sign-up form. If anon auth is disabled in the project
    // (or the network is offline), fall back to the explicit /auth screen.
    try {
      await Supabase.instance.client.auth.signInAnonymously();
    } catch (e, st) {
      AppLogger.error(
        'Anonymous sign-in failed, falling back to /auth',
        e,
        stackTrace: st,
        category: 'onboarding',
      );
      if (!mounted) return;
      context.go(AppRoutes.auth);
      return;
    }
    // Phase 42: now that the user has a session, raise the iOS ATT
    // prompt BEFORE navigating. The ~400 ms internal debounce keeps
    // the prompt from getting eaten by the prediction route's push.
    await AnalyticsService.instance.requestAttIfNeeded();
    if (!mounted) return;
    context.go(AppRoutes.prediction);
  }

  @override
  Widget build(BuildContext context) {
    final showHeader = _index >= _hookSteps;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            if (showHeader)
              _WizardHeader(
                step: _index - _hookSteps + 1,
                total: _totalSteps - _hookSteps,
                onBack: _index == 0 ? null : _back,
              ),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) {
                  setState(() => _index = i);
                  // Funnel event — drop-off per step is the most actionable
                  // metric for onboarding optimisation (Phase 46 plans an
                  // A/B on the 13→9 step squeeze).
                  AnalyticsService.instance.onboardingStepCompleted(
                    stepIndex: i,
                    stepName:
                        i < _stepNames.length ? _stepNames[i] : 'unknown_$i',
                  );
                },
                children: [
                  _WelcomeStep(onStart: _next),
                  _CoachIntroStep(onContinue: _next),
                  _GenderStep(onSelected: _next),
                  _AgeStep(onContinue: _next),
                  _BodyMetricsStep(onContinue: _next),
                  _CurrentPhysiqueStep(onSelected: _next),
                  _TargetPhysiqueStep(onSelected: _next),
                  _ActivityStep(onSelected: _next),
                  _DietPreferenceStep(onSelected: _next),
                  _AllergiesStep(onSelected: _next),
                  _MealFrequencyStep(onSelected: _next),
                  _PrepTimeStep(onSelected: _next),
                  IllusionStep(onComplete: _finish),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    // Full-bleed background shot + dark gradient overlay so the neon copy
    // stays readable against whatever photo ships in photos/. The overlay
    // is stronger at the bottom so the CTA sits on a solid patch.
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'photos/ilkkarşılamaanaekranarkaplanı.webp',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.4,
                colors: [Color(0xFF1A0B3D), Colors.black],
              ),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.35),
                Colors.black.withValues(alpha: 0.55),
                Colors.black.withValues(alpha: 0.9),
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
            child: Column(
              children: [
                const Spacer(flex: 3),
                ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    colors: [_neon, _neonAccent],
                  ).createShader(rect),
                  child: const Text(
                    'Vücudunu Yapay Zeka İle Şekillendir',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                      letterSpacing: 0.5,
                      shadows: [
                        Shadow(blurRadius: 24, color: Colors.black87),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Telefonunun kamerası ile her tekrarını izleyen, '
                  'formunu düzelten ve seni gerçek bir koç gibi motive '
                  'eden kişisel yapay zeka asistanın.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.5,
                    shadows: [Shadow(blurRadius: 18, color: Colors.black87)],
                  ),
                ),
                const Spacer(flex: 2),
                SizedBox(
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: _neon.withValues(alpha: 0.55),
                          blurRadius: 28,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: FilledButton(
                      onPressed: onStart,
                      style: FilledButton.styleFrom(
                        backgroundColor: _neon,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 22),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                          fontSize: 18,
                        ),
                      ),
                      child: const Text('BAŞLA'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const _WelcomeLegalLine(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WelcomeLegalLine extends StatefulWidget {
  const _WelcomeLegalLine();

  @override
  State<_WelcomeLegalLine> createState() => _WelcomeLegalLineState();
}

class _WelcomeLegalLineState extends State<_WelcomeLegalLine> {
  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()
      ..onTap = () => openLegalUrl(LegalUrls.terms);
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => openLegalUrl(LegalUrls.privacy);
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const baseStyle = TextStyle(
      color: Colors.white70,
      fontSize: 11,
      shadows: [Shadow(blurRadius: 12, color: Colors.black)],
    );
    final linkStyle = baseStyle.copyWith(
      color: const Color(0xFF00F0FF),
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: const Color(0xFF00F0FF).withValues(alpha: 0.8),
    );
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          const TextSpan(text: 'Devam ederek '),
          TextSpan(
            text: 'Kullanım Şartları',
            style: linkStyle,
            recognizer: _termsTap,
          ),
          const TextSpan(text: ' ve '),
          TextSpan(
            text: 'Gizlilik Politikası',
            style: linkStyle,
            recognizer: _privacyTap,
          ),
          const TextSpan(text: '’nı kabul edersin.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _CoachIntroStep extends StatelessWidget {
  const _CoachIntroStep({required this.onContinue});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'photos/merhababenseninkişiselyapayzekakoçunumyeniarkaplan.webp',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const ColoredBox(color: Color(0xFF0E0729)),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.2),
                Colors.black.withValues(alpha: 0.55),
                Colors.black.withValues(alpha: 0.9),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
            child: Column(
              children: [
                const Spacer(flex: 2),
                const _PulsingCoachAvatar(),
                const SizedBox(height: 28),
                const Text(
                  'Merhaba 👋',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    shadows: [Shadow(blurRadius: 20, color: Colors.black)],
                  ),
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Ben senin kişisel yapay zeka koçunum. '
                    'Şimdi sana birkaç hızlı soru soracağım ve '
                    'tamamen sana özel bir program çıkaracağım.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.55,
                      shadows: [Shadow(blurRadius: 16, color: Colors.black87)],
                    ),
                  ),
                ),
                const Spacer(flex: 2),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onContinue,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('DEVAM ET'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _neon,
                      foregroundColor: Colors.white,
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
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PulsingCoachAvatar extends StatefulWidget {
  const _PulsingCoachAvatar();

  @override
  State<_PulsingCoachAvatar> createState() => _PulsingCoachAvatarState();
}

class _PulsingCoachAvatarState extends State<_PulsingCoachAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final glow = 0.35 + _c.value * 0.4;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _neon.withValues(alpha: glow),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _neon, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: _neon.withValues(alpha: 0.6),
                    blurRadius: 26,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'photos/kişiselyapayzekakoçfoto.webp',
                  fit: BoxFit.cover,
                  // Center-fit the face and lean into the dark halo when the
                  // webp can't be decoded so we don't flash a grey circle.
                  errorBuilder: (_, __, ___) => Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_neon, _neonAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.smart_toy,
                      color: Colors.white,
                      size: 56,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WizardHeader extends StatelessWidget {
  const _WizardHeader({
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              const Text(
                'FormAI',
                style: TextStyle(
                  color: _neon,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.5,
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '$step/$total',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(_neon),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: _neon,
            foregroundColor: Colors.black,
            disabledBackgroundColor: Colors.white12,
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 2.5,
              fontSize: 14,
            ),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class _GenderStep extends ConsumerWidget {
  const _GenderStep({required this.onSelected});
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(wizardProvider).gender;

    void pick(Gender g) {
      ref.read(wizardProvider.notifier).setGender(g);
      Future<void>.delayed(const Duration(milliseconds: 220), onSelected);
    }

    return Column(
      children: [
        const _StepTitle(
          title: 'Cinsiyetin?',
          subtitle: 'Programını sana göre kalibre edelim.',
        ),
        const SizedBox(height: 16),
        // Fills the full remaining step height: three Expanded cards
        // share the column evenly so there's no dead space at the bottom.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                Expanded(
                  child: PhotoOptionCard(
                    fallbackIcon: Icons.female,
                    title: 'Kadın',
                    subtitle: 'Kadın için optimize edilmiş plan.',
                    selected: selected == Gender.female,
                    onTap: () => pick(Gender.female),
                    image: 'photos/cinsiyetseçimikadın.webp',
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: PhotoOptionCard(
                    fallbackIcon: Icons.male,
                    title: 'Erkek',
                    subtitle: 'Erkek için optimize edilmiş plan.',
                    selected: selected == Gender.male,
                    onTap: () => pick(Gender.male),
                    image: 'photos/cinsiyetseçimierkek.webp',
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: PhotoOptionCard(
                    fallbackIcon: Icons.transgender,
                    title: 'Diğer',
                    subtitle: 'Tarafsız bir plan oluşturalım.',
                    selected: selected == Gender.other,
                    onTap: () => pick(Gender.other),
                    // No bespoke artwork shipped for "Diğer" — text only.
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

class _AgeStep extends ConsumerStatefulWidget {
  const _AgeStep({required this.onContinue});
  final VoidCallback onContinue;

  @override
  ConsumerState<_AgeStep> createState() => _AgeStepState();
}

class _AgeStepState extends ConsumerState<_AgeStep> {
  static const int _minAge = 18;
  static const int _maxAge = 80;
  late final FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    final initial = (ref.read(wizardProvider).age ?? 25) - _minAge;
    _controller = FixedExtentScrollController(initialItem: initial);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(wizardProvider.notifier).setAge(_minAge + initial);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final age = ref.watch(wizardProvider).age ?? 25;
    return Column(
      children: [
        const _StepTitle(
          title: 'Yaşın kaç?',
          subtitle: 'Metabolizmana göre yoğunluğu ayarlayalım.',
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 60,
                margin: const EdgeInsets.symmetric(horizontal: 48),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: _neon.withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                    bottom: BorderSide(
                      color: _neon.withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
              ListWheelScrollView.useDelegate(
                controller: _controller,
                itemExtent: 60,
                perspective: 0.003,
                diameterRatio: 1.6,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: (i) {
                  ref.read(wizardProvider.notifier).setAge(_minAge + i);
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: _maxAge - _minAge + 1,
                  builder: (context, i) {
                    final value = _minAge + i;
                    final selected = value == age;
                    return Center(
                      child: Text(
                        '$value',
                        style: TextStyle(
                          color: selected ? _neon : Colors.white54,
                          fontSize: selected ? 42 : 28,
                          fontWeight:
                              selected ? FontWeight.w900 : FontWeight.w500,
                          shadows: selected
                              ? [Shadow(blurRadius: 18, color: _neon)]
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Positioned(
                right: 32,
                child: Text(
                  'YAŞ',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    letterSpacing: 3,
                  ),
                ),
              ),
            ],
          ),
        ),
        _PrimaryButton(label: 'DEVAM', onPressed: widget.onContinue),
      ],
    );
  }
}

class _BodyMetricsStep extends ConsumerStatefulWidget {
  const _BodyMetricsStep({required this.onContinue});
  final VoidCallback onContinue;

  @override
  ConsumerState<_BodyMetricsStep> createState() => _BodyMetricsStepState();
}

class _BodyMetricsStepState extends ConsumerState<_BodyMetricsStep> {
  static const int _minHeight = 120;
  static const int _maxHeight = 220;
  static const int _minWeight = 30;
  static const int _maxWeight = 200;

  late final FixedExtentScrollController _heightController;
  late final FixedExtentScrollController _weightController;

  @override
  void initState() {
    super.initState();
    final initialHeight =
        (ref.read(wizardProvider).heightCm ?? 170) - _minHeight;
    final initialWeight =
        (ref.read(wizardProvider).weightKg ?? 70) - _minWeight;
    _heightController = FixedExtentScrollController(initialItem: initialHeight);
    _weightController = FixedExtentScrollController(initialItem: initialWeight);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(wizardProvider.notifier).setHeight(_minHeight + initialHeight);
      ref.read(wizardProvider.notifier).setWeight(_minWeight + initialWeight);
    });
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wizardProvider);
    return Column(
      children: [
        const _StepTitle(
          title: 'Boy & Kilo',
          subtitle: 'Kalori ve set hesaplarını buna göre yapacağız.',
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: WheelColumn(
                  label: 'BOY (cm)',
                  controller: _heightController,
                  min: _minHeight,
                  max: _maxHeight,
                  current: state.heightCm ?? 170,
                  onChanged: (v) =>
                      ref.read(wizardProvider.notifier).setHeight(v),
                ),
              ),
              Container(width: 1, color: Colors.white12),
              Expanded(
                child: WheelColumn(
                  label: 'KİLO (kg)',
                  controller: _weightController,
                  min: _minWeight,
                  max: _maxWeight,
                  current: state.weightKg ?? 70,
                  onChanged: (v) =>
                      ref.read(wizardProvider.notifier).setWeight(v),
                ),
              ),
            ],
          ),
        ),
        _PrimaryButton(label: 'DEVAM', onPressed: widget.onContinue),
      ],
    );
  }
}

class _CurrentPhysiqueStep extends ConsumerWidget {
  const _CurrentPhysiqueStep({required this.onSelected});
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(wizardProvider).currentPhysique;

    void pick(Physique p) {
      ref.read(wizardProvider.notifier).setCurrentPhysique(p);
      Future<void>.delayed(const Duration(milliseconds: 220), onSelected);
    }

    return Column(
      children: [
        const _StepTitle(
          title: 'Şu anki vücudun?',
          subtitle: 'Sana en yakın olanı seç.',
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                Expanded(
                  child: PhotoOptionCard(
                    image: 'photos/vücutseçimiZayıf.webp',
                    fallbackIcon: Icons.accessibility,
                    title: 'Zayıf',
                    subtitle: 'Düşük yağ, ince yapı.',
                    selected: selected == Physique.slim,
                    onTap: () => pick(Physique.slim),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: PhotoOptionCard(
                    // Filename carries a "vucüt" typo that ships from the
                    // user's asset export; keep the path verbatim so the
                    // manifest lookup actually matches.
                    image: 'photos/vucütseçimiNormal.webp',
                    fallbackIcon: Icons.accessibility_new,
                    title: 'Normal',
                    subtitle: 'Ortalama yapı.',
                    selected: selected == Physique.normal,
                    onTap: () => pick(Physique.normal),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: PhotoOptionCard(
                    image: 'photos/vücutseçimikiloluhacimli.webp',
                    fallbackIcon: Icons.airline_seat_recline_extra,
                    title: 'Kilolu / Hacimli',
                    subtitle: 'Fazla yağ veya hacimli yapı.',
                    selected: selected == Physique.heavy,
                    onTap: () => pick(Physique.heavy),
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

class _TargetPhysiqueStep extends ConsumerWidget {
  const _TargetPhysiqueStep({required this.onSelected});
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(wizardProvider).targetPhysique;

    void pick(GoalPhysique g) {
      ref.read(wizardProvider.notifier).setTargetPhysique(g);
      Future<void>.delayed(const Duration(milliseconds: 220), onSelected);
    }

    return Column(
      children: [
        const _StepTitle(
          title: 'Hedefin ne?',
          subtitle: '30 gün sonra nereye varmak istersin?',
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                Expanded(
                  child: PhotoOptionCard(
                    image: 'photos/hedefinneSıkılaşmak.webp',
                    fallbackIcon: Icons.local_fire_department,
                    title: 'Sıkılaşmak',
                    subtitle: 'Yağ yak, kasları sıkılaştır.',
                    selected: selected == GoalPhysique.tone,
                    onTap: () => pick(GoalPhysique.tone),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: PhotoOptionCard(
                    image: 'photos/hedefinneHacimKazanmak.webp',
                    fallbackIcon: Icons.fitness_center,
                    title: 'Hacim Kazanmak',
                    subtitle: 'Daha kalın, daha güçlü.',
                    selected: selected == GoalPhysique.bulk,
                    onTap: () => pick(GoalPhysique.bulk),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: PhotoOptionCard(
                    image: 'photos/hedefinneSadeceSix-Pack.webp',
                    fallbackIcon: Icons.bolt,
                    title: 'Sadece Six-Pack',
                    subtitle: 'Net çizgiler, belirgin karın.',
                    selected: selected == GoalPhysique.sixpack,
                    onTap: () => pick(GoalPhysique.sixpack),
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

class _ActivityStep extends ConsumerWidget {
  const _ActivityStep({required this.onSelected});
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(wizardProvider).activityLevel;

    void pick(ActivityLevel a) {
      ref.read(wizardProvider.notifier).setActivityLevel(a);
      Future<void>.delayed(const Duration(milliseconds: 220), onSelected);
    }

    return Column(
      children: [
        const _StepTitle(
          title: 'Günlük aktiviten?',
          subtitle: 'Programın yoğunluğunu buna göre dengeleyeceğiz.',
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                Expanded(
                  child: PhotoOptionCard(
                    image: 'photos/günlükaktivitenmasabaşı.webp',
                    fallbackIcon: Icons.chair,
                    title: 'Masa Başı',
                    subtitle: 'Çoğunlukla otururum, az hareket ederim.',
                    selected: selected == ActivityLevel.sedentary,
                    onTap: () => pick(ActivityLevel.sedentary),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: PhotoOptionCard(
                    image: 'photos/günlükaktivitenhafifhareketli.webp',
                    fallbackIcon: Icons.directions_walk,
                    title: 'Hafif Hareketli',
                    subtitle: 'Düzenli yürüyüş, hafif egzersiz.',
                    selected: selected == ActivityLevel.light,
                    onTap: () => pick(ActivityLevel.light),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: PhotoOptionCard(
                    image: 'photos/günlükaktivitenneÇokAktif.webp',
                    fallbackIcon: Icons.directions_run,
                    title: 'Çok Aktif',
                    subtitle: 'Düzenli antrenman, yüksek tempo.',
                    selected: selected == ActivityLevel.active,
                    onTap: () => pick(ActivityLevel.active),
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

// ============================================================================
// Nutrition wizard steps (phase 21, visuals upgraded in phase 35)
// ----------------------------------------------------------------------------
// Four single-select questions that feed the macro engine + recipe filter.
// `_DietPreferenceStep` carries Unsplash food photos (URLs shared with the
// `supabase_seed_recipes` dataset so we know they resolve); the remaining
// three stay icon-only because an allergy / meal-count / prep-time question
// reads more clearly with an abstract glyph than a stock photo.
// ============================================================================

// Food photos — lifted verbatim from supabase_seed_recipes.sql so each
// URL is already exercised in production and guaranteed to resolve.
const String _dietStandardImg =
    'https://images.unsplash.com/photo-1544025162-d76694265947?w=800&q=80';
const String _dietVegetarianImg =
    'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800&q=80';
const String _dietVeganImg =
    'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=800&q=80';
const String _dietKetoImg =
    'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=800&q=80';

// Meal frequency visuals — same verified-URL rule (all three are already
// on live recipe rows). 2 öğün = single minimalist bowl, 3 öğün = a
// balanced composed plate, 4+ öğün = a high-variety fresh-ingredient
// spread so each option telegraphs its energy at a glance.
const String _mealFreq2Img =
    'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=800&q=80';
const String _mealFreq3Img =
    'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=800&q=80';
const String _mealFreq4Img =
    'https://images.unsplash.com/photo-1525351484163-7529414344d8?w=800&q=80';

class _DietPreferenceStep extends ConsumerWidget {
  const _DietPreferenceStep({required this.onSelected});
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
        const _StepTitle(
          title: 'Diyet Tercihin Nedir?',
          subtitle: 'Tarifleri bu tercihine göre filtreleyeceğiz.',
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                Expanded(
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
                Expanded(
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
                Expanded(
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
                Expanded(
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

class _AllergiesStep extends ConsumerWidget {
  const _AllergiesStep({required this.onSelected});
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
        const _StepTitle(
          title: 'Herhangi bir gıda alerjin var mı?',
          subtitle: 'Tariflerden bu içeriği çıkaracağız.',
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                Expanded(
                  child: PhotoOptionCard(
                    fallbackIcon: Icons.verified_user,
                    title: 'Yok',
                    subtitle: 'Bilinen bir alerjim yok.',
                    selected: selected == 'yok',
                    onTap: () => pick('yok'),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: PhotoOptionCard(
                    fallbackIcon: Icons.emoji_nature,
                    title: 'Kuruyemiş',
                    subtitle: 'Badem, fıstık, ceviz vb.',
                    selected: selected == 'kuruyemis',
                    onTap: () => pick('kuruyemis'),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: PhotoOptionCard(
                    fallbackIcon: Icons.icecream,
                    title: 'Süt Ürünleri',
                    subtitle: 'Süt, peynir, yoğurt vb.',
                    selected: selected == 'sut_urunleri',
                    onTap: () => pick('sut_urunleri'),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
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

class _MealFrequencyStep extends ConsumerWidget {
  const _MealFrequencyStep({required this.onSelected});
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
        const _StepTitle(
          title: 'Günde kaç öğün yersin?',
          subtitle: 'Kalori dağılımını öğün sayına göre planlayacağız.',
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                Expanded(
                  child: PhotoOptionCard(
                    image: _mealFreq2Img,
                    fallbackIcon: Icons.hourglass_top,
                    title: '2 Öğün',
                    subtitle: 'Aralıklı oruç (16:8) tarzı beslenirim.',
                    selected: selected == '2_ogun',
                    onTap: () => pick('2_ogun'),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: PhotoOptionCard(
                    image: _mealFreq3Img,
                    fallbackIcon: Icons.restaurant,
                    title: '3 Öğün',
                    subtitle: 'Standart — kahvaltı, öğle, akşam.',
                    selected: selected == '3_ogun',
                    onTap: () => pick('3_ogun'),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
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

class _PrepTimeStep extends ConsumerWidget {
  const _PrepTimeStep({required this.onSelected});
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(wizardProvider).prepTime;

    void pick(String value) {
      ref.read(wizardProvider.notifier).setPrepTime(value);
      Future<void>.delayed(const Duration(milliseconds: 220), onSelected);
    }

    return Column(
      children: [
        const _StepTitle(
          title: 'Yemek hazırlamak için ne kadar vaktin var?',
          subtitle: 'Tarifleri süresine göre dengeleyeceğiz.',
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                Expanded(
                  child: PhotoOptionCard(
                    fallbackIcon: Icons.timer,
                    title: 'Hızlı & Pratik',
                    subtitle: '10-15 dakika içinde hazırlanan tarifler.',
                    selected: selected == 'hizli',
                    onTap: () => pick('hizli'),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: PhotoOptionCard(
                    fallbackIcon: Icons.soup_kitchen,
                    title: 'Mutfakta Vakit',
                    subtitle: '30+ dakika. Pişirmekten keyif alırım.',
                    selected: selected == 'yavas',
                    onTap: () => pick('yavas'),
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
