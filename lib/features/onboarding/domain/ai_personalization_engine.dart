import '../providers/wizard_provider.dart';

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

  static AiReport generateReport(WizardState state) {
    return AiReport(
      assessment: _assessment(state),
      bmi: _bmi(state),
      maintenanceCalories: _maintenanceCalories(state),
      goalLabel: _goalLabel(state.goal),
      difficultyLabel: _difficultyLabel(state.experienceLevel),
      weeklyWorkoutCount: _weeklyWorkoutCount(state),
      durationLabel: '12 Hafta',
      estimatedResults: _estimatedResults(state),
    );
  }

  // ───────────────────────────── assessment ────────────────────────────────

  static String _assessment(WizardState s) {
    // Greet by name when we have one. The name capture step asks Form
    // "Bu yolculukta sana nasıl sesleneyim?" between coach intro and
    // gender; landing here without a name means the user skipped that
    // step somehow (e.g. legacy save), so we fall back to the un-named
    // greeting instead of a brittle empty-vocative.
    final greeting = _normalizeName(s.name) != null
        ? '${_normalizeName(s.name)}, profilini analiz ettim ve sana '
            'özel bir yol haritası çıkardım.'
        : 'Profilini analiz ettim ve sana özel bir yol haritası çıkardım.';
    final parts = <String>[greeting];

    // Quote-back. Pain-point > experience > activity (pain-point is the most
    // emotionally loaded answer). Without this, the user types 60 seconds of
    // free text and never sees it reflected — the "AI is really listening"
    // contract breaks.
    final quoted = _quoteFirstSentence(s.painPointDescription) ??
        _quoteFirstSentence(s.experienceDescription) ??
        _quoteFirstSentence(s.activityDescription);
    if (quoted != null) {
      parts.add(
        'Yazdıklarına dikkat ettim — özellikle "$quoted" kısmı planını '
        'şekillendirdi.',
      );
    }

    final isFatLossSedentary =
        s.goal == 'belly_burn' && s.activityLevel == ActivityLevel.sedentary;

    // Combination rule 1: fat-loss + sedentary lifestyle.
    if (isFatLossSedentary) {
      parts.add(
        'Aktivite seviyen düşük olduğu için yağlanma riskin var; '
        'planın düşük-eşikli kardiyo + kalori-açıklı beslenmeyle bu '
        'riski hızla tersine çevirecek.',
      );
    } else if (s.activityLevel == ActivityLevel.sedentary) {
      parts.add(
        'Aktivite seviyen düşük; ilk haftayı hareket alışkanlığını '
        'oturtmaya ayıracağım.',
      );
    } else if (s.activityLevel == ActivityLevel.active) {
      parts.add(
        'Aktivite seviyen yüksek — temeli zaten attığın için ilerlemen '
        'ortalamadan daha hızlı olacak.',
      );
    }

    // Goal-specific copy. Skipped when the combo line above already
    // covered fat-loss-for-sedentary so we don't double-explain it.
    if (!isFatLossSedentary) {
      switch (s.goal) {
        case 'belly_burn':
          parts.add(
            'Kilo verme hedefin için kalori açığı yaratıp göbek '
            'bölgesine odaklı core çalışmaları ekleyeceğim.',
          );
        case 'muscle_gain':
          parts.add(
            'Kas yapma hedefin için yüksek-protein beslenme ve '
            'progresif yüklenme ile programını şekillendiriyorum.',
          );
        case 'fitness_look':
          parts.add(
            'Daha fit görünmek için kardiyo + full-body antrenmanını '
            'dengeleyeceğim.',
          );
        case 'strength':
          parts.add(
            'Güçlenme hedefin için bileşik hareketlere ağırlık veren '
            'bir program tasarladım.',
          );
      }
    }

    // Combination rule 2: beginner → newbie-gain story.
    if (s.experienceLevel == 'none') {
      parts.add(
        'Spora yeni başladığın için ilk 30 günde "newbie gain" '
        'etkisiyle çok hızlı ve gözle görülür sonuçlar alacaksın.',
      );
    } else if (s.experienceLevel == 'regular') {
      parts.add(
        'Düzenli antrenman geçmişin programının yoğunluğunu yukarı '
        'çekmeme imkân tanıyor.',
      );
    }

    // Combination rule 3: motivation / consistency → accountability.
    final pain = s.painPoint;
    if (pain == 'motivation' || pain == 'consistency') {
      parts.add(
        'Senin için kritik nokta süreklilik — AI koçun günlük '
        'hesap-veren-arkadaş gibi davranıp seni omurgada tutacak.',
      );
    } else if (pain == 'no_idea') {
      parts.add(
        'Ne yapacağını bilmemek artık dert değil; adım adım yönlendiren '
        'rehber moduyla başlayacağız.',
      );
    } else if (pain == 'diet') {
      parts.add(
        'Diyet konusunda da yanındayım; tercihlerine uygun esnek yemek '
        'listeleri oluşturacağım.',
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

  static String _goalLabel(String? token) {
    return switch (token) {
      'belly_burn' => 'Göbek eritmek',
      'muscle_gain' => 'Kas yapmak',
      'fitness_look' => 'Daha fit görünmek',
      'strength' => 'Güçlenmek',
      _ => 'Form kazanmak',
    };
  }

  static String _difficultyLabel(String? exp) {
    return switch (exp) {
      'none' => 'Başlangıç',
      'occasional' => 'Orta',
      'regular' => 'İleri',
      _ => 'Başlangıç',
    };
  }

  static int _weeklyWorkoutCount(WizardState s) {
    // 4 days/week is the PM-spec'd starter cadence; nudge to 5 for
    // self-reported regulars who can absorb the extra session.
    return s.experienceLevel == 'regular' ? 5 : 4;
  }

  // Store-compliance note: never emit quantified outcome promises here
  // ("4-8 kg", "%20-30") — Apple 1.4.1 / Play health-misrepresentation
  // reject guaranteed numeric results. Qualitative, effort-conditional
  // framing only.
  static String _estimatedResults(WizardState s) {
    return switch (s.goal) {
      'belly_burn' => '12 haftalık yağ yakımı odaklı program',
      'muscle_gain' => '12 haftalık kas gelişimi odaklı program',
      'fitness_look' => '12 haftalık form ve estetik odaklı program',
      'strength' => '12 haftalık güç gelişimi odaklı program',
      _ => '12 haftalık form dönüşümü odaklı program',
    };
  }
}
