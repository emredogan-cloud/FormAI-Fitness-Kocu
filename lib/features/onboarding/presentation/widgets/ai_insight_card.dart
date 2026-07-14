import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Glassmorphism-style insight block dropped into the dead space below the
/// option cards on gender + daily-minutes (and any future step that wants a
/// "Form Diyor ki" beat). The lead emoji + headline anchor it as the named
/// coach speaking; the body explains why the answer matters or reinforces a
/// motivational beat.
class AiInsightCard extends StatelessWidget {
  const AiInsightCard({
    super.key,
    required this.headline,
    required this.body,
  });

  final String headline;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.neon.withValues(alpha: 0.10),
            AppColors.neonAccent.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.neon.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.neon.withValues(alpha: 0.18),
            blurRadius: 20,
            spreadRadius: -6,
          ),
        ],
      ),
      // RC-1 P8 · a small Form avatar anchors the card to the coach — the
      // user should instantly read "this message comes from Form", not from
      // an anonymous system. Avatar left, content right (chat-app grammar).
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.neon.withValues(alpha: 0.65),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.neon.withValues(alpha: 0.30),
                  blurRadius: 10,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'photos/PT_FORM.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.neonAccent,
                  size: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        headline,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.neonAccent,
                      size: 14,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.45,
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
