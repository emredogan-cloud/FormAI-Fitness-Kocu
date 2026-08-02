import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../data/progress_photo_repository.dart';
import '../domain/models/progress_photo.dart';
import 'photo_copy.dart';

/// Roadmap Phase 10 (C2) · before and after.
///
/// **A wipe, not a side-by-side.** Two photographs at half width each
/// are two small photographs; a single full-size frame with a draggable
/// divider keeps the body at the size it was shot at, and the eye
/// compares the same region of the same frame instead of tracking
/// between two. It is also the interaction people already know from
/// every other before/after they have seen.
///
/// The comparison is always within one pose — the gallery only offers it
/// on a group — because a front photo against a side photo compares
/// nothing.
///
/// Both ends are user-selectable rather than pinned to first-and-last.
/// "First and latest" is the obvious default and it is wrong as a
/// constraint: somebody who took a bad photo on day one should not be
/// stuck comparing against it forever.
class PhotoComparisonView extends ConsumerStatefulWidget {
  const PhotoComparisonView({super.key, required this.photos});

  /// One pose's photos. Newest first, as the repository returns them.
  final List<ProgressPhoto> photos;

  @override
  ConsumerState<PhotoComparisonView> createState() =>
      _PhotoComparisonViewState();
}

class _PhotoComparisonViewState extends ConsumerState<PhotoComparisonView> {
  /// 0 = show all of the earlier photo, 1 = all of the later one. Starts
  /// centred so both are visible and the control is discoverable without
  /// a hint telling somebody to drag.
  double _split = 0.5;

  late ProgressPhoto _earlier;
  late ProgressPhoto _later;

  @override
  void initState() {
    super.initState();
    // The list arrives newest first, so the oldest and newest are the
    // two ends.
    _later = widget.photos.first;
    _earlier = widget.photos.last;
    ref.read(progressPhotoRepositoryProvider).warmUp().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final repository = ref.watch(progressPhotoRepositoryProvider);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final dates = DateFormat.yMMMd(localeTag);

    final earlierPath = repository.cachedPathOf(_earlier);
    final laterPath = repository.cachedPathOf(_later);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          l10n.photosCompareTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Text(
              poseLabel(l10n, _later.pose),
              style: const TextStyle(color: Color(0x8CFFFFFF), fontSize: 13),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _Wipe(
                  earlierPath: earlierPath,
                  laterPath: laterPath,
                  split: _split,
                  onSplit: (value) => setState(() => _split = value),
                  earlierLabel: l10n.photosCompareEarlier,
                  laterLabel: l10n.photosCompareLater,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _Picker(
              label: l10n.photosCompareEarlier,
              photos: widget.photos,
              selected: _earlier,
              localeTag: localeTag,
              format: dates,
              onChanged: (photo) => setState(() => _earlier = photo),
            ),
            const SizedBox(height: 8),
            _Picker(
              label: l10n.photosCompareLater,
              photos: widget.photos,
              selected: _later,
              localeTag: localeTag,
              format: dates,
              onChanged: (photo) => setState(() => _later = photo),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _Wipe extends StatelessWidget {
  const _Wipe({
    required this.earlierPath,
    required this.laterPath,
    required this.split,
    required this.onSplit,
    required this.earlierLabel,
    required this.laterLabel,
  });

  final String? earlierPath;
  final String? laterPath;
  final double split;
  final ValueChanged<double> onSplit;
  final String earlierLabel;
  final String laterLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        void update(Offset position) =>
            onSplit((position.dx / width).clamp(0.0, 1.0));

        return GestureDetector(
          onHorizontalDragUpdate: (d) => update(d.localPosition),
          onTapDown: (d) => update(d.localPosition),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: const Color(0xFF0B0B10)),
                _Photo(path: earlierPath),
                // The later photo is clipped to the right of the split.
                // `ClipRect` with a rect rather than two `Positioned`
                // halves, because clipping preserves the image's own
                // geometry — halving the width would squash it, and a
                // squashed before/after is a lie about a body.
                ClipRect(
                  clipper: _RightOf(split),
                  child: _Photo(path: laterPath),
                ),
                // NOT PositionedDirectional, on purpose. `split` comes
                // from `localPosition.dx`, which is physical-left
                // relative in every direction — mirroring the divider
                // would send it away from the finger dragging it.
                //
                // The captions below are anchored for the same reason,
                // and it is the same call Phase 8 made about the trend
                // chart's time axis: earlier-to-later runs left to right
                // and does not flip, because flipping it would say the
                // user's history ran backwards.
                Positioned(
                  left: width * split - 1, // rtl-ignore — follows the finger
                  top: 0,
                  bottom: 0,
                  child: Container(width: 2, color: Colors.white),
                ),
                Positioned(
                  left: width * split - 18, // rtl-ignore — follows the finger
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.code_rounded,
                          size: 18, color: Colors.black),
                    ),
                  ),
                ),
                Positioned(
                  left: 10, // rtl-ignore — labels the physical left half
                  top: 10,
                  child: _Caption(text: earlierLabel),
                ),
                Positioned(
                  right: 10, // rtl-ignore — labels the physical right half
                  top: 10,
                  child: _Caption(text: laterLabel),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RightOf extends CustomClipper<Rect> {
  const _RightOf(this.split);

  final double split;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(size.width * split, 0, size.width, size.height);

  @override
  bool shouldReclip(_RightOf old) => old.split != split;
}

class _Photo extends StatelessWidget {
  const _Photo({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    final value = path;
    if (value == null) return const SizedBox.shrink();
    return Image.file(
      File(value),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Picker extends StatelessWidget {
  const _Picker({
    required this.label,
    required this.photos,
    required this.selected,
    required this.localeTag,
    required this.format,
    required this.onChanged,
  });

  final String label;
  final List<ProgressPhoto> photos;
  final ProgressPhoto selected;
  final String localeTag;
  final DateFormat format;
  final ValueChanged<ProgressPhoto> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          SizedBox(
            width: 66,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0x8CFFFFFF),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final photo = photos[index];
                  final active = photo.fileName == selected.fileName;
                  return Semantics(
                    button: true,
                    selected: active,
                    child: GestureDetector(
                      onTap: () => onChanged(photo),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: active
                              ? AppColors.neon.withValues(alpha: 0.18)
                              : Colors.white.withValues(alpha: 0.06),
                          border: Border.all(
                            color: active
                                ? AppColors.neon
                                : Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        child: Text(
                          format.format(photo.recordedAt),
                          style: TextStyle(
                            color: active ? Colors.white : Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
