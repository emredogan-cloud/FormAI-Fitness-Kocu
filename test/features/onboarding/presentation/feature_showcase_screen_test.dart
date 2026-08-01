import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/features/onboarding/presentation/feature_showcase_screen.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// Roadmap Phase 2 (R1.1) · the post-paywall capability showcase.
///
/// A minimal GoRouter is supplied because the screen finishes with
/// `context.go('/')`; without a router the finish path would throw
/// instead of navigating.
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  double textScale = 1.0,
}) async {
  SharedPreferences.setMockInitialValues(const {});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);

  final router = GoRouter(
    initialLocation: '/showcase',
    routes: [
      GoRoute(
        path: '/showcase',
        builder: (_, __) => const FeatureShowcaseScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('DASHBOARD')),
      ),
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('tr')],
          routerConfig: router,
          debugShowCheckedModeBanner: false,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('opens on the form-analysis card with its proof point',
      (tester) async {
    await _pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('CANLI FORM ANALİZİ'), findsOneWidget);
    expect(
      find.textContaining('Her tekrarını izliyorum.', findRichText: true),
      findsOneWidget,
    );
    // Every card carries a verifiable claim, not an adjective. Phase 6
    // polish moved it from a check-marked line into the assurance card,
    // so the claim is asserted rather than the widget that carried it.
    expect(
      find.textContaining('Tüm analiz tamamen cihazında çalışır'),
      findsOneWidget,
    );
    expect(find.text('DEVAM'), findsOneWidget);
  });

  testWidgets(
    'nothing readable on a card is baked into its artwork — the stat '
    'chips render in the user language',
    (tester) async {
      // `showcase_ai_coach.webp` used to ship "JOINT TRACKING", "POWER
      // OUTPUT" and "RANGE OF MOTION" inside the image, which a Turkish
      // user read in English during their first minute in the app. The
      // asset was re-cropped and the chips rebuilt in Flutter; this is
      // what stops them drifting back into a future asset.
      await _pump(tester);
      await tester.tap(find.text('DEVAM'));
      await tester.pumpAndSettle();

      expect(find.text('Antrenman Serisi'), findsOneWidget);
      expect(find.text('Güç Çıkışı'), findsOneWidget);
      expect(find.text('Kalori'), findsOneWidget);
    },
  );

  testWidgets(
    'the brand gradient paints the accent fragment only, not the whole '
    'headline',
    (tester) async {
      // A ShaderMask is the obvious reach for "gradient text" and paints
      // every glyph in the paragraph — which would have turned "Her
      // tekrarını izliyorum." entirely purple-to-lime and lost the
      // emphasis the design is built on. The gradient is a `foreground`
      // shader on one span; this asserts it stayed that way.
      await _pump(tester);

      final title = tester.widget<RichText>(
        find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText().contains('Her tekrarını izliyorum.'),
        ),
      );
      final spans = <TextSpan>[];
      void walk(InlineSpan s) {
        if (s is! TextSpan) return;
        spans.add(s);
        for (final c in s.children ?? const <InlineSpan>[]) {
          walk(c);
        }
      }

      walk(title.text);
      final painted = spans.where((s) => s.style?.foreground != null).toList();
      expect(painted, hasLength(1));
      expect(painted.single.text, 'izliyorum.');
      // And the rest of the sentence is still there, unpainted.
      expect(
        spans.where((s) => s.text != null && s.style?.foreground == null),
        isNotEmpty,
      );
    },
  );

  test(
    'every headline actually contains its accent fragment, in every locale',
    () async {
      // `splitHighlighted` fails soft: a fragment a translation dropped
      // is simply not found, and the headline renders unstyled. That is
      // the right failure mode at runtime and a silent one in review —
      // the design degrades and nothing complains. This is what
      // complains. It fires the moment somebody edits a title in one ARB
      // and forgets its accent, which is the whole reason the accent is
      // a separate key.
      for (final code in AppLocalizations.supportedLocales) {
        final l = await AppLocalizations.delegate.load(code);
        final pairs = <String, (String, String)>{
          'form': (l.showcaseFormTitle, l.showcaseFormTitleAccent),
          'coach': (l.showcaseCoachTitle, l.showcaseCoachTitleAccent),
          'plan': (l.showcasePlanTitle, l.showcasePlanTitleAccent),
          'nutrition': (
            l.showcaseNutritionTitle,
            l.showcaseNutritionTitleAccent,
          ),
        };
        pairs.forEach((name, p) {
          expect(
            p.$1.contains(p.$2),
            isTrue,
            reason: '[${code.languageCode}] $name: "${p.$1}" does not '
                'contain its accent "${p.$2}"',
          );
        });
      }
    },
  );

  testWidgets('Atla is available on the FIRST card', (tester) async {
    await _pump(tester);
    expect(find.text('Atla'), findsOneWidget);
  });

  testWidgets('walks all four cards and swaps the CTA on the last',
      (tester) async {
    await _pump(tester);

    expect(find.text('CANLI FORM ANALİZİ'), findsOneWidget);

    await tester.tap(find.text('DEVAM'));
    await tester.pumpAndSettle();
    expect(find.text('KİŞİSEL AI KOÇ'), findsOneWidget);

    await tester.tap(find.text('DEVAM'));
    await tester.pumpAndSettle();
    expect(find.text('SANA ÖZEL PROGRAM'), findsOneWidget);

    await tester.tap(find.text('DEVAM'));
    await tester.pumpAndSettle();
    expect(find.text('BESLENME'), findsOneWidget);
    expect(find.text('BAŞLAYALIM'), findsOneWidget);
    expect(find.text('DEVAM'), findsNothing);
  });

  testWidgets('finishing marks the flag and routes to the dashboard',
      (tester) async {
    final container = await _pump(tester);
    expect(container.read(appPreferencesProvider).seenFeatureShowcase, isFalse);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('DEVAM'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('BAŞLAYALIM'));
    await tester.pumpAndSettle();

    expect(container.read(appPreferencesProvider).seenFeatureShowcase, isTrue);
    expect(find.text('DASHBOARD'), findsOneWidget);
  });

  testWidgets(
      'skipping ALSO marks the flag — a skipped showcase must not '
      'reappear on the next dashboard visit', (tester) async {
    final container = await _pump(tester);
    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();

    expect(container.read(appPreferencesProvider).seenFeatureShowcase, isTrue);
    expect(find.text('DASHBOARD'), findsOneWidget);
  });

  testWidgets('renders at a 1.3 text scale without overflow', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 851 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await _pump(tester, textScale: 1.3);
    expect(tester.takeException(), isNull);
    expect(find.text('CANLI FORM ANALİZİ'), findsOneWidget);
  });

  testWidgets('renders on a small phone without overflow', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await _pump(tester);
    expect(tester.takeException(), isNull);
  });
}
