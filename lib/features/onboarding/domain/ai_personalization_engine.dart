import '../providers/wizard_provider.dart';
import '../../../l10n/app_localizations.dart';

/// The cadence the app itself prescribes, in sessions per week.
///
/// 4 days/week is the PM-spec'd starter cadence; 5 for self-reported
/// regulars who can absorb the extra session.
///
/// Public, and top-level, because Roadmap Phase 9's adherence score
/// divides by exactly this number — it is the denominator of "did you
/// do what we asked". A second copy of the rule in the progress feature
/// would let the promise and the scoring drift apart, and the user
/// would be the one who found out.
int weeklyWorkoutCountFor(String? experienceLevel) =>
    experienceLevel == 'regular' ? 5 : 4;

/// Phase 60D · the AI report DTO consumed by the dynamic-report and
/// pre-paywall-summary screens. Single immutable value type so the
/// two screens can pull whichever fields they need without re-running
/// the engine.
class AiReport {
  const AiReport({
    required this.assessment,
    required this.bmi,
    required this.maintenanceCalories,
    required this.goalLabel,
    required this.difficultyLabel,
    required this.weeklyWorkoutCount,
    required this.durationLabel,
    required this.estimatedResults,
  });

  /// Multi-sentence personalised "AI assessment" paragraph. Composed
  /// dynamically from the wizard state — never a static block.
  final String assessment;

  /// Body Mass Index (kg / m²).
  final double bmi;

  /// Daily maintenance calories (Mifflin-St Jeor × activity multiplier).
  final int maintenanceCalories;

  /// User-facing label for the picked goal token (e.g. "Göbek eritmek").
  final String goalLabel;

  /// User-facing difficulty derived from `experienceLevel`.
  final String difficultyLabel;

  /// Recommended workouts per week. Conservative-by-default (4) and
  /// nudged up to 5 for self-reported `regular` trainees.
  final int weeklyWorkoutCount;

  /// Plan duration. Fixed at "12 Hafta" per Phase-60D PM directive.
  final String durationLabel;

  /// One-liner of expected outcome at the 12-week mark, branched on
  /// `goal`.
  final String estimatedResults;
}

/// Phase 60D · the personalisation engine.
///
/// Composes the dynamic AI assessment paragraph and the derived
/// summary fields (difficulty, weekly cadence, projected results) by
/// branching on combinations of `goal`, `activityLevel`,
/// `experienceLevel`, and `painPoint`.
///
/// Combination rules baked in:
///   1. `goal == belly_burn` AND `activityLevel == sedentary` →
///      emphasises fat-accumulation risk + how the plan reverses it.
///   2. `experienceLevel == none` (beginner) → emphasises fast newbie
///      gains in the first 30 days.
///   3. `painPoint == motivation` OR `consistency` → emphasises the
///      AI coach acting as a daily accountability partner.
///
/// Tokens are kept in sync with the values written by the wizard
/// (`belly_burn` etc.). The engine itself is pure — no Riverpod, no
/// I/O — so it's trivially unit-testable and can be reused outside
/// the onboarding flow.
class AiPersonalizationEngine {
  const AiPersonalizationEngine._();

  static AiReport generateReport(AppLocalizations l10n, WizardState state) {
    return AiReport(
      assessment: _assessment(l10n, state),
      bmi: _bmi(state),
      maintenanceCalories: _maintenanceCalories(state),
      goalLabel: _goalLabel(l10n, state.goal),
      difficultyLabel: _difficultyLabel(l10n, state.experienceLevel),
      weeklyWorkoutCount: _weeklyWorkoutCount(state),
      durationLabel: l10n.reportDuration12Weeks,
      estimatedResults: _estimatedResults(l10n, state),
    );
  }

  // ───────────────────────────── assessment ────────────────────────────────

  static String _assessment(AppLocalizations l10n, WizardState s) {
    // Greet by name when we have one. The name capture step asks Form
    // "Bu yolculukta sana nasıl sesleneyim?" between coach intro and
    // gender; landing here without a name means the user skipped that
    // step somehow (e.g. legacy save), so we fall back to the un-named
    // greeting instead of a brittle empty-vocative.
    final normalized = _normalizeName(s.name);
    final greeting = normalized != null
        ? l10n.reportGreetingNamed(normalized)
        : l10n.reportGreeting;
    final parts = <String>[greeting];

    // Quote-back. Pain-point > experience > activity (pain-point is the most
    // emotionally loaded answer). Without this, the user types 60 seconds of
    // free text and never sees it reflected — the "AI is really listening"
    // contract breaks.
    final quoted = _quoteFirstSentence(s.painPointDescription) ??
        _quoteFirstSentence(s.experienceDescription) ??
        _quoteFirstSentence(s.activityDescription);
    if (quoted != null) {
      parts.add(l10n.reportQuoteBack(quoted));
    }

    final isFatLossSedentary =
        s.goal == 'belly_burn' && s.activityLevel == ActivityLevel.sedentary;

    // Combination rule 1: fat-loss + sedentary lifestyle.
    if (isFatLossSedentary) {
      parts.add(
        l10n.reportSedentaryFatLoss,
      );
    } else if (s.activityLevel == ActivityLevel.sedentary) {
      parts.add(
        l10n.reportSedentary,
      );
    } else if (s.activityLevel == ActivityLevel.active) {
      parts.add(
        l10n.reportActive,
      );
    }

    // Goal-specific copy. Skipped when the combo line above already
    // covered fat-loss-for-sedentary so we don't double-explain it.
    if (!isFatLossSedentary) {
      switch (s.goal) {
        case 'belly_burn':
          parts.add(
            l10n.reportGoalBellyBurn,
          );
        case 'muscle_gain':
          parts.add(
            l10n.reportGoalMuscleGain,
          );
        case 'fitness_look':
          parts.add(
            l10n.reportGoalFitnessLook,
          );
        case 'strength':
          parts.add(
            l10n.reportGoalStrength,
          );
      }
    }

    // Combination rule 2: beginner → newbie-gain story.
    if (s.experienceLevel == 'none') {
      parts.add(
        l10n.reportBeginner,
      );
    } else if (s.experienceLevel == 'regular') {
      parts.add(
        l10n.reportRegular,
      );
    }

    // Combination rule 3: motivation / consistency → accountability.
    final pain = s.painPoint;
    if (pain == 'motivation' || pain == 'consistency') {
      parts.add(
        l10n.reportPainConsistency,
      );
    } else if (pain == 'no_idea') {
      parts.add(
        l10n.reportPainNoIdea,
      );
    } else if (pain == 'diet') {
      parts.add(
        l10n.reportPainDiet,
      );
    }

    return parts.join(' ');
  }

  /// Normalises the captured name for assessment-paragraph display.
  /// Trims whitespace, returns null on empty so the greeting branch can
  /// fall back. Capitalises the first character so "emre" → "Emre"
  /// while leaving the rest of the string alone — this avoids
  /// destroying the Turkish dotted/dotless I distinction that
  /// `String.toLowerCase()` mishandles under the default locale.
  static String? _normalizeName(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length == 1) return trimmed.toUpperCase();
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  /// Pulls the first usable sentence out of a free-text answer. Returns null
  /// for empty / one-word inputs so we never quote nonsense back. Splits on
  /// `.`/`!`/`?`/newline and falls back to a length cap so an unterminated
  /// rant still gets surfaced. Length window 4–140 chars keeps the quote
  /// readable inside the assessment paragraph.
  static String? _quoteFirstSentence(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.length < 4) return null;
    final match = RegExp(r'^([^.!?\n]{4,140})').firstMatch(trimmed);
    final first = match?.group(1)?.trim();
    if (first == null || first.isEmpty) return null;
    return first;
  }

  // ───────────────────────────── numbers ───────────────────────────────────

  static double _bmi(WizardState s) {
    final w = s.weightKg ?? 70;
    final h = (s.heightCm ?? 170) / 100.0;
    if (h <= 0) return 0;
    return w / (h * h);
  }

  /// Mifflin-St Jeor with the gender-neutral midpoint correction
  /// (`-78`) — we don't ask gender any more, so the midpoint is the
  /// fairest default. Multiplied by the activity factor.
  static int _maintenanceCalories(WizardState s) {
    final weight = s.weightKg ?? 70;
    final height = s.heightCm ?? 170;
    final age = s.age ?? 25;
    final bmr = (10.0 * weight) + (6.25 * height) - (5.0 * age) - 78.0;
    final mult = switch (s.activityLevel) {
      ActivityLevel.sedentary => 1.2,
      ActivityLevel.light => 1.375,
      ActivityLevel.active => 1.55,
      _ => 1.2,
    };
    return (bmr * mult).round();
  }

  // ───────────────────────────── derived labels ────────────────────────────

  static String _goalLabel(AppLocalizations l10n, String? token) {
    return switch (token) {
      'belly_burn' => l10n.goalBellyBurnLower,
      'muscle_gain' => l10n.goalMuscleGainLower,
      'fitness_look' => l10n.goalFitnessLookLower,
      'strength' => l10n.goalStrengthLower,
      _ => l10n.reportGoalLabelFallback,
    };
  }

  static String _difficultyLabel(AppLocalizations l10n, String? exp) {
    return switch (exp) {
      'none' => l10n.difficultyBeginner,
      'occasional' => l10n.difficultyIntermediateShort,
      'regular' => l10n.difficultyAdvanced,
      _ => l10n.difficultyBeginner,
    };
  }

  static int _weeklyWorkoutCount(WizardState s) =>
      weeklyWorkoutCountFor(s.experienceLevel);

  // Store-compliance note: never emit quantified outcome promises here
  // ("4-8 kg", "%20-30") — Apple 1.4.1 / Play health-misrepresentation
  // reject guaranteed numeric results. Qualitative, effort-conditional
  // framing only.
  static String _estimatedResults(AppLocalizations l10n, WizardState s) {
    return switch (s.goal) {
      'belly_burn' => l10n.reportResultBellyBurn,
      'muscle_gain' => l10n.reportResultMuscleGain,
      'fitness_look' => l10n.reportResultFitnessLook,
      'strength' => l10n.reportResultStrength,
      _ => l10n.reportResultDefault,
    };
  }
}
