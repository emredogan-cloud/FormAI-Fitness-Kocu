/// Roadmap Phase 5 (C12) · metric ⇄ imperial, and how each renders.
///
/// FormAI stores every body measurement in metric — kilograms and
/// centimetres — and always will. This file is a *presentation* layer:
/// it converts on the way out to the user and back on the way in, and
/// nothing it does ever changes what is persisted.
///
/// That separation is the whole design. A codebase that stores whatever
/// the user last picked ends up with rows whose unit is implied by a
/// preference read at a different time, and a BMI calculation that is
/// silently wrong for anyone who ever toggled the switch. Storing one
/// canonical unit makes that class of bug impossible; the cost is this
/// file, which is pure, has no dependencies, and is exhaustively
/// testable.
///
/// Rounding is deliberate and asymmetric:
///   * **Display** rounds to what a human would say — 70.4 kg reads as
///     "70 kg", 155 lb as "155 lb".
///   * **Round-tripping** does not re-round. `lbToKg(kgToLb(x))` returns
///     x to within floating-point error, so a user toggling the unit
///     switch twice never sees their weight drift.
library;

import 'dart:math' as math;

enum UnitSystem {
  metric('metric'),
  imperial('imperial');

  const UnitSystem(this.token);

  /// Stable persisted token. Never rename — it is a preference value.
  final String token;

  /// Unknown / absent / malformed resolves to metric: the app's storage
  /// unit, the unit its Turkish launch market uses, and the safe answer
  /// when nothing is known.
  static UnitSystem fromToken(String? token) {
    for (final system in UnitSystem.values) {
      if (system.token == token) return system;
    }
    return UnitSystem.metric;
  }
}

// ─── Exact conversion factors ───────────────────────────────────────
//
// These are the internationally defined values, not approximations:
// the pound is *defined* as exactly 0.45359237 kg and the inch as
// exactly 2.54 cm. Using the exact factors is what lets the round-trip
// tests assert equality to floating-point tolerance rather than to a
// hand-waved epsilon.

const double kKgPerPound = 0.45359237;
const double kCmPerInch = 2.54;
const int kInchesPerFoot = 12;

double kgToLb(double kg) => kg / kKgPerPound;
double lbToKg(double lb) => lb * kKgPerPound;
double cmToInches(double cm) => cm / kCmPerInch;
double inchesToCm(double inches) => inches * kCmPerInch;

/// A height expressed the way imperial users say it.
class FeetInches {
  const FeetInches(this.feet, this.inches);

  final int feet;
  final int inches;

  @override
  bool operator ==(Object other) =>
      other is FeetInches && other.feet == feet && other.inches == inches;

  @override
  int get hashCode => Object.hash(feet, inches);

  @override
  String toString() => "$feet'$inches\"";
}

/// Splits [cm] into whole feet and inches, rounding to the nearest inch.
///
/// The carry case is the one that matters: 11.6 inches rounds to 12,
/// which is not an inch value a human would ever say — it is one more
/// foot. Handling it here means no caller has to remember to.
FeetInches cmToFeetInches(double cm) {
  final totalInches = cmToInches(cm).round();
  final feet = totalInches ~/ kInchesPerFoot;
  final inches = totalInches % kInchesPerFoot;
  return FeetInches(feet, inches);
}

double feetInchesToCm(int feet, int inches) =>
    inchesToCm((feet * kInchesPerFoot + inches).toDouble());

// ─── Display formatting ─────────────────────────────────────────────

/// Formats a stored weight for display in [system].
///
/// [decimals] defaults to 0 because body weight to a tenth of a pound is
/// false precision — the scale, the time of day and the user's clothes
/// all vary by more than that.
String formatWeight(
  double kg, {
  required UnitSystem system,
  int decimals = 0,
  bool withUnit = true,
}) {
  final value = system == UnitSystem.metric ? kg : kgToLb(kg);
  final text = _trimZeros(value.toStringAsFixed(decimals));
  if (!withUnit) return text;
  return '$text ${weightUnitLabel(system)}';
}

/// Formats a stored height for display in [system].
///
/// Imperial height is feet-and-inches rather than decimal feet, because
/// nobody says "5.75 feet".
String formatHeight(
  double cm, {
  required UnitSystem system,
  bool withUnit = true,
}) {
  if (system == UnitSystem.metric) {
    final text = _trimZeros(cm.toStringAsFixed(0));
    return withUnit ? '$text ${heightUnitLabel(system)}' : text;
  }
  final split = cmToFeetInches(cm);
  return "${split.feet}'${split.inches}\"";
}

String weightUnitLabel(UnitSystem system) =>
    system == UnitSystem.metric ? 'kg' : 'lb';

String heightUnitLabel(UnitSystem system) =>
    system == UnitSystem.metric ? 'cm' : 'ft';

/// Formats a distance in metres for display.
String formatDistance(
  double metres, {
  required UnitSystem system,
  int decimals = 1,
}) {
  if (system == UnitSystem.metric) {
    if (metres < 1000) return '${_trimZeros(metres.toStringAsFixed(0))} m';
    return '${_trimZeros((metres / 1000).toStringAsFixed(decimals))} km';
  }
  const feetPerMetre = 3.280839895013123;
  const feetPerMile = 5280;
  final feet = metres * feetPerMetre;
  if (feet < feetPerMile) return '${_trimZeros(feet.toStringAsFixed(0))} ft';
  return '${_trimZeros((feet / feetPerMile).toStringAsFixed(decimals))} mi';
}

/// Sensible slider/picker bounds for a weight entry field, in the
/// display unit. Keeps pickers from offering values no human has.
({double min, double max}) weightRange(UnitSystem system) =>
    system == UnitSystem.metric
        ? (min: 30, max: 250)
        : (min: kgToLb(30).roundToDouble(), max: kgToLb(250).roundToDouble());

({double min, double max}) heightRange(UnitSystem system) =>
    system == UnitSystem.metric
        ? (min: 120, max: 230)
        : (
            min: cmToInches(120).roundToDouble(),
            max: cmToInches(230).roundToDouble()
          );

/// Drops a trailing `.0` / `.50` so "70.0" reads as "70" and "1.50" as
/// "1.5". Locale-independent by construction: it only ever removes
/// characters this function's own `toStringAsFixed` produced.
String _trimZeros(String text) {
  if (!text.contains('.')) return text;
  var out = text.replaceFirst(RegExp(r'0+$'), '');
  if (out.endsWith('.')) out = out.substring(0, out.length - 1);
  return out;
}

/// Rounds [value] to [places] decimals. Exposed because several
/// surfaces need the *number*, not the formatted string.
double roundTo(double value, int places) {
  final factor = math.pow(10, places);
  return (value * factor).round() / factor;
}
