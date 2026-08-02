import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/neon_surface.dart';
import '../../../l10n/app_localizations.dart';
import '../data/community_repository.dart';
import '../domain/models/community_models.dart';

/// Roadmap Phase 12 (C22, C47) · friends, and the safety controls that
/// have to sit beside them.
///
/// # Three lists, and why they are separate
///
/// Incoming requests, accepted friends, outgoing requests. One list with
/// a status chip would be shorter and would bury the only rows that need
/// a decision under the rows that do not. Incoming comes first because
/// it is the only section that is somebody else waiting on you.
///
/// # The messages are deliberately vague in one direction
///
/// A handle that does not exist and a handle whose owner has not
/// published their profile produce the **same** message, because
/// distinguishing them confirms that a handle is taken. Adding somebody
/// who has blocked you says "you can't add this person" rather than
/// naming the block, for the same reason `blocks` is readable only by
/// the blocker: a blocked person discovering the block is the difference
/// between a safety tool and an escalation.
///
/// # Block and report are one tap from a row
///
/// The roadmap asks for safety controls reachable in one tap from any
/// profile. They are in the overflow on every friend row and in the
/// same sheet, so somebody who needs them does not have to find a
/// settings screen while upset.
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  /// Resolved lazily beside the friendships, so a list of ids becomes a
  /// list of names in one round trip rather than N.
  Map<String, CommunityProfile> _names = const {};
  bool _busy = false;

  String? get _me => ref.read(currentCommunityUserIdProvider);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final friendships = ref.watch(myFriendshipsProvider);

    return Scaffold(
      backgroundColor: NeonSurface.bg,
      appBar: AppBar(
        backgroundColor: NeonSurface.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          l10n.friendsTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: NeonSurface.purple,
        foregroundColor: Colors.white,
        onPressed: _busy ? null : _openAddSheet,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(l10n.friendsAdd),
      ),
      body: friendships.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: NeonSurface.purple),
        ),
        error: (_, __) => _Empty(),
        data: (rows) => _Lists(
          rows: rows,
          me: _me,
          names: _names,
          onResolve: _resolveNames,
          onRespond: _respond,
          onRemove: _confirmRemove,
          onBlock: _confirmBlock,
          onReport: _openReportSheet,
        ),
      ),
    );
  }

  Future<void> _resolveNames(List<String> ids) async {
    if (ids.isEmpty || !mounted) return;
    final resolved =
        await ref.read(communityRepositoryProvider).profilesByIds(ids);
    if (!mounted || resolved.isEmpty) return;
    setState(() => _names = resolved);
  }

  Future<void> _respond(Friendship f, bool accept) async {
    final me = _me;
    final other = me == null ? null : f.otherThan(me);
    if (other == null) return;
    setState(() => _busy = true);
    await ref
        .read(communityRepositoryProvider)
        .respondToFriend(otherUserId: other, accept: accept);
    ref.invalidate(myFriendshipsProvider);
    if (mounted) setState(() => _busy = false);
  }

  /// "They won't be told. You can add each other again later." — both
  /// facts a person actually wants before removing somebody, and neither
  /// is guessable.
  Future<void> _confirmRemove(Friendship f) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      title: l10n.friendsRemoveTitle,
      body: l10n.friendsRemoveBody,
      action: l10n.friendsRemove,
    );
    if (confirmed != true) return;
    final me = _me;
    final other = me == null ? null : f.otherThan(me);
    if (other == null || !mounted) return;
    await ref.read(communityRepositoryProvider).removeFriend(other);
    ref.invalidate(myFriendshipsProvider);
  }

  /// Blocking says what it does — symmetric, and silent. Both halves are
  /// the design rather than side effects, so both are stated.
  Future<void> _confirmBlock(String userId) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      title: l10n.friendsBlockTitle,
      body: l10n.friendsBlockBody,
      action: l10n.friendsBlock,
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(communityRepositoryProvider).block(userId);
    ref.invalidate(myFriendshipsProvider);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.friendsBlocked)));
  }

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String action,
  }) {
    final l10n = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NeonSurface.card,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(body, style: const TextStyle(color: NeonSurface.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child:
                Text(action, style: const TextStyle(color: Color(0xFFFF4D6D))),
          ),
        ],
      ),
    );
  }

  Future<void> _openReportSheet(String userId) async {
    final l10n = AppLocalizations.of(context);
    // Tokens, never the labels: the reason is written to a `check`
    // constraint and read by a human triaging in a different language.
    final reasons = <(String, String)>[
      ('harassment', l10n.friendsReportHarassment),
      ('impersonation', l10n.friendsReportImpersonation),
      ('inappropriate_content', l10n.friendsReportContent),
      ('spam', l10n.friendsReportSpam),
      ('other', l10n.friendsReportOther),
    ];
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: NeonSurface.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: NeonSurface.hairline)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.friendsReportTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              for (final reason in reasons)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(reason.$2,
                      style: const TextStyle(color: Colors.white)),
                  onTap: () => Navigator.of(sheetContext).pop(reason.$1),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(communityRepositoryProvider)
        .report(userId: userId, reason: chosen);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.friendsReported)));
  }

  Future<void> _openAddSheet() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    String? error;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: StatefulBuilder(
          builder: (sheetContext, setSheetState) => Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: NeonSurface.card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: NeonSurface.hairline)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.friendsAddTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_]')),
                      TextInputFormatter.withFunction(
                        (_, next) =>
                            next.copyWith(text: next.text.toLowerCase()),
                      ),
                    ],
                    decoration: InputDecoration(
                      labelText: l10n.profileHandle,
                      labelStyle: const TextStyle(color: NeonSurface.muted),
                      helperText: l10n.friendsAddHint,
                      helperStyle: const TextStyle(color: NeonSurface.faint),
                      errorText: error,
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: NeonSurface.hairline),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: NeonSurface.purple),
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: NeonSurface.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        final message =
                            await _sendRequest(controller.text.trim());
                        if (message == null) {
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                          return;
                        }
                        setSheetState(() => error = message);
                      },
                      child: Text(l10n.friendsAddCta),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    controller.dispose();
  }

  /// Returns null on success, or the message to show beside the field.
  ///
  /// Every wall is named by [FriendRules.cannotRequest] rather than
  /// re-derived here — the rules live in the domain and are unit-tested
  /// there, and this method's only job is turning a reason into a
  /// sentence.
  Future<String?> _sendRequest(String handle) async {
    final l10n = AppLocalizations.of(context);
    if (handle.isEmpty) return l10n.friendsNotFound;

    final repository = ref.read(communityRepositoryProvider);
    final target = await repository.profileByHandle(handle);
    // Not found and not visible are the same message, deliberately.
    if (target == null || !mounted) return l10n.friendsNotFound;

    final me = _me;
    if (me == null) return l10n.friendsRequestFailed;

    final existing = (await repository.friendships())
        .where((f) => f.involves(target.userId))
        .cast<Friendship?>()
        .firstWhere((f) => true, orElse: () => null);
    final blocked = (await repository.blockedIds()).contains(target.userId);
    if (!mounted) return l10n.friendsRequestFailed;

    final reason = FriendRules.cannotRequest(
      fromUserId: me,
      toUserId: target.userId,
      blockedEitherWay: blocked,
      existing: existing,
    );
    if (reason != null) {
      return switch (reason) {
        FriendRequestBlockReason.self => l10n.friendsCannotSelf,
        FriendRequestBlockReason.blocked => l10n.friendsCannotBlocked,
        FriendRequestBlockReason.alreadyFriends => l10n.friendsAlreadyFriends,
        FriendRequestBlockReason.alreadyPending => l10n.friendsAlreadyPending,
        FriendRequestBlockReason.previouslyDeclined =>
          l10n.friendsPreviouslyDeclined,
      };
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      await repository.requestFriend(target.userId);
      ref.invalidate(myFriendshipsProvider);
      if (!mounted) return null;
      messenger.showSnackBar(SnackBar(content: Text(l10n.friendsRequestSent)));
      return null;
    } catch (_) {
      return l10n.friendsRequestFailed;
    }
  }
}

class _Lists extends StatefulWidget {
  const _Lists({
    required this.rows,
    required this.me,
    required this.names,
    required this.onResolve,
    required this.onRespond,
    required this.onRemove,
    required this.onBlock,
    required this.onReport,
  });

  final List<Friendship> rows;
  final String? me;
  final Map<String, CommunityProfile> names;
  final ValueChanged<List<String>> onResolve;
  final void Function(Friendship, bool) onRespond;
  final ValueChanged<Friendship> onRemove;
  final ValueChanged<String> onBlock;
  final ValueChanged<String> onReport;

  @override
  State<_Lists> createState() => _ListsState();
}

class _ListsState extends State<_Lists> {
  @override
  void initState() {
    super.initState();
    // Out of build: resolving names is a network read and doing it
    // during a frame is how a rebuild loop starts.
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  @override
  void didUpdateWidget(_Lists old) {
    super.didUpdateWidget(old);
    if (old.rows.length != widget.rows.length) _resolve();
  }

  void _resolve() {
    final me = widget.me;
    if (me == null) return;
    widget.onResolve([
      for (final row in widget.rows)
        if (row.otherThan(me) case final other?) other,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = widget.me;
    if (me == null || widget.rows.isEmpty) return _Empty();

    final incoming = widget.rows.where((f) => f.canRespond(me)).toList();
    final accepted = widget.rows.where((f) => f.isMutual).toList();
    final outgoing = widget.rows
        .where(
            (f) => f.status == FriendshipStatus.pending && f.requesterId == me)
        .toList();

    if (incoming.isEmpty && accepted.isEmpty && outgoing.isEmpty) {
      return _Empty();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        NeonSurface.gutter,
        8,
        NeonSurface.gutter,
        100,
      ),
      children: [
        // Incoming first: it is the only section that is somebody else
        // waiting on you.
        if (incoming.isNotEmpty) ...[
          _Header(l10n.friendsIncoming),
          for (final f in incoming)
            _Row(
              name: _nameOf(f, me),
              subtitle: null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => widget.onRespond(f, true),
                    child: Text(l10n.friendsAccept),
                  ),
                  TextButton(
                    onPressed: () => widget.onRespond(f, false),
                    child: Text(
                      l10n.friendsDecline,
                      style: const TextStyle(color: NeonSurface.muted),
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (accepted.isNotEmpty) ...[
          // The header repeats the screen's own title, so it only earns
          // its place when there is another section to be distinguished
          // FROM. On a screen with nothing but friends it is the same
          // word twice — the redundancy the Phase 9 walk kept finding.
          if (incoming.isNotEmpty || outgoing.isNotEmpty)
            _Header(l10n.friendsAccepted),
          for (final f in accepted)
            _Row(
              name: _nameOf(f, me),
              subtitle: null,
              trailing: _Overflow(
                onRemove: () => widget.onRemove(f),
                onBlock: () => widget.onBlock(f.otherThan(me)!),
                onReport: () => widget.onReport(f.otherThan(me)!),
              ),
            ),
        ],
        if (outgoing.isNotEmpty) ...[
          _Header(l10n.friendsOutgoing),
          for (final f in outgoing)
            _Row(
              name: _nameOf(f, me),
              subtitle: l10n.friendsWaiting,
              trailing: null,
            ),
        ],
      ],
    );
  }

  /// The other party's display name, or their handle-shaped placeholder
  /// when RLS did not return a profile — a friend who has since gone
  /// private is still a friendship, and hiding the row would make
  /// "remove" unreachable.
  String _nameOf(Friendship f, String me) {
    final other = f.otherThan(me);
    if (other == null) return '—'; // i18n-ignore — an em dash
    return widget.names[other]?.displayName ?? '—'; // i18n-ignore — em dash
  }
}

class _Header extends StatelessWidget {
  const _Header(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.name,
    required this.subtitle,
    required this.trailing,
  });

  final String name;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NeonCard(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 6, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: NeonSurface.faint,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// Remove, block and report, one tap from a row — the roadmap asks for
/// safety controls reachable in one tap, and somebody who needs them
/// should not have to find a settings screen while upset.
class _Overflow extends StatelessWidget {
  const _Overflow({
    required this.onRemove,
    required this.onBlock,
    required this.onReport,
  });

  final VoidCallback onRemove;
  final VoidCallback onBlock;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<int>(
      color: NeonSurface.card,
      icon: const Icon(Icons.more_vert_rounded, color: NeonSurface.muted),
      onSelected: (value) => switch (value) {
        0 => onRemove(),
        1 => onBlock(),
        _ => onReport(),
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 0,
          child: Text(l10n.friendsRemove,
              style: const TextStyle(color: Colors.white)),
        ),
        PopupMenuItem(
          value: 1,
          child: Text(l10n.friendsBlock,
              style: const TextStyle(color: Colors.white)),
        ),
        PopupMenuItem(
          value: 2,
          child: Text(l10n.friendsReport,
              style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.friendsNone,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.friendsNoneBody,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: NeonSurface.muted,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
