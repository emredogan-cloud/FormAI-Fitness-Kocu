import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/macro_target.dart';
import '../../domain/services/next_best_meal_service.dart';
import '../../providers/nutrition_provider.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _proteinColor = Color(0xFF4DA6FF);

/// AI coach banner shown below the macro status card on the nutrition
/// tab. Reads [consumedMacrosProvider] + [macroTargetProvider] +
/// [nextBestMealProvider] and produces a two-line Message + Fix copy
/// via [buildCoachCopy], rendered as **message** (bold) with `→ fix`
/// underneath.
///
/// Phase 25.2 upgraded the copy rules from soft encouragement to
/// data-specific prescriptions:
///   • Over-target → "{X} kcal fazla aldın." + carb/walk fix.
///   • Protein <60% of target → "Protein hedefini kaçırıyorsun." +
///     chicken/fish fix.
///   • Else → existing light-finish / balance fallbacks.
class AiInsightBanner extends ConsumerWidget {
  const AiInsightBanner({super.key, required this.onShowSuggestion});

  /// Called when the user taps the CTA. Wired by the tab to scroll
  /// into the suggestion section; provided via a callback so the
  /// banner doesn't need to know about scroll controllers.
  final VoidCallback onShowSuggestion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(macroTargetProvider);
    final consumed = ref.watch(consumedMacrosProvider);
    final suggestion = ref.watch(nextBestMealProvider);
    final copy = buildCoachCopy(
      target: target,
      consumed: consumed,
      suggestion: suggestion,
    );
    final hasSuggestion = suggestion != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              _neon.withValues(alpha: 0.22),
              _proteinColor.withValues(alpha: 0.12),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: _neon.withValues(alpha: 0.55)),
          boxShadow: [
            BoxShadow(
              color: _neon.withValues(alpha: 0.35),
              blurRadius: 20,
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _neon.withValues(alpha: 0.28),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI KOÇ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        copy.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '→ ',
                            style: TextStyle(
                              color: _neon,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              height: 1.35,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              copy.fix,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (hasSuggestion) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: onShowSuggestion,
                  icon: const Icon(Icons.south, size: 16),
                  label: const Text('Öneriyi Gör'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: _neon, width: 1.2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shape of a coach message: the short problem statement + the
/// actionable fix. Exported as a record so tests can assert copy
/// without rendering the widget tree.
typedef CoachCopy = ({String message, String fix});

/// Maps `(target, consumed, suggestion)` to the copy the banner should
/// render. Rules evaluated top-to-bottom — first match wins:
///
///   1. `consumed.calories > target.calories` — over target. Shows the
///      exact overage and recommends carb cuts / a walk.
///   2. `consumed.protein < target.protein * 0.6` — meaningful protein
///      gap. Suggests a chicken/fish main.
///   3. `remaining.calories < 400` — light finish territory. Points at
///      the current suggestion if any, else generic nudge.
///   4. Otherwise → balance / positive copy.
///
/// `suggestion` may be null (catalogue still loading); the rules
/// degrade gracefully when it is.
CoachCopy buildCoachCopy({
  required MacroTarget target,
  required MacroTarget consumed,
  required NextMealRecommendation? suggestion,
}) {
  final overage = consumed.calories - target.calories;

  // Rule 1 — calorie overshoot.
  if (target.calories > 0 && overage > 0) {
    return (
      message: '$overage kcal fazla aldın.',
      fix: 'Akşam karbonhidratı azalt veya 20 dk yürüyüş yap.',
    );
  }

  // Rule 2 — protein gap (<60% of target). target.protein == 0
  // short-circuits to false so an unset target doesn't fire a false
  // alarm.
  if (target.protein > 0 && consumed.protein < target.protein * 0.6) {
    return (
      message: 'Protein hedefini kaçırıyorsun.',
      fix: 'Tavuk/Balık bazlı bir ana öğün ekle.',
    );
  }

  final remainingCalories = target.calories - consumed.calories;

  // Rule 3 — light-finish territory.
  if (remainingCalories > 0 && remainingCalories < 400) {
    return (
      message: 'Az kalorin kaldı, ölçülü devam.',
      fix: suggestion != null
          ? '${suggestion.recipe.title} senin için uygun görünüyor.'
          : 'Hafif bir ara öğün seç.',
    );
  }

  // Rule 4 — balance / positive default.
  if (suggestion != null) {
    return (
      message: 'Dengeyi koru.',
      fix: 'Sonraki adım: ${suggestion.recipe.title}.',
    );
  }
  return const (
    message: 'Harika gidiyorsun!',
    fix: 'Hedeflerine sadık kal.',
  );
}
