import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/core/services/first_time_ai_scenes.dart';

/// A first-run cinematic must always end.
///
/// The dashboard welcome scene is a full-screen, non-dismissible route
/// with no visible exit. Device QA on a clean first run watched it sit
/// past 22 s against its own 8 s auto-close — the user's only way out was
/// the system back button, which nothing on screen suggests. These tests
/// pin the guarantees that make that impossible: the scene closes on its
/// own, and if it ever doesn't, a watchdog removes it anyway.
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  Map<String, Object> seed = const {},
}) async {
  SharedPreferences.setMockInitialValues(seed);
  final raw = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(raw)],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => FirstTimeAiScenes.showIfNeeded(
                  context,
                  ref,
                  FirstTimeAiScene.dashboardWelcome,
                ),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return container;
}

void main() {
  group('the scene ends on its own', () {
    testWidgets('it opens, then closes without any interaction', (t) async {
      await _pump(t);

      await t.tap(find.text('OPEN'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 700));
      expect(find.text('Bugün dönüşümünün ilk günü.'), findsOneWidget);

      // 8 s auto-close + 500 ms reverse transition. Pumped past the
      // watchdog's own deadline (8 s + 3 s grace) as well, so the test
      // also proves the watchdog is harmless on the normal path — it
      // must not fire, and it must not leave a timer behind.
      await t.pump(const Duration(seconds: 12));
      await t.pumpAndSettle();

      expect(find.text('Bugün dönüşümünün ilk günü.'), findsNothing);
      expect(find.text('OPEN'), findsOneWidget);
    });

    testWidgets('the user is back on the host screen, not on a blank route',
        (t) async {
      await _pump(t);
      await t.tap(find.text('OPEN'));
      await t.pump();
      await t.pump(const Duration(seconds: 12));
      await t.pumpAndSettle();
      expect(find.byType(ElevatedButton), findsOneWidget);
    });
  });

  group('the one-shot gate', () {
    testWidgets('marks seen so the scene never replays', (t) async {
      final container = await _pump(t);

      await t.tap(find.text('OPEN'));
      await t.pump();
      await t.pump(const Duration(seconds: 12));
      await t.pumpAndSettle();

      expect(
        container.read(appPreferencesProvider).seenFirstDashboardAi,
        isTrue,
      );
    });

    testWidgets('a user who has already seen it gets nothing', (t) async {
      await _pump(t, seed: const {'sixpack.seen_first_dashboard_ai': true});

      await t.tap(find.text('OPEN'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 800));

      expect(find.text('Bugün dönüşümünün ilk günü.'), findsNothing);
      expect(find.text('OPEN'), findsOneWidget);
      // Nothing was pushed, so no watchdog should be outstanding either.
      await t.pumpAndSettle();
    });

    testWidgets('the flag is set even if the close path misbehaves', (t) async {
      // `showIfNeeded` marks seen BEFORE pushing, precisely so a scene
      // that fails to close can never become a permanent first-run trap
      // on the next launch too.
      final container = await _pump(t);
      await t.tap(find.text('OPEN'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 700));

      expect(
        container.read(appPreferencesProvider).seenFirstDashboardAi,
        isTrue,
      );

      await t.pump(const Duration(seconds: 12));
      await t.pumpAndSettle();
    });
  });
}
