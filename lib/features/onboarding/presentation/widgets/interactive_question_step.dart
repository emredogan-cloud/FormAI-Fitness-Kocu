import 'package:flutter/material.dart';

import '../../../../core/utils/app_haptics.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _neonAccent = Color(0xFF4DA6FF);

/// A single tappable answer for [InteractiveQuestionStep].
///
/// `value` is the token persisted to wizard state (e.g. `belly_burn`,
/// `sedentary`). `label` is the user-facing copy. `helper` is an
/// optional one-liner shown beneath the label. `imageAsset` is an
/// optional bundled photo path (Phase 60E) — when provided the card
/// renders a 56x56 thumbnail on the right edge of the card; if the
/// asset can't be decoded the tile falls back to a stylised gradient
/// + the option's [icon].
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
  });

  final String title;
  final String? subtitle;
  final List<InteractiveOption> options;
  final String feedbackText;
  final ValueChanged<String> onCommitted;
  final String? initialValue;
  final Duration commitDelay;

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
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
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
        const SizedBox(height: 20),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              children: [
                for (final opt in widget.options) ...[
                  _OptionCard(
                    option: opt,
                    selected: _selected == opt.value,
                    dimmed: _committing && _selected != opt.value,
                    onTap: () => _pick(opt.value),
                  ),
                  if (opt != widget.options.last) const SizedBox(height: 12),
                ],
                const SizedBox(height: 16),
                _FeedbackBanner(
                  fade: _feedbackFade,
                  slide: _feedbackSlide,
                  text: widget.feedbackText,
                ),
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
class _OptionCard extends StatelessWidget {
  const _OptionCard({
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
              child: Row(
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
                        color: selected
                            ? _neonAccent
                            : Colors.white.withValues(alpha: 0.12),
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
                      children: [
                        Text(
                          option.label,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                        if (option.helper != null) ...[
                          const SizedBox(height: 4),
                          // Phase 60E · motivational subtext under the
                          // primary label. PM rule: ~0.7 alpha so it
                          // reads as supportive but doesn't compete
                          // with the choice itself.
                          Text(
                            option.helper!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Phase 60E · trailing slot. With an image asset the
                  // card renders a 56x56 photo tile (selection halo +
                  // a corner check overlay when picked). Without one
                  // the original check-icon-only behaviour stays.
                  if (option.imageAsset != null) ...[
                    const SizedBox(width: 12),
                    _OptionImageTile(
                      asset: option.imageAsset!,
                      icon: option.icon,
                      selected: selected,
                    ),
                  ] else
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
            ),
          ),
        ),
      ),
    );
  }
}

/// Micro-feedback banner that fades+slides in once a card has been
/// picked. Sits below the card list and reads as the AI's "analysis"
/// reaction to the user's choice.
class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({
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

/// Phase 60E · trailing image tile rendered when an [InteractiveOption]
/// supplies an [InteractiveOption.imageAsset]. 56x56, rounded corners,
/// neon halo + corner check overlay when selected. The
/// [Image.asset.errorBuilder] catches missing/corrupt assets and
/// renders a gradient + the option's icon so the layout stays visually
/// balanced even when an asset path is wrong.
class _OptionImageTile extends StatelessWidget {
  const _OptionImageTile({
    required this.asset,
    required this.icon,
    required this.selected,
  });

  final String asset;
  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? _neon : Colors.white.withValues(alpha: 0.15),
          width: selected ? 1.6 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: _neon.withValues(alpha: 0.5),
                  blurRadius: 14,
                  spreadRadius: -2,
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Image.asset(
              asset,
              fit: BoxFit.cover,
              width: 56,
              height: 56,
              errorBuilder: (_, __, ___) => DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _neon.withValues(alpha: 0.45),
                      _neonAccent.withValues(alpha: 0.35),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
              ),
            ),
          ),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: selected ? 1.0 : 0.0,
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: _neon,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 1.4),
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 11,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
