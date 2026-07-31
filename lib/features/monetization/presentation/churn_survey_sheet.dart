import 'package:flutter/material.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../l10n/app_localizations.dart';

const Color _neon = Color(0xFF8E5BFF);

/// Phase 56 Lite · churn / cancellation survey.
///
/// Pops before we hand the user off to the App Store / Play Store
/// subscription-management flow. Captures their reason as a stable
/// English token (`too_expensive`, `reached_goal`, `not_using`,
/// `other`) so the analytics dashboard rolls up cleanly across
/// languages.
///
/// Returns the selected token, or `null` when the user dismissed the
/// sheet without picking a reason. The caller decides whether to
/// proceed with the cancellation in either case — this sheet's only
/// job is to log intent before the user leaves the app.
Future<String?> showChurnSurveySheet(BuildContext context) async {
  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _ChurnSurveySheet(),
  );
  if (result != null) {
    AnalyticsService.instance.logChurnReason(reason: result);
  }
  return result;
}

class _ChurnReason {
  const _ChurnReason({
    required this.token,
    required this.label,
    required this.icon,
  });
  final String token;

  /// Roadmap Phase 5 · resolved at render time rather than stored.
  ///
  /// The catalogue is a top-level `const`, so it cannot hold a
  /// localized string — there is no `BuildContext` where it is
  /// declared. Holding the lookup instead keeps the list const, keeps
  /// the analytics `token` decoupled from the copy, and means the label
  /// follows a locale change without rebuilding the catalogue.
  final String Function(AppLocalizations) label;

  final IconData icon;
}

// Not const: the label is a closure, and closures are not constants.
// The catalogue is still immutable and still built once.
final List<_ChurnReason> _reasons = [
  _ChurnReason(
    token: 'too_expensive',
    label: (l10n) => l10n.churnReasonTooExpensive,
    icon: Icons.attach_money,
  ),
  _ChurnReason(
    token: 'reached_goal',
    label: (l10n) => l10n.churnReasonGoalReached,
    icon: Icons.emoji_events_outlined,
  ),
  _ChurnReason(
    token: 'not_using',
    label: (l10n) => l10n.churnReasonNotUsing,
    icon: Icons.hourglass_empty,
  ),
  _ChurnReason(
    token: 'other',
    label: (l10n) => l10n.churnReasonOther,
    icon: Icons.more_horiz,
  ),
];

class _ChurnSurveySheet extends StatelessWidget {
  const _ChurnSurveySheet();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            AppLocalizations.of(context).churnTitle,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context).churnSubtitle,
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.65),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          for (final r in _reasons) ...[
            _ReasonTile(reason: r),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              AppLocalizations.of(context).churnStay,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.75),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({required this.reason});
  final _ChurnReason reason;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).pop(reason.token),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: scheme.onSurface.withValues(alpha: 0.04),
            border: Border.all(
              color: scheme.onSurface.withValues(alpha: 0.10),
            ),
          ),
          child: Row(
            children: [
              Icon(reason.icon, size: 22, color: _neon),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  reason.label(AppLocalizations.of(context)),
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: scheme.onSurface.withValues(alpha: 0.40),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
