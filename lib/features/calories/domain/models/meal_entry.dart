/// Domain models for the AI calorie tracker.
///
/// The enum wire values are the CHECK-constraint values in migration
/// 028, not display strings — `MealSlot.breakfast.wire` is `'breakfast'`
/// in every locale. Translating them would make the database reject the
/// row, which is the whole reason they are separated from the labels the
/// UI shows.
library;

/// Which part of the day a meal belongs to.
enum MealSlot {
  breakfast('breakfast'),
  lunch('lunch'),
  dinner('dinner'),
  snack('snack');

  const MealSlot(this.wire);

  final String wire;

  static MealSlot fromWire(String? raw) => MealSlot.values.firstWhere(
        (s) => s.wire == raw,
        orElse: () => MealSlot.snack,
      );
}

/// How the numbers in a meal were arrived at.
///
/// Kept on the row rather than inferred, because an AI estimate and a
/// barcode read carry very different trust and the UI has to be able to
/// say which one it is showing months later.
enum MealSource {
  aiScan('ai_scan'),
  barcode('barcode'),
  manual('manual');

  const MealSource(this.wire);

  final String wire;

  static MealSource fromWire(String? raw) => MealSource.values.firstWhere(
        (s) => s.wire == raw,
        orElse: () => MealSource.manual,
      );
}

/// How sure the estimate for a single item is.
///
/// Per item, never per meal. `docs/CALORIE_TRACKING_RESEARCH.md` §6: a
/// plate is not uniformly knowable — the model can be certain about the
/// tomato and guessing at the sauce, and flattening that to one
/// meal-level number would throw away the only honest thing we know.
enum ItemConfidence {
  high('high'),
  medium('medium'),
  low('low');

  const ItemConfidence(this.wire);

  final String wire;

  static ItemConfidence fromWire(String? raw) =>
      ItemConfidence.values.firstWhere(
        (c) => c.wire == raw,
        // An unknown value degrades to `low`, never to `high`. A value we
        // don't recognise is the definition of something we are not sure
        // about, and defaulting upward would launder it into a claim.
        orElse: () => ItemConfidence.low,
      );
}

/// One food inside a meal.
class MealItem {
  const MealItem({
    required this.name,
    required this.portionLabel,
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.confidence = ItemConfidence.medium,
    this.wasEdited = false,
    this.barcode,
    this.id,
  });

  factory MealItem.fromJson(Map<String, dynamic> json) => MealItem(
        id: json['id'] as String?,
        name: (json['name'] as String?) ?? '',
        portionLabel: (json['portion_label'] as String?) ?? '',
        kcal: _asInt(json['kcal']),
        proteinG: _asInt(json['protein_g']),
        carbsG: _asInt(json['carbs_g']),
        fatG: _asInt(json['fat_g']),
        confidence: ItemConfidence.fromWire(json['confidence'] as String?),
        wasEdited: (json['was_edited'] as bool?) ?? false,
        barcode: json['barcode'] as String?,
      );

  final String? id;
  final String name;

  /// A household measure in the user's language — "1 kase", "200 ml".
  ///
  /// Deliberately free text rather than a number and a unit enum. The
  /// model estimates the way people describe food, and forcing that into
  /// grams at capture time would invent a precision nobody measured.
  final String portionLabel;

  final int kcal;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final ItemConfidence confidence;

  /// True once the user has corrected this row.
  final bool wasEdited;

  /// Set when the row came from a barcode rather than the vision model.
  final String? barcode;

  MealItem copyWith({
    String? name,
    String? portionLabel,
    int? kcal,
    int? proteinG,
    int? carbsG,
    int? fatG,
    ItemConfidence? confidence,
    bool? wasEdited,
  }) =>
      MealItem(
        id: id,
        name: name ?? this.name,
        portionLabel: portionLabel ?? this.portionLabel,
        kcal: kcal ?? this.kcal,
        proteinG: proteinG ?? this.proteinG,
        carbsG: carbsG ?? this.carbsG,
        fatG: fatG ?? this.fatG,
        confidence: confidence ?? this.confidence,
        wasEdited: wasEdited ?? this.wasEdited,
        barcode: barcode,
      );

  /// The insert payload. `user_id` is omitted on purpose — migration
  /// 028's trigger derives it from the parent meal, and a client-supplied
  /// value is overwritten anyway.
  Map<String, dynamic> toInsertJson(String mealId, int sortOrder) => {
        'meal_id': mealId,
        'name': name,
        'portion_label': portionLabel,
        'kcal': kcal,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
        'confidence': confidence.wire,
        'was_edited': wasEdited,
        if (barcode != null) 'barcode': barcode,
        'sort_order': sortOrder,
      };
}

/// One logged meal, with its items.
class MealEntry {
  const MealEntry({
    required this.id,
    required this.loggedFor,
    required this.slot,
    required this.source,
    required this.items,
    this.kcal = 0,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.note,
    this.createdAt,
  });

  factory MealEntry.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['meal_items'] as List<dynamic>?) ?? const [];
    return MealEntry(
      id: json['id'] as String,
      loggedFor: DateTime.parse(json['logged_for'] as String),
      slot: MealSlot.fromWire(json['meal_slot'] as String?),
      source: MealSource.fromWire(json['source'] as String?),
      kcal: _asInt(json['kcal']),
      proteinG: _asInt(json['protein_g']),
      carbsG: _asInt(json['carbs_g']),
      fatG: _asInt(json['fat_g']),
      note: json['note'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'] as String),
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(MealItem.fromJson)
          .toList(growable: false),
    );
  }

  final String id;
  final DateTime loggedFor;
  final MealSlot slot;
  final MealSource source;

  /// Totals as the database computed them from the items, not as the
  /// client added them up. Migration 028 maintains these with a trigger,
  /// so a client that got its arithmetic wrong still shows the right
  /// number after a refresh.
  final int kcal;
  final int proteinG;
  final int carbsG;
  final int fatG;

  final String? note;
  final DateTime? createdAt;
  final List<MealItem> items;

  /// True when any item is a low-confidence estimate.
  ///
  /// Drives the meal-level qualifier in the UI. One uncertain item makes
  /// the meal's total uncertain — the totals cannot be more precise than
  /// their least precise component.
  bool get hasLowConfidenceItem =>
      items.any((i) => i.confidence == ItemConfidence.low);
}

/// The day's running totals against the user's targets.
class DailyTotals {
  const DailyTotals({
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.meals,
  });

  factory DailyTotals.from(List<MealEntry> meals) {
    var kcal = 0, p = 0, c = 0, f = 0;
    for (final m in meals) {
      kcal += m.kcal;
      p += m.proteinG;
      c += m.carbsG;
      f += m.fatG;
    }
    return DailyTotals(
      kcal: kcal,
      proteinG: p,
      carbsG: c,
      fatG: f,
      meals: meals,
    );
  }

  final int kcal;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final List<MealEntry> meals;

  static const empty = DailyTotals(
    kcal: 0,
    proteinG: 0,
    carbsG: 0,
    fatG: 0,
    meals: [],
  );

  List<MealEntry> forSlot(MealSlot slot) =>
      meals.where((m) => m.slot == slot).toList(growable: false);

  int kcalForSlot(MealSlot slot) =>
      forSlot(slot).fold(0, (sum, m) => sum + m.kcal);
}

/// Postgres returns numeric columns as `num`, `String`, or `int`
/// depending on the column type and the driver. Everything the UI shows
/// is a whole number, so normalise once here rather than at each call.
int _asInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.round();
  if (raw is String) return (num.tryParse(raw) ?? 0).round();
  return 0;
}
