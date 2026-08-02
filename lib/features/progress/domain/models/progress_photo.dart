/// Roadmap Phase 10 (C2) · a progress photo, as metadata.
///
/// **The bytes are not in here, and that is the design.** This class
/// carries a filename and nothing else about the image; the file lives
/// in the app's private documents directory and is read by path when a
/// screen needs to draw it. Keeping the two apart is what lets the
/// metadata be listed, sorted, exported and — if the user ever opts in —
/// synced, without any of those paths ever touching a photograph.
library;

/// Which view the photo is of.
///
/// A comparison is only meaningful between two photos of the same pose,
/// so this is a key rather than a label: `front` vs `front`, never
/// `front` vs `side`. The token is persisted and must not change.
enum PhotoPose {
  front('front'),
  side('side'),
  back('back');

  const PhotoPose(this.token);

  final String token;

  static PhotoPose fromToken(String? token) {
    for (final pose in PhotoPose.values) {
      if (pose.token == token) return pose;
    }
    // An unknown token means a newer build wrote a pose this one does
    // not have. Front is the honest fallback: it is the pose every
    // capture flow offers first, and dropping the row would lose a
    // photograph the user still has on disk.
    return PhotoPose.front;
  }
}

class ProgressPhoto {
  const ProgressPhoto({
    required this.recordedAt,
    required this.pose,
    required this.fileName,
  });

  /// A moment, not a day — unlike [BodyMetric]. Three poses can be
  /// captured a minute apart, and a comparison wants them ordered.
  final DateTime recordedAt;

  final PhotoPose pose;

  /// The file's name inside the app-private photo directory. A NAME, not
  /// a path: the documents directory's absolute path changes between
  /// installs and on iOS between launches, so a stored absolute path is
  /// a broken image waiting to happen.
  final String fileName;

  Map<String, dynamic> toJson() => {
        'recorded_at': recordedAt.toUtc().toIso8601String(),
        'pose': pose.token,
        'file_name': fileName,
      };

  /// Throws [FormatException] on an entry that cannot be trusted, so the
  /// repository can drop that one row and keep the rest — the same
  /// tolerance `SessionLog` has.
  factory ProgressPhoto.fromJson(Map<String, dynamic> json) {
    final rawAt = json['recorded_at'];
    final at = rawAt is String ? DateTime.tryParse(rawAt) : null;
    if (at == null) {
      throw const FormatException(
          'ProgressPhoto.recorded_at missing or unparseable'); // i18n-ignore — parse diagnostic
    }
    final name = json['file_name'];
    if (name is! String || name.isEmpty) {
      throw const FormatException(
          'ProgressPhoto.file_name missing'); // i18n-ignore — parse diagnostic
    }
    return ProgressPhoto(
      recordedAt: at.toLocal(),
      pose: PhotoPose.fromToken(json['pose'] as String?),
      fileName: name,
    );
  }
}
