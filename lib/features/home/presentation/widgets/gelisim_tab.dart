import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../workout/models/workout_day_model.dart';
import '../../../workout/providers/workout_provider.dart';
import 'stat_tile.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _neonAccent = Color(0xFF4DA6FF);

class GelisimTab extends ConsumerWidget {
  const GelisimTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(workoutSessionProvider).value;
    final completed = session?.days.where((d) => d.isCompleted).length ?? 0;
    final streak = _streakOf(session?.days ?? const []);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        const Text(
          'Gelişim',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'İlerlemen bir bakışta.',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'SERİ',
                value: '$streak gün',
                icon: Icons.local_fire_department,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                label: 'TAMAMLANAN',
                value: '$completed / 30',
                icon: Icons.check_circle_outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const _ComingSoonCard(
          title: 'Detaylı Raporlar Yakında',
          body: 'Haftalık aktivite grafiği, güç artışı eğrileri ve vücut '
              'değişim takibi yakında bu sekmede açılacak.',
        ),
      ],
    );
  }

  int _streakOf(List<WorkoutDay> days) {
    var streak = 0;
    for (final day in days) {
      if (day.isCompleted) {
        streak += 1;
      } else {
        break;
      }
    }
    return streak;
  }
}

class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            _neon.withValues(alpha: 0.18),
            _neonAccent.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: _neon.withValues(alpha: 0.45),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _neon.withValues(alpha: 0.25),
            blurRadius: 18,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _neon.withValues(alpha: 0.25),
                ),
                child: const Icon(
                  Icons.insights,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
