import '../../../l10n/app_localizations.dart';
import '../domain/models/progress_photo.dart';

/// Roadmap Phase 10 (C2) · the words for a pose.
///
/// Split out of the model for the reason the whole codebase splits copy
/// from data: [PhotoPose.token] is persisted and read back, and a label
/// moves when the app is translated. The switch is exhaustive, so a pose
/// added later cannot ship wordless.
String poseLabel(AppLocalizations l10n, PhotoPose pose) => switch (pose) {
      PhotoPose.front => l10n.photosPoseFront,
      PhotoPose.side => l10n.photosPoseSide,
      PhotoPose.back => l10n.photosPoseBack,
    };
