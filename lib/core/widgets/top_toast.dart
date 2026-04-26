import 'dart:async';

import 'package:flutter/material.dart';

/// Phase 57 · sleek top-of-screen transient notification.
///
/// `ScaffoldMessenger`'s SnackBar lives at the bottom and competes with
/// the bottom navigation bar; for celebratory micro-interactions
/// (favourite added, badge pinned, etc.) the PM wanted a top-anchored
/// drop-down that animates in from above the status bar. We render
/// through `Overlay` so the toast sits above any active route's
/// chrome, and dismiss automatically after [duration].
class TopToast {
  TopToast._();

  /// Shows a transient toast pinned to the top centre of the screen.
  /// If a previous toast is still on screen it's replaced — only one
  /// toast lives at a time so the user never sees a stack.
  static void show(
    BuildContext context, {
    required String message,
    IconData? icon,
    Color background = const Color(0xFF8E5BFF),
    Color foreground = Colors.white,
    Duration duration = const Duration(milliseconds: 1800),
  }) {
    _activeEntry?.remove();
    _activeEntry = null;
    _activeTimer?.cancel();

    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (ctx) => _TopToastView(
        message: message,
        icon: icon,
        background: background,
        foreground: foreground,
      ),
    );
    overlay.insert(entry);
    _activeEntry = entry;
    _activeTimer = Timer(duration, () {
      _activeEntry?.remove();
      _activeEntry = null;
      _activeTimer = null;
    });
  }

  static OverlayEntry? _activeEntry;
  static Timer? _activeTimer;
}

class _TopToastView extends StatefulWidget {
  const _TopToastView({
    required this.message,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final String message;
  final IconData? icon;
  final Color background;
  final Color foreground;

  @override
  State<_TopToastView> createState() => _TopToastViewState();
}

class _TopToastViewState extends State<_TopToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    reverseDuration: const Duration(milliseconds: 220),
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, -1.4),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  late final Animation<double> _fade = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOut,
  );

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    return Positioned(
      top: topPadding + 12,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                constraints: const BoxConstraints(maxWidth: 360),
                decoration: BoxDecoration(
                  color: widget.background,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: widget.background.withValues(alpha: 0.45),
                      blurRadius: 22,
                      spreadRadius: 0.5,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: widget.foreground, size: 18),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Text(
                        widget.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.foreground,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
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
