import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/wizard_provider.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _neonAccent = Color(0xFF4DA6FF);

class IllusionStep extends ConsumerStatefulWidget {
  const IllusionStep({super.key, required this.onComplete});
  final VoidCallback onComplete;

  @override
  ConsumerState<IllusionStep> createState() => _IllusionStepState();
}

class _IllusionStepState extends ConsumerState<IllusionStep>
    with SingleTickerProviderStateMixin {
  static const List<_MetricRowData> _rows = [
    _MetricRowData(label: 'Hedefin', startAt: 0.00, endAt: 0.18),
    _MetricRowData(label: 'Senin Hakkında', startAt: 0.14, endAt: 0.44),
    _MetricRowData(label: 'Form Durumu Analizi', startAt: 0.36, endAt: 0.62),
    _MetricRowData(label: 'Yaşam Tarzı Analizi', startAt: 0.55, endAt: 0.82),
    _MetricRowData(label: 'Plan Kurulumu', startAt: 0.72, endAt: 1.00),
  ];

  late final AnimationController _controller;
  bool _completionScheduled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8500),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.forward().whenComplete(() {
        if (_completionScheduled || !mounted) return;
        _completionScheduled = true;
        Future<void>.delayed(const Duration(milliseconds: 650), () {
          if (mounted) widget.onComplete();
        });
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _progressFor(_MetricRowData row, double t) {
    if (t <= row.startAt) return 0;
    if (t >= row.endAt) return 1;
    return ((t - row.startAt) / (row.endAt - row.startAt)).clamp(0.0, 1.0);
  }

  String _predictedCalories() {
    final w = ref.read(wizardProvider);
    final weight = w.weightKg ?? 72;
    final height = w.heightCm ?? 172;
    final age = w.age ?? 28;
    final base = 10 * weight + 6.25 * height - 5 * age + 5;
    final active = (base * 1.45).round();
    return '$active kcal';
  }

  String _predictedBmi() {
    final w = ref.read(wizardProvider);
    final weight = w.weightKg ?? 72;
    final height = w.heightCm ?? 172;
    final hm = height / 100.0;
    if (hm <= 0) return '—';
    return (weight / (hm * hm)).toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    colors: [_neon, _neonAccent],
                  ).createShader(rect),
                  child: const Text(
                    'Gerçek sonuçlar için planlar',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'sana özel',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _neonAccent,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 26),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: _neon.withValues(alpha: 0.35),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _neon.withValues(alpha: 0.15),
                        blurRadius: 22,
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      for (final row in _rows) ...[
                        _IllusionProgressRow(
                          label: row.label,
                          progress: _progressFor(row, t),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _MetricBubble(
                        label: 'BMI',
                        value: _predictedBmi(),
                        icon: Icons.monitor_weight_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricBubble(
                        label: 'GÜNLÜK KAL.',
                        value: _predictedCalories(),
                        icon: Icons.local_fire_department,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricBubble(
                        label: 'KAS PAYI',
                        value: '${(38 + t * 6).toStringAsFixed(1)}%',
                        icon: Icons.fitness_center,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  t < 1
                      ? 'AI kişisel planını hazırlıyor, bir an bekle…'
                      : 'Hazır! Plan güvenli şekilde kaydedildi.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    height: 1.4,
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

class _MetricRowData {
  const _MetricRowData({
    required this.label,
    required this.startAt,
    required this.endAt,
  });
  final String label;
  final double startAt;
  final double endAt;
}

class _IllusionProgressRow extends StatelessWidget {
  const _IllusionProgressRow({required this.label, required this.progress});
  final String label;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '$percent%',
              style: TextStyle(
                color: percent == 100 ? _neonAccent : Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: const AlwaysStoppedAnimation(_neonAccent),
          ),
        ),
      ],
    );
  }
}

class _MetricBubble extends StatelessWidget {
  const _MetricBubble({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: _neon.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _neon, size: 18),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 9.5,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
