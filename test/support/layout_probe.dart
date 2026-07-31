import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pseudo_localizations.dart';

/// The viewports a layout has to survive.
///
/// 393×851 is the 6.1" Android phone the RC-18 fold regression was found
/// on. 320×640 is the narrowest device still in the Play install base —
/// anything that fits there fits everywhere. Both are logical pixels, so
/// the tests set devicePixelRatio to 1.
class Viewports {
  static const Size phone = Size(393, 851);
  static const Size small = Size(320, 640);
}

/// Pumps [child] under the PSEUDO localisations at [size] and
/// [textScale], then fails if the frame produced any exception.
///
/// A `RenderFlex overflowed` is reported as a framework exception, so
/// `takeException()` catches exactly the class of bug a longer
/// translation causes — without pinning a single pixel, which would
/// make the test a maintenance tax rather than a safety net.
Future<void> pumpPseudo(
  WidgetTester tester,
  Widget child, {
  Size size = Viewports.phone,
  double textScale = 1.0,
  TextDirection? textDirection,
  Duration settle = const Duration(milliseconds: 400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: pseudoLocalizationsDelegates,
      supportedLocales: const [Locale('tr')],
      debugShowCheckedModeBanner: false,
      builder: (context, inner) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: inner!,
      ),
      home: textDirection == null
          ? Scaffold(body: child)
          : Directionality(
              textDirection: textDirection,
              child: Scaffold(body: child),
            ),
    ),
  );
  await tester.pump(settle);
}

/// The three-way sweep every localised screen gets: the reference phone,
/// the narrowest supported phone, and the reference phone at the largest
/// text size the app is expected to honour.
///
/// `describe` names the screen in the failure message, because
/// "RenderFlex overflowed by 14 pixels" on its own does not say which of
/// twenty screens produced it.
Future<void> sweepPseudoLayouts(
  WidgetTester tester,
  String describe,
  Widget Function() build, {
  Duration settle = const Duration(milliseconds: 400),
}) async {
  const cases = <(String, Size, double)>[
    ('393×851', Viewports.phone, 1.0),
    ('320×640', Viewports.small, 1.0),
    ('393×851 @ 1.3 text scale', Viewports.phone, 1.3),
  ];

  for (final (label, size, scale) in cases) {
    // Tear the tree down between cases. Pumping the next case straight
    // over the previous one makes Flutter UPDATE the existing elements,
    // and the frame where the old viewport meets the new text scale can
    // overflow on its own — which blames a size that never had a bug.
    await tester.pumpWidget(const SizedBox.shrink());
    while (tester.takeException() != null) {}

    await pumpPseudo(
      tester,
      build(),
      size: size,
      textScale: scale,
      settle: settle,
    );
    // Drain EVERY exception this frame raised, not just the first. One
    // pump can overflow in two places, and taking them one at a time
    // reports the second against the next viewport — which sends you
    // looking for a bug at a size that never had one.
    final errors = <Object>[];
    for (var error = tester.takeException();
        error != null;
        error = tester.takeException()) {
      errors.add(error);
    }
    expect(
      errors,
      isEmpty,
      reason: '$describe overflowed at $label under pseudo-localisation:\n'
          '${errors.join('\n')}',
    );
  }

  await _drainTimers(tester);
}

/// Renders [build] right-to-left at the reference viewport and fails on
/// any layout error.
///
/// The app ships Turkish only today, so this is readiness rather than
/// support: what it catches is a widget tree that assumes left-to-right
/// in a way no amount of translation can fix — a hardcoded `left:`
/// padding, a `TextAlign.right`, an `Alignment.centerLeft` where
/// `AlignmentDirectional.centerStart` was meant. Those decisions are
/// cheap to make correctly now and expensive to find later.
Future<void> sweepRtlLayout(
  WidgetTester tester,
  String describe,
  Widget Function() build, {
  Duration settle = const Duration(milliseconds: 400),
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  while (tester.takeException() != null) {}

  await pumpPseudo(
    tester,
    build(),
    textDirection: TextDirection.rtl,
    settle: settle,
  );
  final errors = <Object>[];
  for (var error = tester.takeException();
      error != null;
      error = tester.takeException()) {
    errors.add(error);
  }
  expect(
    errors,
    isEmpty,
    reason: '$describe failed to lay out right-to-left:\n${errors.join('\n')}',
  );
  await _drainTimers(tester);
}

/// Several onboarding screens schedule a one-shot `Future.delayed` in
/// initState — a settle before the CTA arms, for instance. They are
/// mounted-guarded, so they are harmless, but the test binding fails any
/// test that ends with a timer outstanding. Tear the tree down and let
/// them fire against nothing.
Future<void> _drainTimers(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 5));
  while (tester.takeException() != null) {}
}
