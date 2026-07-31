import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/home/domain/discovery_tips.dart';
import 'package:sixpack_ai/features/home/presentation/widgets/discovery_tip_card.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// Roadmap Phase 2 (C28) · the tip card.
///
/// A DiscoveryTip holds copy as a lookup (the real catalogue is built
/// before a locale exists), so these fixtures return the same sentences
/// the assertions below always looked for.
const _withCtaBody = 'Bir şeyler yapabilirsin ve bu ipucu bunu anlatıyor.';
const _infoOnlyBody = 'Bu sadece bilgilendirme amaçlı bir ipucu metnidir.';

final _withCta = DiscoveryTip(
  id: 'with_cta',
  body: (_) => _withCtaBody,
  ctaLabel: (_) => 'Hemen Dene',
  route: '/coach',
  matches: (_) => true,
);

final _infoOnly = DiscoveryTip(
  id: 'info_only',
  body: (_) => _infoOnlyBody,
  matches: (_) => true,
);

Future<void> _pump(
  WidgetTester tester,
  DiscoveryTip tip, {
  VoidCallback? onDismiss,
  VoidCallback? onAction,
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('tr')],
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: DiscoveryTipCard(
              tip: tip,
              onDismiss: onDismiss ?? () {},
              onAction: onAction ?? () {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('renders the label, body and CTA', (tester) async {
    await _pump(tester, _withCta);

    expect(tester.takeException(), isNull);
    expect(find.text('BİLİYOR MUYDUN?'), findsOneWidget);
    expect(find.text(_withCtaBody), findsOneWidget);
    expect(find.text('Hemen Dene'), findsOneWidget);
  });

  testWidgets(
      'a tip with no route renders no CTA — a dead button is worse '
      'than none', (tester) async {
    await _pump(tester, _infoOnly);
    expect(find.text(_infoOnlyBody), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsNothing);
  });

  testWidgets('the dismiss button fires its callback', (tester) async {
    var dismissed = false;
    await _pump(tester, _withCta, onDismiss: () => dismissed = true);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    expect(dismissed, isTrue);
  });

  testWidgets('the CTA fires its callback', (tester) async {
    var actioned = false;
    await _pump(tester, _withCta, onAction: () => actioned = true);

    await tester.tap(find.text('Hemen Dene'));
    await tester.pump();
    expect(actioned, isTrue);
  });

  testWidgets('the dismiss target meets the 44dp minimum', (tester) async {
    await _pump(tester, _withCta);
    final size = tester.getSize(find.byType(IconButton));
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('dismissal is reachable by a screen reader', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _withCta);
    expect(find.bySemanticsLabel('İpucunu kapat'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('survives a 1.3 text scale on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await _pump(tester, _withCta, textScale: 1.3);
    expect(tester.takeException(), isNull);
  });
}
