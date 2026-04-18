import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/services/app_preferences.dart';
import '../providers/wizard_provider.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _neonAccent = Color(0xFF4DA6FF);
const int _totalSteps = 9;
const int _hookSteps = 2;

// Aesthetic Unsplash placeholders supplied by Phase 18 spec. Mapped onto
// the lean→muscular gradient so users see "current vs. target" framing.
const String _leanPhotoUrl =
    'https://images.unsplash.com/photo-1541534741688-6078c6bfb5c5?auto=format&fit=crop&w=300&q=80';
const String _muscularPhotoUrl =
    'https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?auto=format&fit=crop&w=300&q=80';

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
    await ref.read(appPreferencesProvider).completeOnboarding(
        goal: ref.read(wizardProvider).targetPhysique?.name);
    if (!mounted) return;

    // Frictionless auth: silently create an anonymous Supabase session so
    // the user can preview their personalized prediction without being
    // shoved into a sign-up form. If anon auth is disabled in the project
    // (or the network is offline), fall back to the explicit /auth screen.
    try {
      await Supabase.instance.client.auth.signInAnonymously();
    } catch (e, st) {
      debugPrint('Anonymous sign-in failed, falling back to /auth: $e\n$st');
      if (!mounted) return;
      context.go(AppRoutes.auth);
      return;
    }
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
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  _WelcomeStep(onStart: _next),
                  _CoachIntroStep(onContinue: _next),
                  _GenderStep(onSelected: _next),
                  _AgeStep(onContinue: _next),
                  _BodyMetricsStep(onContinue: _next),
                  _CurrentPhysiqueStep(onSelected: _next),
                  _TargetPhysiqueStep(onSelected: _next),
                  _ActivityStep(onSelected: _next),
                  _IllusionStep(onComplete: _finish),
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
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.4,
          colors: [Color(0xFF1A0B3D), Colors.black],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
        child: Column(
          children: [
            const Spacer(),
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _neon.withValues(alpha: 0.45),
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
                        color: _neon.withValues(alpha: 0.7),
                        blurRadius: 28,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.fitness_center,
                    color: Colors.white,
                    size: 64,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
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
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Telefonunun kamerası ile her tekrarını izleyen, '
              'formunu düzelten ve seni gerçek bir koç gibi motive eden '
              'kişisel yapay zeka asistanın.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _neon.withValues(alpha: 0.5),
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
            const Text(
              'Devam ederek Kullanım Şartları ve Gizlilik Politikasını kabul edersin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoachIntroStep extends StatelessWidget {
  const _CoachIntroStep({required this.onContinue});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      child: Column(
        children: [
          const Spacer(),
          _PulsingCoachAvatar(),
          const SizedBox(height: 32),
          const Text(
            'Merhaba 👋',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
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
                color: Colors.white70,
                fontSize: 15,
                height: 1.55,
              ),
            ),
          ),
          const Spacer(),
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
    );
  }
}

class _PulsingCoachAvatar extends StatefulWidget {
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
              width: 200,
              height: 200,
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
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [_neon, _neonAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _neon.withValues(alpha: 0.6),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.smart_toy,
                color: Colors.white,
                size: 56,
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

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? _neon : Colors.white24;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
            borderRadius: BorderRadius.circular(16),
            color: selected
                ? _neon.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.02),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _neon.withValues(alpha: 0.35),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: borderColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: selected ? _neon : Colors.white70,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.chevron_right,
                color: selected ? _neon : Colors.white24,
              ),
            ],
          ),
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
        const SizedBox(height: 24),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              _OptionCard(
                icon: Icons.female,
                title: 'Kadın',
                subtitle: 'Kadın için optimize edilmiş plan.',
                selected: selected == Gender.female,
                onTap: () => pick(Gender.female),
              ),
              const SizedBox(height: 12),
              _OptionCard(
                icon: Icons.male,
                title: 'Erkek',
                subtitle: 'Erkek için optimize edilmiş plan.',
                selected: selected == Gender.male,
                onTap: () => pick(Gender.male),
              ),
              const SizedBox(height: 12),
              _OptionCard(
                icon: Icons.transgender,
                title: 'Diğer',
                subtitle: 'Tarafsız bir plan oluşturalım.',
                selected: selected == Gender.other,
                onTap: () => pick(Gender.other),
              ),
            ],
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
                child: _WheelColumn(
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
                child: _WheelColumn(
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

class _WheelColumn extends StatelessWidget {
  const _WheelColumn({
    required this.label,
    required this.controller,
    required this.min,
    required this.max,
    required this.current,
    required this.onChanged,
  });

  final String label;
  final FixedExtentScrollController controller;
  final int min;
  final int max;
  final int current;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            letterSpacing: 3,
          ),
        ),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 56,
                margin: const EdgeInsets.symmetric(horizontal: 12),
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
                controller: controller,
                itemExtent: 56,
                perspective: 0.003,
                diameterRatio: 1.6,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: (i) => onChanged(min + i),
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: max - min + 1,
                  builder: (context, i) {
                    final value = min + i;
                    final selected = value == current;
                    return Center(
                      child: Text(
                        '$value',
                        style: TextStyle(
                          color: selected ? _neon : Colors.white54,
                          fontSize: selected ? 36 : 24,
                          fontWeight:
                              selected ? FontWeight.w900 : FontWeight.w500,
                          shadows: selected
                              ? [Shadow(blurRadius: 14, color: _neon)]
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
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
        const SizedBox(height: 24),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              _PhotoOptionCard(
                imageUrl: _leanPhotoUrl,
                fallbackIcon: Icons.accessibility,
                title: 'Zayıf',
                subtitle: 'Düşük yağ, ince yapı.',
                selected: selected == Physique.slim,
                onTap: () => pick(Physique.slim),
              ),
              const SizedBox(height: 12),
              _PhotoOptionCard(
                imageUrl: _leanPhotoUrl,
                fallbackIcon: Icons.accessibility_new,
                title: 'Normal',
                subtitle: 'Ortalama yapı.',
                selected: selected == Physique.normal,
                onTap: () => pick(Physique.normal),
              ),
              const SizedBox(height: 12),
              _PhotoOptionCard(
                imageUrl: _muscularPhotoUrl,
                fallbackIcon: Icons.airline_seat_recline_extra,
                title: 'Kilolu / Hacimli',
                subtitle: 'Fazla yağ veya hacimli yapı.',
                selected: selected == Physique.heavy,
                onTap: () => pick(Physique.heavy),
              ),
            ],
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
        const SizedBox(height: 24),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              _PhotoOptionCard(
                imageUrl: _leanPhotoUrl,
                fallbackIcon: Icons.local_fire_department,
                title: 'Sıkılaşmak',
                subtitle: 'Yağ yak, kasları sıkılaştır.',
                selected: selected == GoalPhysique.tone,
                onTap: () => pick(GoalPhysique.tone),
              ),
              const SizedBox(height: 12),
              _PhotoOptionCard(
                imageUrl: _muscularPhotoUrl,
                fallbackIcon: Icons.fitness_center,
                title: 'Hacim Kazanmak',
                subtitle: 'Daha kalın, daha güçlü.',
                selected: selected == GoalPhysique.bulk,
                onTap: () => pick(GoalPhysique.bulk),
              ),
              const SizedBox(height: 12),
              _PhotoOptionCard(
                imageUrl: _muscularPhotoUrl,
                fallbackIcon: Icons.bolt,
                title: 'Sadece Six-Pack',
                subtitle: 'Net çizgiler, belirgin karın.',
                selected: selected == GoalPhysique.sixpack,
                onTap: () => pick(GoalPhysique.sixpack),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhotoOptionCard extends StatelessWidget {
  const _PhotoOptionCard({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    required this.fallbackIcon,
  });

  final String imageUrl;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? _neon : Colors.white24;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
            borderRadius: BorderRadius.circular(16),
            color: selected
                ? _neon.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.02),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _neon.withValues(alpha: 0.35),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 76,
                  height: 92,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: Colors.white10,
                            alignment: Alignment.center,
                            child: const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white54,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.white10,
                          alignment: Alignment.center,
                          child: Icon(
                            fallbackIcon,
                            color: Colors.white54,
                            size: 32,
                          ),
                        ),
                      ),
                      // Dark gradient overlay so the neon UI stays readable
                      // even on the brightest Unsplash highlights.
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.05),
                              Colors.black.withValues(alpha: 0.55),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.chevron_right,
                color: selected ? _neon : Colors.white24,
              ),
            ],
          ),
        ),
      ),
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
        const SizedBox(height: 24),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              _OptionCard(
                icon: Icons.chair,
                title: 'Masa Başı',
                subtitle: 'Çoğunlukla otururum, az hareket ederim.',
                selected: selected == ActivityLevel.sedentary,
                onTap: () => pick(ActivityLevel.sedentary),
              ),
              const SizedBox(height: 12),
              _OptionCard(
                icon: Icons.directions_walk,
                title: 'Hafif Hareketli',
                subtitle: 'Düzenli yürüyüş, hafif egzersiz.',
                selected: selected == ActivityLevel.light,
                onTap: () => pick(ActivityLevel.light),
              ),
              const SizedBox(height: 12),
              _OptionCard(
                icon: Icons.directions_run,
                title: 'Çok Aktif',
                subtitle: 'Düzenli antrenman, yüksek tempo.',
                selected: selected == ActivityLevel.active,
                onTap: () => pick(ActivityLevel.active),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IllusionStep extends StatefulWidget {
  const _IllusionStep({required this.onComplete});
  final VoidCallback onComplete;

  @override
  State<_IllusionStep> createState() => _IllusionStepState();
}

class _IllusionStepState extends State<_IllusionStep>
    with SingleTickerProviderStateMixin {
  static const List<String> _phrases = [
    'Vücut metrikleri analiz ediliyor…',
    'Hedeflerine uygun egzersizler seçiliyor…',
    'Sana özel 30 günlük plan oluşturuluyor…',
    'Program Hazır!',
  ];

  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  int _phraseIndex = 0;
  Timer? _timer;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    if (_started) return;
    _started = true;
    _timer = Timer.periodic(const Duration(milliseconds: 1200), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_phraseIndex >= _phrases.length - 1) {
        t.cancel();
        _spin.stop();
        Future<void>.delayed(const Duration(milliseconds: 900), () {
          if (mounted) widget.onComplete();
        });
        return;
      }
      setState(() => _phraseIndex += 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = _phraseIndex == _phrases.length - 1;
    final color = done ? const Color(0xFF39FF14) : _neon;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: done
                ? Icon(Icons.check_circle, color: color, size: 140)
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      RotationTransition(
                        turns: _spin,
                        child: SizedBox(
                          width: 140,
                          height: 140,
                          child: CircularProgressIndicator(
                            color: color,
                            strokeWidth: 3,
                            backgroundColor: Colors.white12,
                          ),
                        ),
                      ),
                      Icon(Icons.auto_awesome, color: color, size: 48),
                    ],
                  ),
          ),
          const SizedBox(height: 36),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: Padding(
              key: ValueKey(_phraseIndex),
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _phrases[_phraseIndex],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
