import 'package:flutter/material.dart';

const Color _neon = Color(0xFF8E5BFF);

class ChallengeHeroCard extends StatelessWidget {
  const ChallengeHeroCard({
    super.key,
    required this.dayNumber,
    required this.completed,
    required this.total,
    required this.onTap,
  });

  final int dayNumber;
  final int completed;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFF6A3DFF), Color(0xFF4DA6FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _neon.withValues(alpha: 0.45),
                blurRadius: 28,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -16,
                top: 0,
                bottom: 40,
                width: 170,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      _neon.withValues(alpha: 0.35),
                      BlendMode.softLight,
                    ),
                    child: Image.asset(
                      'photos/günlükmeydanokumayenifoto.webp',
                      fit: BoxFit.cover,
                      alignment: Alignment.centerRight,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Taş Gibi Sert\nKarın Kasları',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: const [
                      Icon(Icons.bolt, color: Colors.white, size: 14),
                      Icon(Icons.bolt, color: Colors.white, size: 14),
                      Icon(Icons.bolt, color: Colors.white70, size: 14),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '$dayNumber. Gün',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: 0.3,
                      shadows: [Shadow(blurRadius: 12, color: Colors.black26)],
                    ),
                  ),
                  const SizedBox(height: 14),
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
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: Material(
                      color: Colors.white,
                      shape: const StadiumBorder(),
                      child: InkWell(
                        customBorder: const StadiumBorder(),
                        onTap: onTap,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: Text(
                              'BAŞLA',
                              style: TextStyle(
                                color: _neon,
                                fontSize: 15,
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
            ],
          ),
        ),
      ),
    );
  }
}
