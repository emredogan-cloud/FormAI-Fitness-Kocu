import 'package:flutter/animation.dart';

/// Centralised motion vocabulary for the cinematic onboarding rebuild.
///
/// Every duration and curve used by the motion primitives in this
/// folder (and by onboarding-side code) pulls from here so the
/// experience feels consistent screen-to-screen. Tweaking one constant
/// ripples through every animated surface.
///
/// Naming follows emotional intent, not waveform: `reassuranceEase`
/// instead of `easeInOutCubic`, so call sites read like "I want this to
/// feel reassuring" rather than "I want this curve."
abstract final class MotionTokens {
  // ─────────────────────────── durations ─────────────────────────────────

  /// One frame at 60fps. Use as a delay step between staggered children
  /// when the goal is a "ripple" rather than a sharp stagger.
  static const Duration frame60 = Duration(milliseconds: 17);

  /// Tap pulse — buttons + card selections.
  static const Duration tap = Duration(milliseconds: 120);

  /// Card / option selection feedback (the moment after the tap).
  static const Duration selection = Duration(milliseconds: 240);

  /// Standard fade-in for content blocks.
  static const Duration enter = Duration(milliseconds: 380);

  /// Entrance with intentional weight — titles, hero copy, milestone
  /// reveals. Long enough that users feel the moment.
  static const Duration heroEnter = Duration(milliseconds: 620);

  /// Page-to-page cross-fade when SceneTransition replaces the default
  /// PageView snap.
  static const Duration sceneCrossfade = Duration(milliseconds: 480);

  /// Multi-element stagger total span — welcome screen, report screen,
  /// any "row of insights" reveal.
  static const Duration staggerSpan = Duration(milliseconds: 1500);

  /// Breath cycle — long enough to feel ambient, short enough that the
  /// rhythm is noticeable. Used by [BreathingBox] / [GlowPulse].
  static const Duration breath = Duration(milliseconds: 2400);

  /// Typewriter character cadence. Slightly slower than a fast typer;
  /// matches the audit's "deliberate" coach voice.
  static const Duration typewriterChar = Duration(milliseconds: 28);

  // ─────────────────────────── curves ────────────────────────────────────

  /// Default entrance — reach-then-settle.
  static const Curve enterEase = Curves.easeOutCubic;

  /// Soft, slow start — used for reassurance moments where motion must
  /// NOT feel snappy.
  static const Curve reassuranceEase = Curves.easeInOutCubic;

  /// Energetic, slight overshoot — milestone reveals (confidence bar
  /// landing on its target, plan card flying in).
  static const Curve revealEase = Curves.easeOutBack;

  /// Calm, no overshoot — reflection / pain-point moments where motion
  /// must feel deliberate and quiet.
  static const Curve reflectionEase = Curves.easeOutQuart;

  /// Symmetric ease for breathing alpha pulses — feels organic.
  static const Curve breathEase = Curves.easeInOutSine;

  /// Sharp finish for haptic-coupled motions (the haptic lands at the
  /// curve's end so the user feels the impact at "max acceleration").
  static const Curve hapticLandEase = Curves.easeOutQuint;
}
