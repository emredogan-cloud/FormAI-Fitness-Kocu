import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../l10n/app_localizations.dart';

/// Roadmap Phase 2 (R1.1) · the post-paywall capability showcase.
///
/// Sits at the one moment in the funnel where the user has committed
/// (bought, or explicitly declined) but has not yet been dropped onto a
/// dashboard full of surfaces they can't name. Four cards, one idea each,
/// each with a concrete proof point rather than an adjective.
///
/// Why here and not inside the 19-step onboarding: that flow is a
/// conversion funnel, and lengthening it to teach would cost conversion
/// while teaching the wrong thing at the wrong time. A user learns what
/// an app *does* when they're about to use it, not while being
/// interviewed about their waistline.
///
/// Shown once ([AppPreferences.seenFeatureShowcase]); the dashboard tour
/// that follows handles orientation, and the Settings replay row handles
/// recall.
class FeatureShowcaseScreen extends ConsumerStatefulWidget {
  const FeatureShowcaseScreen({super.key});

  @override
  ConsumerState<FeatureShowcaseScreen> createState() =>
      _FeatureShowcaseScreenState();
}

class _FeatureShowcaseScreenState extends ConsumerState<FeatureShowcaseScreen> {
  final _controller = PageController();
  int _index = 0;
  int _maxIndexSeen = 0;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.showcaseViewed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int i) {
    setState(() {
      _index = i;
      if (i > _maxIndexSeen) _maxIndexSeen = i;
    });
  }

  Future<void> _next() async {
    AppHaptics.secondaryTap();
    if (_index >= _kCards.length - 1) {
      await _finish();
      return;
    }
    await _controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    AnalyticsService.instance.showcaseCompleted(
      cardsViewed: _maxIndexSeen + 1,
    );
    await ref.read(appPreferencesProvider).markSeenFeatureShowcase();
    if (!mounted) return;
    // `go`, not `push` — the showcase is a funnel step, not a detour.
    // Leaving it on the stack would let a back gesture land the user
    // back in the funnel from the dashboard.
    context.go(AppRoutes.dashboard);
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _kCards.length - 1;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0A0612),
      body: SafeArea(
        child: Column(
          children: [
            // Skip is available from card one. Same principle as the
            // spotlight tour: an unskippable intro is a liability.
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 8, top: 4),
                child: TextButton(
                  onPressed: _finish,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.55),
                    minimumSize: const Size(64, 48),
                  ),
                  child: Text(
                    l10n.showcaseSkip,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: _onPageChanged,
                itemCount: _kCards.length,
                itemBuilder: (_, i) => _ShowcaseCard(card: _kCards[i]),
              ),
            ),
            const SizedBox(height: 8),
            _Dots(index: _index, count: _kCards.length),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.neon,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    isLast ? l10n.showcaseStart : l10n.onbBodyCta,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
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

typedef _Copy = String Function(AppLocalizations);

class _ShowcaseCardData {
  const _ShowcaseCardData({
    required this.asset,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.proof,
  });

  final String asset;
  final _Copy eyebrow;
  final _Copy title;
  final _Copy body;

  /// The concrete claim. Every card carries one verifiable fact rather
  /// than an adjective — the same store-honesty discipline the paywall
  /// follows.
  final _Copy proof;
}

/// The card copy is resolved per-locale, so the catalogue holds
/// lookups rather than strings. The asset paths stay literal — they
/// are bundled files, not copy.
final List<_ShowcaseCardData> _kCards = [
  _ShowcaseCardData(
    asset: 'assets/illustrations/showcase_form_analysis.webp',
    eyebrow: (l) => l.liveFormAnalysisEyebrow,
    title: (l) => l.showcaseFormTitle,
    body: (l) => l.showcaseFormBody,
    proof: (l) => l.showcaseFormProof,
  ),
  _ShowcaseCardData(
    asset: 'assets/illustrations/showcase_ai_coach.webp',
    eyebrow: (l) => l.showcaseCoachEyebrow,
    title: (l) => l.showcaseCoachTitle,
    body: (l) => l.showcaseCoachBody,
    proof: (l) => l.showcaseCoachProof,
  ),
  _ShowcaseCardData(
    asset: 'assets/illustrations/showcase_plan.webp',
    eyebrow: (l) => l.showcasePlanEyebrow,
    title: (l) => l.showcasePlanTitle,
    body: (l) => l.showcasePlanBody,
    proof: (l) => l.showcasePlanProof,
  ),
  _ShowcaseCardData(
    asset: 'assets/illustrations/showcase_nutrition.webp',
    eyebrow: (l) => l.showcaseNutritionEyebrow,
    title: (l) => l.showcaseNutritionTitle,
    body: (l) => l.showcaseNutritionBody,
    proof: (l) => l.showcaseNutritionProof,
  ),
];

class _ShowcaseCard extends StatelessWidget {
  const _ShowcaseCard({required this.card});

  final _ShowcaseCardData card;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AspectRatio, never a fixed height. Fixed-height heroes have
          // caused two separate fold regressions in this app (RC-17
          // paywall, RC-18 Başla) — the lesson is applied here up front.
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 3 / 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                ),
                child: Image.asset(
                  card.asset,
                  fit: BoxFit.cover,
                  // A missing asset must degrade to a neutral panel, not
                  // a grey error box in a first-impression surface.
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(
                      Icons.auto_awesome,
                      color: AppColors.neon,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            card.eyebrow(l10n),
            style: TextStyle(
              color: AppColors.neon.withValues(alpha: 0.95),
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            card.title(l10n),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1.18,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            card.body(l10n),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.74),
              fontSize: 14.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 17,
                color: AppColors.neon.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  card.proof(l10n),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Semantics(
      label: '${index + 1} / $count',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (i) {
          final active = i == index;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: AnimatedContainer(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              width: active ? 22 : 7,
              height: 7,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: active
                    ? AppColors.neon
                    : Colors.white.withValues(alpha: 0.26),
              ),
            ),
          );
        }),
      ),
    );
  }
}
