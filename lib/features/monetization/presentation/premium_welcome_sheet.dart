import 'package:flutter/material.dart';

/// Closed-test polish · the one-time premium welcome shown right after the
/// user's FIRST successful purchase. Congratulates + thanks them, then gives a
/// one-breath tour of what Premium unlocks (AI Coach · Workout · Nutrition ·
/// Progress). Presented as a dismissible modal sheet; the caller owns the
/// once-per-user gating via `AppPreferences.hasSeenPremiumWelcome`.
class PremiumWelcomeSheet extends StatelessWidget {
  const PremiumWelcomeSheet({super.key});

  static const Color _neon = Color(0xFF8E5BFF);
  static const Color _neonAccent = Color(0xFF4DA6FF);
  static const Color _sheet = Color(0xFF140B24);

  /// Presents the sheet and completes when it's dismissed. Non-dismissible by
  /// scrim tap so the user reads the tour; the CTA (or the drag handle) closes.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) => const PremiumWelcomeSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: _sheet,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: _neon, width: 1.5),
          ),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          children: [
            // Grab handle.
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 22),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Celebratory crest.
            Center(
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [_neon, _neonAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _neon.withValues(alpha: 0.5),
                      blurRadius: 28,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(Icons.workspace_premium_rounded,
                    color: Colors.white, size: 46),
              ),
            ),
            const SizedBox(height: 20),
            ShaderMask(
              shaderCallback: (r) => const LinearGradient(
                colors: [Colors.white, _neon],
              ).createShader(r),
              child: const Text(
                'Premium\'a hoş geldin! 🎉',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Bize güvendiğin için teşekkürler. Bugünden itibaren tüm '
              'potansiyelin açık — işte seni neler bekliyor:',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            const _FeatureRow(
              icon: Icons.auto_awesome,
              title: 'AI Koçun her an yanında',
              body: 'Form artık sorularını yanıtlar; antrenman, beslenme ve '
                  'motivasyonda sana özel rehberlik eder.',
            ),
            const _FeatureRow(
              icon: Icons.fitness_center_rounded,
              title: 'Kişisel antrenman programın',
              body: '130+ egzersizde kamerayla canlı form analizi ve gerçek '
                  'zamanlı tekrar sayımı.',
            ),
            const _FeatureRow(
              icon: Icons.restaurant_rounded,
              title: 'Sana özel beslenme',
              body: 'Hedefine göre otomatik günlük menü, öğün takibi ve AI '
                  'öğün önerileri.',
            ),
            const _FeatureRow(
              icon: Icons.insights_rounded,
              title: 'İlerlemeni takip et',
              body: 'Seri, XP, rozetler ve grafiklerle gelişimini her gün gör.',
              isLast: true,
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: FilledButton.styleFrom(
                  backgroundColor: _neon,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                child: const Text('Hadi Başlayalım'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.body,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: PremiumWelcomeSheet._neon.withValues(alpha: 0.16),
              border: Border.all(
                color: PremiumWelcomeSheet._neon.withValues(alpha: 0.5),
              ),
            ),
            child: Icon(icon, color: PremiumWelcomeSheet._neonAccent, size: 22),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12.5,
                    height: 1.4,
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
