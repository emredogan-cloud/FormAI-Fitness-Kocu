import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sixpack_ai/features/home/presentation/widgets/today_task_card.dart';
import 'package:sixpack_ai/features/monetization/providers/monetization_provider.dart';
import 'package:sixpack_ai/features/workout/models/exercise_model.dart';
import 'package:sixpack_ai/features/workout/models/workout_day_model.dart';

/// AsyncNotifier stub — the CTA's `_launch` handler reads `isProProvider`
/// via the subscription snapshot, so we pin a non-Pro state instead of
/// hitting the real RevenueCat SDK. Every test in this file exercises
/// the free-tier / paywall-redirect path, so the Pro branch is not
/// parameterised here.
class _StubSubscriptionNotifier extends SubscriptionNotifier {
  @override
  Future<SubscriptionState> build() async => const SubscriptionState();
}

Exercise _coreExercise({
  String id = 'crunch',
  String name = 'Mekik',
  String difficulty = 'beginner',
  String targetMuscle = 'core',
}) {
  return Exercise(
    id: id,
    name: name,
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 30,
    difficulty: difficulty,
    targetMuscle: targetMuscle,
    isCardio: false,
  );
}

Widget _host(Widget child) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(body: child),
      ),
      GoRoute(
        path: '/plan-detail',
        builder: (_, __) => const Scaffold(body: Text('PLAN_DETAIL_ROUTE')),
      ),
      GoRoute(
        path: '/paywall',
        builder: (_, __) => const Scaffold(body: Text('PAYWALL_ROUTE')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      subscriptionProvider.overrideWith(
        () => _StubSubscriptionNotifier(),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    ),
  );
}

void main() {
  group('TodayTaskCard — state: activeDay exists', () {
    testWidgets('renders the day label, duration, level, and CTA', (
      tester,
    ) async {
      final day = WorkoutDay(
        dayNumber: 2,
        exercises: [
          _coreExercise(id: 'a'),
          _coreExercise(id: 'b'),
          _coreExercise(id: 'c'),
        ],
      );

      await tester.pumpWidget(_host(TodayTaskCard(activeDay: day)));
      await tester.pump();

      expect(find.text('BUGÜNKÜ GÖREV'), findsOneWidget);
      // Day 2 with all-core exercises resolves to the "Göğüs & Core"
      // focus label per `_focusLabel`.
      expect(find.text('Gün 2 – Göğüs & Core'), findsOneWidget);
      expect(find.text('ANTRENMANA BAŞLA'), findsOneWidget);
      // Duration + level are rendered together as "X dk · Başlangıç".
      expect(find.textContaining('dk · Başlangıç'), findsOneWidget);
    });

    testWidgets('CTA routes to /plan-detail for a free day (dayNumber <= 3)',
        (tester) async {
      final day = WorkoutDay(
        dayNumber: 1,
        exercises: [_coreExercise()],
      );

      await tester.pumpWidget(_host(TodayTaskCard(activeDay: day)));
      await tester.pump();

      await tester.tap(find.text('ANTRENMANA BAŞLA'));
      await tester.pumpAndSettle();

      expect(
        find.text('PLAN_DETAIL_ROUTE'),
        findsOneWidget,
        reason: 'free-tier days route straight to the plan detail screen',
      );
    });

    testWidgets(
      'CTA redirects non-Pro users to /paywall for days past the free limit',
      (tester) async {
        final day = WorkoutDay(
          dayNumber: kFreeDayLimit + 1, // 4 (but rest day), shift to 5
          exercises: [_coreExercise()],
        );
        // Day 4 is a rest day; use day 5 to exercise the gating path on
        // an active day specifically.
        final day5 = WorkoutDay(
          dayNumber: 5,
          exercises: [_coreExercise()],
        );

        await tester.pumpWidget(_host(TodayTaskCard(activeDay: day5)));
        await tester.pump();

        await tester.tap(find.text('ANTRENMANA BAŞLA'));
        await tester.pumpAndSettle();

        expect(find.text('PAYWALL_ROUTE'), findsOneWidget);
        // Silence the unused-var lint for `day` — the comment above it
        // documents why kFreeDayLimit + 1 alone isn't the usable input.
        expect(day.dayNumber, greaterThan(kFreeDayLimit));
      },
    );
  });

  group('ProgramCompleteCard — state: program completed', () {
    testWidgets('surfaces the celebration copy with the trophy emoji',
        (tester) async {
      await tester.pumpWidget(_host(const ProgramCompleteCard()));
      await tester.pump();

      expect(find.text('🏆'), findsOneWidget);
      expect(find.text('Tebrikler!'), findsOneWidget);
      expect(find.text('30 günlük programı tamamladın.'), findsOneWidget);
      // Today-task copy must NOT appear on the completion card.
      expect(find.text('BUGÜNKÜ GÖREV'), findsNothing);
      expect(find.text('ANTRENMANA BAŞLA'), findsNothing);
    });
  });

  group('activeDay null — state: neither card is shown', () {
    testWidgets(
      'the Gelişim tab branch that renders today_task_card.dart emits '
      'nothing when days are empty and activeDay is null',
      (tester) async {
        // This is the branch expressed in `gelisim_tab.dart`:
        //   if (isProgramComplete) ProgramCompleteCard()
        //   else if (activeDay != null) TodayTaskCard(activeDay: ...)
        // The host below mirrors that select; with empty `days`, neither
        // branch fires and the slot renders as a zero-size SizedBox.
        const List<WorkoutDay> days = [];
        const WorkoutDay? activeDay = null;
        final isProgramComplete = days.isNotEmpty && activeDay == null;
        final Widget card = isProgramComplete
            ? const ProgramCompleteCard()
            : (activeDay != null
                ? TodayTaskCard(activeDay: activeDay)
                : const SizedBox.shrink());

        await tester.pumpWidget(_host(card));
        await tester.pump();

        expect(find.byType(TodayTaskCard), findsNothing);
        expect(find.byType(ProgramCompleteCard), findsNothing);
        expect(find.text('BUGÜNKÜ GÖREV'), findsNothing);
        expect(find.text('Tebrikler!'), findsNothing);
      },
    );
  });
}
