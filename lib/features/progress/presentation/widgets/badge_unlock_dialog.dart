import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../providers/badge_unlocks_provider.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _neonAccent = Color(0xFF4DA6FF);

/// Phase 48 · celebratory dialog raised the moment a new badge unlocks.
///
/// Presents a single badge at a time so multi-unlock floods (e.g. when
/// the first day completes and trips both `first_step` AND a streak
/// milestone) chain politely instead of stacking on screen. The caller
/// (typically a `ref.listen` in `gelisim_tab.dart`) is responsible for
/// queuing each unlocked id through this method one after another.
Future<void> showBadgeUnlockedDialog(
  BuildContext context,
  BadgeDefinition badge,
) {
  // Heavy thump pairs with the visual pop so the user feels the unlock
  // even with the phone in a sleeve (gym bag, jacket pocket).
  HapticFeedback.heavyImpact();
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _BadgeUnlockDialog(badge: badge),
  );
}

class _BadgeUnlockDialog extends StatefulWidget {
  const _BadgeUnlockDialog({required this.badge});
  final BadgeDefinition badge;

  @override
  State<_BadgeUnlockDialog> createState() => _BadgeUnlockDialogState();
}

class _BadgeUnlockDialogState extends State<_BadgeUnlockDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF221145), Color(0xFF0D0622)],
          ),
          border: Border.all(color: _neon.withValues(alpha: 0.55), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: _neon.withValues(alpha: 0.35),
              blurRadius: 28,
              spreadRadius: 1.5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'YENİ ROZET',
              style: TextStyle(
                color: _neonAccent,
                fontSize: 11,
                letterSpacing: 4,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 18),
            AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) {
                final glow = 0.45 + _ctrl.value * 0.4;
                return Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [_neon, _neonAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _neon.withValues(alpha: glow),
                        blurRadius: 32,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    widget.badge.emoji,
                    style: const TextStyle(fontSize: 56),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            Text(
              widget.badge.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.badge.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: _neon,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('HARİKA!'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
