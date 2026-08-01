import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_extension.dart';
import '../services/feedback_reward_service.dart';
import '../services/feedback_service.dart';
import '../../../l10n/app_localizations.dart';

const Color _neon = Color(0xFF8E5BFF);

/// Phase 56 Lite · in-app feedback sheet. Subject dropdown +
/// multi-line message field + submit button. On success the sheet
/// pops with a [FeedbackResult] so the caller can decide which toast
/// to surface; on validation failure (empty message) the sheet stays
/// open and inline-flags the field.
///
/// Roadmap Phase 1 extends it three ways:
///   * [initialSubject] lets a caller pre-select the topic. The
///     sentiment routing in `RatingMomentService` uses it so a user who
///     tapped 1–3 stars lands on a form that already knows why they're
///     there.
///   * [introOverride] lets the caller reframe the prompt for that
///     context without a second sheet implementation.
///   * Successful submission grants the participation reward (R2.3)
///     and reports it on [FeedbackResult], so both call sites get the
///     reward without duplicating the policy.
Future<FeedbackResult?> showFeedbackSheet(
  BuildContext context, {
  FeedbackSubject initialSubject = FeedbackSubject.bug,
  String? introOverride,
}) {
  return showModalBottomSheet<FeedbackResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _FeedbackSheet(
      initialSubject: initialSubject,
      introOverride: introOverride,
    ),
  );
}

class FeedbackResult {
  const FeedbackResult(this.transport, {this.reward});

  final FeedbackTransport transport;

  /// The participation reward granted for this submission, or `null`
  /// when the user is inside the reward cooldown.
  final FeedbackReward? reward;
}

class _FeedbackSheet extends ConsumerStatefulWidget {
  const _FeedbackSheet({
    required this.initialSubject,
    this.introOverride,
  });

  final FeedbackSubject initialSubject;
  final String? introOverride;

  @override
  ConsumerState<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends ConsumerState<_FeedbackSheet> {
  final _messageCtrl = TextEditingController();
  late FeedbackSubject _subject = widget.initialSubject;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final body = _messageCtrl.text.trim();
    if (body.length < 4) {
      setState(() => _error = AppLocalizations.of(context).feedbackWriteMore);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final transport = await FeedbackService.instance.submit(
        l10n: AppLocalizations.of(context),
        subject: _subject,
        message: body,
      );
      // The reward is granted here rather than at the call sites so the
      // policy lives in exactly one place and both entry points (the
      // Settings row and the sentiment-routed rating flow) behave
      // identically.
      final reward = await ref.read(feedbackRewardProvider).grantIfEligible();
      if (!mounted) return;
      Navigator.of(context).pop(FeedbackResult(transport, reward: reward));
    } on FeedbackException {
      if (!mounted) return;
      setState(() => _error = AppLocalizations.of(context).feedbackSendFailed);
    } catch (e) {
      if (!mounted) return;
      setState(
          () => _error = AppLocalizations.of(context).feedbackUnexpectedError);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + insets),
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
            const SizedBox(height: 14),
            Text(
              AppLocalizations.of(context).feedbackTitle,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.introOverride ??
                  AppLocalizations.of(context).feedbackSubtitle,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.65),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<FeedbackSubject>(
              initialValue: _subject,
              isDense: true,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).feedbackTopicLabel,
                filled: true,
                fillColor: scheme.onSurface.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: scheme.onSurface.withValues(alpha: 0.10),
                  ),
                ),
              ),
              items: FeedbackSubject.values
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.label(AppLocalizations.of(context))),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (next) => setState(() => _subject = next ?? _subject),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _messageCtrl,
              maxLines: 5,
              minLines: 4,
              maxLength: 800,
              textInputAction: TextInputAction.newline,
              keyboardType: TextInputType.multiline,
              inputFormatters: [
                LengthLimitingTextInputFormatter(800),
              ],
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).feedbackMessageLabel,
                hintText: AppLocalizations.of(context).feedbackMessageHint,
                alignLabelWithHint: true,
                filled: true,
                fillColor: scheme.onSurface.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: scheme.onSurface.withValues(alpha: 0.10),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _neon, width: 1.4),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: scheme.error, fontSize: 12),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: _neon,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(AppLocalizations.of(context).feedbackSubmit),
            ),
          ],
        ),
      ),
    );
  }
}
