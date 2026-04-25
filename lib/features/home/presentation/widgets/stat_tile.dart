import 'package:flutter/material.dart';

import '../../../../core/theme/theme_extension.dart';

const Color _neon = Color(0xFF8E5BFF);

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    // Phase 53G · the Profile İLERLEME tiles ("Seri" / "Tamamlanan")
    // were hardcoded white-on-translucent-white, which left the value
    // text ghosted on a light scaffold. Surface, label, and value now
    // route through the active ColorScheme so the tiles read in both
    // palettes.
    final scheme = context.colors;
    final isDark = context.isDarkMode;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark ? Colors.white.withValues(alpha: 0.04) : scheme.surface,
        border: Border.all(
          color: _neon.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _neon, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.55),
                  fontSize: 11,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
