import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Roadmap Phase 2 (R1.1 · C27) · the registry of spotlightable widgets.
///
/// The spotlight tour needs the on-screen rect of widgets it doesn't own
/// (bottom-nav items, the coach entry card). Passing GlobalKeys down
/// through three widget layers would couple the dashboard tree to the
/// tour; holding them in one long-lived object that both sides read
/// keeps that coupling to a single import on each side.
///
/// Contract:
///   * Widgets **attach** their key (`KeyedSubtree`, or `key:` on a
///     Container) during build.
///   * [TourService] **reads** the key to resolve a rect at present time.
///   * A key whose widget isn't mounted resolves to `null`, and the tour
///     silently skips that step — so a tour never crashes because a
///     target moved, was removed, or is off-screen.
///
/// Keys are `final` on a single instance held by a `Provider`, so they
/// survive rebuilds (a fresh GlobalKey each build would detach the
/// element and remount the subtree — a real bug, not a style point).
class TourTargets {
  TourTargets();

  /// The bottom navigation bar as a whole.
  ///
  /// Individual nav items are derived geometrically from this rect rather
  /// than keyed individually — see [navItemRect]. `BottomNavigationBarItem`
  /// takes a `Widget icon`, and a key placed there is attached to the
  /// *inactive* icon only; the moment a tab is selected the framework
  /// swaps in `activeIcon` and the key detaches, so `rectOf` would return
  /// null for whichever tab the user is currently on. Deriving from the
  /// bar is immune to selection state.
  final GlobalKey navBar = GlobalKey(debugLabel: 'tour.navBar');

  /// The AI-coach entry card on the Antrenman tab.
  final GlobalKey coachCard = GlobalKey(debugLabel: 'tour.coachCard');

  /// Today's plan / challenge hero card on the Antrenman tab.
  final GlobalKey planCard = GlobalKey(debugLabel: 'tour.planCard');

  /// The rect of nav item [index] of [count], derived from the bar's own
  /// rect. Returns `null` when the bar isn't laid out.
  ///
  /// `BottomNavigationBarType.fixed` divides its width equally between
  /// items, so an even slice is exact rather than approximate. The slice
  /// is narrowed toward the icon so the spotlight hole reads as pointing
  /// at one destination rather than at a wide empty band.
  Rect? navItemRect(int index, {int count = 4}) {
    final bar = rectOf(navBar);
    if (bar == null) return null;
    if (index < 0 || index >= count) return null;
    final slice = bar.width / count;
    final centerX = bar.left + slice * (index + 0.5);
    // Cap the hole width so a 4-item bar on a tablet doesn't produce a
    // 200px-wide highlight around a 24px icon.
    final halfWidth = (slice * 0.42).clamp(28.0, 56.0);
    return Rect.fromLTRB(
      centerX - halfWidth,
      bar.top,
      centerX + halfWidth,
      bar.bottom,
    );
  }

  /// Trims [rect] so it stops at the top of the bottom nav.
  ///
  /// Tab content scrolls *behind* the nav bar, so a tall card near the
  /// bottom of the list (the plan hero, in practice) reports a rect that
  /// extends underneath it. Spotlighting those true bounds draws the
  /// highlight ring across the nav row, which reads as a rendering
  /// glitch rather than emphasis — device QA caught exactly that.
  ///
  /// Returns `null` if [rect] is null, and returns [rect] unchanged when
  /// the nav bar isn't laid out (nothing to clamp against) or when the
  /// rect already sits entirely above it. If clamping would leave
  /// nothing visible, returns `null` so the step is skipped rather than
  /// drawing a degenerate hole.
  Rect? clampAboveNav(Rect? rect) {
    if (rect == null) return null;
    final nav = rectOf(navBar);
    if (nav == null || rect.bottom <= nav.top) return rect;
    if (rect.top >= nav.top - 24) return null;
    return Rect.fromLTRB(rect.left, rect.top, rect.right, nav.top);
  }

  /// Resolves [key] to a global rect, or `null` when the widget isn't
  /// currently laid out. Callers must treat `null` as "skip this step".
  static Rect? rectOf(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    if (box.size.isEmpty) return null;
    final origin = box.localToGlobal(Offset.zero);
    return Rect.fromLTWH(
      origin.dx,
      origin.dy,
      box.size.width,
      box.size.height,
    );
  }
}

final tourTargetsProvider = Provider<TourTargets>((ref) => TourTargets());
