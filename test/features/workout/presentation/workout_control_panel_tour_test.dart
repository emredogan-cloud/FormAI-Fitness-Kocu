import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/core/services/tour_targets.dart';
import 'package:sixpack_ai/features/workout/presentation/widgets/workout_control_panel.dart';
import 'package:sixpack_ai/features/workout/services/crunch_analyzer.dart';

/// Roadmap Phase 3b · spotlight anchors for the in-session tutorial.
///
/// The coach-mark layer resolves each step's hole from a live RenderBox.
/// A key that isn't attached resolves to null and `SpotlightTour` drops
/// that step *silently* — so an unwired key doesn't fail loudly, it just
/// means the user is never told what the rep counter is. These tests are
/// the only thing standing between that and a shipped release.
Future<void> _pump(
  WidgetTester tester,
  TourTargets targets, {
  bool withKeys = true,
  bool isPaused = false,
  bool canGoBack = true,
}) async {
  await tester.binding.setSurfaceSize(const Size(393, 851));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 220,
          child: WorkoutControlPanel(
            currentSet: 1,
            totalSets: 3,
            metric: 'x 4 / 12',
            exerciseName: 'Squat',
            detectorState: CrunchState.down,
            isPaused: isPaused,
            onTogglePlay: () {},
            onNext: () {},
            onPrev: canGoBack ? () {} : null,
            repCounterKey: withKeys ? targets.workoutRepCounter : null,
            formIndicatorKey: withKeys ? targets.workoutFormIndicator : null,
            pauseControlKey: withKeys ? targets.workoutPauseControl : null,
            nextControlKey: withKeys ? targets.workoutNextControl : null,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('every in-session tour target resolves to a real rect', () {
    testWidgets('rep counter, form indicator, pause and next', (t) async {
      final targets = TourTargets();
      await _pump(t, targets);

      for (final entry in {
        'rep counter': targets.workoutRepCounter,
        'form indicator': targets.workoutFormIndicator,
        'pause control': targets.workoutPauseControl,
        'next control': targets.workoutNextControl,
      }.entries) {
        final rect = TourTargets.rectOf(entry.value);
        expect(rect, isNotNull, reason: '${entry.key} did not resolve');
        expect(rect!.width, greaterThan(0), reason: entry.key);
        expect(rect.height, greaterThan(0), reason: entry.key);
      }
    });

    testWidgets(
        'the resolved rects are distinct — four steps must not '
        'spotlight the same box', (t) async {
      final targets = TourTargets();
      await _pump(t, targets);

      final rects = [
        TourTargets.rectOf(targets.workoutRepCounter),
        TourTargets.rectOf(targets.workoutFormIndicator),
        TourTargets.rectOf(targets.workoutPauseControl),
        TourTargets.rectOf(targets.workoutNextControl),
      ];
      expect(rects.toSet().length, 4);
    });

    testWidgets('the pause and next rects sit on the same control row',
        (t) async {
      final targets = TourTargets();
      await _pump(t, targets);

      final pause = TourTargets.rectOf(targets.workoutPauseControl)!;
      final next = TourTargets.rectOf(targets.workoutNextControl)!;
      expect(next.left, greaterThan(pause.left));
      expect((next.center.dy - pause.center.dy).abs(), lessThan(8));
    });

    testWidgets('the rep counter sits above the control row', (t) async {
      final targets = TourTargets();
      await _pump(t, targets);

      final reps = TourTargets.rectOf(targets.workoutRepCounter)!;
      final pause = TourTargets.rectOf(targets.workoutPauseControl)!;
      expect(reps.bottom, lessThanOrEqualTo(pause.top));
    });

    testWidgets('targets still resolve while the session is paused', (t) async {
      // The user can open the tour, or be shown it, in either state.
      final targets = TourTargets();
      await _pump(t, targets, isPaused: true);
      expect(TourTargets.rectOf(targets.workoutPauseControl), isNotNull);
    });

    testWidgets(
        'the next control resolves on the first exercise, where the '
        'previous button is replaced by a spacer', (t) async {
      // `onPrev: null` swaps in an invisible puck; the next button must
      // keep its key regardless of that layout branch.
      final targets = TourTargets();
      await _pump(t, targets, canGoBack: false);
      expect(TourTargets.rectOf(targets.workoutNextControl), isNotNull);
    });
  });

  group('the panel is unchanged without keys', () {
    testWidgets('renders identically when no tour keys are supplied',
        (t) async {
      // Three existing tests build this widget with no ProviderScope;
      // the keys must stay optional.
      final targets = TourTargets();
      await _pump(t, targets, withKeys: false);

      expect(find.text('x 4 / 12'), findsOneWidget);
      expect(find.text('Squat'), findsOneWidget);
      expect(find.text('SET 1 / 3'), findsOneWidget);
      expect(TourTargets.rectOf(targets.workoutRepCounter), isNull);
    });
  });

  group('key identity', () {
    test('the workout keys are distinct objects from the dashboard ones', () {
      final targets = TourTargets();
      final keys = {
        targets.navBar,
        targets.coachCard,
        targets.planCard,
        targets.workoutRepCounter,
        targets.workoutFormIndicator,
        targets.workoutPauseControl,
        targets.workoutVoiceToggle,
        targets.workoutNextControl,
      };
      expect(keys.length, 8);
    });

    test(
        'keys are stable across reads — a fresh GlobalKey per read would '
        'remount the target subtree', () {
      final targets = TourTargets();
      expect(
        identical(targets.workoutRepCounter, targets.workoutRepCounter),
        isTrue,
      );
      expect(
        identical(targets.workoutVoiceToggle, targets.workoutVoiceToggle),
        isTrue,
      );
    });
  });
}
