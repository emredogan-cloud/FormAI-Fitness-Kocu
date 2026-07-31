import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/features/onboarding/presentation/steps/act_3_buildup_steps.dart';
import 'package:sixpack_ai/features/onboarding/providers/wizard_provider.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// Act 3 collects everything the plan generator needs: gender, goal,
/// experience, session length, activity, body data and pain point.
///
/// Phase 5 moved all of its copy into ARB, which meant unwinding the
/// `const` option lists these steps were built from. Two things can
/// break silently in that move and neither shows up in `flutter
/// analyze`:
///
///   • a step renders but its answer tokens drift — the wizard stores
///     `belly_burn`, not the label — so every option's *token* is
///     asserted alongside its localised label;
///   • the localised value never reaches the widget at all (a missed
///     replacement still compiles).
///
/// The tests below therefore pump each step against the real Turkish
/// ARB and assert the same strings the screens shipped with.

Widget _host(Widget child, {ProviderContainer? container}) {
  return UncontrolledProviderScope(
    container: container ?? ProviderContainer(),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('tr')],
      home: Scaffold(body: child),
      debugShowCheckedModeBanner: false,
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget step, {
  ProviderContainer? container,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_host(step, container: container));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('gender step renders its localised title and options',
      (tester) async {
    await _pump(tester, GenderStep(onCommitted: () {}));

    expect(find.text('Cinsiyetin?'), findsOneWidget);
    expect(find.text('Programını sana göre kalibre edelim.'), findsOneWidget);
    expect(find.text('Kadın'), findsOneWidget);
    expect(find.text('Erkek'), findsOneWidget);
    expect(find.text('Diğer'), findsOneWidget);
    expect(find.text('💡 Yapay Zeka Notu'), findsOneWidget);
  });

  testWidgets('gender step stores the enum token, not the localised label',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    var committed = false;
    await _pump(
      tester,
      GenderStep(onCommitted: () => committed = true),
      container: container,
    );

    await tester.tap(find.text('Kadın'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));

    expect(committed, isTrue);
    // The wizard persists an enum, so translating 'Kadın' can never
    // change what the plan generator reads.
    expect(container.read(wizardProvider).gender, Gender.female);
  });

  testWidgets('goal step reuses the shared goal labels', (tester) async {
    await _pump(tester, GoalStep(onCommitted: () {}));

    expect(find.text('Hedefin ne?'), findsOneWidget);
    // These four labels are shared with the profile + plan surfaces
    // through the goal*Lower keys; a rename there must not silently
    // reword onboarding.
    expect(find.text('Göbek eritmek'), findsOneWidget);
    expect(find.text('Kas yapmak'), findsOneWidget);
    expect(find.text('Daha fit görünmek'), findsOneWidget);
    expect(find.text('Güçlenmek'), findsOneWidget);
  });

  testWidgets('experience step renders labels and their helper lines',
      (tester) async {
    await _pump(tester, ExperienceStep(onCommitted: () {}));

    expect(find.text('Daha önce spor yaptın mı?'), findsOneWidget);
    expect(find.text('Hiç yapmadım'), findsOneWidget);
    expect(
      find.text(
          'Hiç sorun değil. Sıfırdan başlayıp hızlı gelişim sağlayacağız.'),
      findsOneWidget,
    );
    expect(find.text('Ara sıra yaptım'), findsOneWidget);
    expect(find.text('Düzenli yapıyorum'), findsOneWidget);
  });

  testWidgets('daily-minutes step keeps its en-dash ranges', (tester) async {
    await _pump(tester, DailyMinutesStep(onCommitted: () {}));

    expect(find.text('Günde ne kadar zaman ayırabilirsin?'), findsOneWidget);
    // The dash is a typographic en-dash, not a hyphen — a translator
    // round-trip through a spreadsheet is the usual way that flips.
    expect(find.text('10–15 dakika'), findsOneWidget);
    expect(find.text('20–30 dakika'), findsOneWidget);
    expect(find.text('45+ dakika'), findsOneWidget);
    expect(find.text('💡 Form Diyor ki:'), findsOneWidget);
  });

  testWidgets('activity step renders shared activity labels', (tester) async {
    await _pump(tester, ActivityStep(onCommitted: () {}));

    expect(find.text('Günlük aktiviten?'), findsOneWidget);
    expect(find.text('Masa başı'), findsOneWidget);
    expect(find.text('Hafif hareketli'), findsOneWidget);
    expect(find.text('Çok aktif'), findsOneWidget);
    expect(
      find.text('Gününü açıklarsan daha iyi yardımcı olabiliriz'),
      findsOneWidget,
    );
  });

  testWidgets('physical-data step labels the three wheels', (tester) async {
    await _pump(tester, PhysicalDataStep(onContinue: () {}));

    expect(find.text('Vücut bilgilerin'), findsOneWidget);
    expect(find.text('YAŞ'), findsOneWidget);
    expect(find.text('BOY'), findsOneWidget);
    expect(find.text('KİLO'), findsOneWidget);
    expect(find.text('DEVAM'), findsOneWidget);
  });

  testWidgets('pain-point step keeps the audited option order', (tester) async {
    await _pump(tester, PainPointStep(onCommitted: () {}));

    expect(find.text('Seni en çok zorlayan ne?'), findsOneWidget);

    // Phase 114 · the shame-trigger answer stays last so the user has
    // normalised the choice on the first three. Localisation rebuilt
    // this list, so the order is asserted rather than assumed.
    final labels = ['Süreklilik', 'Motivasyon', 'Diyet'];
    var previousY = double.negativeInfinity;
    for (final label in labels) {
      final y = tester.getTopLeft(find.text(label)).dy;
      expect(y, greaterThan(previousY), reason: '$label is out of order');
      previousY = y;
    }
    expect(
      tester.getTopLeft(find.text('Ne yapacağımı bilmiyorum')).dy,
      greaterThan(previousY),
    );
  });
}
