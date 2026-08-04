import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/core/services/tour_targets.dart';

/// Roadmap Phase 2 (C27) · target-rect resolution.
///
/// The geometric nav-item derivation exists because keying
/// `BottomNavigationBarItem.icon` detaches the moment that tab is
/// selected (the framework swaps in `activeIcon`). These tests pin the
/// geometry and, importantly, the null-safety contract that lets a tour
/// skip a step instead of crashing.
void main() {
  group('rectOf', () {
    test('an unmounted key resolves to null, not an exception', () {
      final key = GlobalKey();
      expect(TourTargets.rectOf(key), isNull);
    });

    testWidgets('a mounted key resolves to its global rect', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 20, top: 40),
              child: SizedBox(key: key, width: 100, height: 50),
            ),
          ),
        ),
      );
      final rect = TourTargets.rectOf(key);
      expect(rect, isNotNull);
      expect(rect!.left, 20);
      expect(rect.top, 40);
      expect(rect.width, 100);
      expect(rect.height, 50);
    });

    testWidgets(
        'a zero-size widget resolves to null — a hole around '
        'nothing would look like a rendering bug', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          // Center (loose constraints) rather than `home:` directly —
          // MaterialApp gives its home tight full-screen constraints, so
          // a SizedBox there is forced to 800x600 and could never be
          // zero-sized.
          home: Center(child: SizedBox.shrink(key: key)),
        ),
      );
      expect(TourTargets.rectOf(key), isNull);
    });
  });

  group('navItemRect', () {
    testWidgets('divides the bar evenly and centres on each slot',
        (tester) async {
      final targets = TourTargets();
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              key: targets.navBar,
              width: 400,
              height: 60,
            ),
          ),
        ),
      );

      // Phase 14 · 5 slots across 400px → centres at 40, 120, 200,
      // 280, 360. Was four before Community joined the nav; this test
      // is what caught the change, which is the point of it.
      for (final entry
          in {0: 40.0, 1: 120.0, 2: 200.0, 3: 280.0, 4: 360.0}.entries) {
        final rect = targets.navItemRect(entry.key);
        expect(rect, isNotNull, reason: 'index ${entry.key}');
        expect(rect!.center.dx, closeTo(entry.value, 0.01));
      }
    });

    testWidgets('spans the full bar height so the hole reads as the nav row',
        (tester) async {
      final targets = TourTargets();
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(key: targets.navBar, width: 400, height: 60),
          ),
        ),
      );
      final rect = targets.navItemRect(1)!;
      expect(rect.top, 0);
      expect(rect.bottom, 60);
    });

    testWidgets(
        'caps the hole width so a wide bar does not produce a '
        'giant highlight around a small icon', (tester) async {
      final targets = TourTargets();
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            // Tablet-width bar: an uncapped 42% slice would be ~126px.
            child: SizedBox(key: targets.navBar, width: 1200, height: 60),
          ),
        ),
      );
      expect(targets.navItemRect(0)!.width, lessThanOrEqualTo(112));
    });

    testWidgets('enforces a minimum width on a very narrow bar',
        (tester) async {
      final targets = TourTargets();
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(key: targets.navBar, width: 240, height: 60),
          ),
        ),
      );
      // 240/4 = 60px slots; 42% = 25.2px, clamped up to 28 half-width.
      expect(targets.navItemRect(0)!.width, greaterThanOrEqualTo(56));
    });

    test('an unmounted bar resolves to null', () {
      expect(TourTargets().navItemRect(0), isNull);
    });

    testWidgets('an out-of-range index resolves to null', (tester) async {
      final targets = TourTargets();
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(key: targets.navBar, width: 400, height: 60),
        ),
      );
      expect(targets.navItemRect(-1), isNull);
      expect(targets.navItemRect(kBottomNavItemCount), isNull);
    });
  });

  group('clampAboveNav', () {
    /// Lays out a nav bar pinned to the bottom of an 800x600 test screen
    /// (nav occupies y 540..600).
    Future<TourTargets> hostNav(WidgetTester tester) async {
      final targets = TourTargets();
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(key: targets.navBar, width: 800, height: 60),
          ),
        ),
      );
      return targets;
    }

    testWidgets('a rect entirely above the nav is returned unchanged',
        (tester) async {
      final targets = await hostNav(tester);
      const rect = Rect.fromLTRB(0, 100, 400, 300);
      expect(targets.clampAboveNav(rect), rect);
    });

    testWidgets('a rect extending under the nav is trimmed to the nav top',
        (tester) async {
      final targets = await hostNav(tester);
      final clamped = targets.clampAboveNav(
        const Rect.fromLTRB(0, 300, 400, 620),
      );
      expect(clamped, isNotNull);
      expect(clamped!.bottom, 540);
      expect(clamped.top, 300, reason: 'only the bottom edge moves');
    });

    testWidgets(
        'a rect that would be left with no usable height resolves '
        'to null so the step is skipped', (tester) async {
      final targets = await hostNav(tester);
      expect(
        targets.clampAboveNav(const Rect.fromLTRB(0, 530, 400, 600)),
        isNull,
      );
    });

    testWidgets('null passes through as null', (tester) async {
      final targets = await hostNav(tester);
      expect(targets.clampAboveNav(null), isNull);
    });

    test('with no nav laid out the rect is returned unchanged', () {
      const rect = Rect.fromLTRB(0, 100, 400, 900);
      expect(TourTargets().clampAboveNav(rect), rect);
    });
  });

  test(
      'keys are stable across reads — a fresh GlobalKey per read would '
      'remount the target subtree', () {
    final targets = TourTargets();
    expect(targets.coachCard, same(targets.coachCard));
    expect(targets.navBar, same(targets.navBar));
    expect(targets.planCard, same(targets.planCard));
  });
}
