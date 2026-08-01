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
/// subtitle and CTA flip as the user taps. That is the point: a user
/// who cannot read the current language does not have to trust a label
/// they can't parse — they tap their language and watch the screen
/// become readable. It also means the hot-switch path is exercised by
/// the very first interaction in the product.
///
/// Nothing is written until the user actually taps a row. Arriving on
/// an English phone, seeing English pre-selected and pressing continue
/// leaves the preference as *follow the device* — accepting a default
/// is not the same act as choosing, and only the second one should
/// pin a language against a phone whose own language may change.
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
          center: Alignment(0, -0.75),
          radius: 1.35,
          colors: [Color(0xFF1B0C40), Color(0xFF0A0612)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.language, color: AppColors.neon, size: 40),
              const SizedBox(height: 20),
              Text(
                l10n.languageStepTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.languageStepSubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: ListView.separated(
                  itemCount: kSupportedLocales.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final locale = kSupportedLocales[i];
                    return _LanguageTile(
                      locale: locale,
                      selected: locale.languageCode == active,
                      onTap: () {
                        AppHaptics.secondaryTap();
                        ref.read(localeProvider.notifier).set(locale);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  AppHaptics.secondaryTap();
                  onContinue();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.neon,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    fontSize: 18,
                  ),
                ),
                child: Text(l10n.onbContinueCta),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One language, named in itself.
///
/// The endonym is the only thing on the row that a user of *another*
/// language needs to recognise, so it carries the weight: full size,
/// full contrast, no translated subtitle competing with it.
class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
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
      child: Material(
        color:
            selected ? AppColors.neon.withValues(alpha: 0.16) : Colors.white10,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? AppColors.neon : Colors.white24,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.neon,
                    size: 26,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
