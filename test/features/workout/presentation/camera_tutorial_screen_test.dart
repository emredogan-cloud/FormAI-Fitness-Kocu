import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/routing/app_router.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/features/workout/domain/workout_mode.dart';
import 'package:sixpack_ai/features/workout/presentation/camera_tutorial_screen.dart';

// Roadmap Phase 3 (R1.2 · C26 · C21) · the guided setup's first stage.
//
// The placement stage is deliberately camera-free and permission-free —
// the user learns what to do *before* being asked for anything — which
// is also what makes it fully testable without a camera platform
// channel. These tests pin the promises the stage makes: guidance before
// the ask, the privacy claim at the decision moment, and a camera-free
// exit that is a real choice rather than a dead end.

/// Where the screen navigated to, or null if it stayed put. A real
/// `GoRouter` is used rather than a mock so the exits under test are the
/// same `pushReplacement` / `pop` calls the app performs.
String? lastRoute;

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  bool replay = false,
  Map<String, Object> seed = const {},
  double textScale = 1.0,
  Size surface = const Size(393, 851),
}) async {
  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  lastRoute = null;

  SharedPreferences.setMockInitialValues(seed);
  final raw = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(raw)],
  );
  addTearDown(container.dispose);

  Widget stub(String route) => Builder(builder: (_) {
        lastRoute = route;
        return Scaffold(body: Center(child: Text('ROUTE:$route')));
      });

  final router = GoRouter(
    initialLocation: AppRoutes.cameraTutorial,
    routes: [
      GoRoute(
        path: AppRoutes.cameraTutorial,
        builder: (_, __) => CameraTutorialScreen(replay: replay),
      ),
      GoRoute(
        path: AppRoutes.manualWorkout,
        builder: (_, __) => stub(AppRoutes.manualWorkout),
      ),
      GoRoute(
        path: AppRoutes.workout,
        builder: (_, __) => stub(AppRoutes.workout),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: MaterialApp.router(routerConfig: router),
      ),
    ),
  );
  await tester.pump();
  return container;
}

void main() {
  group('placement stage — guidance before the ask', () {
    testWidgets('opens on placement, not on a permission prompt', (t) async {
      await _pump(t);
      expect(find.text('KURULUM'), findsOneWidget);
      expect(
        find.text('Önce seni görebildiğimden\nemin olalım.'),
        findsOneWidget,
      );
    });

    testWidgets('states all three placement rules', (t) async {
      await _pump(t);
      expect(find.text('Telefonu sabit bir yere koy'), findsOneWidget);
      expect(find.text('Yaklaşık 2 metre uzaklaş'), findsOneWidget);
      expect(find.text('Ortam aydınlık olsun'), findsOneWidget);
    });

    testWidgets(
        'makes the privacy claim at the decision moment, not in a '
        'policy the user will never open', (t) async {
      await _pump(t);
      expect(
        find.textContaining('Görüntün telefonundan çıkmaz'),
        findsOneWidget,
      );
      expect(find.textContaining('hiçbir kare kaydedilmez'), findsOneWidget);
    });

    testWidgets('offers both the camera and the camera-free path', (t) async {
      await _pump(t);
      expect(find.text('KAMERAYI AÇ'), findsOneWidget);
      expect(find.text('Kamerasız devam et'), findsOneWidget);
    });

    testWidgets('sets nothing until the user makes a terminal choice',
        (t) async {
      // Backing out mid-setup must leave the user eligible for the
      // guidance again rather than dropping them into a camera they
      // never learned to position.
      final container = await _pump(t);
      final prefs = container.read(appPreferencesProvider);
      expect(prefs.cameraTutorialCompleted, isFalse);
      expect(prefs.completedPracticeRep, isFalse);
    });
  });

  group('the camera-free path is a real choice (C21)', () {
    testWidgets('choosing it records manual mode and completes the tutorial',
        (t) async {
      final container = await _pump(t);
      await t.tap(find.text('Kamerasız devam et'));
      await t.pumpAndSettle();

      final prefs = container.read(appPreferencesProvider);
      expect(prefs.preferredWorkoutMode, WorkoutMode.manual);
      expect(prefs.cameraTutorialCompleted, isTrue);
    });

    testWidgets(
        'choosing it lands on the manual workout surface, not a '
        'dead end', (t) async {
      await _pump(t);
      await t.tap(find.text('Kamerasız devam et'));
      await t.pumpAndSettle();
      expect(lastRoute, AppRoutes.manualWorkout);
    });

    testWidgets('the camera-free control is a 48dp target', (t) async {
      await _pump(t);
      final size = t.getSize(
        find.ancestor(
          of: find.text('Kamerasız devam et'),
          matching: find.byType(TextButton),
        ),
      );
      expect(size.height, greaterThanOrEqualTo(48.0));
    });
  });

  group('replay mode', () {
    testWidgets('a replay opens on the same placement guidance', (t) async {
      await _pump(t, replay: true);
      expect(find.text('KURULUM'), findsOneWidget);
      expect(find.text('KAMERAYI AÇ'), findsOneWidget);
    });

    testWidgets('a replay does not reset the flags it finds set', (t) async {
      final container = await _pump(
        t,
        replay: true,
        seed: const {
          'sixpack.camera_tutorial_completed': true,
          'sixpack.completed_practice_rep': true,
        },
      );
      final prefs = container.read(appPreferencesProvider);
      expect(prefs.cameraTutorialCompleted, isTrue);
      expect(prefs.completedPracticeRep, isTrue);
    });
  });

  group('resilience', () {
    testWidgets('lays out at 1.3 text scale on a small phone', (t) async {
      await _pump(t, textScale: 1.3, surface: const Size(360, 640));
      expect(t.takeException(), isNull);
      // The primary CTA must survive the squeeze — this app has shipped
      // a below-the-fold CTA twice before.
      expect(find.text('KAMERAYI AÇ'), findsOneWidget);
    });

    testWidgets('the placement copy scrolls rather than overflowing',
        (t) async {
      await _pump(t, surface: const Size(360, 600));
      expect(t.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('a muted voice preference does not block the screen',
        (t) async {
      await _pump(t, seed: const {'sixpack.voice_coach_enabled': false});
      expect(t.takeException(), isNull);
      expect(find.text('KURULUM'), findsOneWidget);
    });
  });
}
