import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../core/utils/angle_calculator.dart';
import 'crunch_analyzer.dart' show CrunchResult, CrunchState;
import 'pose_analyzer.dart';

/// Reps counted when the user lifts both legs from horizontal (~180°
/// shoulder-hip-ankle) to vertical (~90°). Re-uses the same state-machine
/// shape as [CrunchAnalyzer]: DOWN → UP increments. Mirror it for
/// hanging leg raises (the angle math is identical).
class LegRaiseAnalyzer implements PoseAnalyzer {
  LegRaiseAnalyzer({
    this.downThreshold = 150.0,
    this.upThreshold = 110.0,
    this.minRepInterval = const Duration(milliseconds: 1100),
  });

  final double downThreshold;
  final double upThreshold;
  final Duration minRepInterval;

  int _reps = 0;
  CrunchState _state = CrunchState.unknown;
  DateTime? _lastRepTime;

  @override
  void reset() {
    _reps = 0;
    _state = CrunchState.unknown;
    _lastRepTime = null;
  }

  @override
  CrunchResult analyze(Pose pose) {
    final shoulder = _pickHigher(
        pose, PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
    final hip =
        _pickHigher(pose, PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);
    final ankle = _pickHigher(
        pose, PoseLandmarkType.leftAnkle, PoseLandmarkType.rightAnkle);

    if (shoulder == null || hip == null || ankle == null) {
      return CrunchResult(
        reps: _reps,
        state: _state,
        torsoAngle: null,
        neckAngle: null,
        formWarning: null,
        repJustCompleted: false,
      );
    }

    final hipAngle = AngleCalculator.between(shoulder, hip, ankle);
    final previousState = _state;
    var repJustCompleted = false;

    if (hipAngle > downThreshold) {
      _state = CrunchState.down;
    } else if (hipAngle < upThreshold) {
      if (previousState == CrunchState.down) {
        final now = DateTime.now();
        final last = _lastRepTime;
        if (last == null || now.difference(last) >= minRepInterval) {
          _reps += 1;
          repJustCompleted = true;
          _lastRepTime = now;
        }
      }
      _state = CrunchState.up;
    }

    return CrunchResult(
      reps: _reps,
      state: _state,
      torsoAngle: hipAngle,
      neckAngle: null,
      formWarning: null,
      repJustCompleted: repJustCompleted,
    );
  }
}

/// Detects torso rotation by tracking the displacement of the
/// shoulder midpoint relative to the hip midpoint. A "rep" is a
/// complete left↔right swing.
///
/// Tier-B.10 · the previous implementation only read the x-offset,
/// which assumes the user faces the camera. For the natural side-
/// camera Russian twist setup (camera placed perpendicular to the
/// user's sitting plane), the rotation happens along z — the user's
/// torso swings TOWARD and AWAY from the camera — and the x-offset
/// barely moves.
///
/// The fix: compute BOTH x and z offsets per frame and use the
/// dominant axis (whichever has the larger absolute displacement
/// over the rep cycle). The dominant axis is re-elected on every
/// frame, so a user changing camera setup mid-set (rare but real)
/// is handled transparently.
class RussianTwistAnalyzer implements PoseAnalyzer {
  RussianTwistAnalyzer({
    this.twistFraction = 0.18,
    this.minRepInterval = const Duration(milliseconds: 600),
  });

  /// How far (as a fraction of shoulder width) the shoulder-mid must
  /// drift from the hip-mid along the dominant axis before we
  /// register a side commit. Applied to whichever of x or z is
  /// dominant on the current frame.
  final double twistFraction;
  final Duration minRepInterval;

  int _reps = 0;
  _Side _state = _Side.unknown;
  DateTime? _lastRepTime;

  @override
  void reset() {
    _reps = 0;
    _state = _Side.unknown;
    _lastRepTime = null;
  }

  @override
  CrunchResult analyze(Pose pose) {
    final ls = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rs = pose.landmarks[PoseLandmarkType.rightShoulder];
    final lh = pose.landmarks[PoseLandmarkType.leftHip];
    final rh = pose.landmarks[PoseLandmarkType.rightHip];
    if (ls == null || rs == null || lh == null || rh == null) {
      return _empty();
    }

    final shoulderWidth = (ls.x - rs.x).abs();
    if (shoulderWidth < 1) return _empty();

    // Front-camera (or close-to-front) signal: x-offset between
    // shoulder midpoint and hip midpoint.
    final shoulderMidX = (ls.x + rs.x) / 2;
    final hipMidX = (lh.x + rh.x) / 2;
    final xOffset = shoulderMidX - hipMidX;

    // Side-camera signal: z-offset on the same axis. BlazePose's z
    // is on roughly the same scale as x/y, so the same shoulder-
    // width normalisation works for both axes.
    final shoulderMidZ = (ls.z + rs.z) / 2;
    final hipMidZ = (lh.z + rh.z) / 2;
    final zOffset = shoulderMidZ - hipMidZ;

    // Pick the dominant axis on this frame. Whichever signal is
    // currently larger in magnitude is the one driving the rotation
    // — usually camera-orientation-stable across a set, but elected
    // per-frame to handle setup shifts.
    final useZ = zOffset.abs() > xOffset.abs();
    final offset = useZ ? zOffset : xOffset;
    final threshold = shoulderWidth * twistFraction;

    final previous = _state;
    _Side current = previous;
    if (offset < -threshold) {
      current = _Side.left;
    } else if (offset > threshold) {
      current = _Side.right;
    }

    var repJustCompleted = false;
    if (current != previous &&
        previous != _Side.unknown &&
        current != _Side.unknown) {
      final now = DateTime.now();
      final last = _lastRepTime;
      if (last == null || now.difference(last) >= minRepInterval) {
        _reps += 1;
        repJustCompleted = true;
        _lastRepTime = now;
      }
    }
    _state = current;

    // Map the side to the existing CrunchState enum so the UI label still
    // renders something coherent ("DOWN" = left, "UP" = right).
    final mappedState = switch (current) {
      _Side.unknown => CrunchState.unknown,
      _Side.left => CrunchState.down,
      _Side.right => CrunchState.up,
    };
    return CrunchResult(
      reps: _reps,
      state: mappedState,
      torsoAngle: offset,
      neckAngle: null,
      formWarning: null,
      repJustCompleted: repJustCompleted,
    );
  }

  CrunchResult _empty() => CrunchResult(
        reps: _reps,
        state: _state == _Side.unknown
            ? CrunchState.unknown
            : (_state == _Side.left ? CrunchState.down : CrunchState.up),
        torsoAngle: null,
        neckAngle: null,
        formWarning: null,
        repJustCompleted: false,
      );
}

/// Plank-position alternating knee drives. Each cycle (knee-in then back)
/// is one rep — implemented by tracking which knee is "active" (driven
/// forward toward the chest) and counting on L↔R hand-offs.
///
/// Tier-B.3 · the previous 2D-distance check (knee-to-same-side-shoulder
/// distance under a torso-length fraction) systematically undercounted
/// in the typical front-facing camera setup because the knee comes IN
/// toward the chest along the **z** axis. From the camera's POV the
/// knee's 2D coordinates barely move; only its z (depth) decreases.
///
/// New signal: per-side `knee.z - hip.z`. BlazePose's z component is
/// approximately on the same scale as x/y, so we normalise the
/// active-threshold by the 2D torso length and gate at -0.25 × torso
/// length (knee closer to camera than hip by a quarter of torso
/// height). A 2D-distance fallback is preserved for the case where
/// the front camera is replaced with a side-angle setup (z signal
/// nearly zero, 2D knee-to-shoulder distance is the dominant signal).
class MountainClimberAnalyzer implements PoseAnalyzer {
  MountainClimberAnalyzer({
    this.zFraction = 0.25,
    this.activeFraction = 0.55,
    this.minRepInterval = const Duration(milliseconds: 350),
  });

  /// A knee is "active in z" when `hip.z - knee.z > torsoLength × zFraction`
  /// — i.e. the knee is forward of the hip plane by 25 % of torso length.
  final double zFraction;

  /// 2D fallback: a knee is "active in xy" when its 2D distance to the
  /// same-side shoulder drops below `torsoLength × activeFraction`.
  /// Preserved for side-camera setups where z is unreliable.
  final double activeFraction;

  final Duration minRepInterval;

  int _reps = 0;
  _Side _state = _Side.unknown;
  DateTime? _lastRepTime;

  @override
  void reset() {
    _reps = 0;
    _state = _Side.unknown;
    _lastRepTime = null;
  }

  @override
  CrunchResult analyze(Pose pose) {
    final ls = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rs = pose.landmarks[PoseLandmarkType.rightShoulder];
    final lh = pose.landmarks[PoseLandmarkType.leftHip];
    final rh = pose.landmarks[PoseLandmarkType.rightHip];
    final lk = pose.landmarks[PoseLandmarkType.leftKnee];
    final rk = pose.landmarks[PoseLandmarkType.rightKnee];
    if (ls == null ||
        rs == null ||
        lh == null ||
        rh == null ||
        lk == null ||
        rk == null) {
      return _empty();
    }

    final torsoLength = math.max(
      _distance(ls, lh),
      _distance(rs, rh),
    );
    if (torsoLength < 1) return _empty();

    // Primary signal: knee.z relative to hip.z, normalised by 2D torso
    // length. Front-camera mountain climbers move the knee toward the
    // camera (decreasing z), which the previous 2D-distance check
    // missed.
    final leftZDelta = lh.z - lk.z; // positive when knee is closer to camera
    final rightZDelta = rh.z - rk.z;
    final zThreshold = torsoLength * zFraction;
    final leftActiveZ = leftZDelta > zThreshold;
    final rightActiveZ = rightZDelta > zThreshold;

    // Fallback signal: 2D distance from knee to same-side shoulder.
    // Catches the side-camera setup where the depth axis is parallel
    // to the camera plane and z barely changes.
    final leftActive2D =
        _distance(lk, ls) < torsoLength * activeFraction;
    final rightActive2D =
        _distance(rk, rs) < torsoLength * activeFraction;

    // A knee is "active" if EITHER signal fires. Combining them is the
    // safest way to handle mixed camera orientations without a runtime
    // calibration step.
    final leftActive = leftActiveZ || leftActive2D;
    final rightActive = rightActiveZ || rightActive2D;

    _Side current = _state;
    if (leftActive && !rightActive) current = _Side.left;
    if (rightActive && !leftActive) current = _Side.right;

    var repJustCompleted = false;
    if (current != _state &&
        _state != _Side.unknown &&
        current != _Side.unknown) {
      final now = DateTime.now();
      final last = _lastRepTime;
      if (last == null || now.difference(last) >= minRepInterval) {
        _reps += 1;
        repJustCompleted = true;
        _lastRepTime = now;
      }
    }
    _state = current;

    return CrunchResult(
      reps: _reps,
      state: switch (current) {
        _Side.unknown => CrunchState.unknown,
        _Side.left => CrunchState.down,
        _Side.right => CrunchState.up,
      },
      torsoAngle: null,
      neckAngle: null,
      formWarning: null,
      repJustCompleted: repJustCompleted,
    );
  }

  CrunchResult _empty() => CrunchResult(
        reps: _reps,
        state: CrunchState.unknown,
        torsoAngle: null,
        neckAngle: null,
        formWarning: null,
        repJustCompleted: false,
      );
}

/// Bicycle crunch: alternating opposite-elbow-to-knee touches. Tracks the
/// shorter of the two cross-pair distances (LE↔RK vs RE↔LK); when the
/// dominant pair flips, that's a rep.
class BicycleCrunchAnalyzer implements PoseAnalyzer {
  BicycleCrunchAnalyzer({
    this.activeFraction = 0.5,
    this.minRepInterval = const Duration(milliseconds: 500),
  });

  final double activeFraction;
  final Duration minRepInterval;

  int _reps = 0;
  _Side _state = _Side.unknown;
  DateTime? _lastRepTime;

  @override
  void reset() {
    _reps = 0;
    _state = _Side.unknown;
    _lastRepTime = null;
  }

  @override
  CrunchResult analyze(Pose pose) {
    final le = pose.landmarks[PoseLandmarkType.leftElbow];
    final re = pose.landmarks[PoseLandmarkType.rightElbow];
    final lk = pose.landmarks[PoseLandmarkType.leftKnee];
    final rk = pose.landmarks[PoseLandmarkType.rightKnee];
    final ls = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rs = pose.landmarks[PoseLandmarkType.rightShoulder];
    if (le == null ||
        re == null ||
        lk == null ||
        rk == null ||
        ls == null ||
        rs == null) {
      return _empty();
    }

    final reference = _distance(ls, rs);
    if (reference < 1) return _empty();

    final leftPair = _distance(le, rk); // L elbow ↔ R knee
    final rightPair = _distance(re, lk); // R elbow ↔ L knee
    final threshold = reference * activeFraction;

    _Side current = _state;
    if (leftPair < threshold && rightPair > threshold) {
      current = _Side.left;
    } else if (rightPair < threshold && leftPair > threshold) {
      current = _Side.right;
    }

    var repJustCompleted = false;
    if (current != _state &&
        _state != _Side.unknown &&
        current != _Side.unknown) {
      final now = DateTime.now();
      final last = _lastRepTime;
      if (last == null || now.difference(last) >= minRepInterval) {
        _reps += 1;
        repJustCompleted = true;
        _lastRepTime = now;
      }
    }
    _state = current;

    return CrunchResult(
      reps: _reps,
      state: switch (current) {
        _Side.unknown => CrunchState.unknown,
        _Side.left => CrunchState.down,
        _Side.right => CrunchState.up,
      },
      torsoAngle: null,
      neckAngle: null,
      formWarning: null,
      repJustCompleted: repJustCompleted,
    );
  }

  CrunchResult _empty() => CrunchResult(
        reps: _reps,
        state: CrunchState.unknown,
        torsoAngle: null,
        neckAngle: null,
        formWarning: null,
        repJustCompleted: false,
      );
}

/// Lying flutter kicks. Counts a rep each time the lifted leg switches.
/// Uses the relative ankle-y vs hip-y delta: a "lifted" leg has its ankle
/// closer (smaller y in image space) to the hip line than the resting one.
///
/// Tier-B.6 · the previous `minDelta = 12.0` was an absolute pixel
/// threshold. At close camera distance 12 px is a tiny leg motion and
/// noise triggers reps; at far camera distance 12 px is a huge leg
/// motion that the user struggles to reach. The threshold is now
/// expressed as [minDeltaFraction] of the shoulder-to-ankle vertical
/// distance — a scale that's stable across camera setups.
class FlutterKickAnalyzer implements PoseAnalyzer {
  FlutterKickAnalyzer({
    this.minDeltaFraction = 0.04,
    this.minRepInterval = const Duration(milliseconds: 350),
  });

  /// Minimum ankle-y separation as a fraction of the user's
  /// shoulder-to-ankle 2D distance. 0.04 ≈ 4 % of body length
  /// vertically — empirically the smallest visible leg flutter that
  /// reads as a deliberate kick rather than a resting frame jitter.
  final double minDeltaFraction;

  final Duration minRepInterval;

  int _reps = 0;
  _Side _state = _Side.unknown;
  DateTime? _lastRepTime;

  @override
  void reset() {
    _reps = 0;
    _state = _Side.unknown;
    _lastRepTime = null;
  }

  @override
  CrunchResult analyze(Pose pose) {
    final la = pose.landmarks[PoseLandmarkType.leftAnkle];
    final ra = pose.landmarks[PoseLandmarkType.rightAnkle];
    if (la == null || ra == null) return _empty();

    // Scale reference: shoulder-to-ankle vertical distance. We pick
    // the higher-likelihood shoulder so a partially-occluded body
    // (one arm tucked under the head) still calibrates cleanly. The
    // anchor ankle for the scale is the average of left+right ankle
    // y-coordinates; that way a moving leg doesn't shift the
    // reference between frames.
    final shoulder = _pickHigher(
        pose, PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
    if (shoulder == null) return _empty();
    final ankleMidY = (la.y + ra.y) / 2;
    final scale = (ankleMidY - shoulder.y).abs();
    if (scale < 1) return _empty();
    final minDelta = scale * minDeltaFraction;

    final delta = la.y - ra.y;
    _Side current = _state;
    if (delta < -minDelta) {
      // Left ankle is higher in image coords (smaller y) → left leg lifted.
      current = _Side.left;
    } else if (delta > minDelta) {
      current = _Side.right;
    }

    var repJustCompleted = false;
    if (current != _state &&
        _state != _Side.unknown &&
        current != _Side.unknown) {
      final now = DateTime.now();
      final last = _lastRepTime;
      if (last == null || now.difference(last) >= minRepInterval) {
        _reps += 1;
        repJustCompleted = true;
        _lastRepTime = now;
      }
    }
    _state = current;

    return CrunchResult(
      reps: _reps,
      state: switch (current) {
        _Side.unknown => CrunchState.unknown,
        _Side.left => CrunchState.down,
        _Side.right => CrunchState.up,
      },
      torsoAngle: delta,
      neckAngle: null,
      formWarning: null,
      repJustCompleted: repJustCompleted,
    );
  }

  CrunchResult _empty() => CrunchResult(
        reps: _reps,
        state: CrunchState.unknown,
        torsoAngle: null,
        neckAngle: null,
        formWarning: null,
        repJustCompleted: false,
      );
}

/// Plank is time-based — there is no rep to count. The analyzer only
/// surfaces a posture warning when the body sags (shoulder-hip-ankle
/// breaks below ~155°). Throttled internally so TTS isn't spammed.
///
/// Tier-B.5 · the sag detector now requires
/// [_violationStreakThreshold] consecutive low-angle frames before
/// emitting a warning. ML Kit's ankle landmark is the noisiest of the
/// three vertices on the line check, and a single transient bad frame
/// (user shifting weight, sock occluding the ankle) was previously
/// enough to fire "Kalçanı düz tut!" even though the actual posture
/// was fine. Consecutive-frame gating absorbs the noise and only
/// fires on real sustained sag.
class PlankAnalyzer implements PoseAnalyzer {
  PlankAnalyzer({
    this.minStraightAngle = 155.0,
    this.warningCooldown = const Duration(seconds: 8),
  });

  final double minStraightAngle;
  final Duration warningCooldown;

  /// Consecutive frames below [minStraightAngle] required before we
  /// commit to "real sag." 5 frames at the camera screen's ~15 FPS
  /// effective rate = ~0.33 s of sustained violation. Short enough
  /// that the user gets timely feedback on actual sag; long enough
  /// to filter single-frame ankle jitter.
  static const int _violationStreakThreshold = 5;

  int _violationStreak = 0;
  DateTime _lastWarning = DateTime.now().subtract(const Duration(seconds: 10));

  @override
  void reset() {
    _violationStreak = 0;
    _lastWarning = DateTime.now().subtract(const Duration(seconds: 10));
  }

  @override
  CrunchResult analyze(Pose pose) {
    final shoulder = _pickHigher(
        pose, PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
    final hip =
        _pickHigher(pose, PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);
    final ankle = _pickHigher(
        pose, PoseLandmarkType.leftAnkle, PoseLandmarkType.rightAnkle);

    if (shoulder == null || hip == null || ankle == null) {
      // Insufficient tracking — neither warn nor reset the streak
      // (we don't want a single dropped frame to wash out a real
      // violation that's been accumulating).
      return const CrunchResult(
        reps: 0,
        state: CrunchState.unknown,
        torsoAngle: null,
        neckAngle: null,
        formWarning: null,
        repJustCompleted: false,
      );
    }

    final lineAngle = AngleCalculator.between(shoulder, hip, ankle);
    String? warning;
    if (lineAngle < minStraightAngle) {
      _violationStreak += 1;
      if (_violationStreak >= _violationStreakThreshold) {
        final now = DateTime.now();
        if (now.difference(_lastWarning) >= warningCooldown) {
          warning = 'Kalçanı düz tut, plank pozisyonunu koru!';
          _lastWarning = now;
        }
        // Reset the streak after a warning fires so the next sustained
        // sag has to re-cross the threshold before re-warning. Combined
        // with the 8 s cooldown, this prevents alarm-spam.
        _violationStreak = 0;
      }
    } else {
      // Clean frame — wipe the streak so a transient bad frame never
      // accumulates toward the threshold.
      _violationStreak = 0;
    }

    return CrunchResult(
      reps: 0,
      state: CrunchState.up,
      torsoAngle: lineAngle,
      neckAngle: null,
      formWarning: warning,
      repJustCompleted: false,
    );
  }
}

/// Neutral analyzer for time-based holds and rhythmic movements that
/// have no meaningful pose check (calf raise, wall sit, superman, high
/// knees, skipping rope). Returns empty results every frame — no form
/// warnings, no reps — and emits an occasional generic encouragement
/// line via `contextualCue`.
///
/// Exists to stop the previous behaviour where these exercises were
/// misrouted to [PlankAnalyzer], which would yell "Kalçanı düz tut,
/// plank pozisyonunu koru" every 8 s because the shoulder-hip-ankle
/// line check is nonsense for a person who is face-down (superman),
/// seated (wall sit), or standing upright (calf raise / skipping rope).
class SilentHoldAnalyzer implements PoseAnalyzer {
  SilentHoldAnalyzer({
    this.encouragementCooldown = const Duration(seconds: 18),
  });

  final Duration encouragementCooldown;

  static const List<String> _encouragements = [
    'Harika gidiyorsun!',
    'Dayan, bırakma!',
    'Güzel ritim, aynen böyle!',
  ];

  int _index = 0;
  DateTime _lastCue = DateTime.now();

  @override
  void reset() {
    _index = 0;
    _lastCue = DateTime.now();
  }

  @override
  CrunchResult analyze(Pose pose) {
    final now = DateTime.now();
    String? cue;
    if (now.difference(_lastCue) >= encouragementCooldown) {
      cue = _encouragements[_index % _encouragements.length];
      _index++;
      _lastCue = now;
    }
    return CrunchResult(
      reps: 0,
      state: CrunchState.up,
      torsoAngle: null,
      neckAngle: null,
      formWarning: null,
      repJustCompleted: false,
      contextualCue: cue,
    );
  }
}

// ----------------------------------------------------------------------------
// Internal helpers shared across the analyzers above.
// ----------------------------------------------------------------------------

enum _Side { unknown, left, right }

double _distance(PoseLandmark a, PoseLandmark b) {
  final dx = a.x - b.x;
  final dy = a.y - b.y;
  return math.sqrt(dx * dx + dy * dy);
}

PoseLandmark? _pickHigher(
  Pose pose,
  PoseLandmarkType left,
  PoseLandmarkType right,
) {
  final l = pose.landmarks[left];
  final r = pose.landmarks[right];
  if (l == null) return r;
  if (r == null) return l;
  return l.likelihood >= r.likelihood ? l : r;
}
