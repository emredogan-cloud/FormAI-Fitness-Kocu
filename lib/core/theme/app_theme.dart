import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Phase 49 / Phase 53 · centralised `ThemeData` builder.
///
/// Was scattered across `main.dart` (`ColorScheme.fromSeed` + a black
/// scaffold colour) with no shared snackBar / dialog defaults. Phase 49
/// pulled it here and added the floating, neon-bordered SnackBar.
/// Phase 53 added the light-mode counterpart so the user-visible
/// `themeModeProvider` switch flips between two real palettes instead
/// of forcing dark on every install.
///
/// Each builder returns a [ThemeData] with the same SnackBar treatment
/// and ColorScheme seeded from [AppColors.neon] — only the brightness
/// + scaffold / surface tones differ. Anything reading
/// `Theme.of(context).colorScheme` therefore flips cleanly; widgets
/// painted with hardcoded hex values stay frozen in their original
/// look (legible in both modes but visually identical).
class AppTheme {
  const AppTheme._();

  static ThemeData dark() {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.neon,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: AppColors.darkBg,
      useMaterial3: true,
    );
    return base.copyWith(snackBarTheme: _snackBarThemeDark());
  }

  /// Phase 53 light theme. Critical surfaces — the Scaffold background,
  /// AppBar, default text styles, FilledButton background — all flip
  /// to the new light tokens; brand-coloured elements (gradient CTAs,
  /// neon accents, badge halos) keep their hue because they're
  /// painted with explicit hex values, not `colorScheme.primary`.
  ///
  /// Notable choices:
  ///   • `seedColor` stays [AppColors.neon] so Material's auto-derived
  ///     primary/secondary/tertiary tones land in our brand purple
  ///     family. The seed picks a tonal palette that's distinct from
  ///     the dark variant but still recognisably FormAI.
  ///   • The SnackBar gets the same neon hairline treatment as dark
  ///     mode; only the background flips so the toast still feels
  ///     branded against a light surface.
  static ThemeData light() {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.neon,
        brightness: Brightness.light,
        // Override the surface tones so cards don't pick up Material's
        // tinted defaults (which lean a touch lavender from the seed).
        // Pure off-white is what the design spec calls for.
        surface: AppColors.lightSurface,
        // ignore: deprecated_member_use
        background: AppColors.lightBg,
        onSurface: AppColors.lightTextPrimary,
        outline: AppColors.lightSurfaceBorder,
      ),
      scaffoldBackgroundColor: AppColors.lightBg,
      useMaterial3: true,
    );
    return base.copyWith(snackBarTheme: _snackBarThemeLight());
  }

  static SnackBarThemeData _snackBarThemeDark() {
    return SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF14141B),
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: AppColors.neon.withValues(alpha: 0.45),
          width: 1,
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      showCloseIcon: false,
    );
  }

  /// Mirror of [_snackBarThemeDark] for light surfaces. The contrast
  /// flips — dark text on a near-white surface — and the neon
  /// hairline darkens slightly so it reads as a deliberate 1-px
  /// outline rather than a glow.
  static SnackBarThemeData _snackBarThemeLight() {
    return SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.lightSurface,
      contentTextStyle: const TextStyle(
        color: AppColors.lightTextPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: AppColors.neon.withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      showCloseIcon: false,
    );
  }
}
