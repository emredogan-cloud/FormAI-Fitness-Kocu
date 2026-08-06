import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/monetization/providers/monetization_provider.dart';
import 'package:sixpack_ai/features/monetization/widgets/locked_overlay.dart';
import 'package:sixpack_ai/features/workout/domain/workout_plan_titles.dart';
import 'package:sixpack_ai/features/workout/models/exercise_model.dart';
import 'package:sixpack_ai/features/workout/models/workout_plan_model.dart';
import 'package:sixpack_ai/features/workout/presentation/plan_detail_screen.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// A regional/ad-hoc [WorkoutPlan] opened from the dashboard. Passing a
/// non-null plan takes the `_PlanView` branch, which renders the hero,
/// summary header and exercise list, gated behind Pro. These tests
/// cover both the unlocked (Pro) and locked (free) presentations —
/// isProProvider is the only build-time provider that matters; the
/// premium gate is lazy and only fires on tap.

Exercise _ex(String id, String name) => Exercise(
      id: id,
      name: name,
      type: ExerciseType.repBased,
      difficulty: 'beginner',
      targetMuscle: 'upper_body',
      isCardio: false,
      targetReps: 12,
      sets: 3,
    );

/// A real catalogue id, not a synthetic one. `WorkoutPlan.title` now
/// resolves from `workout_plan_titles.dart` by id, so a made-up id would
/// render the id itself and the hero assertion below would be pinning
/// the fallback rather than the feature.
WorkoutPlan _plan() => WorkoutPlan(
      id: 'core_steel_abs',
      category: ExerciseCategory.core,
      levelToken: WorkoutLevel.beginner,
      durationMinutes: 20,
      exercises: [_ex('e1', 'Push Up'), _ex('e2', 'Squat')],
    );

Widget _host({required bool isPro}) {
  return ProviderScope(
    overrides: [
      isProProvider.overrideWithValue(isPro),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('tr')],
      home: PlanDetailScreen(plan: _plan()),
      debugShowCheckedModeBanner: false,
    ),
  );
}

void _tallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  testWidgets('Pro user sees the hero, summary header and unlocked exercises',
      (tester) async {
    _tallViewport(tester);
    await tester.pumpWidget(_host(isPro: true));
    await tester.pump();
    await tester.pump();

    expect(find.text('Çelik Gibi Karın'), findsOneWidget); // hero title
    expect(find.text('2 egzersiz · 20 Dk · Başlangıç'), findsOneWidget);
    expect(find.text('Push Up'), findsOneWidget);
    expect(find.text('Squat'), findsOneWidget);
    // Unlocked → no Pro pills over the tiles.
    expect(find.byType(PremiumProPill), findsNothing);
  });

  testWidgets('free user sees the exercises gated behind Pro pills',
      (tester) async {
    _tallViewport(tester);
    await tester.pumpWidget(_host(isPro: false));
    await tester.pump();
    await tester.pump();

    // The list is still shown (dimmed) but each tile carries a Pro pill.
    expect(find.text('Push Up'), findsOneWidget);
    expect(find.byType(PremiumProPill), findsWidgets);
  });
}
