import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/services/app_preferences.dart';

enum _Step { goal, scan, processing }

class _GoalOption {
  const _GoalOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
}

const List<_GoalOption> _goals = [
  _GoalOption(
    id: 'tone',
    title: 'Sıkılaşmak',
    subtitle: 'Yağ yak, kasları sıkılaştır.',
    icon: Icons.local_fire_department,
  ),
  _GoalOption(
    id: 'bulk',
    title: 'Hacim Kazanmak',
    subtitle: 'Daha kalın, daha güçlü.',
    icon: Icons.fitness_center,
  ),
  _GoalOption(
    id: 'sixpack',
    title: 'Sadece Six-Pack',
    subtitle: 'Net çizgiler, belirgin karın.',
    icon: Icons.bolt,
  ),
];

const List<String> _processingPhrases = [
  'Vücut oranları analiz ediliyor…',
  'Kas yapısı inceleniyor…',
  'Sana özel 30 günlük plan oluşturuluyor…',
  'Program Hazır!',
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  _Step _step = _Step.goal;
  String? _goalId;
  int _processingIndex = 0;
  Timer? _processingTimer;

  @override
  void dispose() {
    _processingTimer?.cancel();
    super.dispose();
  }

  void _selectGoal(String id) {
    setState(() => _goalId = id);
  }

  void _goToScan() {
    if (_goalId == null) return;
    setState(() => _step = _Step.scan);
  }

  void _startAnalysis() {
    setState(() {
      _step = _Step.processing;
      _processingIndex = 0;
    });

    _processingTimer?.cancel();
    _processingTimer = Timer.periodic(const Duration(milliseconds: 1100), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_processingIndex >= _processingPhrases.length - 1) {
        t.cancel();
        _finish();
        return;
      }
      setState(() => _processingIndex += 1);
    });
  }

  Future<void> _finish() async {
    // Hold the "Program Hazır!" state briefly before handing off.
    setState(() => _processingIndex = _processingPhrases.length - 1);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    await ref.read(appPreferencesProvider).completeOnboarding(goal: _goalId);
    if (!mounted) return;
    context.go(AppRoutes.dashboard);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _buildStep(),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _Step.goal:
        return _GoalStep(
          key: const ValueKey('goal'),
          selected: _goalId,
          onSelect: _selectGoal,
          onContinue: _goToScan,
        );
      case _Step.scan:
        return _ScanStep(
          key: const ValueKey('scan'),
          onAnalyze: _startAnalysis,
        );
      case _Step.processing:
        return _ProcessingStep(
          key: const ValueKey('processing'),
          message: _processingPhrases[_processingIndex],
          done: _processingIndex == _processingPhrases.length - 1,
        );
    }
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step, required this.total});
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'SixPack AI',
            style: TextStyle(
              color: Color(0xFF00F0FF),
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          Text(
            '$step / $total',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalStep extends StatelessWidget {
  const _GoalStep({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onContinue,
  });

  final String? selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _StepHeader(step: 1, total: 3),
        const SizedBox(height: 32),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hedefini Seç',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Hangisi seni daha iyi tanımlıyor?',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _goals.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final option = _goals[index];
              final isSelected = option.id == selected;
              return _GoalCard(
                option: option,
                isSelected: isSelected,
                onTap: () => onSelect(option.id),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: selected == null ? null : onContinue,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00F0FF),
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.white12,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              child: const Text('DEVAM'),
            ),
          ),
        ),
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final _GoalOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected ? const Color(0xFF00F0FF) : Colors.white24;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
            borderRadius: BorderRadius.circular(16),
            color: isSelected
                ? const Color(0xFF00F0FF).withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.02),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF00F0FF).withValues(alpha: 0.4),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: borderColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(option.icon,
                    color:
                        isSelected ? const Color(0xFF00F0FF) : Colors.white70),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.subtitle,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected ? const Color(0xFF00F0FF) : Colors.white24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanStep extends StatelessWidget {
  const _ScanStep({super.key, required this.onAnalyze});
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _StepHeader(step: 2, total: 3),
        const SizedBox(height: 32),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Vücut Taraması',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Vücudunu kameraya göster, yapay zeka ölçüsünü alsın.',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: _BodyScanPreview(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onAnalyze,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('ANALİZ ET'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00F0FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BodyScanPreview extends StatefulWidget {
  const _BodyScanPreview();

  @override
  State<_BodyScanPreview> createState() => _BodyScanPreviewState();
}

class _BodyScanPreviewState extends State<_BodyScanPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFF031420), Color(0xFF000607)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: const Color(0xFF00F0FF).withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                const Positioned.fill(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Icon(
                        Icons.accessibility_new,
                        color: Colors.white12,
                        size: 260,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment(0, -1 + _controller.value * 2),
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00F0FF),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00F0FF).withValues(alpha: 0.8),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                const Positioned(
                  top: 12,
                  left: 12,
                  child: _CornerMark(corner: _Corner.topLeft),
                ),
                const Positioned(
                  top: 12,
                  right: 12,
                  child: _CornerMark(corner: _Corner.topRight),
                ),
                const Positioned(
                  bottom: 12,
                  left: 12,
                  child: _CornerMark(corner: _Corner.bottomLeft),
                ),
                const Positioned(
                  bottom: 12,
                  right: 12,
                  child: _CornerMark(corner: _Corner.bottomRight),
                ),
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF00F0FF),
                          width: 0.5,
                        ),
                      ),
                      child: const Text(
                        'SCANNING…',
                        style: TextStyle(
                          color: Color(0xFF00F0FF),
                          fontSize: 10,
                          letterSpacing: 3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

enum _Corner { topLeft, topRight, bottomLeft, bottomRight }

class _CornerMark extends StatelessWidget {
  const _CornerMark({required this.corner});
  final _Corner corner;

  @override
  Widget build(BuildContext context) {
    const side = BorderSide(color: Color(0xFF00F0FF), width: 2);
    Border border;
    switch (corner) {
      case _Corner.topLeft:
        border = const Border(top: side, left: side);
        break;
      case _Corner.topRight:
        border = const Border(top: side, right: side);
        break;
      case _Corner.bottomLeft:
        border = const Border(bottom: side, left: side);
        break;
      case _Corner.bottomRight:
        border = const Border(bottom: side, right: side);
        break;
    }
    return SizedBox(
      width: 20,
      height: 20,
      child: DecoratedBox(decoration: BoxDecoration(border: border)),
    );
  }
}

class _ProcessingStep extends StatelessWidget {
  const _ProcessingStep({
    super.key,
    required this.message,
    required this.done,
  });

  final String message;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: done
                ? const Icon(Icons.check_circle,
                    color: Color(0xFF39FF14), size: 120)
                : Stack(
                    alignment: Alignment.center,
                    children: const [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: CircularProgressIndicator(
                          color: Color(0xFF00F0FF),
                          strokeWidth: 3,
                        ),
                      ),
                      Icon(Icons.auto_awesome,
                          color: Color(0xFF00F0FF), size: 44),
                    ],
                  ),
          ),
          const SizedBox(height: 32),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: child,
            ),
            child: Padding(
              key: ValueKey(message),
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: done ? const Color(0xFF39FF14) : Colors.white,
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
