import 'package:flutter/material.dart';

import '../../models/workout_day_model.dart';

const Color _neon = Color(0xFF00F0FF);

class SessionCompleteOverlay extends StatelessWidget {
  const SessionCompleteOverlay({
    super.key,
    required this.day,
    required this.onAcknowledge,
  });

  final WorkoutDay? day;
  final VoidCallback onAcknowledge;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.75),
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.military_tech, size: 96, color: _neon),
              const SizedBox(height: 16),
              Text(
                day == null ? 'Program Tamam!' : 'Gün ${day!.dayNumber} Tamam!',
                style: const TextStyle(
                  color: _neon,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  shadows: [Shadow(blurRadius: 30, color: _neon)],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Harika iş çıkardın, yarın görüşürüz.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onAcknowledge,
                style: FilledButton.styleFrom(
                  backgroundColor: _neon,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                ),
                child: const Text(
                  'Tamam',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
