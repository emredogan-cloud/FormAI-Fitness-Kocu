/// Phase 134 · taxonomy of premium-gated surfaces.
///
/// Every premium lock-tap in the app routes through
/// [PremiumGateService.handleLockedTap], which consumes a
/// [LockedFeatureType] to pick the right contextual cinematic AI scene
/// (Phase 135) and emit a typed PostHog `source` for funnel analysis.
///
/// New values must update three sites in lockstep:
///   1. The scene table in `ConversionMomentService` (Phase 135).
///   2. The PostHog dashboard funnels keyed by [analyticsSource].
///   3. Wherever this enum's exhaustive `switch` is consumed (Dart will
///      surface the missing branch at compile time).
enum LockedFeatureType {
  /// 30-day personal plan tile beyond [AppConstants.freeDayLimit].
  futureDay,

  /// Equipment-section exercise flagged `isPremium=true`. Lives inside
  /// an otherwise free plan — the "depth waiting for me" beat.
  equipmentExercise,

  /// Whole nutrition tab. Tap on the bottom-nav entry for non-pro users
  /// triggers a cinematic scene instead of opening the section.
  nutritionTab,
}

extension LockedFeatureTypeX on LockedFeatureType {
  /// Stable English token shipped to PostHog as the `source` property
  /// on `paywall_viewed` / `conversion_moment_shown`. Snake_case to
  /// match the project's existing event taxonomy.
  String get analyticsSource {
    switch (this) {
      case LockedFeatureType.futureDay:
        return 'locked_future_day';
      case LockedFeatureType.equipmentExercise:
        return 'locked_equipment_exercise';
      case LockedFeatureType.nutritionTab:
        return 'locked_nutrition_tab';
    }
  }
}
