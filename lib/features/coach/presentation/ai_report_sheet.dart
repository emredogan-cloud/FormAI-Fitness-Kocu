import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../data/ai_report_repository.dart';

const Color _sheet = Color(0xFF17131F);
const Color _hairline = Color(0x1FFFFFFF);
const Color _neon = Color(0xFF8E5BFF);

/// Asks why a coach reply is being reported. Returns null if dismissed.
///
/// Deliberately a reason picker and not a free-text form. A text field
/// would be a second place in this app where a user can type prose that
/// reaches a server — Phase 12 refused exactly that for the activity feed
/// ("the feed carries no free text to moderate", pinned by a test) — and
/// a triager sorting by reason token gets more from four buckets than
/// from a paragraph. The reported reply is already carried with the row,
/// so nothing about the report is ambiguous without it.
///
/// The reasons are ordered with [AiReportReason.harmfulAdvice] first
/// because in a fitness app that is the failure that can hurt somebody.
Future<AiReportReason?> showAiReportSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final reasons = <(AiReportReason, String)>[
    (AiReportReason.harmfulAdvice, l10n.coachReportHarmfulAdvice),
    (AiReportReason.offensive, l10n.coachReportOffensive),
    (AiReportReason.inaccurate, l10n.coachReportInaccurate),
    (AiReportReason.other, l10n.coachReportOther),
  ];

  return showModalBottomSheet<AiReportReason>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _sheet,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: _hairline)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.flag_outlined, color: _neon, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.coachReportTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.coachReportSubtitle,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            for (final (reason, label) in reasons)
              InkWell(
                onTap: () => Navigator.of(sheetContext).pop(reason),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: Colors.white38, size: 20),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: Text(
                  l10n.commonCancel,
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
