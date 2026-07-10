import 'package:flutter/material.dart';

/// Neon-themed error surface used wherever a Riverpod AsyncValue lands in
/// the error branch. Hides the raw exception from users (only debugPrinted)
/// and offers an optional retry button so offline launches don't look dead.
class ErrorCard extends StatelessWidget {
  const ErrorCard({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline_rounded,
    this.compact = false,
  });

  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  /// Compact layout drops the outer padding and big icon halo so this can
  /// be embedded inside a list tile or a short tab body without dominating
  /// the page. Default layout is centered and generous for full-screen use.
  final bool compact;

  // Store-submission U7 · brand purple (was the retired one-off cyan).
  static const Color _neon = Color(0xFF8E5BFF);

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: EdgeInsets.fromLTRB(20, compact ? 16 : 24, 20, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF111118),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _neon.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: _neon.withValues(alpha: 0.18),
            blurRadius: 18,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 40 : 52,
            height: compact ? 40 : 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _neon.withValues(alpha: 0.12),
            ),
            child: Icon(icon, color: _neon, size: compact ? 22 : 26),
          ),
          SizedBox(height: compact ? 10 : 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 13.5 : 14.5,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          if (onRetry != null) ...[
            SizedBox(height: compact ? 12 : 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _neon.withValues(alpha: 0.6)),
                  padding: EdgeInsets.symmetric(vertical: compact ? 10 : 12),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'TEKRAR DENE',
                  style: TextStyle(color: _neon),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (compact) return card;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: card,
      ),
    );
  }
}
