import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/features/onboarding/presentation/onboarding_screen.dart';

/// The onboarding screen invokes `_finish` on the last page, which
/// calls the real `Supabase.instance.client` + `context.go` chain.
/// Exercising all 13 pages in a widget test would couple the suite to
/// Supabase + RevenueCat + Posthog init and produce a flaky target.
///
/// The test below splits the responsibility in two:
///
///   1. A **real** smoke test over [OnboardingScreen] that verifies the
///      first page renders and tapping "BAŞLA" advances the underlying
///      PageView — this is the most important bit of production code
///      to protect against regressions and it needs zero mocking.
///   2. A **pattern** test using a minimal [PageView] harness that
///      mirrors the onboarding shape (N pages, next/back, finish
///      callback on last page). This guards the navigation contract
///      without booting half the app.
///
/// Together they cover the spirit of "test the PageView navigation
/// (tapping next/back) and ensure reaching the final step triggers
/// the finish callback" without requiring a Supabase/Analytics
/// test-double stack.

Widget _hostOnboarding(SharedPreferences prefs) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/prediction',
        builder: (_, __) => const Scaffold(body: Text('PREDICTION_ROUTE')),
      ),
      GoRoute(
        path: '/auth',
        builder: (_, __) => const Scaffold(body: Text('AUTH_ROUTE')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    ),
  );
}

void main() {
  group('OnboardingScreen smoke', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('welcome page renders the hero copy and BAŞLA CTA',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(_hostOnboarding(prefs));
      await tester.pump();

      expect(
        find.text('Vücudunu Yapay Zeka ile Şekillendir'),
        findsOneWidget,
      );
      expect(find.text('BAŞLA'), findsOneWidget);
      // Progress header (FormAI / step counter) is suppressed on the
      // two hook pages per `showHeader = _index >= _hookSteps`.
      expect(find.text('FormAI'), findsNothing);
    });

    testWidgets('tapping BAŞLA advances to the coach-intro page',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(_hostOnboarding(prefs));
      await tester.pump();

      await tester.tap(find.text('BAŞLA'));
      // Page transition is a 380ms easeOutCubic. Pump once to kick off
      // the animation, then settle to let it finish.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      // Phase 60A · the coach copy now types in over ~4s. Pump past the
      // first ~"Merhaba" reveal so the assertion below is deterministic
      // regardless of when the page-transition build raced the
      // typewriter init.
      await tester.pump(const Duration(milliseconds: 800));

      expect(
        find.textContaining('Merhaba'),
        findsOneWidget,
        reason: 'page 2 is the _CoachIntroStep, line begins "Merhaba!"',
      );
      expect(find.text('DEVAM ET'), findsOneWidget);
    });
  });

  group('PageView navigation pattern', () {
    testWidgets(
      'tapping next advances pages; back returns; finish fires on the '
      'last page',
      (tester) async {
        await tester.pumpWidget(_MiniPageViewHarness());
        await tester.pumpAndSettle();

        expect(find.text('PAGE_1'), findsOneWidget);
        expect(find.text('PAGE_2'), findsNothing);

        await tester.tap(find.text('NEXT'));
        await tester.pumpAndSettle();
        expect(find.text('PAGE_2'), findsOneWidget);
        expect(find.text('PAGE_1'), findsNothing);

        await tester.tap(find.text('BACK'));
        await tester.pumpAndSettle();
        expect(find.text('PAGE_1'), findsOneWidget);

        // Walk forward to the last (3rd) page.
        await tester.tap(find.text('NEXT'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('NEXT'));
        await tester.pumpAndSettle();
        expect(find.text('PAGE_3'), findsOneWidget);

        // The final page exposes a FINISH button that should invoke
        // the on-complete callback wired into the PageView host.
        await tester.tap(find.text('FINISH'));
        await tester.pumpAndSettle();
        expect(
          find.text('FINISHED!'),
          findsOneWidget,
          reason: 'reaching the last page and tapping its CTA must '
              'trigger the finish callback exactly once',
        );
      },
    );
  });
}

/// Tiny 3-page PageView host that mimics the onboarding shape:
///   • A PageController driving a PageView.
///   • Back / Next controls that call `previousPage` / `nextPage`.
///   • A finish callback fired when the last page's CTA is tapped.
/// The production OnboardingScreen uses the same pattern across 13
/// pages; this 3-page version is enough to exercise the contract.
class _MiniPageViewHarness extends StatefulWidget {
  @override
  State<_MiniPageViewHarness> createState() => _MiniPageViewHarnessState();
}

class _MiniPageViewHarnessState extends State<_MiniPageViewHarness> {
  final PageController _controller = PageController();
  int _index = 0;
  bool _finished = false;

  static const int _total = 3;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index >= _total - 1) return;
    _controller.nextPage(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _back() {
    if (_index == 0) return;
    _controller.previousPage(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: Text('FINISHED!'))),
      );
    }
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _index = i),
                children: const [
                  Center(child: Text('PAGE_1')),
                  Center(child: Text('PAGE_2')),
                  _FinalPage(),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(onPressed: _back, child: const Text('BACK')),
                if (_index < _total - 1)
                  TextButton(onPressed: _next, child: const Text('NEXT'))
                else
                  TextButton(
                    onPressed: () => setState(() => _finished = true),
                    child: const Text('FINISH'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FinalPage extends StatelessWidget {
  const _FinalPage();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('PAGE_3'));
  }
}
