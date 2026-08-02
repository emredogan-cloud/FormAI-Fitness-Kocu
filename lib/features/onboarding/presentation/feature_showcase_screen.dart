import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/utils/text_span_split.dart';
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
///
/// ---
///
/// **Phase 6 polish · rebuilt to the four reference designs.** The
/// previous version was a photograph with a paragraph under it. The
/// references turn each card into a product demonstration: a framed hero
/// with live-looking stat chips over it, a gradient-accented headline, an
/// assurance card, and a row of capability tiles.
///
/// Three decisions worth knowing about, because each one is a place a
/// later change could quietly undo something:
///
/// 1. **Every chip is a Flutter widget, not part of the photograph.** The
///    reference artwork ships the chips baked in, and the previous
///    `showcase_ai_coach.webp` shipped a *different* set of them baked in
///    — "JOINT TRACKING", "POWER OUTPUT", "RANGE OF MOTION" — in English,
///    on a screen a Turkish user sees during their first minute. The
///    asset was re-cropped to remove them (`docs/i18n/TEXT_IN_IMAGES.md`
///    had the app recorded as clean; it was not). Anything readable on
///    these cards renders here, where it can be translated.
///
/// 2. **The heroes are one aspect ratio, never a fixed height.**
///    Fixed-height heroes have caused two separate fold regressions in
///    this app (RC-17 paywall, RC-18 Başla).
///
/// 3. **The stat chips are illustrative and must stay obviously so.**
///    Illustrative is not the same as untranslatable: the form score
///    reads `92%` in English and `%92` in Turkish, because where the
///    sign sits is orthography and not part of the made-up figure.
///    "92", "842 W", "12 days" are a demonstration of the product's
///    surfaces, not a claim about this user, who at this point in the
///    funnel has trained exactly zero times. They sit inside the framed
///    photograph — the visual language of a screenshot — and never on the
///    page's own background, where they would read as live data.
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
    if (_index >= _kPages.length - 1) {
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
    final isLast = _index == _kPages.length - 1;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: _kBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Skip is available from card one. Same principle as the
            // spotlight tour: an unskippable intro is a liability.
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 8, top: 2),
                child: TextButton.icon(
                  onPressed: _finish,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.62),
                    minimumSize: const Size(64, 48),
                  ),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(
                    l10n.showcaseSkip,
                    style: const TextStyle(
                      fontSize: 15,
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
                itemCount: _kPages.length,
                itemBuilder: (_, i) => _ShowcasePage(page: _kPages[i]),
              ),
            ),
            const SizedBox(height: 10),
            _Dots(index: _index, count: _kPages.length),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: _GradientCta(
                label: isLast ? l10n.showcaseStart : l10n.onbBodyCta,
                onTap: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const Color _kBackground = Color(0xFF0A0612);

/// Purple → lime. The gradient the language picker established this
/// sprint; every accent on these cards is a slice of it.
const List<Color> _kBrandGradient = [AppColors.neon, AppColors.neonGreen];

/// The coordinate space every hero overlay is laid out in, scaled to
/// whatever the hero actually measures. 4:3, matching the hero's own
/// aspect ratio, so the scale is uniform and nothing is distorted.
const Size _kHeroCanvas = Size(400, 300);

// ---------------------------------------------------------------------------
// Page model
// ---------------------------------------------------------------------------

typedef _Copy = String Function(AppLocalizations);

/// One capability tile in the three-across row.
class _Feature {
  const _Feature({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final _Copy title;
  final _Copy subtitle;
}

class _Page {
  const _Page({
    required this.hero,
    required this.eyebrow,
    required this.title,
    required this.titleAccent,
    required this.body,
    required this.cardIcon,
    required this.cardIconColor,
    required this.cardTitle,
    required this.cardBody,
    this.heroAlignment = Alignment.center,
    this.heroOverlay,
    this.chips = const [],
    this.emblem,
    this.features = const [],
    this.cardBeforeFeatures = false,
  });

  final String hero;
  final Alignment heroAlignment;

  /// The headline written across the hero photograph itself — first card
  /// only, where the photo has the room for it.
  final ({_Copy title, _Copy subtitle})? heroOverlay;

  /// Demonstration stat chips laid over the hero.
  final List<Widget> chips;

  final _Copy eyebrow;
  final _Copy title;

  /// The fragment of [title] that carries the brand gradient. Looked up
  /// inside the translated sentence, so the translator decides where the
  /// emphasis lands; a fragment a translation dropped simply isn't found
  /// and the title renders unstyled rather than wrong.
  final _Copy titleAccent;
  final _Copy body;

  /// Circular art beside the headline. Null on the first card, whose
  /// headline runs the full width.
  final Widget? emblem;

  final IconData cardIcon;
  final Color cardIconColor;
  final _Copy cardTitle;
  final _Copy cardBody;

  final List<_Feature> features;

  /// The nutrition card leads with its recipes card and closes with the
  /// tiles; the others do the reverse.
  final bool cardBeforeFeatures;
}

/// Copy is resolved per-locale, so the catalogue holds lookups rather
/// than strings. Asset paths stay literal — they are bundled files, not
/// copy.
final List<_Page> _kPages = [
  // ---- 1 · live form analysis ---------------------------------------
  _Page(
    hero: 'assets/illustrations/showcase_form_analysis.webp',
    heroAlignment: const Alignment(0.25, 0),
    heroOverlay: (
      title: (l) => l.showcaseHeroFormAnalysis,
      subtitle: (l) => l.showcaseHeroFormAnalysisSub,
    ),
    chips: const [
      PositionedDirectional(top: 14, end: 14, child: _FormScoreChip()),
      PositionedDirectional(start: 14, bottom: 14, child: _RepsChip()),
    ],
    eyebrow: (l) => l.liveFormAnalysisEyebrow,
    title: (l) => l.showcaseFormTitle,
    titleAccent: (l) => l.showcaseFormTitleAccent,
    body: (l) => l.showcaseFormBody,
    cardIcon: Icons.lock_outline_rounded,
    cardIconColor: AppColors.neon,
    cardTitle: (l) => l.showcaseFormCardTitle,
    cardBody: (l) => l.showcaseFormCardBody,
    features: [
      _Feature(
        icon: Icons.photo_camera_outlined,
        color: AppColors.neon,
        title: (l) => l.showcaseFormFeature1,
        subtitle: (l) => l.showcaseFormFeature1Sub,
      ),
      _Feature(
        icon: Icons.verified_user_outlined,
        color: AppColors.neonGreen,
        title: (l) => l.showcaseFormFeature2,
        subtitle: (l) => l.showcaseFormFeature2Sub,
      ),
      _Feature(
        icon: Icons.bar_chart_rounded,
        color: AppColors.neon,
        title: (l) => l.showcaseFormFeature3,
        subtitle: (l) => l.showcaseFormFeature3Sub,
      ),
    ],
  ),

  // ---- 2 · the AI coach ---------------------------------------------
  _Page(
    hero: 'assets/illustrations/showcase_ai_coach.webp',
    chips: const [
      PositionedDirectional(
        start: 14,
        top: 14,
        bottom: 14,
        width: 150,
        child: _CoachStatColumn(),
      ),
    ],
    eyebrow: (l) => l.showcaseCoachEyebrow,
    title: (l) => l.showcaseCoachTitle,
    titleAccent: (l) => l.showcaseCoachTitleAccent,
    body: (l) => l.showcaseCoachBody,
    emblem:
        const _EmblemImage('assets/illustrations/showcase_emblem_coach.webp'),
    cardIcon: Icons.verified_user_outlined,
    cardIconColor: AppColors.neonGreen,
    cardTitle: (l) => l.showcaseCoachCardTitle,
    cardBody: (l) => l.showcaseCoachCardBody,
    features: [
      _Feature(
        icon: Icons.fitness_center_rounded,
        color: AppColors.neon,
        title: (l) => l.showcaseCoachFeature1,
        subtitle: (l) => l.showcaseCoachFeature1Sub,
      ),
      _Feature(
        icon: Icons.restaurant_rounded,
        color: AppColors.neonGreen,
        title: (l) => l.showcaseCoachFeature2,
        subtitle: (l) => l.showcaseCoachFeature2Sub,
      ),
      _Feature(
        icon: Icons.bolt_rounded,
        color: AppColors.neon,
        title: (l) => l.showcaseCoachFeature3,
        subtitle: (l) => l.showcaseCoachFeature3Sub,
      ),
    ],
  ),

  // ---- 3 · the 30-day plan ------------------------------------------
  _Page(
    hero: 'assets/illustrations/showcase_plan.webp',
    heroAlignment: const Alignment(0.1, 0),
    chips: const [
      PositionedDirectional(
        start: 14,
        top: 16,
        bottom: 16,
        width: 168,
        child: _PlanChipColumn(),
      ),
    ],
    eyebrow: (l) => l.showcasePlanEyebrow,
    title: (l) => l.showcasePlanTitle,
    titleAccent: (l) => l.showcasePlanTitleAccent,
    body: (l) => l.showcasePlanBody,
    emblem: const _ThirtyDayEmblem(),
    cardIcon: Icons.home_outlined,
    cardIconColor: AppColors.neonGreen,
    cardTitle: (l) => l.showcasePlanCardTitle,
    cardBody: (l) => l.showcasePlanCardBody,
  ),

  // ---- 4 · nutrition -------------------------------------------------
  _Page(
    hero: 'assets/illustrations/showcase_nutrition.webp',
    eyebrow: (l) => l.showcaseNutritionEyebrow,
    title: (l) => l.showcaseNutritionTitle,
    titleAccent: (l) => l.showcaseNutritionTitleAccent,
    body: (l) => l.showcaseNutritionBody,
    emblem: const _EmblemImage(
        'assets/illustrations/showcase_emblem_nutrition.webp'),
    cardIcon: Icons.restaurant_menu_rounded,
    cardIconColor: AppColors.neonGreen,
    cardTitle: (l) => l.showcaseNutritionCardTitle,
    cardBody: (l) => l.showcaseNutritionCardBody,
    cardBeforeFeatures: true,
    features: [
      _Feature(
        icon: Icons.local_fire_department_outlined,
        color: AppColors.neon,
        title: (l) => l.showcaseNutritionFeature1,
        subtitle: (l) => l.showcaseNutritionFeature1Sub,
      ),
      _Feature(
        icon: Icons.track_changes_rounded,
        color: AppColors.neonGreen,
        title: (l) => l.showcaseNutritionFeature2,
        subtitle: (l) => l.showcaseNutritionFeature2Sub,
      ),
      _Feature(
        icon: Icons.rice_bowl_outlined,
        color: AppColors.neonGreen,
        title: (l) => l.showcaseNutritionFeature3,
        subtitle: (l) => l.showcaseNutritionFeature3Sub,
      ),
    ],
  ),
];

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class _ShowcasePage extends StatelessWidget {
  const _ShowcasePage({required this.page});

  final _Page page;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final card = _AssuranceCard(page: page);
    final features =
        page.features.isEmpty ? null : _FeatureRow(features: page.features);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroCard(page: page),
          const SizedBox(height: 20),
          _Headline(page: page, l10n: l10n),
          const SizedBox(height: 18),
          if (page.cardBeforeFeatures) ...[
            card,
            if (features != null) ...[const SizedBox(height: 20), features],
          ] else ...[
            if (features != null) ...[features, const SizedBox(height: 20)],
            card,
          ],
        ],
      ),
    );
  }
}

/// The framed photograph. A 1.6 px gradient hairline around a rounded
/// clip, with the brand glow behind it — the frame the whole reference
/// set is built on.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.page});

  final _Page page;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: _kBrandGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.neon.withValues(alpha: 0.28),
            blurRadius: 26,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20.4),
          child: AspectRatio(
            // Never a fixed height. See the class doc.
            aspectRatio: 4 / 3,
            child: ColoredBox(
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    page.hero,
                    fit: BoxFit.cover,
                    alignment: page.heroAlignment,
                    // A missing asset must degrade to a neutral panel,
                    // not a grey error box in a first-impression surface.
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(
                        Icons.auto_awesome,
                        color: AppColors.neon,
                        size: 40,
                      ),
                    ),
                  ),
                  // Keeps the chips legible over whatever the photograph
                  // happens to put behind them.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Color(0xCC000000), Color(0x00000000)],
                        stops: [0.0, 0.62],
                      ),
                    ),
                  ),
                  // Everything drawn *onto* the photograph lives in one
                  // fixed 4:3 canvas that is then scaled to the hero.
                  //
                  // The chips are a picture of the product's own UI, so
                  // they should shrink with the picture rather than
                  // reflow inside it — the same way the reference
                  // renders do. It also makes the composition
                  // deterministic: a 320 px phone and a tablet get the
                  // identical arrangement, and no amount of translation
                  // length can push a chip out of the frame, because the
                  // frame it must fit is the canvas, not the device.
                  //
                  // This replaced device-space positioning, which
                  // overflowed by 87 px at 320×640 under pseudo-
                  // localisation.
                  Positioned.fill(
                    child: MediaQuery.withNoTextScaling(
                      // The canvas is a *picture of* the product's UI,
                      // not the UI. Letting the system text scaler grow
                      // type inside a fixed-size canvas overflowed it —
                      // and enlarging a screenshot's own labels is not
                      // what a reader who scaled their text up asked
                      // for. The page's real copy below scales normally,
                      // and it is where every one of these claims is
                      // also stated in full.
                      child: FittedBox(
                        fit: BoxFit.fill,
                        child: SizedBox(
                          width: _kHeroCanvas.width,
                          height: _kHeroCanvas.height,
                          child: Stack(
                            children: [
                              if (page.heroOverlay != null)
                                _HeroOverlayTitle(
                                  overlay: page.heroOverlay!,
                                  l10n: l10n,
                                ),
                              ...page.chips,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroOverlayTitle extends StatelessWidget {
  const _HeroOverlayTitle({required this.overlay, required this.l10n});

  final ({_Copy title, _Copy subtitle}) overlay;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      start: 0,
      end: 0,
      top: 0,
      bottom: 0,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 18, end: 150),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GradientText(
              overlay.title(l10n),
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                height: 1.12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              overlay.subtitle(l10n),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.86),
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Eyebrow, headline and body — with the circular emblem alongside on
/// every card that has one.
class _Headline extends StatelessWidget {
  const _Headline({required this.page, required this.l10n});

  final _Page page;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          page.eyebrow(l10n),
          style: TextStyle(
            color: AppColors.neon.withValues(alpha: 0.95),
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.7,
          ),
        ),
        const SizedBox(height: 10),
        _AccentedTitle(
          sentence: page.title(l10n),
          accent: page.titleAccent(l10n),
        ),
        const SizedBox(height: 12),
        Text(
          page.body(l10n),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 14.5,
            height: 1.5,
          ),
        ),
      ],
    );

    if (page.emblem == null) return text;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: text),
        const SizedBox(width: 10),
        // Decoration, and the headline beside it already says everything
        // the artwork does — so it is hidden from screen readers rather
        // than announced as an unlabelled image.
        ExcludeSemantics(
          child: SizedBox(width: 104, height: 104, child: page.emblem),
        ),
      ],
    );
  }
}

/// The headline, with one fragment carrying the brand gradient.
class _AccentedTitle extends StatelessWidget {
  const _AccentedTitle({required this.sentence, required this.accent});

  final String sentence;
  final String accent;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: Colors.white,
      fontSize: 27,
      fontWeight: FontWeight.w900,
      height: 1.16,
      letterSpacing: -0.4,
    );
    if (accent.isEmpty || !sentence.contains(accent)) {
      // The translation does not contain the fragment. Render the
      // sentence plainly rather than emphasising the wrong words.
      return Text(sentence, style: style);
    }
    // The gradient is painted onto the accent span alone, through a
    // shader spanning the paragraph's own width. So the accent picks up
    // the slice of purple→lime that sits under where those words
    // actually land — which is what makes "you need me." run purple to
    // lime the way the reference does, without a second colour having to
    // be authored per language.
    //
    // A ShaderMask would have been the obvious reach here and is wrong:
    // it paints every glyph in the paragraph, not the fragment.
    return LayoutBuilder(
      builder: (context, constraints) {
        final accentStyle = TextStyle(
          foreground: Paint()
            ..shader = const LinearGradient(colors: _kBrandGradient)
                .createShader(Rect.fromLTWH(0, 0, constraints.maxWidth, 1)),
        );
        return Text.rich(
          TextSpan(children: splitHighlighted(sentence, accent, accentStyle)),
          style: style,
        );
      },
    );
  }
}

/// Icon, title, two-line body — the reassurance block every reference
/// card closes on.
class _AssuranceCard extends StatelessWidget {
  const _AssuranceCard({required this.page});

  final _Page page;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: page.cardIconColor.withValues(alpha: 0.12),
              border: Border.all(
                color: page.cardIconColor.withValues(alpha: 0.45),
              ),
            ),
            child: Icon(page.cardIcon, color: page.cardIconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  page.cardTitle(l10n),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  page.cardBody(l10n),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.66),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.features});

  final List<_Feature> features;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final f in features)
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: f.color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: f.color.withValues(alpha: 0.42),
                    ),
                  ),
                  child: Icon(f.icon, color: f.color, size: 26),
                ),
                const SizedBox(height: 10),
                Text(
                  f.title(l10n),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  f.subtitle(l10n),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hero chips — illustrative, never live data. See the class doc.
// ---------------------------------------------------------------------------

/// The shared chip shell: a dark translucent plate with a hairline, the
/// visual language of a UI panel sitting on top of a photograph.
class _ChipShell extends StatelessWidget {
  const _ChipShell({required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
      ),
      child: child,
    );
  }
}

class _ChipLabel extends StatelessWidget {
  const _ChipLabel(this.text, {this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color ?? Colors.white.withValues(alpha: 0.80),
        fontSize: 9.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _FormScoreChip extends StatelessWidget {
  const _FormScoreChip();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _ChipShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _ChipLabel(l10n.showcaseHeroFormScore),
          const SizedBox(height: 2),
          Text(
            // The 92 is illustrative; where the `%` sits is not. Turkish
            // writes `%92`, and this chip sat two rows above `%100 Gizli`
            // getting it right — the same screen, both conventions.
            l10n.showcaseHeroFormScoreValue(92),
            style: const TextStyle(
              color: AppColors.neonGreen,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          const _MiniBar(value: 0.92, color: AppColors.neonGreen, width: 78),
        ],
      ),
    );
  }
}

class _RepsChip extends StatelessWidget {
  const _RepsChip();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _ChipShell(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CustomPaint(painter: _WaveformPainter()),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _ChipLabel(l10n.showcaseHeroRepsTracked),
              const SizedBox(height: 1),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Text(
                    '8', // i18n-ignore — illustrative figure, not copy
                    style: TextStyle(
                      color: AppColors.neon,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '/ 12', // i18n-ignore — illustrative figure, not copy
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The four stacked panels down the left of the coach hero.
class _CoachStatColumn extends StatelessWidget {
  const _CoachStatColumn();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Streak.
        _ChipShell(
          child: Row(
            children: [
              const _GlyphBubble(
                icon: Icons.local_fire_department_rounded,
                color: AppColors.neon,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ChipLabel(l10n.showcaseHeroTrainingStreak),
                    _ValueUnit(
                      value: '12', // i18n-ignore — illustrative figure
                      unit: l10n.showcaseHeroStreakUnit,
                      color: AppColors.neon,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Power output, with a rising trace.
        _ChipShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _ChipLabel(l10n.showcaseHeroPowerOutput),
              const _ValueUnit(
                value: '842', // i18n-ignore — illustrative figure
                unit: 'W', // i18n-ignore — unit symbol
                color: AppColors.neon,
              ),
              const SizedBox(height: 4),
              const SizedBox(
                height: 17,
                width: double.infinity,
                child: CustomPaint(painter: _SparklinePainter()),
              ),
            ],
          ),
        ),
        // Form score, with the ring.
        _ChipShell(
          child: Row(
            children: [
              const _ScoreRing(),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ChipLabel(l10n.showcaseHeroFormScore),
                    _ChipLabel(
                      l10n.showcaseHeroExcellent,
                      color: AppColors.neonGreen,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Calories.
        _ChipShell(
          child: Row(
            children: [
              const _GlyphBubble(
                icon: Icons.local_fire_department_rounded,
                color: AppColors.neonGreen,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ChipLabel(l10n.showcaseHeroCalories),
                    const _ValueUnit(
                      value: '842', // i18n-ignore — illustrative figure
                      unit: 'kcal', // i18n-ignore — unit symbol
                      color: AppColors.neonGreen,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The three labelled panels down the left of the plan hero.
class _PlanChipColumn extends StatelessWidget {
  const _PlanChipColumn();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _PlanChip(
          icon: Icons.calendar_month_rounded,
          color: AppColors.neon,
          title: l10n.showcaseHeroPlanDays,
          subtitle: l10n.showcaseHeroPlanDaysSub,
        ),
        _PlanChip(
          icon: Icons.track_changes_rounded,
          color: AppColors.neonGreen,
          title: l10n.showcaseHeroYourGoal,
          subtitle: l10n.showcaseHeroYourGoalSub,
        ),
        _PlanChip(
          icon: Icons.schedule_rounded,
          color: AppColors.neon,
          title: l10n.showcaseHeroYourTime,
          subtitle: l10n.showcaseHeroYourTimeSub,
        ),
      ],
    );
  }
}

class _PlanChip extends StatelessWidget {
  const _PlanChip({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return _ChipShell(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Row(
        children: [
          _GlyphBubble(icon: icon, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlyphBubble extends StatelessWidget {
  const _GlyphBubble({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Icon(icon, color: color, size: 14),
    );
  }
}

class _ValueUnit extends StatelessWidget {
  const _ValueUnit({
    required this.value,
    required this.unit,
    required this.color,
  });

  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            unit,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.66),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({
    required this.value,
    required this.color,
    required this.width,
  });

  final double value;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Stack(
          children: [
            ColoredBox(
              color: Colors.white.withValues(alpha: 0.18),
              child: const SizedBox.expand(),
            ),
            FractionallySizedBox(
              widthFactor: value,
              child: ColoredBox(color: color, child: const SizedBox.expand()),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              value: 0.92,
              strokeWidth: 3,
              strokeCap: StrokeCap.round,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation(AppColors.neonGreen),
            ),
          ),
          const Text(
            '92', // i18n-ignore — illustrative figure, not copy
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.neon
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    // A fixed, hand-picked profile — a random one would flicker on every
    // rebuild, and this is decoration, not data.
    const amps = <double>[0.18, 0.55, 0.28, 0.95, 0.40, 0.70, 0.22];
    final step = size.width / (amps.length - 1);
    final path = Path()..moveTo(0, size.height / 2);
    for (var i = 0; i < amps.length; i++) {
      final y = size.height / 2 -
          (i.isEven ? amps[i] : -amps[i]) * size.height * 0.45;
      path.lineTo(i * step, y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) => false;
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const points = <double>[
      0.10,
      0.16,
      0.13,
      0.24,
      0.30,
      0.26,
      0.38,
      0.45,
      0.41,
      0.54,
      0.62,
      0.58,
      0.70,
      0.80,
      0.76,
      0.90,
      1.0,
    ];
    final step = size.width / (points.length - 1);
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = Offset(i * step, size.height * (1 - points[i]));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.neon
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(
      Offset(size.width, 0),
      2.4,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Emblems
// ---------------------------------------------------------------------------

/// Supplied artwork. It is additive neon on a solid black plate, so the
/// bundled files carry brightness keyed to alpha — otherwise the plate
/// renders as a black tile over this screen's near-black violet.
class _EmblemImage extends StatelessWidget {
  const _EmblemImage(this.asset);

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}

/// The 30-day ring, drawn rather than bundled.
///
/// The supplied artwork has "30 DAYS" baked into it, which a Turkish
/// user would read beside a headline saying "30 gün". A word that has to
/// be readable renders in Flutter — so the ring, the arrowhead and the
/// glow are painted, and the unit is a `Text`.
class _ThirtyDayEmblem extends StatelessWidget {
  const _ThirtyDayEmblem();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      alignment: Alignment.center,
      children: [
        const Positioned.fill(child: CustomPaint(painter: _RingPainter())),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '30', // i18n-ignore — the plan length, a figure
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            Text(
              l10n.showcaseEmblemDays,
              style: TextStyle(
                color: AppColors.neon.withValues(alpha: 0.95),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final inset = rect.deflate(9);
    const start = math.pi * 0.78;
    const sweep = math.pi * 1.62;

    final shader = const SweepGradient(
      colors: [..._kBrandGradient, AppColors.neon],
      startAngle: start,
      endAngle: start + math.pi * 2,
    ).createShader(inset);

    // Glow first, the crisp stroke over it.
    canvas.drawArc(
      inset,
      start,
      sweep,
      false,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawArc(
      inset,
      start,
      sweep,
      false,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );

    // Arrowhead at the sweep's end — the reference's "a cycle that comes
    // back round" idea.
    final c = inset.center;
    final r = inset.width / 2;
    final end = start + sweep;
    final tip = c + Offset(math.cos(end) * r, math.sin(end) * r);
    final head = Path();
    const angles = [-2.5, 0.35, -0.5];
    for (var i = 0; i < angles.length; i++) {
      final a = end + angles[i];
      final p = tip + Offset(math.cos(a) * 9, math.sin(a) * 9);
      i == 0 ? head.moveTo(p.dx, p.dy) : head.lineTo(p.dx, p.dy);
    }
    head.close();
    canvas.drawPath(head, Paint()..color = AppColors.neon);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => false;
}

/// A word painted with the brand gradient.
class _GradientText extends StatelessWidget {
  const _GradientText(this.text, {required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: _kBrandGradient,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: Text(text, style: style.copyWith(color: Colors.white)),
    );
  }
}

// ---------------------------------------------------------------------------
// Chrome
// ---------------------------------------------------------------------------

class _GradientCta extends StatelessWidget {
  const _GradientCta({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.neon.withValues(alpha: 0.45),
            blurRadius: 26,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            colors: _kBrandGradient,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ],
            ),
          ),
        ),
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
