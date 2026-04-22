import 'daily_meal_slot.dart';
import 'recipe.dart';

/// Lifecycle of a meal inside the daily plan.
///
///   • `planned` — the notifier seeded this meal from the catalogue; the
///     user hasn't touched it yet.
///   • `completed` — the user tapped "Yedim". Counts toward
///     [consumedMacrosProvider].
///   • `skipped` — the user tapped "Atla". Doesn't count toward intake;
///     stays in the timeline so they can undo.
enum MealStatus { planned, completed, skipped }

/// A single entry in the daily meal plan. Wraps a [Recipe] with an
/// identity (`id`, unique per planned instance — not the recipe id), a
/// slot classification, and mutable [status].
///
/// Immutable value type; the notifier replaces entries via [copyWith]
/// when the user acts.
class PlannedMeal {
  const PlannedMeal({
    required this.id,
    required this.recipe,
    required this.slot,
    this.status = MealStatus.planned,
  });

  /// Unique identifier for this planned instance. Distinct from
  /// `recipe.id` because the same recipe can appear in multiple slots
  /// (e.g. two main meals in a 3-ögun plan) and each row needs a stable
  /// handle for the notifier methods.
  final String id;

  final Recipe recipe;
  final DailyMealSlot slot;
  final MealStatus status;

  PlannedMeal copyWith({
    String? id,
    Recipe? recipe,
    DailyMealSlot? slot,
    MealStatus? status,
  }) {
    return PlannedMeal(
      id: id ?? this.id,
      recipe: recipe ?? this.recipe,
      slot: slot ?? this.slot,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PlannedMeal &&
      other.id == id &&
      other.recipe == recipe &&
      other.slot == slot &&
      other.status == status;

  @override
  int get hashCode => Object.hash(id, recipe, slot, status);
}
