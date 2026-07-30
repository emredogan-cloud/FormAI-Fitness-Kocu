import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/core/widgets/spotlight_tour.dart';

/// Roadmap Phase 2 (C27) · the spotlight tour system.
///
/// The invariants under test are the ones that keep a coach-mark layer
/// from becoming a liability: it must always be escapable, it must never
/// crash on a missing target, and it must degrade cleanly under
/// reduce-motion.
Rect _rect(double top) => Rect.fromLTWH(40, top, 200, 60);

Future<List<int>> _runTour(
  WidgetTester tester, {
  required List<SpotlightStep> steps,
  bool reduceMotion = false,
  ValueChanged<bool?>? onResult,
}) async {
  final shown = <int>[];
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: const Size(393, 851),
        disableAnimations: reduceMotion,
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  final r = await showSpotlightTour(
                    context,
                    steps: steps,
                    onStepShown: shown.add,
                  );
                  onResult?.call(r);
                },
                child: const Text('start'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('start'));
  await tester.pumpAndSettle();
  return shown;
}

void main() {
  testWidgets('renders the first step with its copy and step dots',
      (tester) async {
    await _runTour(tester, steps: [
      SpotlightStep(
          title: 'Adım bir', body: 'Açıklama bir', rect: () => _rect(100)),
      SpotlightStep(
          title: 'Adım iki', body: 'Açıklama iki', rect: () => _rect(300)),
    ]);

    expect(tester.takeException(), isNull);
    expect(find.text('Adım bir'), findsOneWidget);
    expect(find.text('Açıklama bir'), findsOneWidget);
    expect(find.text('Adım iki'), findsNothing);
    // Not-last step shows the Next label, not the finish label.
    expect(find.text('Devam'), findsOneWidget);
    expect(find.text('Anladım'), findsNothing);
  });

  testWidgets(
      'Atla is present on the FIRST step — an inescapable tour is '
      'a liability', (tester) async {
    await _runTour(tester, steps: [
      SpotlightStep(title: 'A', body: 'a', rect: () => _rect(100)),
      SpotlightStep(title: 'B', body: 'b', rect: () => _rect(300)),
    ]);
    expect(find.text('Atla'), findsOneWidget);
  });

  testWidgets('advancing walks every step and reports each one',
      (tester) async {
    bool? result;
    final shown = await _runTour(
      tester,
      onResult: (r) => result = r,
      steps: [
        SpotlightStep(title: 'A', body: 'a', rect: () => _rect(100)),
        SpotlightStep(title: 'B', body: 'b', rect: () => _rect(300)),
        SpotlightStep(title: 'C', body: 'c', rect: () => _rect(500)),
      ],
    );

    await tester.tap(find.text('Devam'));
    await tester.pumpAndSettle();
    expect(find.text('B'), findsOneWidget);

    await tester.tap(find.text('Devam'));
    await tester.pumpAndSettle();
    expect(find.text('C'), findsOneWidget);
    // Last step swaps the action label.
    expect(find.text('Anladım'), findsOneWidget);

    await tester.tap(find.text('Anladım'));
    await tester.pumpAndSettle();

    expect(shown, [0, 1, 2]);
    expect(result, isTrue, reason: 'reaching the end reports completion');
  });

  testWidgets('skipping reports NOT completed', (tester) async {
    bool? result;
    await _runTour(
      tester,
      onResult: (r) => result = r,
      steps: [
        SpotlightStep(title: 'A', body: 'a', rect: () => _rect(100)),
        SpotlightStep(title: 'B', body: 'b', rect: () => _rect(300)),
      ],
    );
    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets(
      'tapping the scrim advances, so the whole surface is a '
      'Next affordance', (tester) async {
    await _runTour(tester, steps: [
      SpotlightStep(title: 'A', body: 'a', rect: () => _rect(100)),
      SpotlightStep(title: 'B', body: 'b', rect: () => _rect(600)),
    ]);
    // Tap a point well away from the card and the hole.
    await tester.tapAt(const Offset(360, 20));
    await tester.pumpAndSettle();
    expect(find.text('B'), findsOneWidget);
  });

  group('missing targets', () {
    testWidgets('an unresolvable step is dropped, not crashed on',
        (tester) async {
      await _runTour(tester, steps: [
        SpotlightStep(title: 'Yok', body: 'y', rect: () => null),
        SpotlightStep(title: 'Var', body: 'v', rect: () => _rect(200)),
      ]);
      expect(tester.takeException(), isNull);
      // The resolvable step becomes step 1 of 1.
      expect(find.text('Var'), findsOneWidget);
      expect(find.text('Yok'), findsNothing);
      expect(find.text('Anladım'), findsOneWidget);
    });

    testWidgets(
        'a tour with NO resolvable step shows nothing and reports '
        'not-completed', (tester) async {
      bool? result;
      await _runTour(
        tester,
        onResult: (r) => result = r,
        steps: [
          SpotlightStep(title: 'Yok', body: 'y', rect: () => null),
        ],
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Yok'), findsNothing);
      expect(result, isFalse);
    });
  });

  group('placement', () {
    testWidgets('a target near the TOP puts the card below it', (tester) async {
      await _runTour(tester, steps: [
        SpotlightStep(title: 'Üst', body: 'u', rect: () => _rect(60)),
      ]);
      final cardY = tester.getTopLeft(find.text('Üst')).dy;
      expect(cardY, greaterThan(60 + 60),
          reason: 'card sits below a hole near the top of the screen');
    });

    testWidgets('a target near the BOTTOM puts the card above it',
        (tester) async {
      await _runTour(tester, steps: [
        SpotlightStep(title: 'Alt', body: 'a', rect: () => _rect(770)),
      ]);
      final cardBottom = tester.getBottomLeft(find.text('Alt')).dy;
      expect(cardBottom, lessThan(770),
          reason: 'card sits above a hole near the bottom of the screen');
    });
  });

  testWidgets('reduce-motion still completes the tour', (tester) async {
    bool? result;
    await _runTour(
      tester,
      reduceMotion: true,
      onResult: (r) => result = r,
      steps: [
        SpotlightStep(title: 'A', body: 'a', rect: () => _rect(100)),
        SpotlightStep(title: 'B', body: 'b', rect: () => _rect(300)),
      ],
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Devam'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anladım'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('the step copy is exposed to a screen reader', (tester) async {
    final handle = tester.ensureSemantics();
    await _runTour(tester, steps: [
      SpotlightStep(
        title: 'Başlık',
        body: 'Gövde metni',
        rect: () => _rect(200),
      ),
    ]);
    // A RegExp rather than an exact string: the container's label is
    // merged with its descendants' labels (the step dots and buttons
    // contribute their own), so the assertion that matters is that the
    // step's own copy is present in the announced label — not that it is
    // the entire label.
    expect(
      find.bySemanticsLabel(RegExp('Başlık')),
      findsAtLeastNWidgets(1),
    );
    expect(
      find.bySemanticsLabel(RegExp('Gövde metni')),
      findsAtLeastNWidgets(1),
    );
    handle.dispose();
  });

  testWidgets('survives a 1.3 text scale without overflow', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 851 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(
          size: Size(393, 851),
          textScaler: TextScaler.linear(1.3),
        ),
        child: MaterialApp(home: Scaffold(body: SizedBox())),
      ),
    );
    await _runTour(tester, steps: [
      SpotlightStep(
        title: 'Uzunca bir başlık satırı burada duruyor',
        body: 'Ve bunun altında da epeyce uzun bir açıklama metni '
            'yer alıyor ki sarma davranışını görebilelim.',
        rect: () => _rect(300),
      ),
    ]);
    expect(tester.takeException(), isNull);
  });
}
