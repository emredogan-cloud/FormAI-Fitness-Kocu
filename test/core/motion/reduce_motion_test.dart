import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/core/motion/arrival_pulse.dart';
import 'package:sixpack_ai/core/motion/kinetic_text_reveal.dart';
import 'package:sixpack_ai/core/motion/morphing_number.dart';
import 'package:sixpack_ai/core/motion/stagger_column.dart';

/// Store-submission U4 · every always-on motion primitive must honor the
/// OS "remove animations" accessibility setting (MediaQuery.disableAnimations).
/// These tests pump each primitive under disableAnimations:true and assert
/// it presents its FINAL state on the first frame — with no pending timers /
/// animation controllers left running (a leaked controller fails the test
/// harness), and, for KineticTextReveal, that onComplete still fires so
/// downstream CTA-gating keeps working.

Widget _reduced(Widget child) => MediaQuery(
      data: const MediaQueryData(
        disableAnimations: true,
        // ArrivalPulse/KineticTextReveal read textDirection via inherited
        // widgets; wrap in a minimal Directionality-bearing host.
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: child),
      ),
    );

void main() {
  testWidgets(
    'KineticTextReveal renders the full string immediately and fires '
    'onComplete under reduce-motion (no typewriter, no leaked ticker)',
    (tester) async {
      var completed = false;
      await tester.pumpWidget(_reduced(
        KineticTextReveal(
          text: 'Merhaba Deniz',
          onComplete: () => completed = true,
        ),
      ));
      // A single frame — NOT pumpAndSettle — so a still-typing controller
      // would leave the text partial here.
      await tester.pump();

      expect(find.text('Merhaba Deniz'), findsOneWidget);
      // onComplete is posted via addPostFrameCallback -> one more frame.
      await tester.pump();
      expect(completed, isTrue,
          reason: 'CTA gating depends on onComplete firing even when the '
              'typewriter is skipped');
    },
  );

  testWidgets(
    'MorphingNumber lands on its final formatted value on frame one under '
    'reduce-motion (no roll-up from zero)',
    (tester) async {
      await tester.pumpWidget(_reduced(
        MorphingNumber(
          value: 24.2,
          formatter: (v) => v.toStringAsFixed(1),
        ),
      ));
      await tester.pump();

      expect(find.text('24.2'), findsOneWidget);
      // The from-zero animated value ("0.0") must never have been shown.
      expect(find.text('0.0'), findsNothing);
    },
  );

  testWidgets(
    'StaggerColumn presents all children settled under reduce-motion',
    (tester) async {
      await tester.pumpWidget(_reduced(
        const StaggerColumn(
          children: [
            Text('bir'),
            Text('iki'),
            Text('üç'),
          ],
        ),
      ));
      await tester.pump();

      expect(find.text('bir'), findsOneWidget);
      expect(find.text('iki'), findsOneWidget);
      expect(find.text('üç'), findsOneWidget);
    },
  );

  testWidgets(
    'ArrivalPulse skips the ring but still fires onComplete under '
    'reduce-motion',
    (tester) async {
      var completed = false;
      await tester.pumpWidget(_reduced(
        ArrivalPulse(
          onComplete: () => completed = true,
          child: const Text('coach'),
        ),
      ));
      await tester.pump(); // didChangeDependencies posts the callback
      await tester.pump(); // callback runs

      expect(find.text('coach'), findsOneWidget);
      expect(completed, isTrue);
    },
  );
}
