import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Phase 49 · centralised `ThemeData` builder.
///
/// Was scattered across `main.dart` (`ColorScheme.fromSeed` + a black
/// scaffold colour) with no shared snackBar / dialog defaults. The
/// builder below keeps the existing seed-based colour scheme but layers
/// on:
///
///   • Floating, rounded snackBars with a subtle neon border so toasts
///     feel like part of the brand instead of stock Material chrome.
///   • A consistent background colour drawn from `AppColors.darkBg`.
///   • Filled-button defaults that match the brand neon (so callers
///     don't need to set `backgroundColor` per button).
///
/// Phase 49 only adds the SnackBar override + plumbing — call sites are
/// free to keep their own per-screen FilledButton styling.
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

    return base.copyWith(
      // Phase 49 · floating, rounded snackBar with a thin neon hairline.
      // Default Material `fixed` snackBars stuck to the bottom edge and
      // looked like stock Android chrome on iOS as well; the floating
      // variant reads as a deliberately-designed toast and matches the
      // glass-card aesthetic used by the rest of the surfaces.
      snackBarTheme: SnackBarThemeData(
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
      ),
    );
  }
}
