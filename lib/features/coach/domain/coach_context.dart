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
    this.weightChange30dKg,
    this.waistChange30dCm,
    this.isPlateau = false,
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

  /// Roadmap Phase 9 (C1) · signed change in the user's logged weight
  /// over the last 30 days, in kilograms. Null when they have not logged
  /// enough for the trend maths to say anything.
  ///
  /// This is what turns "keep going!" into "your weight is down 2.4 kg
  /// and your waist has not moved" — the difference between
  /// encouragement and coaching. It is passed as a NUMBER rather than a
  /// pre-built sentence so each locale's prompt block writes its own; a
  /// Turkish string threaded into an English block is the exact bug
  /// Phase 6 fixed here.
  ///
  /// The persona's existing GERÇEKLİK constraint does the rest: it may
  /// only speak about data it was handed, so null means the coach says
  /// nothing about the body rather than guessing at it.
  final double? weightChange30dKg;

  /// Signed change in waist circumference over the same window, in
  /// centimetres. The measure that most often tells the true story when
  /// the scale is flat, which is precisely the conversation a plateau
  /// needs the coach to be able to have.
  final double? waistChange30dCm;

  /// True when the weight series has been genuinely still for three
  /// weeks or more. Surfaced separately from [bodyTrendLine] because a
  /// plateau is the one body-metric state that should change what the
  /// coach *does* — the roadmap asks for a proactive, actionable message
  /// here, not another observation.
  final bool isPlateau;

  String get firstName {
    final n = name?.trim();
    if (n == null || n.isEmpty) return '';
    return n.split(RegExp(r'\s+')).first;
  }

  /// A signed magnitude for the prompt, to one decimal: `-2.4`, `+0.8`,
  /// `0.0`. The sign is explicit because a bare `2.4` in a prompt line
  /// called "change" is genuinely ambiguous, and a model that guesses
  /// wrong congratulates somebody for gaining the weight they are
  /// trying to lose.
  ///
  /// A period decimal separator regardless of locale: this is prompt
  /// scaffolding read by a model, not copy read by a person.
  static String _signed(double value) {
    final rounded = double.parse(value.toStringAsFixed(1));
    return rounded > 0
        ? '+${rounded.toStringAsFixed(1)}'
        : rounded.toStringAsFixed(1);
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
    final weightDelta = weightChange30dKg;
    if (weightDelta != null) {
      b.writeln('- Son 30 günde kilo değişimi: ' // i18n-ignore
          '${_signed(weightDelta)} kg');
    }
    final waistDelta = waistChange30dCm;
    if (waistDelta != null) {
      b.writeln('- Son 30 günde bel değişimi: ' // i18n-ignore
          '${_signed(waistDelta)} cm');
    }
    if (isPlateau) {
      b.writeln(
          '- Kilo üç haftadır sabit. Bu bir başarısızlık değil; ' // i18n-ignore
          'tek bir şeyi (antrenman, porsiyon veya uyku) değiştirmek ' // i18n-ignore
          'için doğru an. Somut ve tek bir öneri ver.'); // i18n-ignore
    }
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
    final weightDelta = weightChange30dKg;
    if (weightDelta != null) {
      b.writeln('- Weight change over the last 30 days: ' // i18n-ignore
          '${_signed(weightDelta)} kg');
    }
    final waistDelta = waistChange30dCm;
    if (waistDelta != null) {
      b.writeln('- Waist change over the last 30 days: ' // i18n-ignore
          '${_signed(waistDelta)} cm');
    }
    if (isPlateau) {
      b.writeln(
          '- Weight has been flat for three weeks. This is not a ' // i18n-ignore
          'failure; it is the normal moment to change ONE thing ' // i18n-ignore
          '(training, portions or sleep). Give one concrete ' // i18n-ignore
          'suggestion.'); // i18n-ignore
    }
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
