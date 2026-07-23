import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../../../core/services/analytics_service.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/legal_urls.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../auth/presentation/auth_modal_bottom_sheet.dart';
import '../../auth/providers/auth_provider.dart';
import '../../onboarding/providers/wizard_provider.dart';
import '../providers/monetization_provider.dart';
import 'premium_welcome_sheet.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

enum _Plan { monthly, yearly, quarterly }

/// Store-honesty pass · returns the package's introductory offer ONLY
/// when it is a genuinely free trial (intro price == 0). Every piece of
/// "ücretsiz dene / şimdi ödeme yok" copy on this screen must derive
/// from this — never hardcode a trial promise the store SKU doesn't
/// carry (Apple 3.1.2 / Play subscriptions policy).
IntroductoryPrice? _freeTrialOf(Package? package) {
  final intro = package?.storeProduct.introductoryPrice;
  if (intro == null || intro.price != 0) return null;
  return intro;
}

/// Human Turkish label for a trial length, e.g. "7 gün", "1 hafta".
/// Falls back to a unitless "ücretsiz deneme" phrasing when the store
/// reports an unknown period unit.
String _trialLengthLabel(IntroductoryPrice intro) {
  final unit = switch (intro.periodUnit) {
    PeriodUnit.day => 'gün',
    PeriodUnit.week => 'hafta',
    PeriodUnit.month => 'ay',
    PeriodUnit.year => 'yıl',
    _ => null,
  };
  if (unit == null) return 'ücretsiz deneme';
  return '${intro.periodNumberOfUnits} $unit';
}

/// Billing-period label for the renewal disclosure line.
String _periodLabelOf(_Plan plan) => switch (plan) {
      _Plan.monthly => 'ay',
      _Plan.yearly => 'yıl',
      _Plan.quarterly => '3 ay',
    };

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  static const Color _neon = Color(0xFF8E5BFF);
  static const Color _neonAccent = Color(0xFF4DA6FF);

  _Plan _selected = _Plan.yearly;
  bool _busy = false;
  bool _restoring = false;

  /// Phase 94 · single-fire latch so the auth gate doesn't re-trigger
  /// after a successful sign-in (the auth state stream rebuilds the
  /// paywall when it transitions; without the latch we'd race-loop the
  /// gate as the user moves from anonymous → registered, because the
  /// `ref.listen` callback fires once per state delivery).
  bool _authGateShown = false;

  /// Phase 141 · single-fire latch for "Pro detected; navigate to
  /// dashboard". A Pro user who lands on the paywall — whether
  /// because the router auto-redirected them from `/auth` after
  /// login, because a locked-feature tap pushed them here, or
  /// because they navigated manually — should never be made to
  /// look at the offer cards. We watch `isProProvider` and self-
  /// redirect to the dashboard the moment it reports true. The
  /// latch prevents repeated post-frame schedules if multiple
  /// listener fires land in the same frame.
  bool _proRouteScheduled = false;

  /// Phase 96 · mirrors `Purchases.isConfigured`. We can't call the
  /// async getter inline from `build()`, so the value is read once on
  /// mount and re-read after each connectivity transition (and after a
  /// successful offerings reload). Buy + Restore stay disabled with a
  /// spinner until this is true AND offerings have loaded — closing
  /// the "first-click race" the previous CTA gating only half-covered.
  bool _purchasesConfigured = false;

  /// Phase 96 · last observed online state, consulted by the
  /// connectivity listener so we only react to actual transitions
  /// (offline → online) instead of every duplicate `true` event the
  /// `connectivity_plus` stream may emit (e.g. WiFi handoff still
  /// reports a non-`none` interface). Initialised to `null` so the
  /// first event always lands as "discovered initial state" — no
  /// redundant invalidation on mount when we were online the whole
  /// time.
  bool? _lastOnline;

  @override
  void initState() {
    super.initState();
    // Phase 42 analytics — fire once per mount so the
    // viewed-→-purchased conversion rate is derivable. If the paywall
    // is reached from multiple surfaces we'll wire a `source` param
    // later via a constructor arg.
    AnalyticsService.instance.paywallViewed();
    // Phase 94 · the auth gate trigger lives in `build()` via
    // `ref.listen(currentUserProvider, …)` plus a synchronous
    // first-pass call to the same handler. The previous
    // post-frame-in-initState approach was unreliable: it only
    // checked the auth state once at first frame and didn't react to
    // transitions (user signs out from another surface, anon-recovery
    // refires after a refresh-token cycle, etc.). The reactive
    // pattern covers both the cold-mount case (synthetic initial
    // fire from `ref.read` in build) and any subsequent state change.

    // Phase 96 · seed `_purchasesConfigured` so the CTA can flip out of
    // the spinner state on cold mount when the SDK was already
    // configured during onboarding / a previous session. The async
    // getter is fire-and-forget; the build method handles the not-yet
    // case by keeping the spinner up.
    _refreshSdkReady();
    // Phase 141 · post-auth refresh safety net.
    //
    // When the router auto-redirects /auth → /paywall on auth state
    // change, AuthScreen unmounts mid-`_submit`. Whichever follow-up
    // calls happened to be in flight (alias, subscription refresh,
    // manual navigation) may have died on the WidgetRef the moment
    // AuthScreen's State was disposed. That left `subscriptionProvider`
    // holding the pre-auth anonymous entitlement snapshot, so
    // `isProProvider` stayed false even for an existing-Pro user, and
    // the self-redirect below couldn't fire.
    //
    // Calling alias here is idempotent — short-circuits if RC is
    // already aliased to the current Supabase user — but for the
    // post-/auth landing case it forces `Purchases.logIn` against the
    // freshly signed-in user, which invalidates `subscriptionProvider`
    // (see `AuthController.aliasRevenueCatWithCurrentUser`), which
    // triggers a fresh `getCustomerInfo`, which flips `isProProvider`
    // to true for an active entitlement. The `isProProvider` listener
    // below then schedules the dashboard navigation on the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hydrateSubscriptionForCurrentUser();
    });
  }

  /// Phase 141 · ensures RC is aliased to the current Supabase user
  /// and subscriptionProvider reflects the post-`logIn` entitlement set.
  /// Idempotent and safe to call repeatedly — the alias helper has its
  /// own "already aligned" short-circuit.
  Future<void> _hydrateSubscriptionForCurrentUser() async {
    if (!mounted) return;
    try {
      await ref.read(authControllerProvider).aliasRevenueCatWithCurrentUser();
    } catch (e, st) {
      AppLogger.warning(
        'paywall mount alias hydration failed; falling back to existing '
        'subscription state',
        category: 'monetization',
        data: {'error': e.toString(), 'stack': st.toString()},
      );
    }
  }

  /// Phase 96 · refresh the cached `Purchases.isConfigured` value.
  /// Called on mount and after each offline → online transition so the
  /// CTA's gating reflects the SDK's actual state instead of the
  /// snapshot we took once at boot.
  Future<void> _refreshSdkReady() async {
    try {
      final ready = await Purchases.isConfigured;
      if (!mounted) return;
      if (_purchasesConfigured != ready) {
        setState(() => _purchasesConfigured = ready);
      }
    } catch (e, st) {
      AppLogger.warning(
        'Purchases.isConfigured probe failed; CTA stays gated',
        category: 'monetization',
        data: {'error': e.toString(), 'stack': st.toString()},
      );
    }
  }

  /// Phase 96 · drives the "internet flickered, now we're back" reset.
  ///
  /// Two things happen in order:
  ///   1. `Purchases.invalidateCustomerInfoCache()` — drops the
  ///      cached entitlement snapshot so the next `getCustomerInfo`
  ///      hits the network. Without this, a user who came online
  ///      after a stale offline session keeps seeing the cached
  ///      "anonymous, no entitlement" view even after a successful
  ///      Restore on the server side.
  ///   2. `subscriptionProvider.notifier.refresh()` — re-fetches the
  ///      offerings catalogue. This re-arms `canPurchase` once a real
  ///      Offering lands, and re-evaluates `isPro` on the freshly
  ///      invalidated cache. The CTA stays gated for the duration
  ///      via `subscription.isLoading`.
  ///
  /// Both calls are best-effort; failures are logged but never thrown
  /// — the user's CTA path keeps falling back to the existing
  /// no-offerings error toast on tap.
  Future<void> _onConnectivityRestored() async {
    try {
      await Purchases.invalidateCustomerInfoCache();
    } catch (e, st) {
      AppLogger.warning(
        'invalidateCustomerInfoCache failed on reconnect',
        category: 'monetization',
        data: {'error': e.toString(), 'stack': st.toString()},
      );
    }
    if (!mounted) return;
    await ref.read(subscriptionProvider.notifier).refresh();
    if (!mounted) return;
    await _refreshSdkReady();
  }

  /// Phase 96 · connectivity transition handler. Only the offline →
  /// online edge triggers the reset; the reverse is silent because
  /// the existing `canPurchase` gate already disables the CTA when
  /// offerings are missing, and we don't want to trash a perfectly
  /// good cached snapshot the moment the device drops a packet.
  void _onConnectivityChanged(
    AsyncValue<bool>? previous,
    AsyncValue<bool> next,
  ) {
    final online = next.value;
    if (online == null) return;
    final wasOnline = _lastOnline;
    _lastOnline = online;
    // First emission: just record it; nothing to react to.
    if (wasOnline == null) return;
    if (!wasOnline && online) {
      unawaited(_onConnectivityRestored());
    }
  }

  /// Phase 141 · listener for [isProProvider] transitions. Fires the
  /// dashboard navigation the first time Pro becomes true. Latched
  /// so duplicate signals (e.g. RC re-emitting customerInfo after a
  /// successful purchase) don't schedule overlapping navigations.
  void _onProDetected(bool? previous, bool next) {
    if (!next || _proRouteScheduled) return;
    _proRouteScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go('/');
    });
  }

  /// Phase 94 · auth-gate dispatcher. Called from two sites in
  /// `build()`: (1) `ref.listen` on every real transition of
  /// [currentUserProvider]; (2) a synchronous first-pass call with
  /// the live Supabase currentUser (NOT the Riverpod-cached value —
  /// see Phase 140 note below). The [_authGateShown] latch ensures
  /// the gate route is pushed at most once per paywall mount even
  /// though the handler is invoked many times.
  ///
  /// Side-effect navigation is deferred to a post-frame callback
  /// because the synchronous first-pass call happens DURING the
  /// build phase — calling `Navigator.push` synchronously there
  /// throws "Tried to push a route while building widgets". Setting
  /// the latch BEFORE scheduling means subsequent listen fires (e.g.
  /// the auth-state stream re-emitting the same anonymous user
  /// during refresh-token rotation) short-circuit at the first
  /// check, so only one post-frame callback ever runs.
  void _onAuthStateChanged(User? previous, User? next) {
    if (_authGateShown) return;
    // Phase 140 · session-wide latch. Once any auth flow has
    // succeeded in this app session, the paywall NEVER re-shows the
    // gate. This survives `pushReplacement` (the email-login return
    // path that destroys+remounts PaywallScreen) because the
    // provider's storage is app-scoped, not widget-scoped. Reset on
    // sign-out via `_invalidateUserScopedProviders`.
    if (ref.read(authGateClearedProvider)) {
      _authGateShown = true;
      return;
    }
    // Phase 139 · email-signup detection (defence in depth). A user
    // who linked an email via `auth.updateUser` keeps
    // `isAnonymous == true` until verification, but their purchase
    // is correctly attributable. `email` is populated when
    // confirmations are off; `newEmail` while one is pending.
    final hasLinkedEmail =
        (next?.email ?? '').isNotEmpty || (next?.newEmail ?? '').isNotEmpty;
    final needsAuth = next == null || (next.isAnonymous && !hasLinkedEmail);
    if (!needsAuth) return;
    _authGateShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showAuthGate(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Phase 94 · forced auth gate, reactively wired.
    //
    // `ref.listen` is the canonical Riverpod pattern for reacting to
    // state changes from inside `build()` — it fires on every
    // transition of `currentUserProvider` (sign-in succeeds, sign-out
    // from another surface, anon-recovery on cold start, etc.) and
    // is safe to register here.
    //
    // Catch — Riverpod 3.x DROPPED the `fireImmediately` flag from
    // `ref.listen`; only `ref.listenManual` retains it. Without the
    // flag, the listener fires only on *changes*, and the failure
    // case the gate exists to catch (anonymous user hitting the
    // paywall with state already settled before mount) produces no
    // change → no fire → no gate. We synthesise the missing
    // fire-immediately by calling the same handler once with the
    // synchronous current value via `ref.read`. The handler's
    // `_authGateShown` latch dedupes between this synthetic initial
    // fire and any real transition that lands in the same frame.
    ref.listen<User?>(currentUserProvider, _onAuthStateChanged);
    // Phase 140 · the synchronous first-pass reads directly from
    // Supabase's in-memory session instead of `currentUserProvider`.
    // The provider's cached value can lag behind the live Supabase
    // state when a fresh PaywallScreen mounts in the same frame as
    // an `auth.updateUser` resolution — the auth-state stream hasn't
    // emitted yet, so the cached value is the pre-auth anonymous
    // user, which would falsely trigger the gate. `currentUser` is
    // a synchronous getter against the in-memory session row, which
    // every auth operation updates before resolving its future.
    _onAuthStateChanged(null, ref.read(supabaseAuthReader)());

    // Phase 141 · self-redirect for Pro users. The router auto-
    // bounces non-anonymous users from `/auth` → `/paywall` the
    // moment Supabase emits `signedIn`, which unmounts AuthScreen
    // before its own `_routePostAuth` can navigate Pro users to
    // the dashboard. Watching `isProProvider` here closes that
    // race: regardless of how a Pro user landed on the paywall,
    // we get them off it on the next frame.
    ref.listen<bool>(isProProvider, _onProDetected);
    final currentIsPro = ref.read(isProProvider);
    if (currentIsPro && !_proRouteScheduled) {
      _proRouteScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go('/');
      });
    }

    // Phase 96 · drive the offline → online reset off the shared
    // connectivity stream. Watching from build() means the listener's
    // lifetime is tied to the screen's, and the handler keys off the
    // last-observed value so duplicate "still online" emissions don't
    // re-invalidate a perfectly good RC cache.
    ref.listen<AsyncValue<bool>>(connectivityProvider, _onConnectivityChanged);

    // Phase 94 · purchase-button gating. The "first-click race"
    // happens when the user taps the CTA before
    // `Purchases.getOfferings()` has resolved — the BillingClient
    // launch then races the offering fetch and Google Play Billing's
    // first click silently no-ops. Watching the AsyncNotifier here
    // surfaces the loading state to the CTA (spinner + disabled)
    // until the active Offering is hydrated.
    //
    // We drill into `offerings.current` (not just `value != null`)
    // because the Notifier returns a `SubscriptionState` synchronously
    // even on the catch path — so `value` is non-null even when
    // RevenueCat failed to fetch offerings. `current` is the actual
    // signal that a buyable Package exists.
    final subscription = ref.watch(subscriptionProvider);
    final offerings = subscription.value?.offerings;
    // Phase 96 · the gate is now `SDK ready AND offerings present`.
    // Splitting these out lets us keep the skeleton-price / em-dash
    // treatment on the cards while disabling the action buttons more
    // strictly — the cards must still draw *something* when the SDK is
    // misconfigured (dev builds), but the action buttons must NOT fire
    // a doomed BillingClient call.
    final canPurchase = _purchasesConfigured && offerings?.current != null;
    // Store-honesty pass · every trial/renewal line below derives from
    // the SELECTED plan's live RevenueCat package. No configured trial
    // on the SKU → no trial promise anywhere on this screen.
    final selectedPackage = _packageForPlan(_selected, offerings);
    final selectedTrial = _freeTrialOf(selectedPackage);
    // Phase 95 · drives the per-card price slot. True only while the
    // RevenueCat fetch is genuinely in flight; once `_load` resolves —
    // even on the catch path that returns a no-offerings
    // `SubscriptionState` — `isLoading` flips to false and the card
    // falls through to the em-dash slot while the plans row surfaces
    // the "Fiyatlar yüklenemedi" retry notice (store-submission M2).
    final offeringsLoading = subscription.isLoading;

    // Phase 53F · drop the Scaffold's hardcoded `Colors.black` so the
    // active theme's `scaffoldBackgroundColor` flows through (lightBg
    // in light mode, darkBg in dark). The brand purple gradient stays
    // because it's the paywall's hero treatment — but in light mode it
    // fades onto white instead of black so the cards below don't sit
    // on a half-black, half-white backdrop.
    final isDark = context.isDarkMode;
    return Scaffold(
      body: Stack(
        children: [
          // Layer 1 · brand gradient (unchanged from Phase 53F).
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? const [Color(0xFF1A0B3D), Colors.black]
                      : [
                          _neon.withValues(alpha: 0.18),
                          context.colors.surface,
                        ],
                  stops: const [0.0, 0.55],
                ),
              ),
            ),
          ),
          // Layer 2 · Phase 115 cinematic backdrop. Dark mode only —
          // light mode keeps its existing flat-gradient treatment so
          // the marketing-card hierarchy stays maximally readable.
          // Reads as "the onboarding journey is layered behind this
          // moment" — the photos the user just walked through stay
          // present in the room, dimmed and blurred, as Form invites
          // them to commit.
          if (isDark) const Positioned.fill(child: _PaywallCinematicBackdrop()),
          // Layer 3 · paywall content (unchanged structure / order).
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeroSection(gender: ref.watch(wizardProvider).gender),
                  const SizedBox(height: 24),
                  _buildPlansRow(
                    offerings: offerings,
                    isLoading: offeringsLoading,
                  ),
                  const SizedBox(height: 18),
                  // "Şimdi ödeme yok!" is only true when the selected
                  // SKU actually carries a free trial — hidden otherwise.
                  if (selectedTrial != null) ...const [
                    _NoPaymentBadge(),
                    SizedBox(height: 16),
                  ],
                  _buildCta(canPurchase: canPurchase, trial: selectedTrial),
                  const SizedBox(height: 6),
                  _buildRestoreButton(
                    canPurchase: canPurchase,
                    isLoading: offeringsLoading,
                  ),
                  const SizedBox(height: 6),
                  _LegalFooter(
                    trial: selectedTrial,
                    priceString: selectedPackage?.storeProduct.priceString,
                    periodLabel: _periodLabelOf(_selected),
                  ),
                  // Phase 40: Sandbox override button is strictly a
                  // debug-only affordance now. The `_kDevProOverrideKey`
                  // logic in `monetization_provider` still reads from
                  // SharedPreferences regardless so local devs can keep
                  // the flag set, but the UI tile only renders in
                  // debug builds — App Store reviewers never see it.
                  if (kDebugMode) ...[
                    const SizedBox(height: 12),
                    _buildSandboxButton(),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: _CloseButton(onTap: () => _close(context)),
          ),
          // Phase 142 · transitional hydration veil.
          //
          // Visible while `subscriptionProvider` is in flight (cold-
          // start RC load, post-auth alias re-fetch) OR while a Pro
          // self-redirect is scheduled but hasn't yet happened. Both
          // cases would otherwise expose the paywall's offer cards
          // briefly during what should be a clean transition — a
          // free user mid-cold-start sees skeleton cards flicker
          // into real prices; a freshly-signed-in Pro user sees the
          // paywall flash for ~500-900ms before the dashboard
          // navigation completes. The veil masks both without
          // adding spinner-hell semantics: a single small brand-
          // purple progress indicator on the paywall's own dark
          // backdrop reads as "preparing" rather than "stuck".
          //
          // The veil is the topmost Stack layer so it covers the
          // close button — intentional, since tapping close during
          // hydration would otherwise race the in-flight alias call.
          // Fade is 320 ms ease-out, matched to the route's 280 ms
          // CustomTransitionPage so the two animations feel of a
          // piece.
          IgnorePointer(
            ignoring: !(subscription.isLoading || _proRouteScheduled),
            child: AnimatedOpacity(
              opacity:
                  (subscription.isLoading || _proRouteScheduled) ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              child: const _PaywallHydrationVeil(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlansRow({
    required Offerings? offerings,
    required bool isLoading,
  }) {
    // Store-submission M2 · loaded-but-no-offering ⇒ say so and offer a
    // retry instead of decorating the cards with invented prices (the
    // CTA is already disabled in this state via the canPurchase gate).
    final loadFailed = !isLoading && offerings?.current == null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loadFailed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  size: 16,
                  color: context.colors.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Text(
                  'Fiyatlar yüklenemedi.',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ref.read(subscriptionProvider.notifier).refresh();
                    _refreshSdkReady();
                  },
                  child: const Text('Tekrar dene'),
                ),
              ],
            ),
          ),
        _plansCards(offerings: offerings, isLoading: isLoading),
      ],
    );
  }

  Widget _plansCards({
    required Offerings? offerings,
    required bool isLoading,
  }) {
    return SizedBox(
      height: 230,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _PlanCard(
              plan: _Plan.monthly,
              isSelected: _selected == _Plan.monthly,
              onTap: () => setState(() => _selected = _Plan.monthly),
              package: _packageForPlan(_Plan.monthly, offerings),
              isLoading: isLoading,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _PlanCard(
              plan: _Plan.yearly,
              isSelected: _selected == _Plan.yearly,
              onTap: () => setState(() => _selected = _Plan.yearly),
              package: _packageForPlan(_Plan.yearly, offerings),
              isLoading: isLoading,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _PlanCard(
              plan: _Plan.quarterly,
              isSelected: _selected == _Plan.quarterly,
              onTap: () => setState(() => _selected = _Plan.quarterly),
              package: _packageForPlan(_Plan.quarterly, offerings),
              isLoading: isLoading,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCta({required bool canPurchase, IntroductoryPrice? trial}) {
    // Phase 53 · the paywall's primary "Devam Et / Try at ₺0,00" path
    // is the screen's monetisation hinge. Wrap with explicit semantics
    // so screen readers announce the action instead of trying to read
    // the price string + arrow icon as separate elements.
    //
    // Phase 94 · the loading-state branch now triggers on EITHER
    // an in-flight purchase (`_busy`) OR an unresolved RevenueCat
    // offering (`!canPurchase`). The latter prevents the
    // "first-click race" where a user taps the CTA in the ~250-600 ms
    // between paywall mount and `Purchases.getOfferings()` resolving:
    // BillingClient was launching against a null Package, the first
    // tap silently no-op'd, and the user thought the app was broken.
    final waiting = _busy || !canPurchase;
    return Semantics(
      button: true,
      enabled: !waiting,
      label: waiting ? 'Yükleniyor' : 'Aboneliğe devam et',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _neon.withValues(alpha: 0.6),
                blurRadius: 32,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [_neon, _neonAccent],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: waiting ? null : _purchase,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: waiting
                      ? const [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          ),
                        ]
                      : [
                          // Phase 53 · `maxLines: 2 + ellipsis` so the
                          // hero CTA copy gracefully wraps when the
                          // user has the system text scaler cranked
                          // (TextScaler ~1.6+ pushed the original
                          // single-line layout into a horizontal
                          // overflow on a 360 px iPhone SE).
                          //
                          // Store-honesty pass · "₺0,00 karşılığında
                          // dene" is only shown when the selected SKU
                          // really carries a free trial; otherwise the
                          // CTA is a plain subscribe action.
                          Flexible(
                            child: Text(
                              trial != null
                                  ? '₺0,00 karşılığında dene'
                                  : "Premium'a Geç",
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSandboxButton() {
    return Center(
      child: TextButton(
        onPressed: _busy || _restoring ? null : _unlockAsDeveloper,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white38,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          textStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        child: const Text("[DEV] Premium'u Aç (Sandbox)"),
      ),
    );
  }

  Widget _buildRestoreButton({
    required bool canPurchase,
    required bool isLoading,
  }) {
    // Phase 53G · was hardcoded `Colors.white70` — invisible on the
    // light paywall scaffold. onSurface flips legibility on both
    // palettes; spinner inherits the same colour.
    final restoreColor = context.colors.onSurface.withValues(alpha: 0.70);
    // Phase 96 · Restore is gated on the same "SDK ready + offerings
    // hydrated" condition as Buy. A pre-init Restore call resolves
    // against the anonymous app-user-ID on whatever cached customer
    // info the SDK happened to ship with — usually nothing — so the
    // user sees "geri yüklenecek bir abonelik bulunamadı" even though
    // the real entitlement IS waiting on the server.
    //
    // Visual treatment:
    //   • spinner only while a load is genuinely in flight (initial
    //     RC probe via `subscription.isLoading`, OR an active Restore
    //     tap via `_restoring`).
    //   • disabled label when the SDK has settled but offerings are
    //     missing (e.g. dev builds without an RC key) — keeping the
    //     label visible communicates the action without spinning the
    //     UI forever in that branch.
    //   • enabled when both `_purchasesConfigured` and an Offering
    //     are present.
    final spinning = _restoring || isLoading;
    final disabled = spinning || _busy || !canPurchase;
    return Center(
      child: TextButton(
        onPressed: disabled ? null : _restore,
        style: TextButton.styleFrom(
          foregroundColor: restoreColor,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          textStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        child: spinning
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: restoreColor,
                ),
              )
            : const Text('Satın Alımları Geri Yükle'),
      ),
    );
  }

  Package? _packageForPlan(_Plan plan, Offerings? offerings) {
    final current = offerings?.current;
    if (current == null) return null;
    return switch (plan) {
      _Plan.monthly => current.monthly,
      _Plan.yearly => current.annual,
      _Plan.quarterly => current.threeMonth,
    };
  }

  Future<void> _purchase() async {
    if (_busy) return;
    final offerings = ref.read(subscriptionProvider).value?.offerings;
    final package = _packageForPlan(_selected, offerings);

    if (package == null) {
      // No RevenueCat offering available (dev builds / missing config).
      // Surface a clear error instead of silently opening a broken purchase
      // sheet — Apple reviewers hit this path when testing without sandbox.
      _toast('Satın alma şu anda kullanılamıyor. Lütfen daha sonra dene.',
          error: true);
      return;
    }

    setState(() => _busy = true);
    final outcome =
        await ref.read(subscriptionProvider.notifier).purchase(package);
    if (!mounted) return;
    setState(() => _busy = false);

    switch (outcome) {
      case PurchaseOutcome.success:
        _toast('Premium aktif edildi!');
        // Closed-test polish (Task 2) · one-time premium welcome tour on the
        // user's FIRST successful purchase. The seen-flag is written BEFORE the
        // sheet so a mid-sheet backgrounding can't replay it.
        final prefs = ref.read(appPreferencesProvider);
        if (!prefs.hasSeenPremiumWelcome) {
          await prefs.setPremiumWelcomeSeen();
          if (!mounted) return;
          await PremiumWelcomeSheet.show(context);
        } else {
          await Future<void>.delayed(const Duration(milliseconds: 600));
        }
        if (!mounted) return;
        _close(context);
      case PurchaseOutcome.cancelled:
        // User tapped cancel — stay on paywall, no noisy toast.
        break;
      case PurchaseOutcome.pending:
        // Phase 138 · M-10. Store accepted the purchase but the
        // charge hasn't resolved yet (parental approval, family
        // share approval, slow card review). The webhook will
        // upgrade the entitlement once it clears; in the meantime
        // we tell the user the purchase is in flight rather than
        // showing the generic error toast.
        _toast(
          'Satın alman onay bekliyor. Onaylanınca Premium otomatik '
          'açılacak.',
        );
      case PurchaseOutcome.notEntitled:
        _toast(
          'Ödeme tamamlandı ama Premium henüz aktifleşmedi. '
          'Satın alımları geri yüklemeyi dene.',
          error: true,
        );
      case PurchaseOutcome.error:
        _toast('Satın alma başarısız oldu. Lütfen tekrar dene.', error: true);
    }
  }

  Future<void> _restore() async {
    if (_restoring) return;
    setState(() => _restoring = true);
    final outcome = await ref.read(subscriptionProvider.notifier).restore();
    if (!mounted) return;
    setState(() => _restoring = false);

    switch (outcome) {
      case RestoreOutcome.restored:
        _toast('Satın alımlar geri yüklendi');
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        _close(context);
      case RestoreOutcome.nothingToRestore:
        _toast('Geri yüklenecek bir abonelik bulunamadı');
      case RestoreOutcome.error:
        _toast('Geri yükleme başarısız oldu. Lütfen tekrar dene.', error: true);
    }
  }

  Future<void> _unlockAsDeveloper() async {
    await ref.read(subscriptionProvider.notifier).unlockPremiumAsDeveloper();
    if (!mounted) return;
    _toast('Geliştirici modu: Premium aktif edildi!');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _close(context);
  }

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              error ? const Color(0xFF5A1B1B) : const Color(0xFF2A1B5C),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  /// Phase 96 · gate the dashboard transition on the RC alias.
  ///
  /// The "login-during-paywall" flow lets a user sign in via the
  /// AuthGate (or via the standalone /auth screen routed from the
  /// gate's "Go to email login" link). The Google / Apple paths
  /// already alias RC inside `AuthController.signIn{Google,Apple}`,
  /// but the email path historically just called
  /// `signInWithPassword` and `pushReplacement`'d back to the
  /// paywall — RC never learned about the new Supabase UUID, and the
  /// next purchase landed on a throwaway anonymous app-user-ID
  /// instead.
  ///
  /// Re-awaiting `aliasRevenueCatWithCurrentUser` on close is the
  /// belt-and-braces fix: the helper short-circuits when RC is
  /// already pointing at the same user (so the Google / Apple paths
  /// pay no extra latency), and otherwise it forces the missing
  /// `Purchases.logIn` BEFORE the dashboard receives focus. The
  /// helper swallows its own errors — a transient RC failure
  /// shouldn't trap the user on the paywall — but a failed alias
  /// surfaces as a single warning log that operators can grep for.
  Future<void> _close(BuildContext context) async {
    final user = ref.read(currentUserProvider);
    // Phase 139 · mirror the auth-gate's "linked email" rule so the
    // belt-and-braces alias call also fires for an anonymous-with-
    // linked-email user (the email-signup mid-conversion case). The
    // alias helper has its own internal guard that bails for pure-
    // anonymous users, so the worst case here is a harmless no-op.
    if (user != null) {
      // Show a one-frame busy state so a slow alias call doesn't
      // present as a frozen close button. We piggy-back on `_busy`
      // which already blocks the CTA + Restore.
      if (mounted) setState(() => _busy = true);
      try {
        await ref.read(authControllerProvider).aliasRevenueCatWithCurrentUser();
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
    if (!context.mounted) return;
    context.go('/');
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.gender});

  final Gender? gender;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF2A1B5C), Color(0xFF0E0729)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: _PaywallScreenState._neon.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _PaywallScreenState._neon.withValues(alpha: 0.25),
                  blurRadius: 30,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              // Male/female users see a personalised before/after composite
              // from the photos/ bundle; "Diğer" and null fall through to
              // the original stylised silhouette placeholder.
              child: _heroContent(gender),
            ),
          ),
        ),
        const SizedBox(height: 20),
        ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            colors: [
              _PaywallScreenState._neon,
              _PaywallScreenState._neonAccent,
            ],
          ).createShader(rect),
          // Phase 60G · reverted to the legacy headline copy. The
          // "alın!" call-to-action verb out-performed the static
          // "hazır" form during the in-house copy review and is the
          // PM's preferred line going forward.
          child: const Text(
            'Kişiselleştirilmiş planınızı alın!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.15,
              letterSpacing: 0.4,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Yapay zeka her tekrarını izlesin, formunu düzeltsin ve '
          '30 günlük programla hedefine her gün biraz daha yaklaşsın. '
          'Sonuçlar bireysel çabaya ve tutarlılığa bağlıdır.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.45),
        ),
        const SizedBox(height: 12),
        // Honesty pass · the old "🔥 10.000+ kişi kullanıyor" crowd tag
        // was a fabricated count for a pre-launch app (Apple 2.3.1 /
        // Play Misrepresentation). Replaced with a verifiable product
        // capability — no user counts until we have real ones.
        const _CapabilityTag(),
      ],
    );
  }
}

/// Phase 60D · "🔥 10.000+ kişi kullanıyor" pill. Sits between the hero
/// subtitle and the plan-card row so the user sees crowd validation
/// before evaluating the price.
class _CapabilityTag extends StatelessWidget {
  const _CapabilityTag();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: _PaywallScreenState._neon.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _PaywallScreenState._neon.withValues(alpha: 0.55),
            width: 1,
          ),
        ),
        child: const Text(
          '🎯 130+ egzersizde canlı form analizi',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

Widget _heroContent(Gender? gender) {
  switch (gender) {
    case Gender.male:
      return const _GenderBeforeAfter(
        todayAsset: 'photos/kişiselleştirilmişplandabugünkühalERKEK.webp',
        thirtyDayAsset: 'photos/kişiselleştirilmiş planda30.günERKEK.webp',
      );
    case Gender.female:
      return const _GenderBeforeAfter(
        todayAsset: 'photos/kişiselleştirilmişplandabugünkühalKADIN.webp',
        thirtyDayAsset: 'photos/kişiselleştirilmişplanda30.günKADIN.webp',
      );
    case Gender.other:
    case null:
      return const _TransformationPlaceholder();
  }
}

/// Side-by-side today-vs-30-day composite with a glowing arrow in the
/// middle and a bold "30 Günlük Değişimin!" ribbon across the bottom.
/// Shipped images live in photos/ (converted to webp in Phase 23.1).
class _GenderBeforeAfter extends StatelessWidget {
  const _GenderBeforeAfter({
    required this.todayAsset,
    required this.thirtyDayAsset,
  });

  final String todayAsset;
  final String thirtyDayAsset;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Row(
          children: [
            Expanded(child: _buildSide(todayAsset, dim: true)),
            Expanded(child: _buildSide(thirtyDayAsset, dim: false)),
          ],
        ),
        // Dark gradient at the bottom so the ribbon text stays readable
        // regardless of which part of the photo sits behind it.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.82),
                ],
              ),
            ),
          ),
        ),
        const Positioned(
          top: 10,
          left: 10,
          child: _HeroTag(label: 'BUGÜN', color: Colors.white70),
        ),
        const Positioned(
          top: 10,
          right: 10,
          child: _HeroTag(
            label: '30. GÜN',
            color: _PaywallScreenState._neonAccent,
          ),
        ),
        Center(child: _GlowingArrow()),
        const Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              '30 Günlük Değişimin!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
                shadows: [
                  Shadow(blurRadius: 18, color: Colors.black),
                  Shadow(
                    blurRadius: 32,
                    color: _PaywallScreenState._neon,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSide(String asset, {required bool dim}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          asset,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const ColoredBox(
            color: Color(0xFF1A0B3D),
          ),
        ),
        if (dim)
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
            ),
          ),
      ],
    );
  }
}

class _HeroTag extends StatelessWidget {
  const _HeroTag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 0.6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          letterSpacing: 2,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _GlowingArrow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _PaywallScreenState._neon.withValues(alpha: 0.85),
            blurRadius: 28,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              _PaywallScreenState._neon,
              _PaywallScreenState._neonAccent,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Icon(
          Icons.arrow_forward_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}

class _TransformationPlaceholder extends StatelessWidget {
  const _TransformationPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 0.8,
              colors: [Color(0x668E5BFF), Colors.transparent],
            ),
          ),
        ),
        Positioned.fill(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Silhouette(
                opacity: 0.45,
                size: 100,
                label: 'BUGÜN',
                color: Colors.white60,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: _PaywallScreenState._neon,
                  size: 30,
                ),
              ),
              _Silhouette(
                opacity: 1,
                size: 120,
                label: '30 GÜN',
                color: _PaywallScreenState._neonAccent,
                glow: true,
              ),
            ],
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _PaywallScreenState._neon.withValues(alpha: 0.6),
                width: 0.6,
              ),
            ),
            child: const Text(
              'AI DESTEKLİ',
              style: TextStyle(
                color: _PaywallScreenState._neon,
                fontSize: 10,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Silhouette extends StatelessWidget {
  const _Silhouette({
    required this.opacity,
    required this.size,
    required this.label,
    required this.color,
    this.glow = false,
  });

  final double opacity;
  final double size;
  final String label;
  final Color color;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.accessibility_new,
          color: color.withValues(alpha: opacity),
          size: size,
          shadows: glow
              ? [
                  Shadow(
                    color: color.withValues(alpha: 0.7),
                    blurRadius: 20,
                  ),
                ]
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isSelected,
    required this.onTap,
    required this.package,
    required this.isLoading,
  });

  final _Plan plan;
  final bool isSelected;
  final VoidCallback onTap;

  /// Phase 95 · the resolved RevenueCat package for this plan, or null
  /// when no Offering has loaded yet (`isLoading == true`) or RC was
  /// never configured / failed to fetch (`isLoading == false`,
  /// fall-through to the em-dash slot). The card uses the package's
  /// [StoreProduct.priceString] verbatim — RC formats it in the device
  /// locale (₺ for tr-TR, $ for en-US, etc.) so we don't rebuild the
  /// formatting ourselves.
  final Package? package;

  /// Phase 95 · `true` while `subscriptionProvider` is in
  /// `AsyncLoading` — i.e. the cold-start `Purchases.getOfferings()`
  /// fetch is still pending. The card swaps the price text for a
  /// shimmering [SkeletonBox] in this state. Flips to `false` the
  /// moment `_load()` resolves on either the success OR catch path,
  /// at which point a null [package] means "RC failed / misconfigured"
  /// and we fall back to the marketing-spec hardcoded price (per the
  /// spec: "Only use fallback text if Purchases.getOfferings()
  /// explicitly fails or returns null").
  final bool isLoading;

  bool get _isHighlighted => plan == _Plan.yearly;

  String get _title => switch (plan) {
        _Plan.monthly => '1 Ay',
        _Plan.yearly => '12 Ay',
        _Plan.quarterly => '3 Ay',
      };

  String get _per => switch (plan) {
        _Plan.monthly => '/ ay',
        _Plan.yearly => '/ yıl',
        _Plan.quarterly => '/ 3 ay',
      };

  /// Phase 95 · resolves the price slot to one of three widgets, in
  /// priority order:
  ///
  ///   1. **Real**: `package.storeProduct.priceString` from the live
  ///      RevenueCat Offering. This is the localised, store-billed
  ///      price (e.g. "₺999,99" on a tr-TR device, "$29.99" on
  ///      en-US). Wrapped in `FittedBox(scaleDown)` so a longer
  ///      currency string (e.g. "BR$ 1.999,99") doesn't blow out the
  ///      card's inner width.
  ///   2. **Loading**: a shimmering [SkeletonBox] while
  ///      `Purchases.getOfferings()` is in flight. Sized to roughly
  ///      match the eventual text height so the card doesn't jump
  ///      when the price lands.
  ///   3. **Unavailable**: an em-dash when the load resolved without a
  ///      Package (RC misconfigured / fetch failed / no offerings).
  ///      Store-submission M2: we never invent a price here — the
  ///      plans row shows a "Fiyatlar yüklenemedi" notice with a
  ///      retry, and the CTA is disabled in this state.
  Widget _buildPriceSlot(ColorScheme scheme) {
    final fontSize = _isHighlighted ? 22.0 : 18.0;
    final priceStyle = TextStyle(
      color: scheme.onSurface,
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      height: 1,
    );
    final livePrice = package?.storeProduct.priceString;
    if (livePrice != null && livePrice.isNotEmpty) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(livePrice, style: priceStyle),
      );
    }
    if (isLoading) {
      // Slightly wider for the highlighted (yearly) card to mirror
      // the typical 6-digit + currency-symbol price width.
      return SkeletonBox(
        width: _isHighlighted ? 92 : 76,
        height: fontSize,
        borderRadius: 6,
      );
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text('—', style: priceStyle),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Phase 53F · plan-card chrome was hardcoded for dark; surface,
    // border, title, price, /per, decoy strikethrough, and the
    // selection radio all flip via the active ColorScheme. The selected
    // state's neon tint stays because it's the brand emphasis.
    final scheme = context.colors;
    final isDark = context.isDarkMode;
    final cardHeight = _isHighlighted ? 220.0 : 180.0;
    final borderColor = isSelected
        ? _PaywallScreenState._neon
        : (_isHighlighted
            ? _PaywallScreenState._neon
            : (isDark ? Colors.white24 : scheme.outlineVariant));

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 230,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: cardHeight,
              padding: const EdgeInsets.fromLTRB(10, 18, 10, 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? _PaywallScreenState._neon.withValues(alpha: 0.14)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : scheme.surface),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: borderColor,
                  width: isSelected || _isHighlighted ? 2 : 1,
                ),
                boxShadow: _isHighlighted || isSelected
                    ? [
                        BoxShadow(
                          color: _PaywallScreenState._neon.withValues(
                            alpha: _isHighlighted ? 0.55 : 0.3,
                          ),
                          blurRadius: _isHighlighted ? 22 : 14,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _title,
                    style: TextStyle(
                      color: isSelected
                          ? _PaywallScreenState._neon
                          : scheme.onSurface.withValues(alpha: 0.70),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildPriceSlot(scheme),
                      const SizedBox(height: 2),
                      Text(
                        _per,
                        style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.55),
                          fontSize: 11,
                          letterSpacing: 1,
                        ),
                      ),
                      // Store-honesty pass · the fictional "₺2.999,99
                      // idi" strikethrough anchor is gone (Apple 2.3.1 /
                      // TR-EU reference-price law). The in-card trial
                      // badge renders only when THIS card's live SKU
                      // carries a real free trial.
                      if (_isHighlighted && _freeTrialOf(package) != null) ...[
                        const SizedBox(height: 8),
                        _InlineTrialBadge(trial: _freeTrialOf(package)!),
                      ],
                    ],
                  ),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? _PaywallScreenState._neon
                          : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? _PaywallScreenState._neon
                            : scheme.onSurface.withValues(alpha: 0.40),
                        width: 1.5,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 14,
                          )
                        : null,
                  ),
                ],
              ),
            ),
            if (_isHighlighted)
              Positioned(
                top: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        _PaywallScreenState._neon,
                        _PaywallScreenState._neonAccent,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _PaywallScreenState._neon.withValues(alpha: 0.7),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Text(
                    'POPÜLER',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Trial badge rendered inside the highlighted (yearly) _PlanCard —
/// ONLY when that card's live RevenueCat SKU carries a free trial.
/// Two-line layout: the copy doesn't fit on a single line at the
/// card's ~80 px inner width without shrinking the type beyond
/// readability. Neon-tinted background + 1 px border so it reads as
/// a risk-removal pill, not body copy.
class _InlineTrialBadge extends StatelessWidget {
  const _InlineTrialBadge({required this.trial});
  final IntroductoryPrice trial;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: _PaywallScreenState._neon.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _PaywallScreenState._neon.withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_trialLengthLabel(trial)} ücretsiz dene',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              height: 1.15,
              letterSpacing: 0.3,
            ),
          ),
          Text(
            'şimdi ödeme yok',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.7),
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              height: 1.2,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoPaymentBadge extends StatelessWidget {
  const _NoPaymentBadge();

  @override
  Widget build(BuildContext context) {
    // Phase 53G · the "Şimdi ödeme yok!" badge sits between the plan
    // cards and the CTA, so it has to read in light mode too. Surface
    // + label both flip via the active scheme; the neon-gradient
    // checkmark stays white-on-purple because the icon is on a brand
    // gradient regardless of theme.
    final scheme = context.colors;
    final isDark = context.isDarkMode;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _PaywallScreenState._neon.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    _PaywallScreenState._neon,
                    _PaywallScreenState._neonAccent,
                  ],
                ),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
            const SizedBox(width: 10),
            // Phase 60G · the external badge reverts to its legacy
            // single-line "Şimdi ödeme yok!" form. The full "7 gün
            // ücretsiz dene — şimdi ödeme yok" callout has been
            // promoted to a more powerful position: inside the
            // highlighted yearly _PlanCard, where the user is
            // evaluating price.
            Text(
              'Şimdi ödeme yok!',
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalFooter extends StatefulWidget {
  const _LegalFooter({
    required this.trial,
    required this.priceString,
    required this.periodLabel,
  });

  /// The selected plan's real free trial, or null when the SKU has
  /// none — drives whether the footer mentions a trial at all.
  final IntroductoryPrice? trial;

  /// Localised store price of the selected plan (e.g. "₺999,99"),
  /// null while offerings are loading / unavailable.
  final String? priceString;

  /// "ay" / "yıl" / "3 ay" — the selected plan's billing period.
  final String periodLabel;

  @override
  State<_LegalFooter> createState() => _LegalFooterState();
}

class _LegalFooterState extends State<_LegalFooter> {
  // TapGestureRecognizers must be disposed or they leak — owning them on
  // the State lets us tear them down when the paywall closes.
  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()
      ..onTap = () => openLegalUrl(LegalUrls.terms);
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => openLegalUrl(LegalUrls.privacy);
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Phase 53G · the fine-print Terms / Privacy footer was painting at
    // `Colors.white38` — a 38% white that vanishes against a light
    // scaffold. Pull body copy from onSurface @ 0.55 so it reads as a
    // muted secondary tone in either palette; the inline links keep
    // their brand neon underline.
    final baseStyle = TextStyle(
      color: context.colors.onSurface.withValues(alpha: 0.55),
      fontSize: 10.5,
      height: 1.4,
    );
    final linkStyle = baseStyle.copyWith(
      color: const Color(0xFF8E5BFF),
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: const Color(0xFF8E5BFF).withValues(alpha: 0.8),
    );
    // Store-honesty pass · the old footer promised a "7 günlük
    // ücretsiz deneme" unconditionally. It now (a) mentions a trial
    // only when the selected SKU really has one, with its real
    // duration, and (b) always carries the explicit auto-renewal +
    // store-billing disclosure Apple 3.1.2 / Play subscriptions
    // require.
    final trial = widget.trial;
    final price = widget.priceString;
    final renewal = price != null
        ? 'Abonelik ($price / ${widget.periodLabel}) iptal edilmedikçe '
            'her dönem sonunda otomatik yenilenir ve ücret mağaza '
            'hesabına yansıtılır.'
        : 'Abonelik iptal edilmedikçe her dönem sonunda otomatik '
            'yenilenir ve ücret mağaza hesabına yansıtılır.';
    final opening = trial != null
        ? '${_trialLengthLabel(trial)} süren ücretsiz denemenin sonunda '
            'seçtiğin abonelik otomatik başlar. $renewal Deneme süresi '
            'içinde ayarlardan istediğin zaman iptal edebilirsin. '
            'Devam ederek '
        : '$renewal İstediğin zaman mağaza aboneliklerinden iptal '
            'edebilirsin. Devam ederek ';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text.rich(
        TextSpan(
          style: baseStyle,
          children: [
            TextSpan(text: opening),
            TextSpan(
              text: 'Kullanım Şartları',
              style: linkStyle,
              recognizer: _termsTap,
            ),
            const TextSpan(text: ' ve '),
            TextSpan(
              text: 'Gizlilik Politikası',
              style: linkStyle,
              recognizer: _privacyTap,
            ),
            const TextSpan(text: '’nı kabul etmiş olursun.'),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.6),
      shape: const CircleBorder(
        side: BorderSide(color: Colors.white24, width: 1),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 36,
          height: 36,
          child: Icon(Icons.close, color: Colors.white70, size: 18),
        ),
      ),
    );
  }
}

/// Phase 142 · transitional hydration veil drawn on top of the paywall
/// content while [subscriptionProvider] is in flight or while a Pro
/// self-redirect is queued. Renders as a full-screen dark scrim
/// matching the paywall's hero backdrop, with a single small brand-
/// purple progress indicator centered. No copy ("Loading…",
/// "Hazırlanıyor", etc.) — the dark scrim + brand-tint indicator reads
/// as a deliberate "preparing" beat without sliding into spinner-hell
/// territory. The parent [AnimatedOpacity] supplies the 320 ms fade.
class _PaywallHydrationVeil extends StatelessWidget {
  const _PaywallHydrationVeil();

  static const Color _neon = Color(0xFF8E5BFF);

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF050410),
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            valueColor: AlwaysStoppedAnimation<Color>(_neon),
          ),
        ),
      ),
    );
  }
}

/// Phase 115 · cinematic backdrop layered behind the dark-mode
/// paywall content. Reverse-engineered from the reference video's
/// ~1:11 paywall composition — adapted for FormAI by keeping the
/// dark/neon identity and using the user's onboarding artwork as
/// the layered visual material.
///
/// Five photos from `photos/` (gender / goal / activity / strength /
/// lifestyle) drift slowly via a single 30 s repeating controller
/// (each gets its own alignment offset slope so the parallax
/// directions vary). Photos are rendered at 14–22 % opacity, soft-
/// rounded, with mild rotations (±5°). A bottom-weighted dim
/// gradient over the top keeps foreground content readable.
///
/// The user reads it as "the journey I just walked through is
/// layered behind this commitment moment" — same emotional grammar
/// as Unrot's paywall layered composition, but expressed entirely
/// through FormAI's existing dark/neon brand vocabulary. No new
/// asset commissions required.
///
/// Performance: ImageFiltered/BackdropFilter avoided. Five Image
/// widgets at <40 % screen width each, rendered with simple Opacity
/// + Transform.rotate. Single AnimationController. RepaintBoundary
/// at the root so the paywall content above doesn't re-render with
/// the parallax tick.
class _PaywallCinematicBackdrop extends StatefulWidget {
  const _PaywallCinematicBackdrop();

  @override
  State<_PaywallCinematicBackdrop> createState() =>
      _PaywallCinematicBackdropState();
}

class _PaywallCinematicBackdropState extends State<_PaywallCinematicBackdrop>
    with TickerProviderStateMixin {
  late final AnimationController _drift;

  /// Phase 142 · entrance fade. The cinematic backdrop is the most
  /// paint-heavy layer on the paywall (5 image widgets + filters +
  /// per-frame transform updates), so it pays the largest first-
  /// frame cost during a route transition. Starting at opacity 0
  /// and fading to 1 over 520 ms lets Flutter skip painting it
  /// entirely on the first frame (the `Opacity` widget short-
  /// circuits at exactly 0) — the paywall's hero, plan cards, and
  /// CTA get the first frame to themselves, then the ambient
  /// backdrop fades in as a secondary "depth arriving" beat. The
  /// drift controller still starts immediately so the parallax is
  /// already in motion the moment the backdrop becomes visible.
  late final AnimationController _entranceFade;

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat(reverse: true);
    _entranceFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _entranceFade.forward();
    });
  }

  @override
  void dispose() {
    _drift.dispose();
    _entranceFade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _entranceFade,
          curve: Curves.easeOutCubic,
        ),
        child: AnimatedBuilder(
          animation: _drift,
          builder: (context, _) {
            // Smoothed bell so the parallax never reverses harshly at
            // the loop ends; each photo reads its own alignment offset
            // off this `t`, multiplied by a per-photo direction so
            // parallax directions vary across the layer stack.
            final t =
                (math.sin(_drift.value * math.pi * 2 - math.pi / 2) + 1) / 2;
            return Stack(
              fit: StackFit.expand,
              children: [
                _BackdropImage(
                  asset: 'photos/cinsiyetseçimierkek.webp',
                  alignment: Alignment(-0.78 + 0.05 * t, -0.55 + 0.04 * t),
                  widthFraction: 0.42,
                  opacity: 0.18,
                  rotationDegrees: -3,
                ),
                _BackdropImage(
                  asset: 'photos/hedefinneSıkılaşmak.webp',
                  alignment: Alignment(0.65 - 0.05 * t, -0.62 + 0.03 * t),
                  widthFraction: 0.36,
                  opacity: 0.16,
                  rotationDegrees: 4,
                ),
                _BackdropImage(
                  asset: 'photos/hedefinneHacimKazanmak.webp',
                  alignment: Alignment(-0.55 + 0.04 * t, 0.30 - 0.05 * t),
                  widthFraction: 0.40,
                  opacity: 0.14,
                  rotationDegrees: -2,
                ),
                _BackdropImage(
                  asset: 'photos/hedef_guclenmek.webp',
                  alignment: Alignment(0.72 + 0.04 * t, 0.55 - 0.04 * t),
                  widthFraction: 0.38,
                  opacity: 0.18,
                  rotationDegrees: 5,
                ),
                _BackdropImage(
                  asset: 'photos/günlükaktivitenmasabaşı.webp',
                  alignment: Alignment(0.0, 0.85 - 0.04 * t),
                  widthFraction: 0.34,
                  opacity: 0.13,
                  rotationDegrees: 0,
                ),
                // Bottom-weighted dim gradient — keeps the marketing
                // cards + CTA readable against the layered photos
                // without flattening the depth at the top of the screen
                // where the hero artwork sits.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x00000000),
                        Color(0x55000000),
                        Color(0xAA000000),
                      ],
                      stops: [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BackdropImage extends StatelessWidget {
  const _BackdropImage({
    required this.asset,
    required this.alignment,
    required this.widthFraction,
    required this.opacity,
    required this.rotationDegrees,
  });

  final String asset;
  final Alignment alignment;
  final double widthFraction;
  final double opacity;
  final double rotationDegrees;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = size.width * widthFraction;
    // Portrait-leaning ratio (1.4) to match the original onboarding
    // artwork's aspect — no awkward squishing.
    final height = width * 1.4;
    return Align(
      alignment: alignment,
      child: Transform.rotate(
        angle: rotationDegrees * math.pi / 180,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Opacity(
            opacity: opacity,
            child: Image.asset(
              asset,
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  SizedBox(width: width, height: height),
            ),
          ),
        ),
      ),
    );
  }
}
