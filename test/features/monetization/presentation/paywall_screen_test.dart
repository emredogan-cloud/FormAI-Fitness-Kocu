import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:sixpack_ai/features/auth/providers/auth_provider.dart';
import 'package:sixpack_ai/features/monetization/presentation/paywall_screen.dart';
import 'package:sixpack_ai/features/monetization/providers/monetization_provider.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// Stubs [SubscriptionNotifier.build] with a fixed [SubscriptionState] so
/// the widget tree never touches the RevenueCat SDK. Everything else on
/// the notifier (purchase / restore / developer override) stays
/// inherited, but the tests below only exercise [build] / [dispose].
class _StubSubscriptionNotifier extends SubscriptionNotifier {
  _StubSubscriptionNotifier(this._seed);
  final SubscriptionState _seed;

  @override
  Future<SubscriptionState> build() async => _seed;
}

/// Minimal host: a GoRouter with `/` and `/paywall` so the close-button
/// target (`context.go('/')`) has somewhere to resolve to without a real
/// app shell.
Widget _wrapPaywall({required SubscriptionState seededState}) {
  final router = GoRouter(
    initialLocation: '/paywall',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('HOME')),
      ),
      GoRoute(
        path: '/paywall',
        builder: (_, __) => const PaywallScreen(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      subscriptionProvider.overrideWith(
        () => _StubSubscriptionNotifier(seededState),
      ),
      // PaywallScreen.build reads two auth surfaces during mount:
      //   1. `ref.listen<User?>(currentUserProvider, ...)` triggers
      //      `currentUserProvider` to compute, which calls
      //      `Supabase.instance` — asserts in tests.
      //   2. `ref.read(supabaseAuthReader)()` performs a live in-memory
      //      Supabase read in the same frame for the Phase-140 sync
      //      first pass.
      // Both pin to "signed out" so the screen mounts without
      // initializing Supabase. The `isProProvider` chain
      // (`isReviewerProvider` → `currentUserProvider`) is also covered
      // by override (1).
      currentUserProvider.overrideWith((ref) => null),
      supabaseAuthReader.overrideWithValue(() => null),
    ],
    child: MaterialApp.router(
      // Roadmap Phase 5 · localized strings need the
      // delegates; assertions stay unchanged because the
      // Turkish ARB values are the same literals.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('tr')],
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    ),
  );
}

/// Builds a minimal real `Offerings` whose current offering carries an
/// annual package — optionally with an introductory price — so the
/// paywall's trial-copy derivation runs against genuine RevenueCat
/// model objects instead of stubs.
Offerings _offeringsWithAnnual({
  IntroductoryPrice? intro,
  String priceString = '₺999,99',
  String currency = 'TRY',
}) {
  const ctx = PresentedOfferingContext('default', null, null);
  final product = StoreProduct(
    'formai_pro_yearly',
    'FormAI Pro yıllık abonelik',
    'FormAI Pro (Yıllık)',
    999.99,
    priceString,
    currency,
    introductoryPrice: intro,
  );
  final annual = Package(
    r'$rc_annual',
    PackageType.annual,
    product,
    ctx,
  );
  final offering = Offering(
    'default',
    'Default offering',
    const <String, Object>{},
    [annual],
    annual: annual,
  );
  return Offerings({'default': offering}, current: offering);
}

void main() {
  testWidgets(
    'loading / null-offerings state still renders the plan cards + CTA',
    (tester) async {
      await tester.pumpWidget(_wrapPaywall(
        seededState: const SubscriptionState(),
      ));
      // `pump` (not `pumpAndSettle`) so we don't block on the eternal
      // pulsing animation that some paywall art plays.
      await tester.pump();

      // Hero copy renders.
      // Task 1 redesign · the hero title is now a two-colour RichText
      // ("Kişiselleştirilmiş" / "planınızı alın!"), so match the rich span.
      expect(find.textContaining('planınızı alın', findRichText: true),
          findsOneWidget);
      // The three plan pickers (1 Ay / 3 Ay / 12 Ay) are all on screen.
      expect(find.text('1 Ay'), findsOneWidget);
      expect(find.text('3 Ay'), findsOneWidget);
      expect(find.text('12 Ay'), findsOneWidget);
      // Phase 94 · with offerings null the CTA still mounts but renders
      // its loading-state branch (spinner instead of the "₺0,00
      // karşılığında dene" copy). Asserting on the spinner keeps the
      // intent of the test — the CTA region didn't fail to build —
      // without coupling to a specific copy string that only appears
      // once a real RevenueCat Offering is hydrated.
      expect(find.byType(CircularProgressIndicator), findsAtLeastNWidgets(1));
      // Restore button renders regardless of offerings availability.
      expect(find.text('Satın Alımları Geri Yükle'), findsOneWidget);
    },
  );

  testWidgets(
    'no offerings -> NO trial promise renders anywhere (store honesty: '
    'trial copy must derive from a real SKU, never be hardcoded)',
    (tester) async {
      await tester.pumpWidget(_wrapPaywall(
        seededState: const SubscriptionState(isPro: false),
      ));
      await tester.pump();

      expect(find.byType(PaywallScreen), findsOneWidget);
      // With no RevenueCat offering there is no trial to promise:
      // both the external badge and the in-card pill must be absent.
      expect(find.text('Şimdi ödeme yok!'), findsNothing);
      expect(find.textContaining('ücretsiz dene'), findsNothing);
      // The fictional "was ₺2.999,99" decoy anchor is permanently gone.
      expect(find.textContaining('2.999'), findsNothing);
      // The legal footer must still disclose auto-renewal explicitly.
      expect(
        find.textContaining('otomatik yenilenir', findRichText: true),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'SKU with a real free trial -> trial badges + trial-aware footer '
    'render with the real duration',
    (tester) async {
      await tester.pumpWidget(_wrapPaywall(
        seededState: SubscriptionState(
          isPro: false,
          offerings: _offeringsWithAnnual(
            intro: const IntroductoryPrice(
              0,
              '₺0,00',
              'P1W',
              1,
              PeriodUnit.day,
              7,
            ),
          ),
        ),
      ));
      await tester.pump();

      // External badge + in-card pill both derive from the live SKU.
      expect(find.text('Şimdi ödeme yok!'), findsOneWidget);
      expect(find.text('7 gün ücretsiz dene'), findsOneWidget);
      // Footer states the real trial length and the renewal terms.
      expect(
        find.textContaining('7 gün süren ücretsiz denemenin',
            findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('₺999,99 / yıl', findRichText: true),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'SKU without a trial -> subscribe-only copy: no trial words, '
    'price + renewal disclosure present',
    (tester) async {
      await tester.pumpWidget(_wrapPaywall(
        seededState: SubscriptionState(
          isPro: false,
          offerings: _offeringsWithAnnual(intro: null),
        ),
      ));
      await tester.pump();

      expect(find.text('Şimdi ödeme yok!'), findsNothing);
      expect(find.textContaining('ücretsiz dene'), findsNothing);
      expect(
        find.textContaining('₺999,99 / yıl', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('otomatik yenilenir', findRichText: true),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'entitlement-active state renders without throwing so a paywall '
    'resurfaced to a Pro user cannot crash the app',
    (tester) async {
      await tester.pumpWidget(_wrapPaywall(
        seededState: const SubscriptionState(isPro: true),
      ));
      await tester.pump();

      // The paywall doesn't currently auto-dismiss when entitlement flips
      // true, but the smoke test here is that the widget still *mounts*
      // in this state (otherwise Pro users who get deep-linked here
      // would hit a redscreen).
      expect(find.byType(PaywallScreen), findsOneWidget);
      // Task 1 redesign · the hero title is now a two-colour RichText
      // ("Kişiselleştirilmiş" / "planınızı alın!"), so match the rich span.
      expect(find.textContaining('planınızı alın', findRichText: true),
          findsOneWidget);
    },
  );

  testWidgets(
    'store-submission M2 · loaded-but-no-offering shows the "Fiyatlar '
    'yüklenemedi" retry notice instead of inventing prices',
    (tester) async {
      // A resolved SubscriptionState with a null offerings catalogue is
      // the exact "RC configured but fetch failed / empty" signal.
      await tester.pumpWidget(_wrapPaywall(
        seededState: const SubscriptionState(isPro: false),
      ));
      await tester.pump();

      // The honest load-failure notice + retry affordance are present.
      expect(find.text('Fiyatlar yüklenemedi.'), findsOneWidget);
      expect(find.text('Tekrar dene'), findsOneWidget);
    },
  );

  testWidgets(
    'store-submission M2 · the retired hardcoded fallback prices never '
    'render (₺249,99 / ₺999,99 / ₺499,99 as invented values)',
    (tester) async {
      await tester.pumpWidget(_wrapPaywall(
        seededState: const SubscriptionState(isPro: false),
      ));
      await tester.pump();

      // None of the old marketing-spec fallback numbers may appear when
      // there is no live offering — the price slot shows an em-dash.
      expect(find.textContaining('249,99'), findsNothing);
      expect(find.textContaining('499,99'), findsNothing);
      // ₺999,99 only ever appears from a live SKU (covered by the trial
      // tests above); with no offering it must be absent here too.
      expect(find.textContaining('999,99'), findsNothing);
    },
  );

  testWidgets(
    'store-submission M2 · a live offering suppresses the retry notice '
    'and shows the real store price',
    (tester) async {
      await tester.pumpWidget(_wrapPaywall(
        seededState: SubscriptionState(
          isPro: false,
          offerings: _offeringsWithAnnual(intro: null),
        ),
      ));
      await tester.pump();

      // With a real offering there is nothing to retry; the notice is gone
      // and the live price string renders instead of an em-dash.
      expect(find.text('Fiyatlar yüklenemedi.'), findsNothing);
      expect(find.text('Tekrar dene'), findsNothing);
      expect(
        find.textContaining('₺999,99 / yıl', findRichText: true),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'closed-test hotfix (Task 2) · the purchase CTA sits above the fold on a '
    '6.1" phone — visible without scrolling',
    (tester) async {
      // A 6.1" logical viewport (Pixel / iPhone-14 class): 393 × 852.
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrapPaywall(
        seededState: SubscriptionState(
          isPro: false,
          offerings: _offeringsWithAnnual(intro: null),
        ),
      ));
      await tester.pump();

      // The primary purchase CTA carries a stable key so we can locate it
      // regardless of its loading/loaded state.
      final cta = find.byKey(const ValueKey('paywall_primary_cta'));
      expect(cta, findsOneWidget);

      // Its top edge must land comfortably inside the 852 px viewport so the
      // user never has to scroll to reach it. Before the hotfix (guarantee +
      // AI-features card above the CTA, 320 px hero) it sat ~967 px down.
      final ctaTop = tester.getTopLeft(cta).dy;
      expect(
        ctaTop,
        lessThan(800),
        reason: 'CTA top ($ctaTop px) must be above the 852 px fold',
      );
    },
  );
  testWidgets(
    'a non-Turkish storefront renders no lira sign anywhere on the paywall',
    (tester) async {
      // Phase 5 · the trial CTA read "₺0,00 karşılığında dene" with the
      // lira sign and the Turkish decimal comma baked into Dart; it now
      // renders the store's own introductory price string. The CTA copy
      // itself only mounts once the billing SDK reports ready, which a
      // widget test cannot reach — so what is asserted here is the
      // property that mattered: on a USD storefront every price the
      // paywall DOES render comes from the store, and no lira leaks
      // through from hardcoded copy.
      await tester.pumpWidget(_wrapPaywall(
        seededState: SubscriptionState(
          isPro: false,
          offerings: _offeringsWithAnnual(
            priceString: r'$29.99',
            currency: 'USD',
            intro: const IntroductoryPrice(
              0,
              r'$0.00',
              'P1W',
              1,
              PeriodUnit.day,
              7,
            ),
          ),
        ),
      ));
      await tester.pump();

      expect(find.textContaining(r'$29.99', findRichText: true), findsWidgets);
      expect(find.textContaining('₺', findRichText: true), findsNothing);
      // The trial length still comes from the SKU, in the user's language.
      expect(find.text('7 gün ücretsiz dene'), findsOneWidget);
    },
  );

  testWidgets(
    'the subscription disclosure keeps both legal links tappable',
    (tester) async {
      await tester.pumpWidget(_wrapPaywall(
        seededState: SubscriptionState(
          isPro: false,
          offerings: _offeringsWithAnnual(intro: null),
        ),
      ));
      await tester.pump();

      // The disclosure is assembled from whole ARB sentences and the
      // links are attached by splitting the result. Store policy needs
      // the terms and privacy documents reachable from here, so the
      // recognisers are asserted, not just the words.
      final footer = tester.widget<RichText>(
        find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText().contains('otomatik yenilenir'),
        ),
      );
      final tappable = _flattenSpans(footer.text as TextSpan)
          .where((s) => s.recognizer != null)
          .toList();
      expect(tappable, hasLength(2));
      expect(
        tappable.map((s) => s.text),
        containsAll(<String>['Kullanım Şartları', 'Gizlilik Politikası']),
      );
      // Sentence order: renewal terms, then how to cancel, then consent.
      final plain = footer.text.toPlainText();
      expect(
        plain.indexOf('otomatik yenilenir'),
        lessThan(plain.indexOf('Devam ederek')),
      );
      expect(plain, endsWith('kabul etmiş olursun.'));
    },
  );
}

/// `Text.rich` wraps the caller's span in one of its own, so the linked
/// fragments are never direct children.
Iterable<TextSpan> _flattenSpans(TextSpan root) sync* {
  yield root;
  for (final child in root.children ?? const <InlineSpan>[]) {
    if (child is TextSpan) yield* _flattenSpans(child);
  }
}
