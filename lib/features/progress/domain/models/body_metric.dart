/// Roadmap Phase 9 (C1) · one day's body measurements.
///
/// Everything here is stored metric — kilograms and centimetres — and
/// converted only at the render boundary by `core/utils/unit_system.dart`.
/// That file explains why at length; the short version is that a column
/// whose unit depends on a preference read at some other time produces a
/// BMI that is silently wrong for anyone who ever toggled the switch.
///
/// A metric entry is keyed by the DAY it describes, not the moment it
/// was typed. Weighing yourself twice on Tuesday is one observation
/// measured twice, not two data points — the scale moves more between
/// breakfast and dinner than a good week of real change does. Re-logging
/// a day replaces it.
library;

/// The measurable dimensions, and what each is called on the wire.
///
/// An enum rather than six fields threaded through every signature: the
/// entry sheet, the chart, the trend maths and the coach summary all
/// need to iterate "whatever the user tracks", and six parallel
/// `if (waist != null)` branches is where a seventh measurement would
/// get forgotten in four places.
enum BodyMeasure {
  weight('weight_kg'),
  waist('waist_cm'),
  chest('chest_cm'),
  arm('arm_cm'),
  thigh('thigh_cm'),
  hip('hip_cm');

  const BodyMeasure(this.column);

  /// Supabase column name, and the JSON key on device. Never derive it
  /// from [name] — a rename would orphan every entry already on disk.
  final String column;

  /// True for the one measure carried in kilograms. Everything else is
  /// a circumference in centimetres.
  bool get isWeight => this == BodyMeasure.weight;

  static BodyMeasure? fromColumn(String? column) {
    for (final measure in BodyMeasure.values) {
      if (measure.column == column) return measure;
    }
    return null;
  }
}

/// The bounds the entry sheet validates against and the migration's
/// check constraints repeat. Kept in one place so the client cannot
/// accept a value the server will reject.
///
/// The upper bounds are deliberately generous. They exist to catch a
/// slipped decimal point or a millimetre value typed into a centimetre
/// field — not to tell anybody what size they are allowed to be.
({double min, double max}) measureRangeMetric(BodyMeasure measure) =>
    switch (measure) {
      BodyMeasure.weight => (min: 30, max: 250),
      BodyMeasure.waist => (min: 30, max: 250),
      BodyMeasure.chest => (min: 30, max: 250),
      BodyMeasure.arm => (min: 10, max: 100),
      BodyMeasure.thigh => (min: 20, max: 150),
      BodyMeasure.hip => (min: 30, max: 250),
    };

/// Longest note the server will accept, mirrored from the migration.
const int kBodyMetricNoteMaxLength = 280;

class BodyMetric {
  const BodyMetric({
    required this.recordedOn,
    this.weightKg,
    this.waistCm,
    this.chestCm,
    this.armCm,
    this.thighCm,
    this.hipCm,
    this.note,
  });

  /// The day this describes, normalised to midnight local. Use
  /// [dayOf] to build one — a `DateTime` carrying a time component
  /// compares unequal to the same calendar day and would let two
  /// entries for one day coexist.
  final DateTime recordedOn;

  final double? weightKg;
  final double? waistCm;
  final double? chestCm;
  final double? armCm;
  final double? thighCm;
  final double? hipCm;

  /// Free text the user attached — "after a long flight", "morning,
  /// fasted". It exists so a value that looks like a jump has somewhere
  /// to carry its own explanation instead of reading as a failure.
  final String? note;

  /// Strips the time component so two entries on the same calendar day
  /// are the same key. Local time deliberately: a user in Istanbul
  /// logging at 01:00 means that date on their wall, not the UTC one.
  static DateTime dayOf(DateTime when) =>
      DateTime(when.year, when.month, when.day);

  double? valueOf(BodyMeasure measure) => switch (measure) {
        BodyMeasure.weight => weightKg,
        BodyMeasure.waist => waistCm,
        BodyMeasure.chest => chestCm,
        BodyMeasure.arm => armCm,
        BodyMeasure.thigh => thighCm,
        BodyMeasure.hip => hipCm,
      };

  /// Every measure this entry actually carries, in enum order.
  List<BodyMeasure> get presentMeasures =>
      BodyMeasure.values.where((m) => valueOf(m) != null).toList();

  /// An entry with no measurement is a date, not an observation. The
  /// repository refuses to save one and the migration's check
  /// constraint refuses to store one, so no reader ever has to decide
  /// what an empty entry means on a chart.
  bool get isEmpty => presentMeasures.isEmpty;

  BodyMetric copyWith({
    DateTime? recordedOn,
    double? weightKg,
    double? waistCm,
    double? chestCm,
    double? armCm,
    double? thighCm,
    double? hipCm,
    String? note,
  }) =>
      BodyMetric(
        recordedOn: recordedOn ?? this.recordedOn,
        weightKg: weightKg ?? this.weightKg,
        waistCm: waistCm ?? this.waistCm,
        chestCm: chestCm ?? this.chestCm,
        armCm: armCm ?? this.armCm,
        thighCm: thighCm ?? this.thighCm,
        hipCm: hipCm ?? this.hipCm,
        note: note ?? this.note,
      );

  /// `yyyy-MM-dd`, which is both the JSON key on device and the `date`
  /// literal Postgres accepts. Hand-formatted rather than via `intl`
  /// because this is a wire format, not copy — a locale-aware formatter
  /// here would write Arabic-Indic digits under an `ar` locale and
  /// silently corrupt every row.
  String get recordedOnIso {
    final m = recordedOn.month.toString().padLeft(2, '0');
    final d = recordedOn.day.toString().padLeft(2, '0');
    return '${recordedOn.year}-$m-$d';
  }

  Map<String, dynamic> toJson() => {
        'recorded_on': recordedOnIso,
        for (final measure in BodyMeasure.values)
          if (valueOf(measure) != null) measure.column: valueOf(measure),
        if (note != null && note!.isNotEmpty) 'note': note,
      };

  /// Tolerant by design: a missing measurement is null, not an error,
  /// so adding a seventh measure later cannot break v1 readers. A row
  /// with no parseable date throws [FormatException] and the repository
  /// drops just that entry.
  factory BodyMetric.fromJson(Map<String, dynamic> json) {
    final rawDate = json['recorded_on'];
    final parsed = rawDate is String ? DateTime.tryParse(rawDate) : null;
    if (parsed == null) {
      throw const FormatException(
        'BodyMetric.recorded_on missing or unparseable', // i18n-ignore — parse diagnostic
      );
    }
    double? read(BodyMeasure measure) {
      final value = json[measure.column];
      if (value is num) return value.toDouble();
      // Supabase returns `numeric` as a string over PostgREST.
      if (value is String) return double.tryParse(value);
      return null;
    }

    final note = json['note'];
    return BodyMetric(
      recordedOn: dayOf(parsed),
      weightKg: read(BodyMeasure.weight),
      waistCm: read(BodyMeasure.waist),
      chestCm: read(BodyMeasure.chest),
      armCm: read(BodyMeasure.arm),
      thighCm: read(BodyMeasure.thigh),
      hipCm: read(BodyMeasure.hip),
      note: note is String && note.isNotEmpty ? note : null,
    );
  }
}
