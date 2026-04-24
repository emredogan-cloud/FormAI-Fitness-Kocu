import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../monetization/providers/monetization_provider.dart';
import '../../../workout/models/workout_day_model.dart';

const Color _neon = Color(0xFF8B5CF6);
const Color _neonDeep = Color(0xFF6A3DFF);
const Color _success = Color(0xFF22C55E);
const Color _surface = Color(0xFF0F0F14);
const Color _surfaceBorder = Color(0xFF1E1E26);

/// First N days the user can run without a Pro entitlement. Tapping the
/// CTA for a day beyond this threshold routes the user to the paywall
/// instead of the plan-detail screen.
const int kFreeDayLimit = 3;

/// Headline card on the "Gelişim" tab that surfaces the user's next
/// active workout day: dumbbell icon + day label + duration / level
/// summary, with a full-width purple CTA that routes to the plan
/// detail screen. Extracted from `gelisim_tab.dart` in Phase 44 so a
/// widget test can smoke the three activeDay branches without
/// booting the whole progress tab.
class TodayTaskCard extends ConsumerWidget {
  const TodayTaskCard({required this.activeDay, super.key});

  final WorkoutDay activeDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focus = _focusLabel(activeDay);
    final minutes = _estimateMinutes(activeDay);
    final level = _levelLabel(activeDay);
    return _SoftCard(
      accent: _neon,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _CardLabel(text: 'BUGÜNKÜ GÖREV'),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: _neon.withValues(alpha: 0.18),
                  border: Border.all(color: _neon.withValues(alpha: 0.45)),
                ),
                child: const Icon(
                  Icons.fitness_center,
                  color: _neon,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Gün ${activeDay.dayNumber} – $focus',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$minutes dk · $level',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _PrimaryCta(onTap: () => _launch(context, ref)),
        ],
      ),
    );
  }

  Future<void> _launch(BuildContext context, WidgetRef ref) async {
    if (activeDay.exercises.isEmpty) return;
    final isPro = ref.read(isProProvider);
    if (!isPro && activeDay.dayNumber > kFreeDayLimit) {
      HapticFeedback.lightImpact();
      context.push(AppRoutes.paywall);
      return;
    }
    HapticFeedback.mediumImpact();
    context.push(AppRoutes.planDetail);
  }

  String _focusLabel(WorkoutDay day) {
    if (day.isRestDay) return 'Aktif Dinlenme';
    final counts = <String, int>{};
    for (final exercise in day.exercises) {
      counts[exercise.targetMuscle] = (counts[exercise.targetMuscle] ?? 0) + 1;
    }
    if (counts.isEmpty) return 'Antrenman';
    final dominant =
        counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    switch (dominant) {
      case 'core':
        return 'Göğüs & Core';
      case 'upper_body':
        return 'Göğüs & Kol';
      case 'lower_body':
        return 'Bacak Gücü';
      case 'cardio':
        return 'Yağ Yakıcı Kardiyo';
      case 'full_body':
        return 'Tüm Vücut HIIT';
      default:
        return 'Antrenman';
    }
  }

  int _estimateMinutes(WorkoutDay day) {
    var seconds = 0;
    for (final ex in day.exercises) {
      final work = ex.isTimeBased
          ? (ex.targetDurationInSeconds ?? 30) * ex.sets
          : (ex.targetReps ?? 10) * 3 * ex.sets;
      final rest = ex.restDurationInSeconds * ex.sets;
      seconds += work + rest;
    }
    final minutes = (seconds / 60).round();
    final bucketed = ((minutes / 5).round() * 5).clamp(10, 120);
    return bucketed;
  }

  String _levelLabel(WorkoutDay day) {
    final counts = <String, int>{};
    for (final ex in day.exercises) {
      counts[ex.difficulty] = (counts[ex.difficulty] ?? 0) + 1;
    }
    if (counts.isEmpty) return 'Başlangıç';
    final dominant =
        counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    switch (dominant) {
      case 'advanced':
        return 'İleri';
      case 'intermediate':
        return 'Orta Seviye';
      default:
        return 'Başlangıç';
    }
  }
}

/// Terminal-state companion to [TodayTaskCard]: replaces the card once
/// the user has completed every active day in the 30-day program.
class ProgramCompleteCard extends StatelessWidget {
  const ProgramCompleteCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      accent: _success,
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 30)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Tebrikler!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '30 günlük programı tamamladın.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({
    required this.child,
    required this.accent,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final Color accent;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: _surface,
        border: Border.all(color: _surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.10),
            blurRadius: 18,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CardLabel extends StatelessWidget {
  const _CardLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xD9B3B3B3),
        fontSize: 10,
        letterSpacing: 2,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _PrimaryCta extends StatelessWidget {
  const _PrimaryCta({required this.onTap});
  final VoidCallback onTap;

  static final BorderRadius _radius = BorderRadius.circular(16);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: _radius,
          boxShadow: [
            BoxShadow(
              color: _neon.withValues(alpha: 0.50),
              blurRadius: 22,
              spreadRadius: 0.4,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: _radius,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: _radius,
              gradient: const LinearGradient(
                colors: [_neonDeep, _neon],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: InkWell(
              borderRadius: _radius,
              onTap: onTap,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'ANTRENMANA BAŞLA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
