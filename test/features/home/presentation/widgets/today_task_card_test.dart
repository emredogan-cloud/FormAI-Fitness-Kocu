import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sixpack_ai/core/constants/app_constants.dart';
import 'package:sixpack_ai/features/auth/providers/auth_provider.dart';
import 'package:sixpack_ai/features/home/presentation/widgets/today_task_card.dart';
import 'package:sixpack_ai/features/monetization/models/locked_feature_type.dart';
import 'package:sixpack_ai/features/monetization/providers/monetization_provider.dart';
import 'package:sixpack_ai/features/monetization/services/premium_gate_service.dart';
import 'package:sixpack_ai/features/workout/models/exercise_model.dart';
import 'package:sixpack_ai/features/workout/models/workout_day_model.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// AsyncNotifier stub — the CTA's `_launch` handler reads `isProProvider`
/// via the subscription snapshot, so we pin a non-Pro state instead of
/// hitting the real RevenueCat SDK. Every test in this file exercises
/// the free-tier / paywall-redirect path, so the Pro branch is not
/// parameterised here.
class _StubSubscriptionNotifier extends SubscriptionNotifier {
  @override
  Future<SubscriptionState> build() async => const SubscriptionState();
}

/// Phase 135 · the live gate routes locked taps through the cinematic
/// conversion scene (`ConversionMomentService.show`) before the paywall
/// — which needs SharedPreferences + animation controllers + the full
/// CinematicAiPresence widget tree. Far too much wiring for a tile-
/// level widget test. The stub preserves the original test contract
/// ("locked tap reaches /paywall") by pushing the route directly.
class _StubPremiumGate extends PremiumGateService {
  _StubPremiumGate(super.ref);

  @override
  Future<void> handleLockedTap(
    BuildContext context,
    LockedFeatureType type, {
    String? source,
  }) async {
    if (!context.mounted) return;
    GoRouter.of(context).push('/paywall');
  }
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
      premiumGateProvider.overrideWith(_StubPremiumGate.new),
      // `isProProvider` reads `isReviewerProvider` → `currentUserProvider`,
      // which calls `Supabase.instance` on first build. Tests never
      // initialize Supabase, so we short-circuit the chain at the leaf
      // by pinning the auth state to "signed out."
      currentUserProvider.overrideWith((ref) => null),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('tr')],
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

    testWidgets(
        'CTA routes to /plan-detail for a free day (dayNumber <= freeDayLimit)',
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
        // The test constructs `WorkoutDay` directly with `exercises: [...]`,
        // so the day is always active regardless of where rest days fall
        // in a real generated plan. Pick the first day clearly past the
        // free limit (`freeDayLimit + 1`) to exercise the gate.
        final lockedDay = WorkoutDay(
          dayNumber: AppConstants.freeDayLimit + 1,
          exercises: [_coreExercise()],
        );

        await tester.pumpWidget(_host(TodayTaskCard(activeDay: lockedDay)));
        await tester.pump();

        await tester.tap(find.text('ANTRENMANA BAŞLA'));
        await tester.pumpAndSettle();

        expect(find.text('PAYWALL_ROUTE'), findsOneWidget);
        expect(lockedDay.dayNumber, greaterThan(AppConstants.freeDayLimit));
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
