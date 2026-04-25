import 'package:flutter/material.dart';

/// Phase 53 hotfix · convenience accessors so per-widget code can read
/// theme values without typing `Theme.of(context)` four times in a row.
///
/// The hotfix root cause was that most surface paint instructions across
/// the app referenced static dark-palette constants (`AppColors.darkBg`,
/// hardcoded `0xFF...` values, `Colors.black`). Switching `themeMode`
/// changed `MaterialApp.theme` cleanly, but the widget tree kept
/// painting itself dark because nothing was actually reading the active
/// `ColorScheme`. Migrating those call sites to `context.colors.*`
/// makes the surfaces flip with the toggle.
///
/// Naming: `colors` over the more obvious `colorScheme` because the
/// shorter name lands cleanly inline:
///   `Container(color: context.colors.surface)` reads better than
///   `Container(color: context.colorScheme.surface)` and matches the
///   codebase's preference for terse accessors (cf. `AppColors`).
extension ThemeColorsExt on BuildContext {
  /// Active [ColorScheme]. Flips between
  /// [ThemeData.dark]/[ThemeData.light] depending on the user's
  /// `themeMode` choice + the OS preference.
  ColorScheme get colors => Theme.of(this).colorScheme;

  /// Active [TextTheme]. Hot path for body / headline copy that needs
  /// to flip between white-on-dark and charcoal-on-light.
  TextTheme get textStyles => Theme.of(this).textTheme;

  /// `true` when the active theme is dark — useful for tinting bespoke
  /// gradients or hairlines that don't have a clean ColorScheme token.
  /// Prefer the ColorScheme accessors above when one fits.
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}
