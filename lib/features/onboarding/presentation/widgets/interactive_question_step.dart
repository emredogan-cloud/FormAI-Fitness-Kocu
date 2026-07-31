import 'package:flutter/material.dart';

import '../../../../core/utils/app_haptics.dart';
import 'onboarding_image.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _neonAccent = Color(0xFF4DA6FF);

/// A single tappable answer for [InteractiveQuestionStep].
///
/// `value` is the token persisted to wizard state (e.g. `belly_burn`,
/// `sedentary`). `label` is the user-facing copy. `helper` is an
/// optional one-liner shown beneath the label. `imageAsset` is an
/// optional bundled photo path — when provided (Phase 60H), the card
/// switches to a Fitify-style side-image layout: the photo flush-
/// mounts to the right ~45% of the card with a left-to-right dark
/// gradient blend, while text + helper sit on the left ~55%. Without
/// an asset the card falls back to a text-only layout with a trailing
/// selection check icon.
class InteractiveOption {
  const InteractiveOption({
    required this.value,
    required this.label,
    required this.icon,
    this.helper,
    this.imageAsset,
  });

  final String value;
  final String label;
  final IconData icon;
  final String? helper;
  final String? imageAsset;
}

/// Phase 60B · the reusable "interactive" question surface.
///
/// Renders a title + a list of [options] as premium dark cards. When
/// the user taps a card:
///   1. that card glows/pulses neon and the others dim
///   2. [feedbackText] fades + slides in below the card list
///   3. after [commitDelay] (1.5s), [onCommitted] fires with the picked
///      `value`, advancing the wizard
///
/// Tapping again during the commit window is a no-op so the UX feels
/// committed instead of jittery.
class InteractiveQuestionStep extends StatefulWidget {
  const InteractiveQuestionStep({
    super.key,
    required this.title,
    this.subtitle,
    required this.options,
    required this.feedbackText,
    required this.onCommitted,
    this.initialValue,
    this.commitDelay = const Duration(milliseconds: 1500),
    this.bottomSlot,
    this.feedbackTextBuilder,
  });

  final String title;
  final String? subtitle;
  final List<InteractiveOption> options;

  /// Static fallback line shown in the feedback banner. Used when
  /// [feedbackTextBuilder] is null OR returns null for the picked
  /// value.
  final String feedbackText;

  /// Optional per-answer feedback line. Receives the value the user
  /// just picked and returns the line to render — the Act 3 emotional
  /// reconstruction (Phase 104) uses this to deliver predictive
  /// empathy that observes the user's choice rather than just
  /// confirming it. Return null to fall back to [feedbackText].
  final String? Function(String pickedValue)? feedbackTextBuilder;

  final ValueChanged<String> onCommitted;
  final String? initialValue;
  final Duration commitDelay;

  /// Phase 63A · optional widget rendered below the feedback banner.
  /// Used by the gender + daily-minutes steps to fill the dead space
  /// at the bottom with an "AI Insight" card. The inner column is
  /// scrollable, so the slot will stay reachable even on small
  /// devices when the cards already fill the visible area.
  final Widget? bottomSlot;

  @override
  State<InteractiveQuestionStep> createState() =>
      _InteractiveQuestionStepState();
}

class _InteractiveQuestionStepState extends State<InteractiveQuestionStep>
    with SingleTickerProviderStateMixin {
  String? _selected;
  bool _committing = false;

  late final AnimationController _feedback;
  late final Animation<double> _feedbackFade;
  late final Animation<Offset> _feedbackSlide;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue;
    _feedback = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _feedbackFade =
        CurvedAnimation(parent: _feedback, curve: Curves.easeOutCubic);
    _feedbackSlide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _feedback, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _feedback.dispose();
    super.dispose();
  }

  /// Resolve which feedback line to render in the banner. Builder wins
  /// over static; null builder result falls back to the static line so
  /// callers can selectively customise only the values they care about.
  String _resolveFeedbackText() {
    final picked = _selected;
    if (picked != null) {
      final dynamic = widget.feedbackTextBuilder?.call(picked);
      if (dynamic != null) return dynamic;
    }
    return widget.feedbackText;
  }

  Future<void> _pick(String value) async {
    if (_committing) return;
    // Phase 60D · UX rule §4: light impact on the *selection* moment
    // (the user picked an option). The medium "transition" tap fires
    // 1.5 s later from the wizard's `_next()` when the page advances.
    AppHaptics.secondaryTap();
    setState(() {
      _selected = value;
      _committing = true;
    });
    _feedback.forward();
    await Future<void>.delayed(widget.commitDelay);
    if (!mounted) return;
    widget.onCommitted(value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          // Phase 68 · top padding 24 → 16 to recover 8 px of viewport
          // for the taller (102 px) cards below; subtitle gap stays at
          // 8 because the title/subtitle pair already reads as a single
          // header block.
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.subtitle!,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
        // Phase 68 · 20 → 14. Title block is the largest absorbable gap
        // and the cards now have enough internal weight that a tighter
        // header→cards transition still reads as deliberate.
        const SizedBox(height: 14),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              children: [
                for (final opt in widget.options) ...[
                  OptionCard(
                    option: opt,
                    selected: _selected == opt.value,
                    dimmed: _committing && _selected != opt.value,
                    onTap: () => _pick(opt.value),
                  ),
                  // Phase 68 · 12 → 8 between cards. On 4-option screens
                  // this reclaims 12 px (3 separators) — the dominant
                  // lever for absorbing the height bump.
                  if (opt != widget.options.last) const SizedBox(height: 8),
                ],
                // Phase 68 · 16 → 12 ahead of the feedback banner; the
                // banner reads against the dim'd card stack, so a tighter
                // gap doesn't muddy the visual hierarchy.
                const SizedBox(height: 12),
                FeedbackBanner(
                  fade: _feedbackFade,
                  slide: _feedbackSlide,
                  text: _resolveFeedbackText(),
                ),
                if (widget.bottomSlot != null) ...[
                  const SizedBox(height: 18),
                  widget.bottomSlot!,
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Single tappable card. Animates border + scale when selected, fades
/// to ~45% when another option has been picked.
///
/// Phase 60H · "Fitify-style" side-image layout. When the option
/// supplies an [InteractiveOption.imageAsset] the card splits into a
/// padded text area on the left (~55%) and a flush-mounted image on
/// the right (~45%) — the image touches the card's top, right, and
/// bottom edges. A `Colors.black → Colors.transparent` left-to-right
/// gradient is laid over the image so it appears to bleed out of the
/// dark left half of the card. Cards without an image (`Diğer`,
/// `strength`, etc.) fall back to the pre-60H all-text layout with a
/// trailing check icon.
class OptionCard extends StatelessWidget {
  const OptionCard({
    super.key,
    required this.option,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  final InteractiveOption option;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = option.imageAsset != null;
    return AnimatedScale(
      scale: selected ? 1.025 : 1.0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: dimmed ? 0.4 : 1.0,
        duration: const Duration(milliseconds: 220),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: dimmed ? null : onTap,
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              // Phase 68 · "Goldilocks" bump from 88 → 102 (~16%) so the
              // side image regains visual grandeur without re-introducing
              // the pre-65 overflow. The list-level spacings (between
              // cards, subtitle→cards, title top padding) absorb the
              // extra 14 px × 4 cards on 4-option screens — see the
              // SizedBox tightening below in this file and the matching
              // hybrid-screen tweaks in `onboarding_screen.dart`.
              height: 102,
              decoration: BoxDecoration(
                color: selected
                    ? _neon.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected ? _neon : Colors.white.withValues(alpha: 0.1),
                  width: selected ? 1.6 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: _neon.withValues(alpha: 0.42),
                          blurRadius: 22,
                          spreadRadius: -2,
                        ),
                      ]
                    : null,
              ),
              // `clipBehavior` lets the right-side image bleed all the
              // way to the card's rounded corners without renders
              // leaking past the radius.
              clipBehavior: Clip.antiAlias,
              child: hasImage
                  ? _CardWithImage(option: option, selected: selected)
                  : _CardTextOnly(option: option, selected: selected),
            ),
          ),
        ),
      ),
    );
  }
}

/// Phase 60H · Fitify-style row. Left: padded icon + label + helper.
/// Right: flush full-height image with the centerLeft→centerRight
/// dark fade and a corner check overlay.
class _CardWithImage extends StatelessWidget {
  const _CardWithImage({required this.option, required this.selected});
  final InteractiveOption option;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    // Phase 65 · the parent OptionCard now pins the card to a fixed
    // 88 px height, so we no longer need IntrinsicHeight + a 96 px
    // floor. `crossAxisAlignment: stretch` lets the side-image panel
    // (Stack.expand) fill the full card height with BoxFit.cover.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 11,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: _CardTextContent(option: option, selected: selected),
          ),
        ),
        Expanded(
          flex: 9,
          child: _SideImagePanel(
            asset: option.imageAsset!,
            icon: option.icon,
            selected: selected,
          ),
        ),
      ],
    );
  }
}

/// Pre-60H all-text variant kept for cards without a bundled image
/// asset (`Diğer`, `Güçlenmek`). Same internal padding the legacy
/// design used so the option list stays visually coherent next to the
/// new side-image cards.
class _CardTextOnly extends StatelessWidget {
  const _CardTextOnly({required this.option, required this.selected});
  final InteractiveOption option;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    // Phase 65 · vertical padding tightened from 18 → 10 so this
    // image-less variant sits at the same compact height (88) as the
    // image cards without overflowing on hybrid card+input screens.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: _CardTextContent(option: option, selected: selected),
          ),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: selected ? 1.0 : 0.0,
            child: const Icon(
              Icons.check_circle,
              color: _neon,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared icon-bubble + label + helper block used by both the side-
/// image and text-only variants so the typography stays identical
/// between them.
class _CardTextContent extends StatelessWidget {
  const _CardTextContent({required this.option, required this.selected});
  final InteractiveOption option;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected
                ? _neon.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color:
                  selected ? _neonAccent : Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            option.icon,
            color: selected ? Colors.white : Colors.white70,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Both lines are Flexible: the card has a fixed height, so
              // a longer language has to shorten the text rather than
              // push it past the bottom edge. `maxLines` alone was not
              // enough — label + helper together overran by 2 px under
              // pseudo-localisation.
              Flexible(
                child: Text(
                  option.label,
                  // 2 lines (was 1): image-backed goal cards left too little
                  // width, truncating "Daha fit görünmek" → "Daha fit görü…".
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              if (option.helper != null) ...[
                const SizedBox(height: 4),
                Flexible(
                  child: Text(
                    option.helper!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Phase 60H · the right-hand image panel. Stacks the photo, the
/// dark-to-transparent left-blend gradient, and the selection check
/// pill. The outer card's `Clip.antiAlias` rounds this panel's right
/// corners; the panel itself doesn't carry its own borderRadius so
/// the image flush-mounts to the card edges per PM brief.
class _SideImagePanel extends StatelessWidget {
  const _SideImagePanel({
    required this.asset,
    required this.icon,
    required this.selected,
  });

  final String asset;
  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Image fills the panel via OnboardingImage (placeholder +
        // fade-in + error fallback). dimOverlay disabled because we
        // layer our own directional gradient on top.
        OnboardingImage(
          asset: asset,
          fallbackIcon: icon,
          borderRadius: 0,
          dimOverlay: false,
        ),
        // Phase 60H · seamless dark-to-transparent left blend per PM
        // brief. Reads as if the image is bleeding out of the card's
        // dark left half.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Colors.black, Colors.transparent],
            ),
          ),
        ),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: selected ? 1.0 : 0.0,
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: _neon,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 1.4),
                  boxShadow: [
                    BoxShadow(
                      color: _neon.withValues(alpha: 0.6),
                      blurRadius: 12,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check,
                  size: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Micro-feedback banner that fades+slides in once a card has been
/// picked. Sits below the card list and reads as the AI's "analysis"
/// reaction to the user's choice.
///
/// Public since Phase 60F so the hybrid `_ActivityStep` can render
/// the same banner without duplication.
class FeedbackBanner extends StatelessWidget {
  const FeedbackBanner({
    super.key,
    required this.fade,
    required this.slide,
    required this.text,
  });

  final Animation<double> fade;
  final Animation<Offset> slide;
  final String text;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _neon.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _neon.withValues(alpha: 0.45),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _neon.withValues(alpha: 0.18),
                blurRadius: 18,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.15,
            ),
          ),
        ),
      ),
    );
  }
}
