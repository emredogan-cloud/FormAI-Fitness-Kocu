/// Identifies a slot in the day's meal plan. Distinct from
/// [Recipe.mealType] because:
///   • `lunch` and `dinner` both filter from the catalogue's `main`
///     bucket — the enum values only differ for the UI label.
///   • The set is closed and knowable at compile time, which lets the
///     UI switch on it exhaustively without a default arm.
///
/// Extracted to its own file so both [PlannedMeal] and the daily-menu
/// notifier can depend on it without the provider layer leaking into
/// the model layer.
enum DailyMealSlot { breakfast, lunch, dinner, snack }

/// Parses a slot token coming from the public notifier API
/// (`addRecipeToPlan(recipe, slot)` takes a `String` per the phase 23.1
/// spec). Unknown values fall back to [DailyMealSlot.snack] so an
/// unexpected call can't crash the app — it just shows up in the
/// Ara Öğün bucket until the caller is fixed.
// The `case` values below are DATA, not copy: they are the strings the
// API and the plan rows actually carry (`addRecipeToPlan(recipe, slot)`
// takes a raw String). Localising them would stop the parse matching.
// Content localisation is Phase 7, via the migration-011 columns.
DailyMealSlot parseDailyMealSlot(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'breakfast':
    case 'kahvalti':
    case 'kahvaltı': // i18n-ignore
      return DailyMealSlot.breakfast;
    case 'lunch':
    case 'ogle':
    case 'öğle': // i18n-ignore
    case 'öğle yemeği': // i18n-ignore
      return DailyMealSlot.lunch;
    case 'dinner':
    case 'aksam':
    case 'akşam': // i18n-ignore
    case 'akşam yemeği': // i18n-ignore
    case 'main':
      return DailyMealSlot.dinner;
    case 'snack':
    case 'atistirmalik':
    case 'atıştırmalık': // i18n-ignore
    case 'ara':
    case 'ara öğün': // i18n-ignore
      return DailyMealSlot.snack;
    default:
      return DailyMealSlot.snack;
  }
}
