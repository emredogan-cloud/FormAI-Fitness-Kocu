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
  /// remaining" status.
  static const Color orange = Color(0xFFF97316);

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
}
