import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/theme_extension.dart';
import '../../../../l10n/app_localizations.dart';
import '../../providers/outcome_report_provider.dart';

/// Roadmap Phase 10 (C4, C39) · the way in to the outcome report.
///
/// **It hides itself until there is a report worth opening.** A row that
/// leads to an empty state is a promise the app cannot keep yet, and the
/// Progress tab is already dense. Two sessions is the same threshold
/// `OutcomeReport.isSubstantive` uses, read from the report rather than
/// re-derived here — so the card and the screen can never disagree about
/// whether there is anything to show.
///
/// Themed rather than hardcoded-dark, unlike the screen it opens: this
/// sits inside the Progress tab among cards that follow the ambient
/// theme, and a black tile in a light list would read as a rendering
/// fault rather than as a design.
class OutcomeReportCard extends ConsumerWidget {
  const OutcomeReportCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(outcomeReportProvider);
    if (report == null || !report.isSubstantive) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;
    // Roadmap Phase 10 · the monthly recap is this card wearing a
    // different sentence, not a second card. A recap row and a report
    // row on the same tab would be two controls that do the same thing —
    // the defect class the Phase 9 walk found and the polish sprint
    // fixed.
    final recap = report.isRecapDue;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(AppRoutes.progressReport),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  recap
                      ? Icons.celebration_outlined
                      : Icons.auto_awesome_mosaic_outlined,
                  color: scheme.primary,
                  size: 26,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        recap ? l10n.recapTitle : l10n.outcomeReportTitle,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        recap
                            ? l10n.recapCta
                            : l10n.outcomeReportCompletion(
                                report.daysCompleted,
                                report.programLength,
                              ),
                        style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.65),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurface.withValues(alpha: 0.45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
