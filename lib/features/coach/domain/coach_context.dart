/// Everything the coach knows about the user, gathered into one immutable
/// snapshot. This is the "memory" layer: the same object feeds the current
/// rule-based brain AND, later, an LLM (via [toPromptContext], which is
/// already the system-prompt the future coach will be given). Keeping all
/// knowledge in one plain model is what lets the brain behind the coach
/// change without touching the UI or the aggregation.
class CoachContext {
  const CoachContext({
    required this.hour,
    this.name,
    this.goalLabel,
    this.age,
    this.heightCm,
    this.weightKg,
    this.activityLabel,
    this.hasEquipment,
    this.streakDays = 0,
    this.level = 1,
    this.xp = 0,
    this.badgeCount = 0,
    this.completedDays = 0,
    this.totalDays = 30,
    this.todayDayNumber,
    this.todayExerciseCount = 0,
    this.todayIsCompleted = false,
    this.todayExerciseNames = const [],
    this.lastSessionLine,
    this.firstCameraSession = false,
    this.workoutMode = 'camera',
  });

  final int hour; // 0–23 local
  final String? name;
  final String? goalLabel; // human-readable Turkish goal
  final int? age;
  final int? heightCm;
  final int? weightKg;
  final String? activityLabel;
  final bool? hasEquipment;
  final int streakDays;
  final int level;
  final int xp;
  final int badgeCount;
  final int completedDays;
  final int totalDays;
  final int? todayDayNumber;
  final int todayExerciseCount;
  final bool todayIsCompleted;

  /// Names of today's exercises, so the coach can answer "bugün ne var?"
  /// with the real plan instead of a generic description.
  final List<String> todayExerciseNames;

  /// One-line digest of the most recent logged workout (day, reps, duration,
  /// exercises) built from the on-device session log — the camera/workout
  /// pipeline's ground truth. Lets the coach reference what the user actually
  /// did ("dün 84 tekrar yaptın") instead of guessing.
  final String? lastSessionLine;

  /// Roadmap Phase 3 · true once the user has been through the guided
  /// camera setup but has not yet logged a session.
  ///
  /// It buys the coach exactly one thing, and it's a big one: the ability
  /// to reference a moment the user just lived through ("kamerayı ayarladık,
  /// sıra ilk seansında") instead of greeting them as a stranger. Coaches
  /// who remember the last five minutes feel like coaches.
  final bool firstCameraSession;

  /// `camera` or `manual`. The coach must not promise form feedback to
  /// someone training without a camera — the fastest way to sound like
  /// software that isn't paying attention.
  final String workoutMode;

  String get firstName {
    final n = name?.trim();
    if (n == null || n.isEmpty) return '';
    return n.split(RegExp(r'\s+')).first;
  }

  double? get bmi {
    final h = heightCm;
    final w = weightKg;
    if (h == null || w == null || h <= 0) return null;
    final m = h / 100.0;
    return w / (m * m);
  }

  /// The system-prompt context the LLM coach is handed verbatim.
  ///
  /// PROMPT SCAFFOLDING, not UI copy — none of it is ever rendered, and
  /// the literals below are marked `// i18n-ignore` for that reason.
  ///
  /// It is nevertheless PER-LOCALE, and that was a bug for a while. The
  /// original note here said per-locale prompting was Phase 7's job.
  /// Phase 6 shipped English and made that wrong: an English user's coach
  /// was handed an English persona and then a Turkish profile block, and
  /// a model given two languages picks one per turn. That is exactly the
  /// "sometimes Turkish, sometimes English" the founder reported.
  ///
  /// Turkish keeps its original wording byte for byte — it is the shipped,
  /// working path and there is no reason to risk its quality. English is
  /// a parallel block, not a translation of a translation.
  String toPromptContext({String locale = 'tr'}) {
    return locale == 'en' ? _promptContextEn() : _promptContextTr();
  }

  String _promptContextTr() {
    final b = StringBuffer();
    b.writeln('Kullanıcı profili:'); // i18n-ignore
    if (firstName.isNotEmpty) b.writeln('- İsim: $firstName'); // i18n-ignore
    if (goalLabel != null) b.writeln('- Hedef: $goalLabel'); // i18n-ignore
    if (age != null) b.writeln('- Yaş: $age'); // i18n-ignore
    if (heightCm != null) b.writeln('- Boy: $heightCm cm');
    if (weightKg != null) b.writeln('- Kilo: $weightKg kg');
    final bmiV = bmi;
    if (bmiV != null) b.writeln('- BMI: ${bmiV.toStringAsFixed(1)}');
    if (activityLabel != null) b.writeln('- Aktivite: $activityLabel');
    if (hasEquipment != null) {
      b.writeln('- Ekipman: ${hasEquipment! ? 'var' : 'yok'}');
    }
    b.writeln('İlerleme:'); // i18n-ignore
    b.writeln('- Seri: $streakDays gün'); // i18n-ignore
    b.writeln('- Tamamlanan: $completedDays/$totalDays gün'); // i18n-ignore
    b.writeln('- Seviye: $level ($xp XP), Rozet: $badgeCount');
    if (todayDayNumber != null) {
      b.writeln('- Bugünkü gün: $todayDayNumber ' // i18n-ignore
          '(${todayIsCompleted ? 'tamamlandı' : '$todayExerciseCount egzersiz, ' // i18n-ignore
              'henüz yapılmadı'})'); // i18n-ignore
    }
    if (todayExerciseNames.isNotEmpty) {
      b.writeln(
          '- Bugünkü egzersizler: ${todayExerciseNames.join(', ')}'); // i18n-ignore
    }
    if (lastSessionLine != null) b.writeln('- $lastSessionLine');
    if (workoutMode == 'manual') {
      b.writeln(
          '- Antrenman modu: kamerasız (tekrarları kullanıcı sayıyor; ' // i18n-ignore
          'form analizi yapılmıyor)'); // i18n-ignore
    }
    if (firstCameraSession) {
      b.writeln(
          '- Kamera kurulumunu az önce tamamladı; henüz ilk seansını ' // i18n-ignore
          'yapmadı.'); // i18n-ignore
    }
    return b.toString().trim();
  }

  String _promptContextEn() {
    final b = StringBuffer();
    b.writeln('User profile:'); // i18n-ignore
    if (firstName.isNotEmpty) b.writeln('- Name: $firstName'); // i18n-ignore
    if (goalLabel != null) b.writeln('- Goal: $goalLabel'); // i18n-ignore
    if (age != null) b.writeln('- Age: $age'); // i18n-ignore
    if (heightCm != null) b.writeln('- Height: $heightCm cm');
    if (weightKg != null) b.writeln('- Weight: $weightKg kg');
    final bmiV = bmi;
    if (bmiV != null) b.writeln('- BMI: ${bmiV.toStringAsFixed(1)}');
    if (activityLabel != null) b.writeln('- Activity: $activityLabel');
    if (hasEquipment != null) {
      b.writeln('- Equipment: ${hasEquipment! ? 'yes' : 'no'}'); // i18n-ignore
    }
    b.writeln('Progress:'); // i18n-ignore
    b.writeln('- Streak: $streakDays days'); // i18n-ignore
    b.writeln('- Completed: $completedDays/$totalDays days'); // i18n-ignore
    b.writeln('- Level: $level ($xp XP), Badges: $badgeCount');
    if (todayDayNumber != null) {
      b.writeln('- Today is day $todayDayNumber ' // i18n-ignore
          '(${todayIsCompleted ? 'completed' : '$todayExerciseCount exercises, ' // i18n-ignore
              'not done yet'})'); // i18n-ignore
    }
    if (todayExerciseNames.isNotEmpty) {
      b.writeln(
          "- Today's exercises: ${todayExerciseNames.join(', ')}"); // i18n-ignore
    }
    if (lastSessionLine != null) b.writeln('- $lastSessionLine');
    if (workoutMode == 'manual') {
      b.writeln(
          '- Workout mode: camera-free (the user counts their own reps; ' // i18n-ignore
          'no form analysis)'); // i18n-ignore
    }
    if (firstCameraSession) {
      b.writeln(
          '- Just finished camera setup; has not done a first session ' // i18n-ignore
          'yet.'); // i18n-ignore
    }
    return b.toString().trim();
  }
}
