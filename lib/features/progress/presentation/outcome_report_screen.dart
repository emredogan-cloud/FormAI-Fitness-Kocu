import 'dart:io';

import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers/unit_system_provider.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/services/data_export_service.dart';
import '../../../core/services/share_service.dart';
import '../../../core/utils/unit_system.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/outcome_report.dart';
import '../../workout/data/session_log_repository.dart';
import '../data/body_metrics_repository.dart';
import '../data/progress_photo_repository.dart';
import '../providers/outcome_report_provider.dart';
import '../providers/target_weight_provider.dart';
import '../domain/models/progress_photo.dart';
import 'body_metrics_copy.dart';
import 'outcome_report_copy.dart';

/// Roadmap Phase 10 (C4, C39) · the 30-day outcome report.
///
/// The roadmap asks for this to be "a genuine keepsake — this artifact
/// will be screenshotted and shared; it deserves the same design
/// investment as the paywall". So it wears the same neon-on-black
/// surface the pre-Phase-10 rebuild gave "Your body", and it is
/// deliberately **dark-only** for the same reason: it is a branded,
/// immersive surface, and the one thing a screenshot must not do is
/// arrive in whichever theme the reader happened to have on.
///
/// Three things it refuses to do, all of which are the point:
///
///   * **It never grades a body.** Deltas are stated as two ends, the
///     arithmetic is not shown, and no figure is coloured by direction.
///     See `outcome_report_copy.dart`.
///   * **It never reports a section it cannot support.** No body
///     readings means the body section is replaced by a sentence saying
///     so, framed as a fact rather than as a lapse.
///   * **It never claims a session it did not see.** The energy figure
///     carries a tilde and a footnote calling itself an estimate,
///     because it is derived from completed days rather than measured.
class OutcomeReportScreen extends ConsumerWidget {
  const OutcomeReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final report = ref.watch(outcomeReportProvider);

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          l10n.outcomeReportTitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: report == null
          ? const Center(child: CircularProgressIndicator(color: _kPurple))
          : report.isSubstantive
              ? _Report(report: report)
              : const _NotYet(),
    );
  }
}

const Color _kBg = Color(0xFF000000);
const Color _kCard = Color(0xFF0B0B10);
const Color _kHairline = Color(0x17FFFFFF);
const Color _kMuted = Color(0x8CFFFFFF);
const Color _kFaint = Color(0x5CFFFFFF);
const Color _kLime = Color(0xFFB8FF33);
const Color _kPurple = AppColors.neon;
const List<Color> _kBrandSweep = [_kPurple, _kLime];
const double _kGutter = 16;

class _NotYet extends StatelessWidget {
  const _NotYet();

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
              l10n.outcomeReportEmptyTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.outcomeReportEmptyBody,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _kMuted,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Report extends ConsumerWidget {
  const _Report({required this.report});

  final OutcomeReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final system = ref.watch(unitSystemProvider);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final dates = DateFormat.MMMd(localeTag);
    final minutes = report.totalActiveTime.inMinutes;

    return ListView(
      padding: const EdgeInsets.fromLTRB(_kGutter, 4, _kGutter, 40),
      children: [
        Text(
          reportWindow(
            l10n,
            dates.format(report.windowStart),
            dates.format(report.windowEnd),
          ),
          style: const TextStyle(color: _kFaint, fontSize: 13),
        ),
        const SizedBox(height: 16),
        _CompletionCard(report: report),
        const SizedBox(height: 22),
        _SectionHeader(l10n.outcomeReportSectionEffort),
        const SizedBox(height: 10),
        _StatGrid(
          tiles: [
            (
              l10n.outcomeReportSessions(report.sessionCount),
              l10n.outcomeReportSessionsLabel
            ),
            (
              l10n.outcomeReportMinutes(minutes),
              l10n.outcomeReportMinutesLabel
            ),
            (
              l10n.outcomeReportRepsValue(report.totalReps),
              l10n.outcomeReportRepsLabel
            ),
            (
              l10n.outcomeReportStreak(report.longestStreak),
              l10n.outcomeReportStreakLabel
            ),
          ],
        ),
        const SizedBox(height: 10),
        _EnergyCard(kcal: report.estimatedKcal),
        // Present so a camera-free user's report reads as equal rather
        // than lesser. Absent when it would be a footnote about nothing.
        if (report.cameraFreeSessions > 0) ...[
          const SizedBox(height: 10),
          Text(
            l10n.outcomeReportCameraFree(report.cameraFreeSessions),
            style: const TextStyle(color: _kFaint, fontSize: 12.5),
          ),
        ],
        const SizedBox(height: 24),
        _SectionHeader(l10n.outcomeReportSectionBody),
        const SizedBox(height: 10),
        if (!report.hasBodyData)
          _SoftCard(
            child: Text(
              l10n.outcomeReportNoBody,
              style: const TextStyle(
                color: _kMuted,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
          )
        else
          _SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final delta in [
                  if (report.weight case final w?) w,
                  ...report.measurements,
                ]) ...[
                  Text(
                    deltaSentence(
                      l10n,
                      delta,
                      system: system,
                      localeTag: localeTag,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        if (report.milestones.isNotEmpty) ...[
          const SizedBox(height: 24),
          _SectionHeader(l10n.outcomeReportSectionStory),
          const SizedBox(height: 10),
          _Timeline(milestones: report.milestones, localeTag: localeTag),
        ],
        const SizedBox(height: 24),
        _ShareRow(report: report, system: system, localeTag: localeTag),
        const SizedBox(height: 8),
        const _PhotosRow(),
        const SizedBox(height: 8),
        const _ExportRow(),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

/// The headline: how much of the program is done, as a count.
///
/// A count and not a percentage, for the same reason the adherence card
/// is a count — "18 of 30 days" is a fact, and "60 %" reads as a grade.
/// The ring is there because the shape carries the same information
/// faster, not because the number needed decorating.
class _CompletionCard extends StatelessWidget {
  const _CompletionCard({required this.report});

  final OutcomeReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _kPurple.withValues(alpha: 0.22),
            blurRadius: 26,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: _kBrandSweep,
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
          ),
        ),
        padding: const EdgeInsets.all(1.4),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF08070E),
            borderRadius: BorderRadius.circular(18.6),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.outcomeReportCompletion(
                        report.daysCompleted,
                        report.programLength,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              _CompletionRing(fraction: report.completionFraction),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletionRing extends StatelessWidget {
  const _CompletionRing({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: 66,
        height: 66,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: fraction),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, value, __) => CircularProgressIndicator(
            value: value,
            strokeWidth: 6,
            backgroundColor: Colors.white.withValues(alpha: 0.10),
            valueColor: const AlwaysStoppedAnimation(_kLime),
          ),
        ),
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.tiles});

  /// (value, label) pairs. The value is a whole localized phrase — "12
  /// sessions" — rather than a number beside a unit, because Turkish and
  /// English put the two in different places and splitting them here
  /// would be the concatenation rule broken in a grid.
  final List<(String, String)> tiles;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < tiles.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 10),
          // `IntrinsicHeight`, not `CrossAxisAlignment.stretch`. A Row
          // inside a ListView has unbounded height, and `stretch` hands
          // that infinity straight to the children — which is an
          // assertion, not a layout. Intrinsics measure the taller tile
          // first and match the other to it, which is what "stretch"
          // was reaching for.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _StatTile(tiles[i])),
                if (i + 1 < tiles.length) ...[
                  const SizedBox(width: 10),
                  Expanded(child: _StatTile(tiles[i + 1])),
                ] else
                  const Spacer(),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(this.tile);

  final (String, String) tile;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tile.$2,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _kFaint,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 5),
          // Scaled down rather than wrapped: "1,240 repetitions" at a
          // 1.3 text scale is wider than half a 320 px phone, and a
          // wrapped headline figure reads as two facts.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              tile.$1,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The energy estimate, and the sentence that stops it being a claim.
class _EnergyCard extends StatelessWidget {
  const _EnergyCard({required this.kcal});

  final int kcal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _SoftCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.outcomeReportKcalLabel,
                  style: const TextStyle(
                    color: _kFaint,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  l10n.outcomeReportKcal(kcal),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.outcomeReportKcalNote,
                  style: const TextStyle(
                    color: _kFaint,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The journey, oldest first.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.milestones, required this.localeTag});

  final List<Milestone> milestones;
  final String localeTag;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final format = DateFormat.MMMd(localeTag);
    final rows = <Widget>[];
    for (final milestone in milestones) {
      final sentence = milestoneSentence(l10n, milestone);
      // A milestone whose copy has gone missing drops its row rather
      // than rendering an id at a person.
      if (sentence == null) continue;
      rows.add(_TimelineRow(
        glyph: milestoneGlyph(milestone),
        sentence: sentence,
        when: format.format(milestone.at),
      ));
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.glyph,
    required this.sentence,
    required this.when,
  });

  final String glyph;
  final String sentence;
  final String when;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 30,
          child: ExcludeSemantics(
            child: Text(glyph, style: const TextStyle(fontSize: 19)),
          ),
        ),
        Expanded(
          child: Text(
            sentence,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          when,
          style: const TextStyle(color: _kFaint, fontSize: 12),
        ),
      ],
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kHairline),
      ),
      child: child,
    );
  }
}

/// Roadmap Phase 10 (C48) · the way out.
///
/// Portability sits at the bottom of the report rather than in Settings
/// because this is the screen where a person is already looking at
/// everything the app knows about them — which is the moment "can I keep
/// this?" is a real question rather than a legal checkbox.
class _ExportRow extends ConsumerStatefulWidget {
  const _ExportRow();

  @override
  ConsumerState<_ExportRow> createState() => _ExportRowState();
}

class _ExportRowState extends ConsumerState<_ExportRow> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        onPressed: _busy ? null : _openSheet,
        icon: const Icon(Icons.ios_share_rounded, size: 18, color: _kLime),
        label: Text(
          l10n.outcomeReportExport,
          style: const TextStyle(color: _kLime, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Future<void> _openSheet() async {
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: _kHairline)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.outcomeReportExportTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.outcomeReportExportBody,
                style:
                    const TextStyle(color: _kMuted, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 18),
              _ExportAction(
                label: l10n.outcomeReportExportJson,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _run(json: true);
                },
              ),
              const SizedBox(height: 10),
              _ExportAction(
                label: l10n.outcomeReportExportCsv,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _run(json: false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the file and hands it to the OS share sheet.
  ///
  /// Everything is written to the temp directory, which the OS reclaims —
  /// an export the user cancels does not become a permanent copy of their
  /// data sitting in app storage. The failure branch says explicitly that
  /// nothing was sent, because "export failed" on a privacy feature reads
  /// as "sent somewhere and failed" unless it is spelled out.
  Future<void> _run({required bool json}) async {
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final export = DataExport(
        sessionLogs: ref.read(sessionLogsProvider).value ?? const {},
        bodyMetrics: ref.read(bodyMetricsProvider).value ?? const [],
        targetWeightKg: ref.read(targetWeightProvider),
        locale: Localizations.localeOf(context).toLanguageTag(),
        unitSystem: ref.read(unitSystemProvider).name,
        generatedAt: DateTime.now(),
      );
      final directory = await getTemporaryDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final files = <XFile>[];
      if (json) {
        final file = File('${directory.path}/formai_export_$stamp.json');
        await file.writeAsString(export.toJson(), flush: true);
        files.add(XFile(file.path));
      } else {
        for (final entry in export.toCsv().entries) {
          final file = File('${directory.path}/${stamp}_${entry.key}');
          await file.writeAsString(entry.value, flush: true);
          files.add(XFile(file.path));
        }
      }
      await SharePlus.instance.share(ShareParams(files: files));
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.outcomeReportExportDone)),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.outcomeReportExportFailed)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _ExportAction extends StatelessWidget {
  const _ExportAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: _kHairline),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(label),
      ),
    );
  }
}

/// Roadmap Phase 10 (C2) · the way to the photographs.
///
/// On the report rather than in the Progress tab's card stack, because a
/// progress photo is an outcome — it belongs with the sessions and the
/// measurements that explain it, not beside the controls that produce
/// them. It also keeps the one screen that shows a user's body reachable
/// from exactly one place, which is easier to reason about than three.
class _PhotosRow extends ConsumerWidget {
  const _PhotosRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final count = ref.watch(progressPhotosProvider).value?.length ?? 0;
    return Material(
      color: _kCard,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.progressPhotos),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _kHairline),
          ),
          child: Row(
            children: [
              const Icon(Icons.photo_camera_outlined, color: _kLime, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.photosTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      // The count when there is one, and the privacy
                      // promise when there is not — which is the line
                      // that decides whether somebody starts.
                      count == 0
                          ? l10n.photosPrivacyAtCapture
                          : l10n.photosCount(count),
                      style: const TextStyle(color: _kFaint, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _kFaint),
            ],
          ),
        ),
      ),
    );
  }
}

/// Roadmap Phase 10 (C4) · the share card, and the consent that precedes
/// it.
///
/// **The options sheet is not a settings screen.** Nothing it holds is
/// remembered: every switch is off when it opens, every time. That is
/// deliberate and it is the difference between "the user opted in" and
/// "the user opted in once, months ago, and has forgotten". The sessions
/// and minutes are always on the card — they are the report's substance
/// and disclose nothing about a body — and everything that does is a
/// decision made in the moment.
///
/// The photograph is the sharpest case: it is the only path in this
/// whole feature by which an image of the user's body can leave the
/// handset. It is off, it is last, and it is asked again next time.
class _ShareRow extends ConsumerStatefulWidget {
  const _ShareRow({
    required this.report,
    required this.system,
    required this.localeTag,
  });

  final OutcomeReport report;
  final UnitSystem system;
  final String localeTag;

  @override
  ConsumerState<_ShareRow> createState() => _ShareRowState();
}

class _ShareRowState extends ConsumerState<_ShareRow> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        onPressed: _busy ? null : _openOptions,
        icon: const Icon(Icons.share_outlined, size: 18, color: _kLime),
        label: Text(
          l10n.outcomeReportShare,
          style: const TextStyle(color: _kLime, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Future<void> _openOptions() async {
    final l10n = AppLocalizations.of(context);
    final hasPhotos =
        (ref.read(progressPhotosProvider).value ?? const []).isNotEmpty;
    // Fresh every time. See the class doc.
    var body = false;
    var streak = false;
    var photo = false;

    final go = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: _kHairline)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.outcomeReportShareTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.outcomeReportShareBody,
                  style: const TextStyle(
                      color: _kMuted, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 8),
                if (widget.report.hasBodyData)
                  _ShareToggle(
                    label: l10n.outcomeReportShareBodyMetrics,
                    value: body,
                    onChanged: (v) => setSheetState(() => body = v),
                  ),
                _ShareToggle(
                  label: l10n.outcomeReportShareStreak,
                  value: streak,
                  onChanged: (v) => setSheetState(() => streak = v),
                ),
                if (hasPhotos)
                  _ShareToggle(
                    label: l10n.outcomeReportSharePhotos,
                    value: photo,
                    onChanged: (v) => setSheetState(() => photo = v),
                  ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(l10n.outcomeReportShareCta),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (go != true || !mounted) return;
    await _render(body: body, streak: streak, photo: photo);
  }

  Future<void> _render({
    required bool body,
    required bool streak,
    required bool photo,
  }) async {
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final report = widget.report;
    final dates = DateFormat.MMMd(widget.localeTag);

    // Formatted here, where the locale and the unit system are, and
    // handed to the template already finished. See the template's doc.
    final lines = <(String, String)>[
      (
        l10n.outcomeReportSessionsLabel,
        l10n.outcomeReportSessions(report.sessionCount)
      ),
      (
        l10n.outcomeReportMinutesLabel,
        l10n.outcomeReportMinutes(report.totalActiveTime.inMinutes)
      ),
      (
        l10n.outcomeReportRepsLabel,
        l10n.outcomeReportRepsValue(report.totalReps)
      ),
      if (streak)
        (
          l10n.outcomeReportStreakLabel,
          l10n.outcomeReportStreak(report.longestStreak)
        ),
      if (body)
        for (final delta in [
          if (report.weight case final w?) w,
          ...report.measurements,
        ])
          (
            measureLabel(l10n, delta.measure),
            formatMeasure(delta.last, delta.measure,
                system: widget.system, localeTag: widget.localeTag)
          ),
    ];

    Uint8List? bytes;
    if (photo) bytes = await _newestPhotoBytes();
    if (!mounted) return;

    final ok = await ShareService.instance.shareOutcomeReport(
      context: context,
      headline: l10n.outcomeReportCompletion(
        report.daysCompleted,
        report.programLength,
      ),
      subline: reportWindow(
        l10n,
        dates.format(report.windowStart),
        dates.format(report.windowEnd),
      ),
      lines: lines,
      photoBytes: bytes,
    );
    if (!mounted) return;
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.outcomeReportShareFailed)),
      );
    }
    setState(() => _busy = false);
  }

  /// The newest photo of any pose, read straight off disk.
  ///
  /// Front by preference — it is the pose a comparison is usually of —
  /// falling back to whatever exists, because a user who only ever takes
  /// side photos still opted in.
  Future<Uint8List?> _newestPhotoBytes() async {
    final photos = ref.read(progressPhotosProvider).value ?? const [];
    if (photos.isEmpty) return null;
    final chosen = photos.firstWhere(
      (p) => p.pose == PhotoPose.front,
      orElse: () => photos.first,
    );
    try {
      final repository = ref.read(progressPhotoRepositoryProvider);
      final file = File(await repository.pathOf(chosen));
      return file.existsSync() ? await file.readAsBytes() : null;
    } catch (_) {
      return null;
    }
  }
}

class _ShareToggle extends StatelessWidget {
  const _ShareToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      activeThumbColor: _kPurple,
      title: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 14.5),
      ),
    );
  }
}
