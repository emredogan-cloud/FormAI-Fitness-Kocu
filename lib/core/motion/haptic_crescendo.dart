import 'package:flutter/animation.dart';
import 'package:flutter/scheduler.dart';

import '../utils/app_haptics.dart';

/// Schedules light → medium → heavy haptic impacts across an
/// [Animation]'s 0..1 progress.
///
/// Used by the final-act sequence (analysis_illusion → dynamic_report
/// → pre_paywall_summary) to escalate the felt intensity of the wizard
/// without the user consciously noticing why each step lands harder
/// than the last. The audit (§8.4) calls out the absence of a
/// crescendo pattern — this is the implementation.
///
/// Wire by calling [HapticCrescendo.attach] with the animation, a
/// readable accessor for its current value, and the breakpoint /
/// impact lists. Defaults fire at 0.0 / 0.33 / 0.66 / 1.0 with light /
/// medium / heavy / light intensity.
abstract final class HapticCrescendo {
  /// Subscribe to [animation] and fire the matching haptic each time
  /// its value crosses a breakpoint going forward. Returns a function
  /// that detaches the listener — call it from the host widget's
  /// `dispose()` to avoid leaks.
  static VoidCallback attach(
    Animation<double> animation, {
    List<double> breakpoints = const [0.0, 0.33, 0.66, 1.0],
    List<HapticIntensity> impacts = const [
      HapticIntensity.light,
      HapticIntensity.medium,
      HapticIntensity.heavy,
      HapticIntensity.light,
    ],
  }) {
    assert(breakpoints.length == impacts.length);
    var lastIdx = -1;
    void listener() {
      final v = animation.value;
      var hit = -1;
      for (var i = 0; i < breakpoints.length; i++) {
        if (v >= breakpoints[i]) hit = i;
      }
      if (hit > lastIdx) {
        final impact = impacts[hit];
        // Defer the haptic to after the current frame so it doesn't
        // compete with the frame's draw cost. Cheap on Android, free
        // on iOS.
        SchedulerBinding.instance.addPostFrameCallback((_) {
          switch (impact) {
            case HapticIntensity.light:
              AppHaptics.secondaryTap();
            case HapticIntensity.medium:
              AppHaptics.primaryCta();
            case HapticIntensity.heavy:
              AppHaptics.milestone();
          }
        });
        lastIdx = hit;
      }
    }

    animation.addListener(listener);
    return () => animation.removeListener(listener);
  }
}

enum HapticIntensity { light, medium, heavy }
