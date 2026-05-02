import 'package:flutter/material.dart';

const Color _neon = Color(0xFF8E5BFF);

/// Dashboard hero card for the user's personalized 30-day program.
///
/// Rebuilt in phase 19.5 to mirror the `EquipmentStrip` layout: a
/// full-bleed image at the back, a dark bottom-weighted gradient to
/// keep text readable, then the headline + day number + progress +
/// BAŞLA button stacked on top. The prior version used a `Positioned`
/// image beside a `Column` of text and they collided on narrow widths.
class ChallengeHeroCard extends StatelessWidget {
  const ChallengeHeroCard({
    super.key,
    required this.title,
    required this.dayNumber,
    required this.completed,
    required this.total,
    required this.onTap,
  });

  /// Headline shown at the top of the card. Derived upstream from the
  /// current day's content — rest days show "Dinlenme Günü"; active
  /// days show a muscle-group-flavoured title.
  final String title;

  final int dayNumber;
  final int completed;
  final int total;
  final VoidCallback onTap;

  static const double _height = 320;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);
    return SizedBox(
      height: _height,
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _neon.withValues(alpha: 0.45),
                blurRadius: 28,
                spreadRadius: 1,
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Layer 1 — full-bleed background image. Falls back to
                // the gradient behind it if the asset fails to load.
                Image.asset(
                  'photos/günlükmeydanokumayenifoto.webp',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  errorBuilder: (_, __, ___) => const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF6A3DFF), Color(0xFF4DA6FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                // Layer 2 — dark bottom-weighted gradient for text
                // contrast. Keeps the image visible at the top while
                // giving the BAŞLA button a solid dark surface to sit on.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.15),
                          Colors.black.withValues(alpha: 0.55),
                          Colors.black.withValues(alpha: 0.90),
                        ],
                        stops: const [0.25, 0.6, 1.0],
                      ),
                    ),
                  ),
                ),
                // Layer 3 — foreground content.
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                          letterSpacing: 0.3,
                          shadows: [
                            Shadow(blurRadius: 12, color: Colors.black87),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: const [
                          Icon(Icons.bolt, color: Colors.white, size: 16),
                          Icon(Icons.bolt, color: Colors.white, size: 16),
                          Icon(Icons.bolt, color: Colors.white70, size: 16),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        '$dayNumber. Gün',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          letterSpacing: 0.3,
                          shadows: [
                            Shadow(blurRadius: 12, color: Colors.black87),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '$completed/$total Gün',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: Colors.white.withValues(alpha: 0.25),
                          valueColor:
                              const AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: Material(
                          color: Colors.white,
                          shape: const StadiumBorder(),
                          child: InkWell(
                            customBorder: const StadiumBorder(),
                            onTap: onTap,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Center(
                                child: Text(
                                  'BAŞLA',
                                  style: TextStyle(
                                    color: _neon,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
