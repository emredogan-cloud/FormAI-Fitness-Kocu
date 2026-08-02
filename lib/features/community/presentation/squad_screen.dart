import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/neon_surface.dart';
import '../../../l10n/app_localizations.dart';
import '../data/community_repository.dart';
import '../domain/models/community_models.dart';
import 'squad_feed_screen.dart';

/// Roadmap Phase 12 (C22) · squads.
///
/// # Twelve, and the count is always visible
///
/// Every row says "7 of 12" rather than "7 members", so the ceiling is
/// never a surprise at the moment somebody tries to invite a friend.
/// Twelve is a product decision — the roadmap's, and it is the whole
/// premise: small groups outperform global feeds for accountability, and
/// twelve is small enough that a quiet week gets noticed.
///
/// # Creating is three taps and joining is one field
///
/// The roadmap asks for squad creation in ≤ 3 taps and joining via a
/// single link. Create → name → done. The invite code is generated
/// client-side from a restricted alphabet and confirmed unique by the
/// database's own `unique` constraint rather than by a lookup — a
/// check-then-insert would race, and the constraint is already there.
///
/// # The cap is enforced on the server, not here
///
/// [Squad.cannotJoin] renders an honest button; `join_squad()` counts
/// and inserts in one statement. Two people joining a squad of eleven
/// both pass the client check and one of them gets a clean error. That
/// asymmetry is deliberate and is documented in the migration.
class SquadScreen extends ConsumerStatefulWidget {
  const SquadScreen({super.key});

  @override
  ConsumerState<SquadScreen> createState() => _SquadScreenState();
}

class _SquadScreenState extends ConsumerState<SquadScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final squads = ref.watch(mySquadsProvider);
    final me = ref.watch(currentCommunityUserIdProvider);

    return Scaffold(
      backgroundColor: NeonSurface.bg,
      appBar: AppBar(
        backgroundColor: NeonSurface.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          l10n.squadTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: squads.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: NeonSurface.purple),
        ),
        error: (_, __) => _Empty(onCreate: _create, onJoin: _openJoinSheet),
        data: (rows) => rows.isEmpty
            ? _Empty(onCreate: _create, onJoin: _openJoinSheet)
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  NeonSurface.gutter,
                  8,
                  NeonSurface.gutter,
                  40,
                ),
                children: [
                  for (final squad in rows)
                    _SquadRow(
                      squad: squad,
                      isOwner: me != null && squad.isOwner(me),
                      onOpen: () => _openFeed(squad),
                      onShare: () => _shareCode(squad),
                      onLeave: () => _confirmLeave(squad),
                    ),
                  const SizedBox(height: 16),
                  _Actions(onCreate: _create, onJoin: _openJoinSheet),
                ],
              ),
      ),
    );
  }

  void _openFeed(Squad squad) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SquadFeedScreen(squad: squad)),
    );
  }

  /// An uppercase alphanumeric code, matching the migration's
  /// `check (invite_code ~ '^[A-Z0-9]{6,10}$')`.
  ///
  /// `I`, `O`, `0` and `1` are left out: this code gets read aloud and
  /// typed from a screenshot, and those four are the pairs people get
  /// wrong. Losing four characters costs nothing against a 32^8 space.
  static String _newInviteCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // i18n-ignore — code
    final random = math.Random.secure();
    return String.fromCharCodes([
      for (var i = 0; i < 8; i++)
        alphabet.codeUnitAt(random.nextInt(alphabet.length)),
    ]);
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final name = await _promptSheet(
      title: l10n.squadCreateTitle,
      label: l10n.squadNameLabel,
      cta: l10n.squadCreate,
      controller: controller,
      maxLength: 32,
    );
    controller.dispose();
    if (name == null || name.trim().length < 2 || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final created = await ref.read(communityRepositoryProvider).createSquad(
          name: name.trim(),
          inviteCode: _newInviteCode(),
        );
    ref.invalidate(mySquadsProvider);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(
        created == null ? l10n.squadCreateFailed : l10n.squadCreated,
      ),
    ));
  }

  Future<void> _openJoinSheet() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final code = await _promptSheet(
      title: l10n.squadJoinTitle,
      label: l10n.squadCodeLabel,
      cta: l10n.squadJoinCta,
      controller: controller,
      maxLength: 10,
      uppercase: true,
    );
    controller.dispose();
    if (code == null || code.trim().isEmpty || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    // `join_squad` is idempotent — it returns the squad id when the
    // caller is already a member — so the RPC cannot distinguish
    // "joined" from "was already in". Checking the squads we already
    // hold is what lets the message be true. It is a courtesy, exactly
    // like `Squad.cannotJoin`: the cap and the membership are both
    // re-decided server-side.
    final typed = code.trim().toUpperCase();
    final existing = ref.read(mySquadsProvider).value ?? const <Squad>[];
    for (final squad in existing) {
      if (squad.inviteCode != typed) continue;
      final reason = squad.cannotJoin(userId: '', alreadyMember: true);
      if (reason == SquadJoinBlockReason.alreadyMember) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.squadAlreadyMember)),
        );
        return;
      }
    }

    String message;
    try {
      final id =
          await ref.read(communityRepositoryProvider).joinSquad(code.trim());
      // `join_squad` raises rather than returning null for a full squad
      // and for an unknown code, so a null here means the schema is not
      // applied — which the entry point has already reported.
      message = id == null ? l10n.squadJoinFailed : l10n.squadJoined;
      ref.invalidate(mySquadsProvider);
    } catch (e) {
      // The three outcomes the function distinguishes. Matched on the
      // message it raises, because PostgREST surfaces a RAISE as text
      // and there is no code to switch on.
      final text = e.toString();
      message = text.contains('squad is full') // i18n-ignore — PG raise
          ? l10n.squadFull
          : l10n.squadJoinFailed;
    }
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _shareCode(Squad squad) async {
    final l10n = AppLocalizations.of(context);
    await SharePlus.instance.share(
      ShareParams(text: l10n.squadInviteMessage(squad.inviteCode)),
    );
  }

  Future<void> _confirmLeave(Squad squad) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NeonSurface.card,
        title: Text(l10n.squadLeaveTitle,
            style: const TextStyle(color: Colors.white)),
        // Both facts somebody wants before leaving: nobody is told, and
        // it is reversible.
        content: Text(l10n.squadLeaveBody,
            style: const TextStyle(color: NeonSurface.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.squadLeave,
                style: const TextStyle(color: Color(0xFFFF4D6D))),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(communityRepositoryProvider).leaveSquad(squad.id);
    ref.invalidate(mySquadsProvider);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.squadLeft)));
  }

  Future<String?> _promptSheet({
    required String title,
    required String label,
    required String cta,
    required TextEditingController controller,
    required int maxLength,
    bool uppercase = false,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Container(
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
                  title,
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
                  maxLength: maxLength,
                  textCapitalization: uppercase
                      ? TextCapitalization.characters
                      : TextCapitalization.words,
                  inputFormatters: uppercase
                      ? [
                          FilteringTextInputFormatter.allow(
                              RegExp('[a-zA-Z0-9]')),
                          TextInputFormatter.withFunction(
                            (_, next) =>
                                next.copyWith(text: next.text.toUpperCase()),
                          ),
                        ]
                      : null,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: label,
                    labelStyle: const TextStyle(color: NeonSurface.muted),
                    counterStyle: const TextStyle(color: NeonSurface.faint),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: NeonSurface.hairline),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: NeonSurface.purple),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: NeonSurface.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () =>
                        Navigator.of(sheetContext).pop(controller.text),
                    child: Text(cta),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SquadRow extends StatelessWidget {
  const _SquadRow({
    required this.squad,
    required this.isOwner,
    required this.onOpen,
    required this.onShare,
    required this.onLeave,
  });

  final Squad squad;
  final bool isOwner;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(NeonSurface.radius),
          onTap: onOpen,
          child: NeonCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        squad.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        // The cap is stated alongside the count, so a
                        // full squad is never a surprise at the moment
                        // somebody tries to invite a friend.
                        l10n.squadMembers(squad.memberCount),
                        style: TextStyle(
                          color: squad.isFull
                              ? NeonSurface.lime
                              : NeonSurface.faint,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l10n.squadInviteShare,
                  onPressed: onShare,
                  icon: const Icon(Icons.ios_share_rounded,
                      color: NeonSurface.muted, size: 20),
                ),
                PopupMenuButton<int>(
                  color: NeonSurface.card,
                  icon: const Icon(Icons.more_vert_rounded,
                      color: NeonSurface.muted),
                  onSelected: (_) => onLeave(),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 0,
                      child: Text(l10n.squadLeave,
                          style: const TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.onCreate, required this.onJoin});

  final VoidCallback onCreate;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: NeonSurface.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: onCreate,
            child: Text(l10n.squadCreate),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: NeonSurface.hairline),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: onJoin,
            child: Text(l10n.squadJoin),
          ),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onCreate, required this.onJoin});

  final VoidCallback onCreate;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.squadNone,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.squadNoneBody,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: NeonSurface.muted,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            _Actions(onCreate: onCreate, onJoin: onJoin),
          ],
        ),
      ),
    );
  }
}
