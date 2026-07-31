import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/onboarding/presentation/steps/act_4_revelation_steps.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// The AI report's primary CTA must be on screen at every phone height.
///
/// Device QA on a Huawei ANE-LX1 (1080×2280) found the report's
/// fixed-height children overflowing the viewport: "KİŞİSEL PLANIMI AL"
/// was clipped at the bottom edge and would not accept a tap, so
/// onboarding could not be completed on that phone at all. The same
/// class of bug has shipped twice before (RC-17 paywall, RC-18 Başla),
/// which is why it is now pinned by a test rather than by inspection.
///
/// The assertion is deliberately about **reachability**, not pixels: the
/// CTA must be fully inside the viewport and must actually fire its
/// callback when tapped.
Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required VoidCallback onComplete,
  double textScale = 1.0,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      child: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('tr')],
          home: Scaffold(
            backgroundColor: const Color(0xFF0A0612),
            body: DynamicReportStep(onComplete: onComplete),
          ),
        ),
      ),
    ),
  );
  // Let the 1800 ms staggered reveal finish so the CTA is at its final
  // opacity and offset before anything is measured.
  await tester.pump(const Duration(milliseconds: 2200));
}

void main() {
  // Logical sizes for the two phones this was verified on, plus a
  // deliberately cramped one. The Huawei is the short viewport that
  // exposed the bug.
  const redmi = Size(393, 851);
  const huawei = Size(393, 829);
  const cramped = Size(360, 720);

  group('the CTA is inside the viewport', () {
    for (final entry in <String, Size>{
      'Redmi-class 393×851': redmi,
      'Huawei-class 393×829': huawei,
      'cramped 360×720': cramped,
    }.entries) {
      testWidgets(entry.key, (tester) async {
        await _pump(tester, size: entry.value, onComplete: () {});

        final cta = find.text('KİŞİSEL PLANIMI AL');
        expect(cta, findsOneWidget);

        final rect = tester.getRect(cta);
        expect(
          rect.bottom,
          lessThanOrEqualTo(entry.value.height),
          reason: 'CTA label overflows the bottom of ${entry.key}',
        );
        expect(rect.top, greaterThanOrEqualTo(0));
      });
    }
  });

  group('the CTA is tappable', () {
    testWidgets('on the short viewport that exposed the bug', (tester) async {
      var completed = false;
      await _pump(tester, size: huawei, onComplete: () => completed = true);

      // The real failure was not "looks clipped" but "cannot proceed",
      // so the test taps it rather than measuring it.
      await tester.tap(find.text('KİŞİSEL PLANIMI AL'));
      await tester.pump();
      expect(completed, isTrue);
    });

    testWidgets('on the tallest supported viewport', (tester) async {
      var completed = false;
      await _pump(tester, size: redmi, onComplete: () => completed = true);
      await tester.tap(find.text('KİŞİSEL PLANIMI AL'));
      await tester.pump();
      expect(completed, isTrue);
    });
  });

  group('the report still lays out without overflow', () {
    testWidgets('short viewport reports no overflow exception', (tester) async {
      await _pump(tester, size: huawei, onComplete: () {});
      expect(tester.takeException(), isNull);
    });

    testWidgets('and survives a 1.3 text scale', (tester) async {
      // Accessibility scale is exactly what turns "just fits" into
      // "clipped", so it is part of the guarantee rather than a separate
      // concern.
      await _pump(
        tester,
        size: huawei,
        onComplete: () {},
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
      final rect = tester.getRect(find.text('KİŞİSEL PLANIMI AL'));
      expect(rect.bottom, lessThanOrEqualTo(huawei.height));
    });

    testWidgets('the content above the CTA scrolls rather than overflowing',
        (tester) async {
      await _pump(tester, size: cramped, onComplete: () {});
      // A scroll area is what absorbs any shortfall; without one the
      // fixed children push the CTA off screen again.
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });
  });
}
