import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/theme_extension.dart';
import '../services/feedback_service.dart';

const Color _neon = Color(0xFF8E5BFF);

/// Phase 56 Lite · in-app feedback sheet. Subject dropdown +
/// multi-line message field + submit button. On success the sheet
/// pops with a [FeedbackResult] so the caller can decide which toast
/// to surface; on validation failure (empty message) the sheet stays
/// open and inline-flags the field.
Future<FeedbackResult?> showFeedbackSheet(BuildContext context) {
  return showModalBottomSheet<FeedbackResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _FeedbackSheet(),
  );
}

class FeedbackResult {
  const FeedbackResult(this.transport);
  final FeedbackTransport transport;
}

class _FeedbackSheet extends StatefulWidget {
  const _FeedbackSheet();

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  final _messageCtrl = TextEditingController();
  FeedbackSubject _subject = FeedbackSubject.bug;
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
      setState(() => _error = 'Lütfen birkaç cümle yaz.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final transport = await FeedbackService.instance.submit(
        subject: _subject,
        message: body,
      );
      if (!mounted) return;
      Navigator.of(context).pop(FeedbackResult(transport));
    } on FeedbackException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Beklenmeyen bir hata oluştu.');
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
              'Destek & Geri Bildirim',
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Sorunu, fikrini ya da sorunu yaz; ekibimize doğrudan ulaşır.',
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
                labelText: 'Konu',
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
                      child: Text(s.localized),
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
                labelText: 'Mesajın',
                hintText: 'Olabildiğince çok detay paylaş.',
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
                  : const Text('Gönder'),
            ),
          ],
        ),
      ),
    );
  }
}
