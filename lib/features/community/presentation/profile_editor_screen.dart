import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/analytics_service.dart';

import '../../../core/theme/neon_surface.dart';
import '../../../l10n/app_localizations.dart';
import '../data/community_repository.dart';
import '../domain/models/community_models.dart';

/// Roadmap Phase 12 (R6, C24) · creating and editing a public profile.
///
/// **Every switch starts off**, including on a profile that already
/// exists — for an existing one they start where the user left them,
/// which is the same statement: the app never moves a visibility flag
/// on somebody's behalf. `019_social_profiles.sql` defaults all three to
/// `false`, `ProfileVisibility.private` is the Dart default, and this
/// screen is the third place that rule is expressed. It is expressed
/// three times because it is the promise the whole feature rests on.
///
/// The handle field enforces the same shape the database's
/// `check (handle ~ '^[a-z0-9_]{3,20}$')` does. Enforcing it here is a
/// courtesy — it turns a rejected write into a message beside the
/// field — and the constraint is the guarantee. Never the other way
/// round.
class ProfileEditorScreen extends ConsumerStatefulWidget {
  const ProfileEditorScreen({super.key, this.existing});

  final CommunityProfile? existing;

  @override
  ConsumerState<ProfileEditorScreen> createState() =>
      _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends ConsumerState<ProfileEditorScreen> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.displayName ?? '');
  late final TextEditingController _handle =
      TextEditingController(text: widget.existing?.handle ?? '');

  late ProfileVisibility _visibility =
      widget.existing?.visibility ?? ProfileVisibility.private;

  bool _busy = false;
  String? _nameError;
  String? _handleError;

  @override
  void dispose() {
    _name.dispose();
    _handle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: NeonSurface.bg,
      appBar: AppBar(
        backgroundColor: NeonSurface.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          widget.existing == null ? l10n.profileCreate : l10n.profileEdit,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          NeonSurface.gutter,
          12,
          NeonSurface.gutter,
          40,
        ),
        children: [
          _Field(
            controller: _name,
            label: l10n.profileDisplayName,
            error: _nameError,
            maxLength: 32,
          ),
          const SizedBox(height: 16),
          _Field(
            controller: _handle,
            label: l10n.profileHandle,
            error: _handleError,
            helper: l10n.profileHandleHint,
            maxLength: 20,
            // The database's own alphabet, applied as you type so a
            // rejected write is not the first time somebody hears about
            // it. Uppercase is folded rather than blocked: typing a
            // capital is not a mistake worth a red message.
            formatters: [
              FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_]')),
              TextInputFormatter.withFunction(
                (_, next) => next.copyWith(text: next.text.toLowerCase()),
              ),
            ],
          ),
          const SizedBox(height: 22),
          NeonCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.profileVisibilityTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.profileVisibilityBody,
                  style: const TextStyle(
                    color: NeonSurface.muted,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 6),
                _Toggle(
                  label: l10n.profileVisibilityPublic,
                  value: _visibility.isPublic,
                  onChanged: (v) => setState(
                    () => _visibility = _visibility.copyWith(isPublic: v),
                  ),
                ),
                // Badges and stats are only meaningful once somebody can
                // find the profile at all, so they follow the first
                // switch rather than standing alone — and switching the
                // first one off does NOT silently clear them, because a
                // user who goes private for a week should get their
                // settings back, not a reset.
                _Toggle(
                  label: l10n.profileVisibilityBadges,
                  value: _visibility.showBadges,
                  enabled: _visibility.isPublic,
                  onChanged: (v) => setState(
                    () => _visibility = _visibility.copyWith(showBadges: v),
                  ),
                ),
                _Toggle(
                  label: l10n.profileVisibilityStats,
                  value: _visibility.showStats,
                  enabled: _visibility.isPublic,
                  onChanged: (v) => setState(
                    () => _visibility = _visibility.copyWith(showStats: v),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: NeonSurface.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              onPressed: _busy ? null : _save,
              child: Text(l10n.profileCreate),
            ),
          ),
          if (widget.existing != null) ...[
            const SizedBox(height: 14),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: _busy ? null : _confirmDelete,
                child: Text(
                  l10n.profileDelete,
                  style: const TextStyle(color: Color(0xFFFF4D6D)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final name = _name.text.trim();
    final handle = _handle.text.trim().toLowerCase();

    setState(() {
      _nameError = name.length < 2 ? l10n.profileNameTooShort : null;
      _handleError = RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(handle)
          ? null
          : l10n.profileHandleHint;
    });
    if (_nameError != null || _handleError != null) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final saved = await ref.read(communityRepositoryProvider).saveProfile(
            displayName: name,
            handle: handle,
            visibility: _visibility,
          );
      if (!mounted) return;
      if (saved == null) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.profileSaveFailed)));
        setState(() => _busy = false);
        return;
      }
      // Only the first save is a creation. An edit is a different
      // behaviour and counting it as a creation would inflate the one
      // number this phase is judged on.
      if (widget.existing == null) {
        unawaited(AnalyticsService.instance.profileCreated());
      }
      messenger.showSnackBar(SnackBar(content: Text(l10n.profileSaved)));
      navigator.pop(true);
    } catch (e) {
      if (!mounted) return;
      // A unique-violation on `handle` is the one failure with a
      // specific, actionable message. Everything else is "could not
      // save", because guessing at a cause is worse than saying so.
      final taken = e.toString().contains('23505');
      setState(() {
        _busy = false;
        _handleError = taken ? l10n.profileHandleTaken : null;
      });
      if (!taken) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.profileSaveFailed)));
      }
    }
  }

  Future<void> _confirmDelete() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NeonSurface.card,
        title: Text(l10n.profileDeleteTitle,
            style: const TextStyle(color: Colors.white)),
        // Names exactly what is lost and what is not. "Your workouts,
        // measurements and photos are not affected" is the sentence that
        // stops somebody keeping a profile they do not want out of fear.
        content: Text(l10n.profileDeleteBody,
            style: const TextStyle(color: NeonSurface.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.profileDelete,
                style: const TextStyle(color: Color(0xFFFF4D6D))),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await ref.read(communityRepositoryProvider).deleteProfile();
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.profileDeleted)));
    navigator.pop(true);
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.maxLength,
    this.error,
    this.helper,
    this.formatters,
  });

  final TextEditingController controller;
  final String label;
  final int maxLength;
  final String? error;
  final String? helper;
  final List<TextInputFormatter>? formatters;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      inputFormatters: formatters,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: NeonSurface.muted),
        helperText: helper,
        helperStyle: const TextStyle(color: NeonSurface.faint),
        helperMaxLines: 2,
        errorText: error,
        counterStyle: const TextStyle(color: NeonSurface.faint),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: NeonSurface.hairline),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: NeonSurface.purple),
        ),
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: enabled ? onChanged : null,
      activeThumbColor: NeonSurface.purple,
      title: Text(
        label,
        style: TextStyle(
          color: enabled ? Colors.white : NeonSurface.faint,
          fontSize: 14,
        ),
      ),
    );
  }
}
