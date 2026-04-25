import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../core/utils/legal_urls.dart';
import '../../onboarding/providers/wizard_provider.dart';
import '../providers/monetization_provider.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

enum _Plan { monthly, yearly, quarterly }

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  static const Color _neon = Color(0xFF8E5BFF);
  static const Color _neonAccent = Color(0xFF4DA6FF);

  _Plan _selected = _Plan.yearly;
  bool _busy = false;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    // Phase 42 analytics — fire once per mount so the
    // viewed-→-purchased conversion rate is derivable. If the paywall
    // is reached from multiple surfaces we'll wire a `source` param
    // later via a constructor arg.
    AnalyticsService.instance.paywallViewed();
  }

  @override
  Widget build(BuildContext context) {
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
          DecoratedBox(
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
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeroSection(gender: ref.watch(wizardProvider).gender),
                    const SizedBox(height: 24),
                    _buildPlansRow(),
                    const SizedBox(height: 18),
                    const _NoPaymentBadge(),
                    const SizedBox(height: 16),
                    _buildCta(),
                    const SizedBox(height: 6),
                    _buildRestoreButton(),
                    const SizedBox(height: 6),
                    const _LegalFooter(),
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
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: _CloseButton(onTap: () => _close(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildPlansRow() {
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
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _PlanCard(
              plan: _Plan.yearly,
              isSelected: _selected == _Plan.yearly,
              onTap: () => setState(() => _selected = _Plan.yearly),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _PlanCard(
              plan: _Plan.quarterly,
              isSelected: _selected == _Plan.quarterly,
              onTap: () => setState(() => _selected = _Plan.quarterly),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCta() {
    // Phase 53 · the paywall's primary "Devam Et / Try at ₺0,00" path
    // is the screen's monetisation hinge. Wrap with explicit semantics
    // so screen readers announce the action instead of trying to read
    // the price string + arrow icon as separate elements. While `_busy`
    // we surface a loading state so blind users aren't left tapping a
    // disabled button.
    return Semantics(
      button: true,
      enabled: !_busy,
      label: _busy ? 'Yükleniyor' : 'Aboneliğe devam et',
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
              onTap: _busy ? null : _purchase,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _busy
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
                      : const [
                          // Phase 53 · `maxLines: 2 + ellipsis` so the
                          // hero CTA copy gracefully wraps when the
                          // user has the system text scaler cranked
                          // (TextScaler ~1.6+ pushed the original
                          // single-line layout into a horizontal
                          // overflow on a 360 px iPhone SE).
                          Flexible(
                            child: Text(
                              '₺0,00 karşılığında dene',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
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

  Widget _buildRestoreButton() {
    // Phase 53G · was hardcoded `Colors.white70` — invisible on the
    // light paywall scaffold. onSurface flips legibility on both
    // palettes; spinner inherits the same colour.
    final restoreColor = context.colors.onSurface.withValues(alpha: 0.70);
    return Center(
      child: TextButton(
        onPressed: _restoring || _busy ? null : _restore,
        style: TextButton.styleFrom(
          foregroundColor: restoreColor,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          textStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        child: _restoring
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
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        _close(context);
      case PurchaseOutcome.cancelled:
        // User tapped cancel — stay on paywall, no noisy toast.
        break;
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

  void _close(BuildContext context) {
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
          'Yapay zeka her tekrarını izlesin, formunu düzeltsin '
          've seni 30 günde hedefe taşısın.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.45),
        ),
      ],
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
  });

  final _Plan plan;
  final bool isSelected;
  final VoidCallback onTap;

  bool get _isHighlighted => plan == _Plan.yearly;

  String get _title => switch (plan) {
        _Plan.monthly => '1 Ay',
        _Plan.yearly => '12 Ay',
        _Plan.quarterly => '3 Ay',
      };

  String get _price => switch (plan) {
        _Plan.monthly => '₺249,99',
        _Plan.yearly => '₺999,99',
        _Plan.quarterly => '₺499,99',
      };

  String get _per => switch (plan) {
        _Plan.monthly => '/ ay',
        _Plan.yearly => '/ yıl',
        _Plan.quarterly => '/ 3 ay',
      };

  String? get _decoy => plan == _Plan.yearly ? '₺2.999,99 idi' : null;

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
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _price,
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: _isHighlighted ? 22 : 18,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _per,
                        style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.55),
                          fontSize: 11,
                          letterSpacing: 1,
                        ),
                      ),
                      if (_decoy != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _decoy!,
                          style: TextStyle(
                            color: scheme.onSurface.withValues(alpha: 0.55),
                            fontSize: 11,
                            decoration: TextDecoration.lineThrough,
                            decorationColor:
                                scheme.onSurface.withValues(alpha: 0.60),
                            decorationThickness: 2,
                          ),
                        ),
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
  const _LegalFooter();

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text.rich(
        TextSpan(
          style: baseStyle,
          children: [
            const TextSpan(
              text: '7 günlük ücretsiz deneme süresinin sonunda seçtiğin '
                  'abonelik otomatik başlar. Deneme süresi içinde ayarlardan '
                  'istediğin zaman iptal edebilirsin. Devam ederek ',
            ),
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
