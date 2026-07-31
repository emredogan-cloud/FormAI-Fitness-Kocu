import '../../../core/services/progressive_disclosure.dart';
import '../../../l10n/app_localizations.dart';

/// Roadmap Phase 5 · the words for the disclosure layer.
///
/// [Capability] and [unlockHint] decide what is locked and what is
/// closest to opening; this file is the only place that says it out
/// loud. Keeping the split lets `progressive_disclosure.dart` keep the
/// promise in its own header — no providers, no clock, no BuildContext,
/// every function pure and exhaustively testable.
extension CapabilityCopy on Capability {
  String title(AppLocalizations l10n) => switch (this) {
        Capability.nutrition => l10n.capabilityNutritionTitle,
        Capability.progress => l10n.capabilityProgressTitle,
        Capability.badges => l10n.capabilityBadgesTitle,
        Capability.calendar => l10n.capabilityCalendarTitle,
        Capability.referral => l10n.capabilityReferralTitle,
        Capability.advancedSettings => l10n.capabilityAdvancedSettingsTitle,
      };

  String blurb(AppLocalizations l10n) => switch (this) {
        Capability.nutrition => l10n.capabilityNutritionBlurb,
        Capability.progress => l10n.capabilityProgressBlurb,
        Capability.badges => l10n.capabilityBadgesBlurb,
        Capability.calendar => l10n.capabilityCalendarBlurb,
        Capability.referral => l10n.capabilityReferralBlurb,
        Capability.advancedSettings => l10n.capabilityAdvancedSettingsBlurb,
      };
}

extension CapabilityPillarCopy on CapabilityPillar {
  String label(AppLocalizations l10n) => switch (this) {
        CapabilityPillar.training => l10n.pillarTraining,
        CapabilityPillar.nutrition => l10n.pillarNutrition,
        CapabilityPillar.progress => l10n.pillarProgress,
        CapabilityPillar.coach => l10n.pillarCoach,
        CapabilityPillar.community => l10n.pillarCommunity,
      };
}

extension UnlockHintCopy on UnlockHint {
  /// Renders the hint.
  ///
  /// The counts go through ICU plurals rather than interpolation
  /// because the one-case is not a smaller version of the other-case:
  /// a day away is "opens tomorrow", which names the day instead of
  /// counting it. Turkish has no plural agreement here and English
  /// does; only the ARB can hold both truths.
  String text(AppLocalizations l10n) => switch (this) {
        UnlockAfterSessions(:final sessions) =>
          l10n.unlockAfterSessions(sessions),
        UnlockAfterDays(:final days) => l10n.unlockAfterDays(days),
        UnlockSoon() => l10n.unlockSoon,
      };
}
