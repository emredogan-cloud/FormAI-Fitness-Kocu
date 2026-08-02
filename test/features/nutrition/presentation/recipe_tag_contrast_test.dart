import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/nutrition/domain/recipe_tag_token.dart';
import 'package:sixpack_ai/features/nutrition/presentation/widgets/recipe_tags.dart';

/// Phase 7 device walk · the tag badges and the meal-type pill rendered a
/// white label on a `tint` filled at 18 % alpha. Over the dark scaffold
/// that fill is dark and white reads fine; over the light one it is a
/// pastel, and the labels measured 1.24:1 to 1.32:1 on the device — the
/// same white-on-white failure the Phase 6 walk found on "PREMIUM".
///
/// The guard computes the ratio rather than pinning a hex value, so it
/// keeps working if a tint is restyled and fails if a new tag is added in
/// a colour the rule cannot darken far enough.

/// WCAG relative luminance.
double _luminance(Color c) {
  double channel(double v) {
    final s = v;
    return s <= 0.03928
        ? s / 12.92
        : math.pow((s + 0.055) / 1.055, 2.4) as double;
  }

  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// The badge's own fill — `tint` at 18 % — composited over [surface].
Color _fillOver(Color tint, Color surface) =>
    Color.alphaBlend(tint.withValues(alpha: 0.18), surface);

/// A `BuildContext` whose `Theme.of(...).brightness` is [brightness].
Future<BuildContext> _contextWith(
  WidgetTester tester,
  Brightness brightness,
) async {
  late BuildContext captured;
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: Builder(builder: (context) {
      captured = context;
      return const SizedBox.shrink();
    }),
  ));
  return captured;
}

void main() {
  // Every tint the six shipped tokens use, plus the meal-type pill's.
  final tints = <String, Color>{
    for (final token in kRecipeFilterTokens) token: recipeTagStyle(token)!.tint,
    'budget_friendly': recipeTagStyle('budget_friendly')!.tint,
    'mealTypePill': const Color(0xFF8E5BFF),
  };

  testWidgets(
      'every tag label clears WCAG AA against its own fill in light '
      'mode', (tester) async {
    final context = await _contextWith(tester, Brightness.light);
    const surface = Colors.white;

    for (final entry in tints.entries) {
      final label = recipeTagLabelColor(context, entry.value);
      final ratio = _contrast(label, _fillOver(entry.value, surface));
      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason: '${entry.key} label is ${ratio.toStringAsFixed(2)}:1 on its '
            'own fill — it was 1.3:1 when the label was hardcoded white',
      );
    }
  });

  testWidgets('and in dark mode, where white was already right',
      (tester) async {
    final context = await _contextWith(tester, Brightness.dark);
    // The scaffold the nutrition surfaces actually paint on.
    const surface = Color(0xFF0B0B12);

    for (final entry in tints.entries) {
      final label = recipeTagLabelColor(context, entry.value);
      expect(label, Colors.white);
      final ratio = _contrast(label, _fillOver(entry.value, surface));
      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason: '${entry.key} label is ${ratio.toStringAsFixed(2)}:1',
      );
    }
  });

  testWidgets('a badge over a photograph stays white in both themes',
      (tester) async {
    // The nutrition tab positions its badge on the recipe image, whose
    // pixels do not change when the app theme does.
    for (final brightness in Brightness.values) {
      final context = await _contextWith(tester, brightness);
      for (final tint in tints.values) {
        expect(
          recipeTagLabelColor(context, tint, onImagery: true),
          Colors.white,
        );
      }
    }
  });
}
