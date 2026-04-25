import 'package:flutter/material.dart';

/// Phase 48 · app-wide colour palette.
///
/// Every feature surface defined its own `_neon`, `_neonAccent`,
/// `_success`, `_danger`, etc. as private file-level constants. The
/// values agreed in spirit but disagreed in detail (e.g. one screen
/// shipped `0xFF8E5BFF`, another shipped `0xFF8B5CF6` — both labelled
/// "neon"). Centralising the palette here lets a future redesign edit
/// a single literal instead of grepping the codebase, and makes the
/// brand identity legible at a glance.
///
/// Existing per-file private constants kept for now — this module is
/// additive. New code should prefer `AppColors.<name>` over re-
/// declaring locally; legacy files migrate opportunistically.
class AppColors {
  const AppColors._();

  // -- Brand neon ranges ----------------------------------------------

  /// Primary purple-neon. Borders, focus rings, primary CTAs across
  /// onboarding / dashboard / nutrition / progress.
  static const Color neon = Color(0xFF8E5BFF);

  /// Secondary neon — cooler blue-violet that pairs with [neon] for
  /// gradients (workout screen accents, badge halos).
  static const Color neonAccent = Color(0xFF4DA6FF);

  /// Deeper purple used as the bottom stop in vertical neon gradients
  /// (Gelişim cards, AI coach avatar ring).
  static const Color neonDeep = Color(0xFF6A3DFF);

  /// Cyber-cyan, used for the workout camera HUD + the post-workout
  /// SessionCompleteOverlay trophy. Intentionally distinct from the
  /// brand neon so the camera surface reads as "live" / "active".
  static const Color cyberCyan = Color(0xFF00F0FF);

  /// Bright neon green — CTAs that imply progress ("Hemen Ekle"),
  /// macro bar accents, on-track status pill.
  static const Color neonGreen = Color(0xFF39FF14);

  // -- Status / semantic ----------------------------------------------

  /// Success green used by completion checks, "Açıldı!" badge pills,
  /// and the nutrition labor-illusion success panel.
  static const Color success = Color(0xFF22C55E);

  /// Destructive accent for delete-account flows, hard error toasts,
  /// and the "kalori aşıldı" status colour.
  static const Color danger = Color(0xFFFF4D6D);

  /// Warm warning hue. Streak pills, weekly kcal cards, "low calories
  /// remaining" status. Phase 53 audited against WCAG AA: 4.5:1 needs
  /// the 14-pt on-light path, which `0xFFF97316` (luminance 0.43)
  /// fails on white. Use [orangeOnLight] when rendering this hue
  /// against light surfaces; the original [orange] stays the dark-mode
  /// constant.
  static const Color orange = Color(0xFFF97316);

  /// Phase 53 accessibility tweak. `Color(0xFFB45309)` (Tailwind
  /// orange-700) clears 4.74:1 against pure white and 4.55:1 against
  /// our [lightSurface] — a contrast-passing alternative for warning
  /// text in light mode. Glyph filling (icon backgrounds with low
  /// alpha overlays) can keep using [orange]; only foreground text
  /// or thin lines need the swap.
  static const Color orangeOnLight = Color(0xFFB45309);

  /// Softer amber — rest day cells, "İlk Adım" badge accent.
  static const Color amber = Color(0xFFFFB84D);

  /// Pink accent used by the carbs macro bar and the "HIIT Ustası"
  /// badge.
  static const Color pink = Color(0xFFFF4DDB);

  // -- Macro bar palette ----------------------------------------------

  /// Protein bar + "Core Master" badge tint.
  static const Color protein = Color(0xFF4DA6FF);

  /// Carbs bar tint (also re-used as the [pink] accent above).
  static const Color carbs = Color(0xFFFF4DDB);

  /// Fat bar — bright phosphor yellow.
  static const Color fat = Color(0xFFEAFF00);

  // -- Surfaces -------------------------------------------------------

  /// App-wide near-black background used by every Scaffold.
  static const Color darkBg = Color(0xFF0B0B12);

  /// Card surface above [darkBg]. Dashboard cards, badge tiles,
  /// settings tiles all sit on this one tone.
  static const Color surface = Color(0xFF0F0F14);

  /// Subtle border tone for cards on [surface]. One step above
  /// surface so the outline is visible without competing with neon
  /// accents.
  static const Color surfaceBorder = Color(0xFF1E1E26);

  /// Inactive cell colour — locked day grid, disabled tiles, faded
  /// chrome.
  static const Color inactive = Color(0xFF1C1C24);

  // -- Light surfaces (Phase 53) --------------------------------------
  // Phase 53 introduces a Light theme. Most existing widgets paint with
  // hardcoded hex values from the dark palette and stay legible-but-
  // off-brand in light mode; the Material widgets that respect the
  // ThemeData ColorScheme (Scaffold backgrounds, AppBars, default
  // FilledButtons) flip cleanly via the new tokens below. Bespoke
  // surfaces will migrate opportunistically.

  /// Crisp off-white scaffold. Picked over pure `0xFFFFFFFF` to avoid
  /// the harsh white that would otherwise strobe under the neon
  /// brand accents.
  static const Color lightBg = Color(0xFFF7F8FA);

  /// Cards and elevated surfaces in light mode.
  static const Color lightSurface = Color(0xFFFFFFFF);

  /// 1-px outline on cards in light mode. Subtle so it reads as a
  /// hairline rather than a heavy frame.
  static const Color lightSurfaceBorder = Color(0xFFE2E5EA);

  /// Primary text on light surfaces. Charcoal rather than pure black so
  /// long blocks of body copy don't fight the screen.
  static const Color lightTextPrimary = Color(0xFF111118);

  /// Secondary / metadata text on light surfaces. WCAG AA compliant
  /// against [lightSurface] (5.07:1).
  static const Color lightTextSecondary = Color(0xFF565B66);
}
