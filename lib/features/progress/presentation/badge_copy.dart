import '../../../l10n/app_localizations.dart';
import '../providers/badge_unlocks_provider.dart';

/// Roadmap Phase 5 · the words for a badge.
///
/// [BadgeDefinition] keeps only what is data — the stable `id` that is
/// persisted and that the XP calculator keys off, and the emoji. The
/// label and the celebration line moved here.
///
/// Why this switches on a String instead of an enum, unlike
/// [CoachLine]: badge IDs are written to storage and read back by
/// `unlockedBadgesProvider`, `xpForBadge` and the gallery. Turning them
/// into an enum to buy compile-time exhaustiveness would put a
/// persistence migration inside a copy extraction, which is a bad trade.
/// The guarantee is bought in `badge_copy_test.dart` instead: it walks
/// [kBadgeCatalog] in every supported locale and fails on any badge
/// whose copy is missing — so a new badge still cannot ship wordless.
extension BadgeCopy on BadgeDefinition {
  /// The badge name, shared with the gallery.
  String title(AppLocalizations l10n) => switch (id) {
        'first_step' => l10n.badgeFirstStepTitle,
        'disciplined' => l10n.badgeDisciplinedTitle,
        'first_week' => l10n.badgeFirstWeekTitle,
        'steady' => l10n.badgeSteadyTitle,
        'halfway' => l10n.badgeHalfwayTitle,
        'voice_heard' => l10n.badgeVoiceHeardTitle,
        'calorie_hunter' => l10n.badgeCalorieHunterTitle,
        'hiit_master' => l10n.badgeHiitMasterTitle,
        'core_master' => l10n.badgeCoreMasterTitle,
        'strength_stone' => l10n.badgePowerStoneTitle,
        'nutrition_hero' => l10n.badgeNutritionHeroTitle,
        'thirty_day_champion' => l10n.badgeThirtyDayChampTitle,
        'form_legend' => l10n.badgeFormLegendTitle,
        // Unreachable for any catalogue entry — see the class comment.
        // Falls back to the ID rather than throwing: a mislabelled badge
        // is a blemish, a crash in the celebration dialog is a bug
        // report about the moment the user just succeeded.
        _ => id,
      };

  /// The celebration line, shown the moment the badge unlocks.
  ///
  /// Past tense, unlike the gallery's description, which states the goal
  /// in the imperative. Both exist on purpose: "finish your first day"
  /// before, "you finished your first day!" after.
  String unlockMessage(AppLocalizations l10n) => switch (id) {
        'first_step' => l10n.badgeFirstStepUnlocked,
        'disciplined' => l10n.badgeDisciplinedUnlocked,
        'first_week' => l10n.badgeFirstWeekUnlocked,
        'steady' => l10n.badgeSteadyUnlocked,
        'halfway' => l10n.badgeHalfwayUnlocked,
        'voice_heard' => l10n.badgeVoiceHeardUnlocked,
        'calorie_hunter' => l10n.badgeCalorieHunterUnlocked,
        'hiit_master' => l10n.badgeHiitMasterUnlocked,
        'core_master' => l10n.badgeCoreMasterUnlocked,
        'strength_stone' => l10n.badgePowerStoneUnlocked,
        'nutrition_hero' => l10n.badgeNutritionHeroUnlocked,
        'thirty_day_champion' => l10n.badgeThirtyDayChampUnlocked,
        'form_legend' => l10n.badgeFormLegendUnlocked,
        _ => id,
      };
}
