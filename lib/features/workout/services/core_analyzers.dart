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

/// Detects torso rotation by tracking the horizontal displacement of the
/// shoulder midpoint relative to the hip midpoint. A "rep" is a complete
/// left↔right swing. Works for the seated front-facing-camera setup —
/// a side-camera deployment would benefit from explicit z-axis input.
class RussianTwistAnalyzer implements PoseAnalyzer {
  RussianTwistAnalyzer({
    this.twistFraction = 0.18,
    this.minRepInterval = const Duration(milliseconds: 600),
  });

  /// How far (as a fraction of shoulder width) the shoulder-mid must drift
  /// from the hip-mid before we register a side commit.
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

    final shoulderMidX = (ls.x + rs.x) / 2;
    final hipMidX = (lh.x + rh.x) / 2;
    final offset = shoulderMidX - hipMidX;
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
/// is one rep — implemented by tracking which knee is "active" (closer to
/// its same-side shoulder than the resting threshold) and counting on
/// L↔R hand-offs.
class MountainClimberAnalyzer implements PoseAnalyzer {
  MountainClimberAnalyzer({
    this.activeFraction = 0.55,
    this.minRepInterval = const Duration(milliseconds: 350),
  });

  /// A knee is "active" when its distance to the same-side shoulder drops
  /// below this fraction of the resting torso length (shoulder→hip).
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

    final leftActive = _distance(lk, ls) < torsoLength * activeFraction;
    final rightActive = _distance(rk, rs) < torsoLength * activeFraction;

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
class FlutterKickAnalyzer implements PoseAnalyzer {
  FlutterKickAnalyzer({
    this.minDelta = 12.0,
    this.minRepInterval = const Duration(milliseconds: 350),
  });

  /// Minimum y-difference between the two ankles (in pixels) before we
  /// commit to a side. Filters out the stand-still resting frame.
  final double minDelta;
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
class PlankAnalyzer implements PoseAnalyzer {
  PlankAnalyzer({
    this.minStraightAngle = 155.0,
    this.warningCooldown = const Duration(seconds: 8),
  });

  final double minStraightAngle;
  final Duration warningCooldown;

  DateTime _lastWarning = DateTime.now().subtract(const Duration(seconds: 10));

  @override
  void reset() {
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
      final now = DateTime.now();
      if (now.difference(_lastWarning) >= warningCooldown) {
        warning = 'Kalçanı düz tut, plank pozisyonunu koru!';
        _lastWarning = now;
      }
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
