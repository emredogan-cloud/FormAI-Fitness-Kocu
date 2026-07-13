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

  /// The system-prompt context a future LLM coach is handed verbatim. It is
  /// deliberately plain Turkish prose so the same string is human-auditable
  /// and model-ready. Building it now (even though the rule-based brain
  /// doesn't need it) keeps the LLM swap a one-line change.
  String toPromptContext() {
    final b = StringBuffer();
    b.writeln('Kullanıcı profili:');
    if (firstName.isNotEmpty) b.writeln('- İsim: $firstName');
    if (goalLabel != null) b.writeln('- Hedef: $goalLabel');
    if (age != null) b.writeln('- Yaş: $age');
    if (heightCm != null) b.writeln('- Boy: $heightCm cm');
    if (weightKg != null) b.writeln('- Kilo: $weightKg kg');
    final bmiV = bmi;
    if (bmiV != null) b.writeln('- BMI: ${bmiV.toStringAsFixed(1)}');
    if (activityLabel != null) b.writeln('- Aktivite: $activityLabel');
    if (hasEquipment != null) {
      b.writeln('- Ekipman: ${hasEquipment! ? 'var' : 'yok'}');
    }
    b.writeln('İlerleme:');
    b.writeln('- Seri: $streakDays gün');
    b.writeln('- Tamamlanan: $completedDays/$totalDays gün');
    b.writeln('- Seviye: $level ($xp XP), Rozet: $badgeCount');
    if (todayDayNumber != null) {
      b.writeln('- Bugünkü gün: $todayDayNumber '
          '(${todayIsCompleted ? 'tamamlandı' : '$todayExerciseCount egzersiz, '
              'henüz yapılmadı'})');
    }
    return b.toString().trim();
  }
}
