import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/locale_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../l10n/app_localizations.dart';

/// Roadmap Phase 6 (R3.2, C29) · onboarding step 0 — the language ask.
///
/// It is first because everything after it is words. An international
/// user who lands on the Turkish welcome hero has already decided
/// whether this app is for them before they find a setting.
///
/// The selection applies **immediately**, so this screen's own title,
/// subtitle and CTA flip as the user taps. That is the point: a user who
/// cannot read the current language does not have to trust a label they
/// can't parse — they tap their language and watch the screen become
/// readable. It also means the hot-switch path is exercised by the very
/// first interaction in the product.
///
/// Nothing is written until the user actually taps a row. Arriving on an
/// English phone, seeing English pre-selected and pressing continue
/// leaves the preference as *follow the device* — accepting a default is
/// not the same act as choosing, and only the second one should pin a
/// language against a phone whose own language may change.
///
/// ## Built to `photos/new-image/language-choose.png`
///
/// Two deliberate departures from the reference, both because the
/// reference is a visual target and the screen has to tell the truth:
///
///   * **The rows are driven by [kSupportedLocales], not by the mock.**
///     The mock shows five languages; the app ships two. Rendering
///     Deutsch, Español and Français as selectable rows would be a lie
///     the moment somebody tapped one, and greying them out advertises
///     an absence. When Phase 8 adds them they appear here for free.
///   * **No page dots.** The mock has four, implying a four-page intro.
///     This is step 0 of twenty and the wizard has its own progress
///     chrome, which is deliberately hidden during the hook steps.
class LanguageStep extends ConsumerWidget {
  const LanguageStep({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // What the app is *rendering*, not what is stored — so the
    // pre-selection reflects the device on a fresh install.
    final active = Localizations.localeOf(context).languageCode;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.55),
          radius: 1.2,
          colors: [Color(0xFF15082E), Color(0xFF07040D)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const _LanguagePill(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(child: _NeonHero()),
                    const SizedBox(height: 14),
                    Center(
                      child: Text(
                        l10n.languageWelcomeTo,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    // `scaleDown`, and this is the one place it is the
                    // right tool. A wordmark must never wrap — "Form"
                    // over "AI" is not the logo — so shrinking is the
                    // only correct response to a 1.3 text scale on a
                    // narrow phone, where the Row overflowed by 2.8 px.
                    // Everywhere else in this app a FittedBox was hiding
                    // text that should have wrapped instead.
                    const Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _FormAiWordmark(),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        l10n.languageTagline,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        const Icon(
                          Icons.language,
                          color: AppColors.neon,
                          size: 26,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            l10n.languageStepTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.languageStepSubtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.52),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final locale in kSupportedLocales) ...[
                      _LanguageRow(
                        locale: locale,
                        selected: locale.languageCode == active,
                        onTap: () {
                          AppHaptics.secondaryTap();
                          ref.read(localeProvider.notifier).set(locale);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: _ContinueButton(
                label: l10n.languageContinue,
                onPressed: () {
                  AppHaptics.secondaryTap();
                  onContinue();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "Language" chip in the top-right of the reference.
///
/// Decorative rather than interactive: it labels the screen. Making it a
/// button would be a second, redundant way to do the only thing this
/// screen does.
class _LanguagePill extends StatelessWidget {
  const _LanguagePill();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(0, 8, 20, 0),
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 18, 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.language, color: Colors.white, size: 19),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context).languageSettingsTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The neon brain-and-dumbbell mark from the reference.
///
/// A bundled image rather than a painter: it is a piece of brand
/// artwork with a glow, a particle field and a two-tone rim, and a
/// hand-rolled `CustomPainter` approximation of that would look like an
/// approximation. Re-encoded to 720² WebP (40 KB) from the 1.3 MB source
/// so the first screen in the app does not cost a megabyte to draw.
class _NeonHero extends StatelessWidget {
  const _NeonHero();

  @override
  Widget build(BuildContext context) {
    // Proportional to the screen so it holds its share of the layout on
    // a 320-wide phone as well as a tall one, capped so it cannot
    // dominate a tablet.
    final side = (MediaQuery.sizeOf(context).width * 0.62).clamp(150.0, 260.0);
    return SizedBox(
      width: side,
      height: side,
      child: Image.asset(
        'assets/illustrations/language_hero.webp',
        fit: BoxFit.contain,
        // The mark is a brand asset; if it ever fails to decode, the
        // screen still has to be usable, so fall back to the glyph the
        // rest of the screen already uses.
        errorBuilder: (_, __, ___) => const Icon(
          Icons.psychology_outlined,
          color: AppColors.neon,
          size: 96,
        ),
      ),
    );
  }
}

/// "Form" in brand purple, "AI" in brand lime — the wordmark exactly as
/// the reference draws it.
///
/// Two `Text`s in a `Row` rather than one `ShaderMask`: the reference
/// puts a hard colour boundary between the two halves, and a gradient
/// mask would blend across it.
class _FormAiWordmark extends StatelessWidget {
  const _FormAiWordmark();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 46,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.5,
      height: 1.05,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Form', // i18n-ignore — brand wordmark
          style: style.copyWith(
            color: AppColors.neon,
            shadows: [
              BoxShadow(
                color: AppColors.neon.withValues(alpha: 0.55),
                blurRadius: 24,
              ),
            ],
          ),
        ),
        Text(
          'AI', // i18n-ignore — brand wordmark
          style: style.copyWith(
            color: AppColors.neonGreen,
            shadows: [
              BoxShadow(
                color: AppColors.neonGreen.withValues(alpha: 0.55),
                blurRadius: 24,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One language: flag, endonym, English name, selection indicator.
///
/// The endonym carries the weight — it is the only thing on the row a
/// user of *another* language needs to recognise.
class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.locale,
    required this.selected,
    required this.onTap,
  });

  final Locale locale;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = localeEndonym(locale);
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.neon.withValues(alpha: 0.45),
                    blurRadius: 22,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: selected
              ? Colors.white.withValues(alpha: 0.045)
              : Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 13, 16, 13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? AppColors.neon
                      : Colors.white.withValues(alpha: 0.07),
                  width: selected ? 1.8 : 1,
                ),
              ),
              child: Row(
                children: [
                  _Flag(locale: locale),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          localeEnglishName(locale),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _SelectionDot(selected: selected),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The flag as an emoji inside the reference's rounded plate.
///
/// Emoji rather than bundled images: the platform already ships every
/// flag, at every density, and Phase 8's four extra languages then cost
/// nothing. A `photos/flag_tr.webp` set would be four more assets to
/// keep in sync with [kSupportedLocales].
class _Flag extends StatelessWidget {
  const _Flag({required this.locale});

  final Locale locale;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white.withValues(alpha: 0.06),
      ),
      clipBehavior: Clip.antiAlias,
      child: Text(
        localeFlagEmoji(locale),
        style: const TextStyle(fontSize: 30),
      ),
    );
  }
}

/// Lime filled check when selected, hollow ring when not — the
/// reference's two states.
class _SelectionDot extends StatelessWidget {
  const _SelectionDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.neonGreen : Colors.transparent,
        border: Border.all(
          color: selected
              ? AppColors.neonGreen
              : Colors.white.withValues(alpha: 0.22),
          width: 1.6,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.neonGreen.withValues(alpha: 0.55),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
      child: selected
          ? const Icon(Icons.check, color: Colors.black, size: 19)
          : null,
    );
  }
}

/// The purple-to-lime pill from the reference.
class _ContinueButton extends StatelessWidget {
  const _ContinueButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.neon.withValues(alpha: 0.40),
            blurRadius: 26,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(
            colors: [AppColors.neon, AppColors.neonGreen],
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 19),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.black,
                    size: 24,
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
