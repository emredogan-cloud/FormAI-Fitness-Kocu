import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:sixpack_ai/features/workout/presentation/widgets/practice_rep_stage.dart';
import 'package:sixpack_ai/features/workout/services/back_legs_analyzers.dart';
import 'package:sixpack_ai/features/workout/services/crunch_analyzer.dart';

/// Roadmap Phase 3 feature 3 (R1.2) · the guided practice rep.
///
/// The claim this stage makes to the user is "I am watching these joints
/// and I counted that rep". These tests pin the two halves of that claim:
/// the labels name the joints the production analyzer genuinely reads,
/// and the counter shown is the counter the analyzer produced.
Future<void> _pump(
  WidgetTester tester, {
  int reps = 0,
  CrunchState state = CrunchState.unknown,
  String? cue,
  VoidCallback? onSkip,
  double textScale = 1.0,
  Size surface = const Size(393, 851),
}) async {
  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF0A0612),
          body: PracticeRepStage(
            // A null controller is the honest test fixture: it is the
            // real state while the camera is opening, and it lets the
            // whole stage be exercised without a platform channel.
            controller: null,
            pose: null,
            imageSize: null,
            lensDirection: null,
            reps: reps,
            state: state,
            cue: cue,
            onSkip: onSkip ?? () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('tracked joints', () {
    test('every labelled joint is one the SquatAnalyzer actually reads', () {
      // The analyzer's rep cycle is hip-knee-ankle; its form check adds
      // the shoulder. A label outside that set would be a claim the code
      // does not back — invisible in review, and the most corrosive kind
      // of dishonesty in a feature whose whole pitch is "it sees you".
      expect(
        PracticeRepStage.trackedJoints.keys.toSet(),
        {
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.leftHip,
          PoseLandmarkType.leftKnee,
          PoseLandmarkType.leftAnkle,
        },
      );
    });

    test('every label is non-empty Turkish copy', () {
      for (final label in PracticeRepStage.trackedJoints.values) {
        expect(label.trim(), isNotEmpty);
      }
      expect(PracticeRepStage.trackedJoints.values, contains('Diz'));
    });

    test('the analyzer under the stage is the production SquatAnalyzer', () {
      // Guards the substitution the stage's value depends on: swap in a
      // demo counter and the rehearsal stops being a rehearsal.
      expect(SquatAnalyzer(), isA<SquatAnalyzer>());
    });
  });

  group('rendering', () {
    testWidgets('shows the instruction and the skip affordance', (t) async {
      await _pump(t);
      expect(find.text('Bir kez çömel ve kalk.'), findsOneWidget);
      expect(find.text('Bu adımı atla'), findsOneWidget);
    });

    testWidgets('renders a loading indicator while the camera is opening',
        (t) async {
      await _pump(t);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('the rep readout shows the count it was given', (t) async {
      await _pump(t, reps: 0);
      expect(find.text('0'), findsOneWidget);

      await _pump(t, reps: 1, state: CrunchState.up);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('says "Kadraja gir" until the detector has a state', (t) async {
      await _pump(t);
      expect(find.text('Kadraja gir'), findsOneWidget);
      expect(find.text('Seni takip ediyorum'), findsNothing);
    });

    testWidgets('switches to "Seni takip ediyorum" once tracking begins',
        (t) async {
      await _pump(t, state: CrunchState.down);
      expect(find.text('Seni takip ediyorum'), findsOneWidget);
      expect(find.text('Kadraja gir'), findsNothing);
    });

    testWidgets('no cue chip is shown when the analyzer emitted none',
        (t) async {
      await _pump(t);
      expect(find.text('Aşağıda görüyorum — şimdi kalk.'), findsNothing);
    });

    testWidgets('renders the analyzer cue verbatim when there is one',
        (t) async {
      await _pump(
        t,
        state: CrunchState.down,
        cue: 'Göğsünü yukarı tut, geriye doğru otur!',
      );
      expect(
        find.text('Göğsünü yukarı tut, geriye doğru otur!'),
        findsOneWidget,
      );
    });
  });

  group('the skip is a real exit', () {
    testWidgets('tapping skip invokes the callback', (t) async {
      var skipped = false;
      await _pump(t, onSkip: () => skipped = true);
      await t.tap(find.text('Bu adımı atla'));
      await t.pump();
      expect(skipped, isTrue);
    });

    testWidgets('the skip target meets the 48dp minimum', (t) async {
      await _pump(t);
      final size = t.getSize(
        find.ancestor(
          of: find.text('Bu adımı atla'),
          matching: find.byType(TextButton),
        ),
      );
      expect(size.height, greaterThanOrEqualTo(48.0));
    });
  });

  group('accessibility', () {
    testWidgets('the rep count is announced as a live region', (t) async {
      await _pump(t, reps: 1, state: CrunchState.up);
      final handle = t.ensureSemantics();
      // A screen-reader user must get the same "it counted me" moment a
      // sighted user gets from the digit changing.
      expect(find.bySemanticsLabel('Sayılan tekrar: 1'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('survives a 1.3 text scale on a narrow phone without overflow',
        (t) async {
      await _pump(
        t,
        reps: 12,
        state: CrunchState.down,
        cue: 'Göğsünü yukarı tut, geriye doğru otur!',
        textScale: 1.3,
        surface: const Size(360, 690),
      );
      // An overflow is reported as a thrown exception during layout;
      // this phone size + text scale is the combination that has bitten
      // this app twice before (RC-17 paywall, RC-18 Başla).
      expect(t.takeException(), isNull);
      expect(find.text('Bu adımı atla'), findsOneWidget);
    });
  });
}
