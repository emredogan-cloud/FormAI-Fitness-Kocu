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
  final today = BodyMetric.dayOf(DateTime(2026, 8, 2));
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

  group('the empty state', () {
    testWidgets('invites rather than instructs', (tester) async {
      await pump(tester, await host(entries: const []));
      expect(find.text('Henüz kayıt yok'), findsOneWidget);
      expect(
        find.textContaining('Başlamak için tek bir sayı yeter'),
        findsOneWidget,
      );
    });

    testWidgets('offers the entry action', (tester) async {
      await pump(tester, await host(entries: const []));
      expect(find.text('Ölçüm ekle'), findsWidgets);
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
      expect(find.textContaining('verdin'), findsOneWidget);
    });

    testWidgets(
        'states a gain in exactly the same register — a bulking user is '
        'succeeding here', (tester) async {
      await pump(
        tester,
        await host(entries: [weight(28, 70), weight(14, 72), weight(0, 74)]),
      );
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
      expect(find.textContaining('kilon sabit'), findsOneWidget);
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
      expect(find.textContaining("You're down"), findsOneWidget);
      expect(find.text('Consistency'), findsOneWidget);
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
