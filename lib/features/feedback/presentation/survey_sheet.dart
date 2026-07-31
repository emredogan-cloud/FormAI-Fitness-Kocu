import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_extension.dart';
import '../../../core/utils/app_haptics.dart';
import '../domain/survey.dart';
import '../services/survey_service.dart';
import '../../../l10n/app_localizations.dart';

const Color _neon = Color(0xFF8E5BFF);

/// Roadmap Phase 1 (C8) · the micro-survey sheet.
///
/// Deliberately a bottom sheet rather than a full-screen route or a
/// blocking dialog: the user opened FormAI to train, and a survey that
/// stands between them and that is a survey that earns a 1-star review.
/// Drag-to-dismiss and the explicit close button are both first-class
/// exits, and dismissal is recorded so we never ask twice.
///
/// Returns `true` when an answer was submitted, `false`/`null` when the
/// user dismissed.
Future<bool?> showSurveySheet(
  BuildContext context, {
  required SurveyDefinition survey,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _SurveySheet(survey: survey),
  );
}

class _SurveySheet extends ConsumerStatefulWidget {
  const _SurveySheet({required this.survey});

  final SurveyDefinition survey;

  @override
  ConsumerState<_SurveySheet> createState() => _SurveySheetState();
}

class _SurveySheetState extends ConsumerState<_SurveySheet> {
  bool _submitting = false;
  bool _submitted = false;

  Future<void> _answer({int? score, String? optionToken}) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    AppHaptics.primaryCta();
    await ref.read(surveyServiceProvider).submit(
          SurveyAnswer(
            surveyId: widget.survey.id,
            score: score,
            optionToken: optionToken,
          ),
        );
    if (!mounted) return;
    // Brief thank-you state before auto-closing, so the tap visibly
    // registers rather than the sheet vanishing under the finger.
    setState(() => _submitted = true);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    await Future<void>.delayed(
      reduceMotion
          ? const Duration(milliseconds: 400)
          : const Duration(milliseconds: 1100),
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _dismiss() async {
    await ref.read(surveyServiceProvider).recordDismissal(widget.survey);
    if (!mounted) return;
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SingleChildScrollView(
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
            const SizedBox(height: 10),
            if (_submitted)
              _ThankYou(scheme: scheme)
            else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      widget.survey.question,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Explicit exit. Drag-to-dismiss also works, but a
                  // visible close affordance is what a user reaches for
                  // when they feel interrupted.
                  Semantics(
                    button: true,
                    label: AppLocalizations.of(context).surveyClose,
                    child: IconButton(
                      onPressed: _submitting ? null : _dismiss,
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: scheme.onSurface.withValues(alpha: 0.5),
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              if (widget.survey.subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  widget.survey.subtitle!,
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.62),
                    fontSize: 12.5,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              switch (widget.survey.kind) {
                SurveyKind.nps => _NpsScale(
                    enabled: !_submitting,
                    onPick: (score) => _answer(score: score),
                  ),
                SurveyKind.choice => _ChoiceList(
                    options: widget.survey.options,
                    enabled: !_submitting,
                    onPick: (token) => _answer(optionToken: token),
                  ),
              },
            ],
          ],
        ),
      ),
    );
  }
}

class _ThankYou extends StatelessWidget {
  const _ThankYou({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Column(
        children: [
          const Icon(Icons.favorite_rounded, color: _neon, size: 34),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context).surveyThanks,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context).surveyShapesFormai,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.65),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// 0–10 NPS scale. Wraps rather than scrolls horizontally so every
/// value stays reachable at large text scales and on narrow phones —
/// a horizontally-scrolling scale hides the promoter end, which biases
/// the result.
class _NpsScale extends StatelessWidget {
  const _NpsScale({required this.enabled, required this.onPick});

  final bool enabled;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: List.generate(11, (i) {
            return Semantics(
              button: true,
              label: '$i puan',
              child: SizedBox(
                width: 48,
                height: 48,
                child: Material(
                  color: scheme.onSurface.withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: scheme.onSurface.withValues(alpha: 0.10),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: enabled ? () => onPick(i) : null,
                    child: Center(
                      child: Text(
                        '$i',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        // Flexible + explicit alignment rather than a plain
        // spaceBetween Row: at textScaler 1.3 the two anchor labels
        // together exceed a 393px viewport and the Row overflowed by
        // ~83px. Letting each label wrap keeps the scale accessible
        // instead of capping it.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                AppLocalizations.of(context).surveyNpsLow,
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.45),
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppLocalizations.of(context).surveyNpsHigh,
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.45),
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChoiceList extends StatelessWidget {
  const _ChoiceList({
    required this.options,
    required this.enabled,
    required this.onPick,
  });

  final List<SurveyOption> options;
  final bool enabled;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final option in options) ...[
          Material(
            color: scheme.onSurface.withValues(alpha: 0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: scheme.onSurface.withValues(alpha: 0.10),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? () => onPick(option.token) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 15,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        option.label,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: scheme.onSurface.withValues(alpha: 0.35),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
