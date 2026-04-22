import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/macro_target.dart';
import '../../domain/models/recipe.dart';
import '../../providers/nutrition_provider.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _proteinColor = Color(0xFF4DA6FF);

/// AI coach banner shown below the macro status card on the nutrition
/// tab. Reads [remainingMacrosProvider] + [nextBestMealProvider] and
/// produces a two-line message (problem + prescription) plus an
/// optional "Öneriyi Gör" CTA that scrolls the tab to the next-best-
/// meal section.
///
/// Extracted out of `nutrition_tab.dart` in phase 23.2 because the
/// banner graduated from a static pep-talk line into a decision
/// surface; keeping its copy-generation rules in the tab file was
/// going to hide them under hundreds of lines of layout code.
class AiInsightBanner extends ConsumerWidget {
  const AiInsightBanner({super.key, required this.onShowSuggestion});

  /// Called when the user taps the CTA. Wired by the tab to scroll
  /// into the suggestion section; provided via a callback so the
  /// banner doesn't need to know about scroll controllers.
  final VoidCallback onShowSuggestion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remaining = ref.watch(remainingMacrosProvider);
    final suggestion = ref.watch(nextBestMealProvider);
    final copy = buildCoachCopy(remaining: remaining, suggestion: suggestion);
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
              crossAxisAlignment: CrossAxisAlignment.center,
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
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        copy.action,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
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

/// Shape of a coach message: the short problem statement + the actionable
/// prescription. Exported as a record so tests can assert copy without
/// rendering the widget tree.
typedef CoachCopy = ({String message, String action});

/// Maps `(remaining, suggestion)` to the copy the banner should render.
/// Mirrors the priority tiers in [NextBestMealService] so the banner
/// explains *why* the suggestion is what it is:
///
///   • Protein gap (>30 g) → "Protein hedefini kaçırıyorsun."
///   • Calorie overshoot (remaining < 0) → "Günlük kalori hedefini aştın."
///   • Light finish needed (remaining < 400 kcal) → "Az kalorin kaldı."
///   • Otherwise → a balance-tier line.
///
/// When `suggestion` is null (catalogue empty / still loading) the copy
/// falls back to an encouraging default without an actionable line.
CoachCopy buildCoachCopy({
  required MacroTarget remaining,
  required Recipe? suggestion,
}) {
  if (suggestion == null) {
    return const (
      message: 'Harika gidiyorsun!',
      action: 'Hedeflerine sadık kal.',
    );
  }

  if (remaining.protein > 30) {
    return (
      message: 'Protein hedefini kaçırıyorsun.',
      action:
          '${suggestion.title} tarzı yüksek proteinli bir öğün eklemeni öneririm.',
    );
  }

  if (remaining.calories < 0) {
    return (
      message: 'Günlük kalori hedefini aştın.',
      action: 'Hafif bir seçenek: ${suggestion.title}.',
    );
  }

  if (remaining.calories < 400) {
    return (
      message: 'Az kalorin kaldı, ölçülü devam.',
      action: '${suggestion.title} senin için uygun görünüyor.',
    );
  }

  return (
    message: 'Dengeyi koru.',
    action: 'Sonraki adım: ${suggestion.title}.',
  );
}
