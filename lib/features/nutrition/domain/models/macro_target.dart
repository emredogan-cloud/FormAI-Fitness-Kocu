/// Daily caloric + macronutrient target produced by
/// [NutritionCalculatorService.calculateDailyMacros]. Values are whole
/// numbers because the UI displays them as rounded grams / kcal; the
/// calculator does its math in doubles and rounds at the final step.
class MacroTarget {
  const MacroTarget({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  /// Total kilocalories per day.
  final int calories;

  /// Macronutrients in grams per day.
  final int protein;
  final int carbs;
  final int fat;

  @override
  bool operator ==(Object other) =>
      other is MacroTarget &&
      other.calories == calories &&
      other.protein == protein &&
      other.carbs == carbs &&
      other.fat == fat;

  @override
  int get hashCode => Object.hash(calories, protein, carbs, fat);

  @override
  String toString() => 'MacroTarget(calories: $calories, protein: ${protein}g, '
      'carbs: ${carbs}g, fat: ${fat}g)';
}
