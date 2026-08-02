import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../data/progress_photo_repository.dart';
import '../domain/models/progress_photo.dart';
import 'photo_capture_screen.dart';
import 'photo_comparison_view.dart';
import 'photo_copy.dart';

/// Roadmap Phase 10 (C2) · the photo gallery, and the way into a
/// comparison.
///
/// Grouped by pose rather than by date, which is the opposite of how the
/// entries list on "Your body" is organised — and deliberately so. A
/// date-ordered grid of front, side and back photos interleaves three
/// series that are only meaningful against themselves; grouping by pose
/// puts each series in its own row and makes "compare these two" the
/// obvious next action rather than something the user has to construct.
///
/// **Dark-only**, like the report and "Your body". This screen shows
/// photographs of the user's body and nothing else; a light chrome
/// around them would be the only bright thing in the app's own
/// photographic surfaces.
class PhotoGalleryScreen extends ConsumerStatefulWidget {
  const PhotoGalleryScreen({super.key});

  @override
  ConsumerState<PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends ConsumerState<PhotoGalleryScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(progressPhotoRepositoryProvider).warmUp().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _capture() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PhotoCaptureScreen()),
    );
    ref.invalidate(progressPhotosProvider);
  }

  /// Deletion is confirmed, and the confirmation says WHY it is final.
  /// "It's only on this phone, so there's no copy to restore" is the
  /// privacy promise stated as a consequence — which is the honest way
  /// to present it, because it is the same fact.
  Future<void> _delete(ProgressPhoto photo) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _kCard,
        title: Text(l10n.photosDeleteConfirmTitle,
            style: const TextStyle(color: Colors.white)),
        content: Text(l10n.photosDeleteConfirmBody,
            style: const TextStyle(color: _kMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.photosDeleteConfirmAction,
                style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(progressPhotoRepositoryProvider).delete(photo);
    ref.invalidate(progressPhotosProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).photosDeleted)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final photos = ref.watch(progressPhotosProvider);

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(l10n.photosTitle,
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.neon,
        foregroundColor: Colors.white,
        onPressed: _capture,
        icon: const Icon(Icons.camera_alt_rounded),
        label: Text(l10n.photosAdd),
      ),
      body: photos.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.neon)),
        error: (_, __) => _Empty(onAdd: _capture),
        data: (list) => list.isEmpty
            ? _Empty(onAdd: _capture)
            : _Grouped(
                photos: list,
                onDelete: _delete,
              ),
      ),
    );
  }
}

const Color _kBg = Color(0xFF000000);
const Color _kCard = Color(0xFF0B0B10);
const Color _kMuted = Color(0x8CFFFFFF);
const Color _kFaint = Color(0x5CFFFFFF);

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_camera_outlined, size: 44, color: _kFaint),
            const SizedBox(height: 18),
            Text(
              l10n.photosEmptyTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.photosEmptyBody,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: _kMuted, fontSize: 13.5, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _Grouped extends ConsumerWidget {
  const _Grouped({required this.photos, required this.onDelete});

  final List<ProgressPhoto> photos;
  final ValueChanged<ProgressPhoto> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final repository = ref.watch(progressPhotoRepositoryProvider);
    final localeTag = Localizations.localeOf(context).toLanguageTag();

    // Photos exist but no pose has two of them, so no Compare button is
    // offered anywhere. Saying why is better than leaving somebody to
    // work out that the feature they came for is missing.
    final canCompareAny = PhotoPose.values
        .any((p) => photos.where((x) => x.pose == p).length > 1);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
      children: [
        if (!canCompareAny)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              l10n.photosCompareNeedsTwo,
              style:
                  const TextStyle(color: _kFaint, fontSize: 12.5, height: 1.4),
            ),
          ),
        for (final pose in PhotoPose.values)
          if (photos.where((p) => p.pose == pose).toList() case final group
              when group.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      poseLabel(l10n, pose),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    l10n.photosCount(group.length),
                    style: const TextStyle(color: _kFaint, fontSize: 12.5),
                  ),
                  // Two of the same pose is what a comparison needs. The
                  // action is absent rather than disabled below that —
                  // a greyed-out button is a thing to wonder about.
                  if (group.length >= 2) ...[
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: () => _openCompare(context, group),
                      child: Text(l10n.photosCompare),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(
              height: 168,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: group.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) => _Tile(
                  photo: group[index],
                  path: repository.cachedPathOf(group[index]),
                  localeTag: localeTag,
                  onDelete: () => onDelete(group[index]),
                ),
              ),
            ),
          ],
      ],
    );
  }

  void _openCompare(BuildContext context, List<ProgressPhoto> group) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotoComparisonView(photos: group),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.photo,
    required this.path,
    required this.localeTag,
    required this.onDelete,
  });

  final ProgressPhoto photo;
  final String? path;
  final String localeTag;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: 118,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: _kCard),
                  if (path != null)
                    Image.file(
                      File(path!),
                      fit: BoxFit.cover,
                      // A file that has gone leaves the card, never an
                      // error glyph over somebody's body.
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  PositionedDirectional(
                    top: 2,
                    end: 2,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: IconButton(
                        iconSize: 17,
                        tooltip: l10n.photosDelete,
                        color: Colors.white,
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat.MMMd(localeTag).format(photo.recordedAt),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _kMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
