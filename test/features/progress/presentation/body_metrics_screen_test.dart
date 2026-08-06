import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/features/progress/data/body_metrics_repository.dart';
import 'package:sixpack_ai/features/progress/domain/models/body_metric.dart';
import 'package:sixpack_ai/features/progress/presentation/body_metrics_screen.dart';
import 'package:sixpack_ai/features/progress/providers/target_weight_provider.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// Roadmap Phase 9 (C1, C3) · the body-metrics screen.
///
/// The assertions here are mostly about what the screen REFUSES to say.
/// Weight is charged, and the failure mode this feature has to avoid is
/// not a crash — it is a card that tells somebody they are behind, or
/// that their body has not changed, on evidence that cannot support it.
void main() {
  // Anchored to the wall clock, NOT to a literal date. The screen
  // computes its own window from `DateTime.now()`
  // (body_metrics_screen.dart), so a fixture pinned to a fixed day
  // drifts out of that window as real time moves past it: this file was
  // written against `DateTime(2026, 8, 2)` and began failing on
  // 2026-08-06 when the seeded points aged past the trend window and
  // `summarize()` started returning null — which hides the insights CTA
  // three of these tests tap. Reading the same clock the screen reads
  // keeps the fixtures and the window aligned on every future run.
  final today = BodyMetric.dayOf(DateTime.now());
  DateTime daysAgo(int n) => today.subtract(Duration(days: n));

  BodyMetric weight(int daysBack, double kg) =>
      BodyMetric(recordedOn: daysAgo(daysBack), weightKg: kg);

  Future<Widget> host({
    required List<BodyMetric> entries,
    Map<String, Object> seed = const {},
    Locale locale = const Locale('tr'),
  }) async {
    SharedPreferences.setMockInitialValues(seed);
    final prefs = await SharedPreferences.getInstance();
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // Overridden rather than stubbed at the repository, because the
        // repository constructs a Supabase client and `Supabase.instance`
        // is not initialised under test.
        bodyMetricsProvider.overrideWith((ref) async => entries),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('tr'), Locale('en')],
        locale: locale,
        home: const BodyMetricsScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }

  Future<void> pump(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  /// The pre-Phase-10 rebuild moved the trend sentence, the plateau note
  /// and the goal reconciliation off the scroll and into a sheet behind
  /// "View insights". The assertions below still pin exactly what they
  /// pinned — the tone rules are the point of this file — they just have
  /// to open the drawer first.
  ///
  /// It asserts the pill is there before tapping, because a
  /// `findsNothing` written against a control that has silently stopped
  /// existing is a test that passes for the wrong reason. Three of the
  /// assertions this helper serves are negative ones.
  Future<void> openInsights(
    WidgetTester tester, {
    String label = 'Yorumu gör',
  }) async {
    expect(find.text(label), findsOneWidget);
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  group('the empty state', () {
    testWidgets('invites rather than instructs', (tester) async {
      await pump(tester, await host(entries: const []));
      expect(find.text('Henüz kayıt yok'), findsOneWidget);
      expect(
        find.textContaining('Başlamak için tek bir sayı yeter'),
        findsOneWidget,
      );
    });

    testWidgets(
        'offers the entry action exactly once — the device walk found the '
        'empty state and the FAB saying the same words on one screen',
        (tester) async {
      await pump(tester, await host(entries: const []));
      // Exactly one, not two. The rebuild made the floating action the
      // screen's own gradient pill rather than a `FloatingActionButton`,
      // so counting the label is what pins the contract now — and it
      // pins it more directly than counting a framework type did.
      expect(find.text('Ölçüm ekle'), findsOneWidget);
      expect(find.text('Henüz kayıt yok'), findsOneWidget);
    });

    testWidgets(
        'the floating action comes back once there is something '
        'to add to', (tester) async {
      await pump(tester, await host(entries: [weight(0, 80)]));
      expect(find.text('Ölçüm ekle'), findsOneWidget);
      expect(find.text('Henüz kayıt yok'), findsNothing);
    });
  });

  group('precision', () {
    testWidgets(
        'a tenth of a kilogram survives to the screen — this is the whole '
        'point of the feature, and it was being rounded away', (tester) async {
      await pump(tester, await host(entries: [weight(0, 82.4)]));
      expect(find.textContaining('82,4 kg'), findsWidgets);
      expect(find.textContaining('82 kg'), findsNothing);
    });

    testWidgets('a round value gains no decimal it does not need',
        (tester) async {
      await pump(tester, await host(entries: [weight(0, 80)]));
      expect(find.textContaining('80 kg'), findsWidgets);
      expect(find.textContaining('80,0'), findsNothing);
    });

    testWidgets('the decimal separator follows the language', (tester) async {
      await pump(
        tester,
        await host(entries: [weight(0, 82.4)], locale: const Locale('en')),
      );
      expect(find.textContaining('82.4 kg'), findsWidgets);
    });
  });

  group('what one data point may claim', () {
    testWidgets(
        'a single entry says "log once more", never "no change" — the '
        'second is a claim about a body one point cannot support',
        (tester) async {
      await pump(tester, await host(entries: [weight(0, 80)]));
      expect(
        find.text('Bir kayıt daha gir — eğilim iki noktadan başlar.'),
        findsOneWidget,
      );
    });

    testWidgets('one point draws no chart either', (tester) async {
      await pump(tester, await host(entries: [weight(0, 80)]));
      expect(
        find.text('İki kayıt girdiğinde burada bir çizgi belirir.'),
        findsOneWidget,
      );
    });
  });

  group('the trend readout', () {
    testWidgets('states a loss without praising it', (tester) async {
      await pump(
        tester,
        await host(entries: [weight(28, 84), weight(14, 82), weight(0, 80)]),
      );
      await openInsights(tester);
      expect(find.textContaining('verdin'), findsOneWidget);
    });

    testWidgets(
        'states a gain in exactly the same register — a bulking user is '
        'succeeding here', (tester) async {
      await pump(
        tester,
        await host(entries: [weight(28, 70), weight(14, 72), weight(0, 74)]),
      );
      await openInsights(tester);
      expect(find.textContaining('aldın'), findsOneWidget);
    });

    testWidgets('a flat series reads as "held steady", not "no change"',
        (tester) async {
      await pump(
        tester,
        await host(entries: [
          weight(21, 80.0),
          weight(14, 80.1),
          weight(7, 79.9),
          weight(0, 80.0),
        ]),
      );
      await openInsights(tester);
      expect(find.textContaining('kilon sabit'), findsOneWidget);
    });
  });

  // The delta under the big number is the one reading that stays on the
  // screen, so it carries the no-valence rule on its own now.
  group('the delta line', () {
    testWidgets('names the window and never signs the magnitude',
        (tester) async {
      await pump(
        tester,
        await host(entries: [weight(28, 84), weight(14, 82), weight(0, 80)]),
      );
      expect(find.textContaining('gün öncesine göre'), findsOneWidget);
      expect(find.textContaining('-'), findsNothing);
    });

    // Found on the device. The card read "1.8 kg vs 30 days ago" beside
    // an insights sheet reading "over the last 13 days" — 30 was the
    // selected range and 13 was how far back the readings actually went.
    // The screen was claiming a weight from a day it has never been told
    // anything about, and the two numbers came from two sources nobody
    // had compared.
    testWidgets(
        'the window is the span of the readings, not the range the user '
        'picked', (tester) async {
      await pump(
        tester,
        // Default range is 30D; the data only reaches back 13 days.
        await host(entries: [weight(13, 84.2), weight(0, 82.4)]),
      );

      expect(find.textContaining('13 gün öncesine göre'), findsOneWidget);
      expect(find.textContaining('30 gün öncesine göre'), findsNothing);

      // …and the sheet that interprets it agrees, which is the property
      // that was actually broken.
      await openInsights(tester);
      expect(find.textContaining('Son 13 günde'), findsOneWidget);
    });

    testWidgets(
        'a gain and a loss are painted the same colour — the arrow is '
        'the direction, the colour is not a verdict', (tester) async {
      Color colourOf(WidgetTester tester) => tester
          .widget<Text>(find.textContaining('gün öncesine göre'))
          .style!
          .color!;

      await pump(
        tester,
        await host(entries: [weight(28, 84), weight(0, 80)]),
      );
      final losing = colourOf(tester);
      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);

      // Unmounted between the two, because re-pumping a ProviderScope
      // whose only change is the value inside an override reuses the
      // element tree and the screen keeps the first series.
      await tester.pumpWidget(const SizedBox.shrink());
      await pump(
        tester,
        await host(entries: [weight(28, 80), weight(0, 84)]),
      );
      expect(colourOf(tester), losing);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    });
  });

  group('the plateau card', () {
    testWidgets('appears after three still weeks, framed as a moment',
        (tester) async {
      await pump(
        tester,
        await host(entries: [
          weight(21, 80.0),
          weight(14, 80.1),
          weight(7, 79.9),
          weight(0, 80.0),
        ]),
      );
      await openInsights(tester);
      expect(find.text('Sabit bir dönem'), findsOneWidget);
      expect(
        find.textContaining('bir şeyin ters gittiği anlamına değil'),
        findsOneWidget,
      );
    });

    testWidgets('stays away after two', (tester) async {
      await pump(
        tester,
        await host(entries: [
          weight(14, 80.0),
          weight(7, 80.1),
          weight(0, 80.0),
        ]),
      );
      // Opened, not skipped: asserting the plateau copy is absent from a
      // screen that never renders it anywhere would pass whatever the
      // plateau logic did.
      await openInsights(tester);
      expect(find.text('Sabit bir dönem'), findsNothing);
    });
  });

  group('the target', () {
    testWidgets('reads "not set" and offers to set one, without nagging',
        (tester) async {
      await pump(tester, await host(entries: [weight(0, 80)]));
      expect(find.text('Belirlenmedi'), findsOneWidget);
      expect(find.text('Hedef belirle'), findsOneWidget);
    });

    testWidgets('no target means no reconciliation card at all',
        (tester) async {
      await pump(
        tester,
        await host(entries: [weight(28, 84), weight(0, 80)]),
      );
      await openInsights(tester);
      expect(find.text('Hedefine doğru'), findsNothing);
    });

    testWidgets('a stated target produces the reconciliation card',
        (tester) async {
      await pump(
        tester,
        await host(
          entries: [weight(28, 84), weight(14, 82), weight(0, 80)],
          seed: {TargetWeightNotifier.storageKey: 75.0},
        ),
      );
      await openInsights(tester);
      expect(find.text('Hedefine doğru'), findsOneWidget);
    });

    testWidgets(
        'moving away from the target does not repeat the distance back '
        'at the user', (tester) async {
      await pump(
        tester,
        await host(
          entries: [weight(28, 84), weight(0, 87)],
          seed: {TargetWeightNotifier.storageKey: 75.0},
        ),
      );
      await openInsights(tester);
      expect(
        find.textContaining('hikâyenin tamamı değil'),
        findsOneWidget,
      );
      expect(
        find.textContaining('kaldı'),
        findsNothing,
        reason: 'quoting the figure at somebody who has just been told '
            'they went the wrong way is a rebuke, not a report',
      );
    });
  });

  group('adherence', () {
    testWidgets(
        'a fresh install never reports a 30-day percentage — below a week '
        'of history it is an artefact of the install date', (tester) async {
      await pump(
        tester,
        await host(
          entries: [weight(0, 80)],
          seed: {
            'sixpack.installed_at': DateTime.now().toIso8601String(),
          },
        ),
      );
      expect(find.text('Henüz planlanmış antrenman yok.'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets(
        'the week is a count, not a percentage — one of four on a Tuesday '
        'is not a grade', (tester) async {
      await pump(
        tester,
        await host(
          entries: [weight(0, 80)],
          seed: {
            'sixpack.installed_at': DateTime.now()
                .subtract(const Duration(days: 40))
                .toIso8601String(),
          },
        ),
      );
      // Nothing logged, so the week reads "0 of 4" rather than "%0".
      expect(find.text('4 antrenmanın 0 tanesi'), findsOneWidget);
    });

    testWidgets('the 30-day figure appears once there is a week of history',
        (tester) async {
      await pump(
        tester,
        await host(
          entries: [weight(0, 80)],
          seed: {
            'sixpack.installed_at': DateTime.now()
                .subtract(const Duration(days: 40))
                .toIso8601String(),
          },
        ),
      );
      expect(find.text('%0'), findsOneWidget);
    });

    testWidgets('the longest streak is always stated', (tester) async {
      await pump(
        tester,
        await host(
          entries: [weight(0, 80)],
          seed: {'sixpack.max_streak': 6},
        ),
      );
      expect(find.text('En uzun seri: 6 gün'), findsOneWidget);
    });
  });

  group('units', () {
    testWidgets('metric renders kilograms', (tester) async {
      await pump(
        tester,
        await host(
          entries: [weight(0, 80)],
          seed: {'sixpack.unit_system': 'metric'},
        ),
      );
      expect(find.textContaining('80 kg'), findsWidgets);
    });

    testWidgets('imperial renders pounds — and nothing stored was converted',
        (tester) async {
      await pump(
        tester,
        await host(
          entries: [weight(0, 80)],
          seed: {'sixpack.unit_system': 'imperial'},
        ),
      );
      expect(find.textContaining('lb'), findsWidgets);
      expect(find.textContaining('80 kg'), findsNothing);
    });
  });

  group('English', () {
    testWidgets('the whole screen resolves, with no Turkish left in it',
        (tester) async {
      await pump(
        tester,
        await host(
          entries: [weight(28, 84), weight(14, 82), weight(0, 80)],
          locale: const Locale('en'),
        ),
      );
      expect(find.text('Your body'), findsOneWidget);
      expect(find.text('Consistency'), findsOneWidget);
      expect(find.textContaining('days ago'), findsOneWidget);
      expect(find.text('Weight trend'), findsOneWidget);
      await openInsights(tester, label: 'View insights');
      expect(find.textContaining("You're down"), findsOneWidget);
    });

    testWidgets('the percent sign sits where the language puts it',
        (tester) async {
      // Turkish writes %82; English writes 82%. Third time this codebase
      // has needed its own key for that.
      await pump(
        tester,
        await host(
          entries: [weight(0, 80)],
          seed: {
            'sixpack.installed_at': DateTime.now()
                .subtract(const Duration(days: 40))
                .toIso8601String(),
          },
          locale: const Locale('en'),
        ),
      );
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('%0'), findsNothing);
    });
  });
}
