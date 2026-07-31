/// Roadmap Phase 1 (C30) · in-app help centre content.
///
/// Deflects the questions that otherwise arrive as feedback tickets or,
/// worse, as 1-star reviews that describe a misunderstanding rather
/// than a defect. Camera setup and subscription management are the two
/// highest-volume categories for a product shaped like FormAI, so they
/// lead.
///
/// Kept as data (not widgets) so the whole set is one ARB extraction
/// away from being localisable, and so the search index in
/// [HelpCenterScreen] can be built generically.
///
/// Roadmap Phase 5 · that extraction happened, and it turned the
/// catalogue from a `const` list into a function of [AppLocalizations].
/// It could not stay `const`: [FaqEntry.searchIndex] lower-cases the
/// question and answer TOGETHER, so entries need resolved text rather
/// than lookups. Rebuilding the list per call is cheap — 17 entries, no
/// I/O — and it only happens while the help centre is open.
library;

import '../../../l10n/app_localizations.dart';

class FaqCategory {
  const FaqCategory({required this.title, required this.entries});

  final String title;
  final List<FaqEntry> entries;
}

class FaqEntry {
  const FaqEntry({required this.question, required this.answer});

  final String question;
  final String answer;

  /// Lower-cased haystack used by the help-centre search field.
  String get searchIndex => '$question $answer'.toLowerCase();
}

/// The full catalogue, in the caller's locale.
List<FaqCategory> faqCategories(AppLocalizations l10n) => [
      FaqCategory(
        title: l10n.faqCategoryWorkoutCamera,
        entries: [
          FaqEntry(
            question: l10n.faqCameraNotSeeingQ,
            answer: l10n.faqCameraNotSeeingA,
          ),
          FaqEntry(
            question: l10n.faqPhoneSideQ,
            answer: l10n.faqPhoneSideA,
          ),
          FaqEntry(
            question: l10n.faqNoCameraQ,
            answer: l10n.faqNoCameraA,
          ),
          FaqEntry(
            question: l10n.faqPhoneRingsQ,
            answer: l10n.faqPhoneRingsA,
          ),
          FaqEntry(
            question: l10n.faqOfflineQ,
            answer: l10n.faqOfflineA,
          ),
        ],
      ),
      FaqCategory(
        title: l10n.faqCategoryAiCoach,
        entries: [
          FaqEntry(
            question: l10n.faqWhoIsFormQ,
            answer: l10n.faqWhoIsFormA,
          ),
          FaqEntry(
            question: l10n.faqShortAnswersQ,
            answer: l10n.faqShortAnswersA,
          ),
          FaqEntry(
            question: l10n.faqHealthAdviceQ,
            answer: l10n.faqHealthAdviceA,
          ),
        ],
      ),
      FaqCategory(
        title: l10n.faqCategorySubscription,
        entries: [
          FaqEntry(
            question: l10n.faqCancelSubQ,
            answer: l10n.faqCancelSubA,
          ),
          FaqEntry(
            question: l10n.faqTransferPurchaseQ,
            answer: l10n.faqTransferPurchaseA,
          ),
          FaqEntry(
            question: l10n.faqFreeFeaturesQ,
            answer: l10n.faqFreeFeaturesA,
          ),
        ],
      ),
      FaqCategory(
        title: l10n.faqCategoryAccountData,
        entries: [
          FaqEntry(
            question: l10n.faqDataStorageQ,
            answer: l10n.faqDataStorageA,
          ),
          FaqEntry(
            question: l10n.faqDeleteAccountQ,
            answer: l10n.faqDeleteAccountA,
          ),
          FaqEntry(
            question: l10n.faqGuestProgressQ,
            answer: l10n.faqGuestProgressA,
          ),
        ],
      ),
      FaqCategory(
        title: l10n.faqCategoryNotificationsOther,
        entries: [
          FaqEntry(
            question: l10n.faqNoRemindersQ,
            answer: l10n.faqNoRemindersA,
          ),
          FaqEntry(
            question: l10n.faqStreakResetQ,
            answer: l10n.faqStreakResetA,
          ),
          FaqEntry(
            question: l10n.faqReportBugQ,
            answer: l10n.faqReportBugA,
          ),
        ],
      ),
    ];

/// Flat, lower-cased search over every entry in every category.
/// Returns categories containing at least one match, each pruned to
/// only its matching entries, so the grouped layout survives filtering.
List<FaqCategory> searchFaq(AppLocalizations l10n, String rawQuery) {
  final categories = faqCategories(l10n);
  final query = rawQuery.trim().toLowerCase();
  if (query.isEmpty) return categories;
  final results = <FaqCategory>[];
  for (final category in categories) {
    final matches = category.entries
        .where((e) => e.searchIndex.contains(query))
        .toList(growable: false);
    if (matches.isNotEmpty) {
      results.add(FaqCategory(title: category.title, entries: matches));
    }
  }
  return results;
}
